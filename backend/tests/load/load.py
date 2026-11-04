#!/usr/bin/env python3
"""Queued FF07 preparation. Default invocation is offline selftest, NEVER load.

Direct PostgreSQL ingestion-function benchmark, NOT HTTP/Android capacity proof.
No fixture creation, migrations, reset, cleanup, or privileged writes exist here.
"""
from __future__ import annotations
import argparse
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import queue
import re
import resource
import stat
import subprocess
import sys
import threading
import time
from uuid import UUID, uuid4

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent


def percentile(values, q):
    """Linear interpolation, rank=(n-1)*q/100; milliseconds stay milliseconds."""
    if not 0 <= q <= 100:
        raise ValueError('percentile outside 0..100')
    if not values:
        return None
    a = sorted(values)
    rank = (len(a) - 1) * q / 100
    lo, hi = math.floor(rank), math.ceil(rank)
    return a[lo] + (a[hi] - a[lo]) * (rank - lo)


def summary(values):
    return {f'p{q}': percentile(values, q) for q in (50, 95, 99)}


def validate_target(v, proof=False):
    allowed = {'host', 'hostaddr', 'port', 'dbname', 'user', 'password', 'sslmode'}
    if (set(v) - allowed or v.get('host') not in ('127.0.0.1', '::1')
            or v.get('hostaddr', v.get('host')) != v.get('host')
            or v.get('port') not in ('15432', '15433', '15434')
            or v.get('dbname') != 'madalasa_alarka_test'
            or v.get('user') != ('madalasa_migrator' if proof else 'madalasa_dev')
            or v.get('sslmode', 'disable') not in ('disable', 'require')):
        raise ValueError('Explicit dedicated synthetic loopback test identity required')


def validate_bounds(clients, pool, ramp, batches, batch_size, seconds):
    if (not 1 <= clients <= 108 or not 1 <= pool <= 16 or not ramp or len(ramp) > 8
            or ramp != sorted(set(ramp)) or not all(1 <= n <= clients for n in ramp)
            or not 1 <= batches <= 100 or not 1 <= batch_size <= 500
            or not 1 <= seconds <= 300 or clients * batches * batch_size * len(ramp) > 100000):
        raise ValueError('Bound exceeded: 108 clients/16 connections/8 stages/100000 events/300s')


def read_private(path):
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    except OSError:
        raise ValueError('Private fixture unavailable or symlink refused') from None
    with os.fdopen(fd) as f:
        s = os.fstat(f.fileno())
        if not stat.S_ISREG(s.st_mode) or s.st_uid != os.getuid() or s.st_mode & 0o077 or s.st_size > 1048576:
            raise ValueError('Fixture must be an owner-only regular file under 1 MiB')
        return json.load(f)


def validate_fixture(f, clients):
    keys = {'synthetic_only', 'runtime_dsn', 'proof_dsn', 'device_guc', 'devices'}
    if (set(f) != keys or f['synthetic_only'] is not True
            or not all(isinstance(f[k], str) and f[k] for k in ('runtime_dsn', 'proof_dsn', 'device_guc'))
            or f['device_guc'] != 'ap.device_credential_sha256'
            or not isinstance(f['devices'], list) or len(f['devices']) != clients):
        raise ValueError('Invalid private synthetic fixture schema')
    ids, children, credentials = set(), set(), set()
    for d in f['devices']:
        if (set(d) != {'device_id', 'child_id', 'credential', 'sequence_start'}
                or not isinstance(d['credential'], str) or not 16 <= len(d['credential']) <= 4096
                or type(d['sequence_start']) is not int or not 1 <= d['sequence_start'] <= 2**62):
            raise ValueError('Invalid device fixture')
        for k in ('device_id', 'child_id'):
            if str(UUID(d[k])) != d[k]:
                raise ValueError('Canonical UUID required')
        if d['device_id'] in ids or d['child_id'] in children or d['credential'] in credentials:
            raise ValueError('Distinct synthetic child/device credentials required')
        ids.add(d['device_id']); children.add(d['child_id']); credentials.add(d['credential'])


def source_chain(root=ROOT):
    path = root / 'backend/persistence/migration-lineages.json'
    if not path.is_file():
        raise ValueError('Validated 0025..0027 source chain absent; NOT_RUN')
    entries = json.loads(path.read_text())['migrations']
    selected = []
    for n in (25, 26, 27):
        found = [e for e in entries if e['id'] == f'v2:{n:04d}']
        # Repository migrations are often published:false while under review;
        # the pinned checksum and the database's APPLIED history are the proof
        # that matters here, not a release flag.
        if len(found) != 1:
            raise ValueError('Validated 0025..0027 source chain absent; NOT_RUN')
        e = found[0]
        p = (root / e['path']).resolve()
        if not p.is_relative_to(root.resolve()) or not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest() != e['sha256']:
            raise ValueError('0025..0027 checksum drift; NOT_RUN')
        selected.append(e)
    return entries, selected


def validate_container(item, port):
    labels = item.get('Config', {}).get('Labels', {})
    owned = labels.get('com.madalasa.local-db-root') == str(ROOT)
    owned = owned or any(m.get('Source') == str(ROOT / '.local-db/pgdata')
                         and m.get('Destination') == '/var/lib/postgresql/data'
                         for m in item.get('Mounts', []))
    bindings = item.get('HostConfig', {}).get('PortBindings', {}).get('5432/tcp', [])
    if (labels.get('com.madalasa.local-db') != 'synthetic' or not owned
            or not item.get('State', {}).get('Running') or not bindings
            or any(b.get('HostIp') not in ('127.0.0.1', '::1') or b.get('HostPort') != port for b in bindings)):
        raise ValueError('Target must be a running checkout-owned synthetic loopback container')


def docker(args):
    return subprocess.run(['docker', *args], capture_output=True, text=True, check=True, timeout=15).stdout


def inspect_container(name, port):
    if name not in ('madalasa-local-postgres', 'madalasa-memory-test-postgres', 'madalasa-pr11-test-postgres'):
        raise ValueError('Unrecognized synthetic container')
    # Deliberately do not read Config.Env (may contain credentials): select the
    # non-secret fields from the plain inspect document instead of a template,
    # because Go-template dict expressions fail on null nested values.
    raw = json.loads(docker(['inspect', name]))[0]
    item = {'Id': raw.get('Id'), 'Image': raw.get('Image'), 'State': raw.get('State'),
            'Mounts': raw.get('Mounts'), 'Config': {'Labels': (raw.get('Config') or {}).get('Labels')},
            'HostConfig': {k: (raw.get('HostConfig') or {}).get(k)
                           for k in ('PortBindings', 'Memory', 'NanoCpus')}}
    validate_container(item, port)
    return item


def bind_device(conn, guc, device):
    if guc != 'ap.device_credential_sha256':
        raise ValueError('Unknown 0027 device GUC')
    digest = hashlib.sha256(device['credential'].encode('utf-8')).hexdigest()
    conn.execute("SELECT set_config('ap.session_token','',true),set_config(%s,%s,true)", (guc, digest))
    resolved = conn.execute('SELECT ap_m1.ctx_device(),ap_m1.ctx_principal()').fetchone()
    if not resolved or str(resolved[0]) != device['device_id'] or resolved[1] is not None:
        raise ValueError('0027 credential did not resolve to exact synthetic device')


def parse_container_sample(text):
    cpu, rest = text.split('SYSTEM_MEMORY\n', 1)
    memory, rest = rest.split('NETWORK\n', 1)
    network, rss = rest.split('RSS\n', 1)
    usage = dict(line.split() for line in cpu.splitlines() if len(line.split()) == 2)
    rx = tx = 0
    for line in network.splitlines():
        if ':' in line:
            fields = line.split(':', 1)[1].split()
            rx += int(fields[0]); tx += int(fields[8])
    match = re.search(r'^VmRSS:\s+(\d+) kB$', rss, re.M)
    return {'cpu_usage_usec': int(usage['usage_usec']), 'memory_current_bytes': int(memory.strip()),
            'network_rx_bytes': rx, 'network_tx_bytes': tx,
            'postgres_pid1_rss_bytes': int(match[1]) * 1024 if match else None}


def container_sample(name):
    command = ('cat /sys/fs/cgroup/cpu.stat; printf "SYSTEM_MEMORY\\n"; '
               'cat /sys/fs/cgroup/memory.current; printf "NETWORK\\n"; '
               'cat /proc/net/dev; printf "RSS\\n"; cat /proc/1/status')
    try:
        result = parse_container_sample(docker(['exec', name, 'sh', '-c', command]))
        return dict(result, status='MEASURED', monotonic_seconds=time.monotonic())
    except Exception:
        return {'status': 'NOT_RUN', 'reason': 'cgroup-v2/container counters unavailable'}


def connect(dsn, read_only=False):
    import psycopg
    return psycopg.connect(dsn, connect_timeout=5, application_name='issue32_synthetic_load',
                          tcp_user_timeout=5000, keepalives=1, keepalives_idle=5,
                          keepalives_interval=1, keepalives_count=1,
                          passfile='/dev/null', options='-c statement_timeout=3000 -c lock_timeout=1000'
                          + (' -c default_transaction_read_only=on' if read_only else ''))


def preflight(f, entries, chain):
    from tools.database import manage
    # Use the actual repository manifest/history validator; no alternate lineage.
    if manage.load_migration_manifest() != entries:
        raise ValueError('Repository manifest validation mismatch')
    source = (ROOT / chain[-1]['path']).read_text()
    # Only a literal read in actual 0027 is accepted; never guess a legacy GUC.
    if f['device_guc'] not in re.findall(r"current_setting\s*\(\s*'([^']+)'", source):
        raise ValueError('Actual 0027 credential GUC not found; refuse adapter guess')
    with connect(f['proof_dsn'], read_only=True) as db:
        rows = []
        for table in ('history', 'lineage_history'):
            if db.execute('SELECT to_regclass(%s)', ('ma_migrations.' + table,)).fetchone()[0]:
                rows.append(db.execute('SELECT version,filename,checksum,status FROM ma_migrations.' + table).fetchall())
            else:
                rows.append([])
        applied = manage.validate_migration_history(entries, rows[0], rows[1], True)
        if not {e['id'] for e in chain} <= applied:
            raise ValueError('Target 0025..0027 APPLIED history missing')
        if any(row[3] != 'APPLIED' for group in rows for row in group):
            raise ValueError('Failed migration ledger rows prohibit benchmark')
        db.execute('SELECT ap_m1.assert_role_boundary()')
        # Privileged proof only, always transaction-read-only; never used for ingestion.
        db.execute('SET LOCAL ROLE ap_db_executor')
        if db.execute('SELECT enabled FROM ap_m1.local_test_settings WHERE singleton').fetchone() != (True,):
            raise ValueError('Target lacks explicit synthetic opt-in')
        for d in f['devices']:
            row = db.execute("SELECT c.id::text, c.alias LIKE 'synthetic%%', p.enabled "
                             "FROM ap_m1.devices d JOIN ap_m1.children c ON c.id=d.child_id "
                             "JOIN ap_m1.location_collection_policies p ON p.child_id=c.id WHERE d.id=%s",
                             (d['device_id'],)).fetchone()
            if row != (d['child_id'], True, True):
                raise ValueError('Precreated synthetic child/device/policy proof failed')
            maximum = db.execute('SELECT coalesce(max(sequence),0) FROM ap_m1.location_event_dedup WHERE device_id=%s',
                                 (d['device_id'],)).fetchone()[0]
            if d['sequence_start'] <= maximum:
                raise ValueError('Fixture sequence range already used; parent must reserve fresh range')
        environment = {'postgres_version': db.execute('SHOW server_version').fetchone()[0],
                       'postgis_version': db.execute('SELECT public.postgis_full_version()').fetchone()[0],
                       'settings': {k: db.execute('SHOW ' + k).fetchone()[0] for k in
                                    ('max_connections', 'shared_buffers', 'work_mem', 'synchronous_commit', 'fsync')}}
        db.rollback()
    with connect(f['runtime_dsn'], read_only=True) as db:
        identity = db.execute('SELECT current_database(),session_user,current_user,inet_server_port()').fetchone()
        if identity[:3] != ('madalasa_alarka_test', 'madalasa_dev', 'madalasa_dev') or identity[3] != 5432:
            raise ValueError('Server identity differs from guarded container target')
        # Every credential is resolved, and a deliberately wrong credential must fail.
        for d in f['devices']:
            bind_device(db, f['device_guc'], d)
            db.rollback()
        try:
            bind_device(db, f['device_guc'], dict(f['devices'][0], credential='synthetic-invalid-' + uuid4().hex))
        except Exception:
            db.rollback()
        else:
            raise ValueError('Invalid device credential was accepted')
    return environment


def stage(f, pool, concurrency, args, sequence, deadline):
    from psycopg.types.json import Jsonb
    lock = threading.Lock()
    metrics = {'attempts': 0, 'successes': 0, 'events_committed': 0, 'errors': Counter(),
               'latencies': [], 'success_latencies': [], 'db_times': [], 'queue_times': [],
               'executor_waits': [], 'pool_peak_waiters': 0, 'pool_waiters': 0}
    start = time.monotonic()
    committed_batches = []

    def client(index, device, submitted):
        with lock:
            metrics['executor_waits'].append((time.monotonic() - submitted) * 1000)
        for _ in range(args.batches_per_device):
            if time.monotonic() >= deadline:
                break
            payload = events(args.batch_size, sequence[index])
            sequence[index] += args.batch_size  # Even failed requests consume their range; no destructive retry.
            batch = uuid4()
            began = time.monotonic()
            conn = None
            error = None
            acquired = None
            with lock:
                metrics['attempts'] += 1
                metrics['pool_waiters'] += 1
                metrics['pool_peak_waiters'] = max(metrics['pool_peak_waiters'], metrics['pool_waiters'])
            try:
                conn = pool.get(timeout=min(5, max(0.001, deadline - began)))
                acquired = time.monotonic()
                with lock:
                    metrics['pool_waiters'] -= 1
                with conn.transaction():
                    bind_device(conn, f['device_guc'], device)
                    receipt = conn.execute('SELECT ingest_batch_id,accepted_count,duplicate_count,replayed FROM ap_m1.ingest_location_batch_receipt(%s,%s,%s)',
                                           (device['device_id'], batch, Jsonb(payload))).fetchone()
                    if receipt != (batch, len(payload), 0, False):
                        raise ValueError('Unexpected ingestion receipt for fresh synthetic batch')
                # Transaction context committed, not merely submitted.
            except Exception as exc:
                code = getattr(exc, 'sqlstate', None)
                error = code if code and re.fullmatch('[0-9A-Z]{5}', code) else type(exc).__name__
                if conn is not None:
                    try: conn.rollback()
                    except Exception: pass
            finally:
                end = time.monotonic()
                if conn is not None:
                    pool.put(conn)
                with lock:
                    if acquired is None:
                        metrics['pool_waiters'] -= 1
                    metrics['latencies'].append((end - began) * 1000)
                    metrics['queue_times'].append(((acquired or end) - began) * 1000)
                    if acquired is not None:
                        metrics['db_times'].append((end - acquired) * 1000)
                    if error:
                        metrics['errors'][error] += 1
                    else:
                        metrics['successes'] += 1
                        committed_batches.append(batch)
                        metrics['events_committed'] += len(payload)
                        metrics['success_latencies'].append((end - began) * 1000)
            time.sleep(min(args.interval_ms / 1000, max(0, deadline - time.monotonic())))

    with ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures = [executor.submit(client, i, d, time.monotonic()) for i, d in enumerate(f['devices'])]
        for future in futures:
            future.result()
    elapsed = time.monotonic() - start
    return {'_private_batch_ids': committed_batches, 'concurrency': concurrency, 'wall_seconds': elapsed, 'attempts': metrics['attempts'],
            'successes': metrics['successes'], 'events_committed': metrics['events_committed'],
            'errors': dict(metrics['errors']), 'successful_batches_per_second': metrics['successes'] / elapsed,
            'events_per_second': metrics['events_committed'] / elapsed,
            'all_attempt_latency_ms': summary(metrics['latencies']),
            'success_latency_ms': summary(metrics['success_latencies']),
            'db_transaction_ms': summary(metrics['db_times']), 'pool_queue_ms': summary(metrics['queue_times']),
            'executor_wait_ms': summary(metrics['executor_waits']),
            'pool_peak_waiters': metrics['pool_peak_waiters'],
            'deadline_reached': time.monotonic() >= deadline}


def events(count, sequence):
    at = (datetime.now(timezone.utc) - timedelta(seconds=2)).isoformat()
    return [{'event_id': str(uuid4()), 'sequence': sequence + i, 'observed_at': at,
             'latitude': 0.125, 'longitude': 0.25, 'accuracy_m': 5, 'provider': 'SYNTHETIC'}
            for i in range(count)]


def git(*args):
    return subprocess.run(['git', '-C', str(ROOT), *args], capture_output=True, check=True, timeout=10).stdout


def run(args):
    if not args.fixture or not args.container or args.confirm != 'SYNTHETIC_APPEND_ONLY':
        raise ValueError('Explicit fixture, container and SYNTHETIC_APPEND_ONLY acknowledgement required')
    if args.output.parent.resolve() != HERE or args.output.exists() or args.output.is_symlink():
        raise ValueError('Output must be a new file inside the queued harness directory')
    ramp = [int(s) for s in args.ramp.split(',')]
    validate_bounds(args.clients, args.pool, ramp, args.batches_per_device, args.batch_size, args.max_seconds)
    if not 0 <= args.interval_ms <= 10000:
        raise ValueError('Interval must be between 0 and 10000ms')
    entries, chain = source_chain()  # Missing 0026/0027 stops before private-file access.
    if any(k.startswith('PG') for k in os.environ):
        raise ValueError('Ambient libpq PG* configuration prohibited')
    sys.path.insert(0, str(ROOT))
    import psycopg
    f = read_private(args.fixture)
    validate_fixture(f, args.clients)
    targets = [psycopg.conninfo.conninfo_to_dict(f[k]) for k in ('runtime_dsn', 'proof_dsn')]
    for index, target in enumerate(targets):
        validate_target(target, proof=bool(index))
        if not target.get('password'):
            raise ValueError('Private fixture must provide explicit passwords; no ambient credential sources')
    if any(targets[0].get(k) != targets[1].get(k) for k in ('host', 'hostaddr', 'port', 'dbname')):
        raise ValueError('Runtime and read-only proof targets differ')
    # Reuse repository target rules with correct isolated-checkout mode, not config secrets.
    if targets[0]['port'] == '15434':
        os.environ['MA_LOCAL_DB_DIR'] = str(ROOT / '.local-db/pr11-runtime')
    elif os.environ.get('MA_LOCAL_DB_DIR'):
        raise ValueError('Unexpected ambient local target selection')
    if os.environ.get('MA_LOCAL_DB_CI'):
        raise ValueError('CI service target is not an owned checkout container')
    from tools.database import manage
    for target in targets:
        manage.validate_target(target)
    container = inspect_container(args.container, targets[0]['port'])
    environment = preflight(f, entries, chain)
    environment.update({'checkout_sha': git('rev-parse', 'HEAD').decode().strip(),
                        'tracked_diff_sha256': hashlib.sha256(git('diff', 'HEAD', '--binary')).hexdigest(),
                        'harness_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                        'python': sys.version, 'psycopg': psycopg.__version__,
                        'platform': platform.platform(), 'logical_cpu_count': os.cpu_count(),
                        'cpu_affinity': sorted(os.sched_getaffinity(0)),
                        'cpu_model': next((s.split(':', 1)[1].strip() for s in Path('/proc/cpuinfo').read_text().splitlines()
                                           if s.startswith('model name')), 'unknown'),
                        'memory_total_kib': next((s.split(':', 1)[1].strip() for s in Path('/proc/meminfo').read_text().splitlines()
                                                 if s.startswith('MemTotal:')), 'unknown'),
                        'container_id': container['Id'], 'container_image_digest': container['Image'],
                        'container_limits': {k: container['HostConfig'].get(k) for k in ('Memory', 'NanoCpus')},
                        'migration_checksums': {e['id']: e['sha256'] for e in chain}})
    report = {'schema': 'issue32.synthetic-postgresql-load/v1', 'status': 'NOT_RUN',
              'scope': 'DIRECT_POSTGRES_INGEST_FUNCTION_ONLY', 'environment': environment,
              'physical_android': {'status': 'NOT_RUN', 'battery': None},
              'target_environment_capacity': {'status': 'NOT_RUN', 'supported_devices': None},
              'claim': '108 simulated clients is a workload parameter, never a device-capacity certification',
              'config': {k: getattr(args, k) for k in ('clients', 'pool', 'ramp', 'batches_per_device', 'batch_size', 'interval_ms', 'max_seconds')},
              'started_utc': datetime.now(timezone.utc).isoformat(), 'stages': []}
    pool = queue.Queue(maxsize=args.pool)
    connections = []
    sequence = [d['sequence_start'] for d in f['devices']]
    try:
        # Proof login is closed before creating the pool: max(pool,1) simultaneous DB connections.
        for _ in range(args.pool):
            conn = connect(f['runtime_dsn'])
            connections.append(conn)
            pool.put(conn)
        deadline = time.monotonic() + args.max_seconds
        for concurrency in ramp:
            if time.monotonic() >= deadline:
                break
            before = container_sample(args.container)
            cpu_start = time.process_time()
            result = stage(f, pool, concurrency, args, sequence, deadline)
            result['generator_cpu_seconds'] = time.process_time() - cpu_start
            result['generator_peak_rss_bytes'] = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss * 1024
            after = container_sample(args.container)
            result['container_samples'] = [before, after]
            if before['status'] == after['status'] == 'MEASURED':
                result['container_counter_delta'] = {k: after[k] - before[k] for k in
                    ('cpu_usage_usec', 'network_rx_bytes', 'network_tx_bytes')}
                result['container_cpu_percent_one_core'] = (after['cpu_usage_usec'] - before['cpu_usage_usec']) / 10000 / (after['monotonic_seconds'] - before['monotonic_seconds'])
            report['stages'].append(result)
        report['status'] = 'MEASURED_SYNTHETIC_ONLY'
        if len(report['stages']) != len(ramp) or any(s['errors'] or s['deadline_reached'] for s in report['stages']):
            report['status'] = 'PARTIAL_SYNTHETIC_ONLY'
    finally:
        for conn in connections:
            conn.close()
    private_batch_sets = [s.pop('_private_batch_ids') for s in report['stages']]
    try:
        with connect(f['proof_dsn'], read_only=True) as db:
            db.execute('SET LOCAL ROLE ap_db_executor')
            for result, ids in zip(report['stages'], private_batch_sets):
                count = db.execute('SELECT count(*), coalesce(sum(item_count),0) FROM ap_m1.location_ingest_batches WHERE id=ANY(%s::uuid[])', (ids,)).fetchone()
                result['commit_readback'] = {'status': 'VERIFIED' if count == (result['successes'], result['events_committed']) else 'MISMATCH',
                                             'batches': count[0], 'events_in_batches': int(count[1])}
                if result['commit_readback']['status'] != 'VERIFIED':
                    report['status'] = 'PARTIAL_SYNTHETIC_ONLY'
            db.rollback()
    except Exception:
        report['status'] = 'PARTIAL_SYNTHETIC_ONLY'
        for result in report['stages']:
            result.setdefault('commit_readback', {'status': 'NOT_RUN'})
    report['finished_utc'] = datetime.now(timezone.utc).isoformat()
    # Output is exclusively aggregate metrics; never private fixture, identifiers or SQL diagnostics.
    fd = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'w') as stream:
        json.dump(report, stream, indent=2, allow_nan=False)
        stream.write('\n')
    print(json.dumps({'status': report['status'], 'stages_recorded': len(report['stages']),
                      'android_battery': 'NOT_RUN', 'device_capacity': 'NOT_RUN'}))
    return 0 if report['status'] == 'MEASURED_SYNTHETIC_ONLY' else 1


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', nargs='?', choices=('selftest', 'check-source', 'run'), default='selftest')
    parser.add_argument('--fixture', type=Path)
    parser.add_argument('--container')
    parser.add_argument('--confirm')
    parser.add_argument('--clients', type=int, default=108)
    parser.add_argument('--pool', type=int, default=8)
    parser.add_argument('--ramp', default='1,8,32,108')
    parser.add_argument('--batches-per-device', type=int, default=10)
    parser.add_argument('--batch-size', type=int, default=1)
    parser.add_argument('--interval-ms', type=int, default=100)
    parser.add_argument('--max-seconds', type=int, default=120)
    parser.add_argument('--output', type=Path, default=HERE / 'metrics.actual.json')
    args = parser.parse_args(argv)
    if args.mode == 'selftest':
        import unittest
        return 0 if unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.discover(str(HERE), pattern='test_load.py')).wasSuccessful() else 1
    if args.mode == 'check-source':
        try:
            source_chain()
        except ValueError as exc:
            print(json.dumps({'status': 'NOT_RUN', 'reason': str(exc)}))
            return 2
        print(json.dumps({'source_chain': 'VALIDATED', 'database': 'NOT_RUN'}))
        return 0
    try:
        return run(args)
    except Exception as exc:
        # Never emit libpq errors/SQL parameter values/credential strings.
        print(json.dumps({'status': 'NOT_RUN_OR_ABORTED', 'error_class': type(exc).__name__,
                          'reason': 'Guard/contract/target failure; no capacity claim. Run check-source first.'}))
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
