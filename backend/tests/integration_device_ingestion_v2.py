#!/usr/bin/env python3
"""Issue 32 E03: production DeviceBearer HTTP -> PostgreSQL integration.

Run after the coordinator migrates the disposable synthetic test database:
  .venv/bin/python backend/tests/integration_device_ingestion_v2.py \
      build/backend/ma_backend --evidence .local-db/device-ingestion-http.json

No DDL, synthetic authentication headers, .env loading, or production data.
The privileged fixture login seeds an invented bearer HASH only; the server
uses the separate restricted runtime login. This is not enrollment evidence.
"""
import argparse
import contextlib
from datetime import datetime, timedelta, timezone
import hashlib
import json
import os
from pathlib import Path
import secrets
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from uuid import UUID, uuid4

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'backend/tests/database'))
import fixtures  # noqa: E402
from test_location import domain_fixture, cleanup_domain  # noqa: E402
from psycopg.conninfo import conninfo_to_dict  # noqa: E402


class Failure(AssertionError):
    pass


def require(condition, label):
    if not condition:
        raise Failure(label)


def event(sequence):
    return dict(event_id=str(uuid4()), sequence=sequence,
                observed_at=(datetime.now(timezone.utc) - timedelta(seconds=30)).isoformat(),
                latitude=0.125, longitude=0.25, accuracy_m=12, provider='SYNTHETIC')


def scrub(value, sensitive):
    for secret in sorted(set(sensitive), key=len, reverse=True):
        if secret:
            value = value.replace(secret, '[REDACTED]')
    return value


@contextlib.contextmanager
def server(binary, runtime, evidence, sensitive):
    # Do not inherit ambient auth/DB/release configuration from the developer.
    env = {k: v for k, v in os.environ.items() if not k.startswith('MA_')}
    env.update(MA_LISTEN_ADDR='127.0.0.1', MA_PARENT_AUTH_MODE='v2_session',
               MA_RELEASE_PROFILE='FREE_ONLY', MA_PG_HOST=runtime['host'],
               MA_PG_PORT=runtime['port'], MA_PG_DB=runtime['dbname'],
               MA_PG_USER=runtime['user'], MA_PG_PASSWORD=runtime.get('password', ''))
    with socket.socket() as reservation:
        reservation.bind(('127.0.0.1', 0))
        port = reservation.getsockname()[1]
    env['MA_LISTEN_PORT'] = str(port)
    evidence['http'] = {'host': '127.0.0.1', 'port': port, 'synthetic_headers': False}
    # Anonymous private file: raw backend output never becomes an evidence file.
    with tempfile.TemporaryFile(dir=os.environ.get('TMPDIR', ROOT / '.local-db')) as log:
        proc = subprocess.Popen([str(binary)], cwd=ROOT, env=env,
                                stdout=log, stderr=subprocess.STDOUT)
        require(proc.pid > 0, 'server must have a positive owned PID')
        evidence['server_pid'] = proc.pid
        url = f'http://127.0.0.1:{port}'
        try:
            for _ in range(200):
                require(proc.poll() is None, 'backend exited during startup')
                try:
                    with urllib.request.urlopen(url + '/healthz', timeout=.2) as response:
                        if response.status == 200:
                            break
                except (OSError, urllib.error.URLError):
                    time.sleep(.05)
            else:
                raise Failure('backend startup timed out')
            yield url
            require(proc.poll() is None, 'backend must survive all requests')
        finally:
            # Signal only this Popen child; never kill by name or process group.
            if proc.poll() is None:
                proc.terminate()
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait(timeout=5)
            evidence['server_stopped'] = proc.poll() is not None
            log.seek(0)
            raw = log.read().decode(errors='replace')
            evidence['server_log'] = scrub(raw, sensitive)
            evidence['secret_free_server_log'] = not any(s and s in raw for s in sensitive)
            require(evidence['secret_free_server_log'], 'backend log leaked credential material')


def call(url, device, body, token=None):
    headers = {'Content-Type': 'application/json'}
    if token is not None:
        headers['Authorization'] = 'Bearer ' + token
    request = urllib.request.Request(url + f'/v1/devices/{device}/locations:batch',
                                     data=json.dumps(body).encode(), headers=headers, method='POST')
    try:
        response = urllib.request.urlopen(request, timeout=10)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        status, payload = response.status, response.read()
        request_id = response.headers.get('X-Request-Id', '')
    try:
        UUID(request_id)
    except ValueError:
        raise Failure('missing UUID X-Request-Id') from None
    return {'status': status, 'json': json.loads(payload), 'request_id': request_id}


def snapshot(child):
    with fixtures.admin_connection() as db:
        return {table: db.execute('SELECT count(*) FROM ap_m1.' + table + ' WHERE child_id=%s',
                                  (child,)).fetchone()[0]
                for table in ('location_observations', 'location_ingest_batches',
                              'location_batch_items', 'location_event_dedup', 'ingestion_outbox')}


def exercise(binary, evidence, sensitive):
    cache = binary.parent / 'CMakeCache.txt'
    require(cache.is_file() and 'MA_SYNTHETIC_AUTH:BOOL=OFF' in cache.read_text(),
            'binary must have adjacent CMakeCache with MA_SYNTHETIC_AUTH=OFF')
    evidence['binary'] = str(binary)
    evidence['synthetic_auth_compiled'] = False
    runtime = conninfo_to_dict(fixtures._dsn('runtime'))
    for kind in ('runtime', 'admin'):
        dsn = fixtures._dsn(kind)
        sensitive.append(dsn)
        password = conninfo_to_dict(dsn).get('password')
        if password:
            sensitive.append(password)
    with fixtures.runtime_connection() as db:
        role = db.execute('SELECT rolsuper,rolbypassrls FROM pg_roles WHERE rolname=current_user').fetchone()
        require(role == (False, False), 'HTTP database login must be restricted NOBYPASSRLS')
    evidence['restricted_runtime'] = True
    f = domain_fixture()
    child, device = f['child_a'], f['device_a']
    token = secrets.token_hex(32)
    digest = hashlib.sha256(token.encode()).digest()
    sensitive.extend((token, digest.hex(), '\\x' + digest.hex()))
    try:
        with fixtures.admin_connection() as db:
            seeded = db.execute(
                'INSERT INTO ap_m1.device_credentials(device_id,key_id,token_sha256,issued_via,expires_at,'
                'bound_key_generation,bound_key_fingerprint_sha256) '
                "SELECT %s,key_id,%s,'ENROLLMENT',clock_timestamp()+interval '1 hour',generation,fingerprint_sha256 "
                'FROM ap_m1.device_key_records WHERE key_id=%s RETURNING id',
                (device, digest, f['device_key_a'])).fetchone()
            require(seeded is not None, 'fixture must seed exactly one credential hash')
        checks = evidence['checks']

        def send(label, events, accepted=None, duplicate=None, status=202, code=None,
                 batch=None, path_device=device, authenticated=True):
            body = {'batch_id': str(batch or uuid4()), 'events': events}
            before = snapshot(child)
            result = call(url, path_device, body, token if authenticated else None)
            after = snapshot(child)
            checks.append(dict(label=label, request=body, response=result, before=before, after=after))
            require(result['status'] == status, label + ': HTTP status mismatch')
            payload = result['json']
            if status == 202:
                require(payload == dict(batch_id=body['batch_id'], accepted_count=accepted,
                                        duplicate_count=duplicate, rejected_count=0,
                                        processing='QUEUED', durable_stage='INBOX_COMMITTED'),
                        label + ': receipt JSON mismatch')
                require(after['location_observations'] == before['location_observations'] + accepted,
                        label + ': durable GPS count mismatch')
                if label == 'exact_batch_replay':
                    require(after == before, label + ': exact replay changed durable ingestion state')
            else:
                require(payload.get('code') in (code if isinstance(code, tuple) else (code,)),
                        label + ': error code mismatch')
                require(payload.get('request_id') == result['request_id'], label + ': request id mismatch')
                require(after == before, label + ': refused request changed durable ingestion state')
            checks[-1]['passed'] = True
            return body['batch_id']

        with server(binary, runtime, evidence, sensitive) as url:
            first = event(7000001)
            batch = send('first_batch', [first], 1, 0)
            send('exact_batch_replay', [first], 0, 1, batch=batch)
            send('new_batch_known_event', [first], 0, 1)
            second = event(7000002)
            send('within_array_fresh_duplicate', [second, second], 1, 1)
            send('within_array_known_duplicates', [second, second], 0, 2)
            send('MAB01_batch_payload_conflict', [event(7000003)], status=409,
                 code='CONFLICT', batch=batch)
            send('MAB02_event_payload_conflict', [dict(first, latitude=1.0)],
                 status=409, code='CONFLICT')
            send('MAB03_sequence_reuse', [event(first['sequence'])], status=409, code='CONFLICT')
            send('wrong_device', [event(7000004)], status=403, code='FORBIDDEN',
                 path_device=fixtures.seed_core()['device_a'])
            send('absent_authentication', [event(7000005)], status=401,
                 code='UNAUTHENTICATED', authenticated=False)
            with fixtures.admin_connection() as db:
                db.execute('UPDATE ap_m1.device_credentials SET revoked_at=clock_timestamp() '
                           'WHERE device_id=%s AND token_sha256=%s', (device, digest))
            send('revoked_credential', [event(7000006)], status=401, code='UNAUTHENTICATED')
            evidence['final_counts'] = snapshot(child)
            require(evidence['final_counts']['location_observations'] == 2, 'exactly two unique GPS events')
        for state in ('MAB01', 'MAB02', 'MAB03'):
            require('state=' + state in evidence['server_log'], state + ': SQLSTATE not observed in backend log')
    finally:
        # Delete only this fixture's credential, before its key/device FK targets.
        with fixtures.admin_connection() as db:
            db.execute('DELETE FROM ap_m1.device_credentials WHERE device_id=%s', (device,))
        cleanup_domain(f)
        with fixtures.admin_connection() as db:
            require(db.execute('SELECT count(*) FROM ap_m1.children WHERE id=%s', (child,)).fetchone()[0] == 0,
                    'owned domain cleanup failed')
            require(db.execute('SELECT count(*) FROM ap_m1.device_credentials WHERE device_id=%s',
                               (device,)).fetchone()[0] == 0, 'owned credential cleanup failed')
        evidence['fixture_cleaned'] = True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path)
    parser.add_argument('--evidence', type=Path, required=True)
    args = parser.parse_args()
    evidence = {'suite': 'issue32-e03-production-http-postgres', 'checks': [], 'passed': False}
    sensitive = []
    try:
        exercise(args.binary.resolve(), evidence, sensitive)
        evidence['passed'] = True
    except Exception as exc:
        # Driver exceptions can contain connection secrets: never serialize them.
        evidence['failure'] = str(exc) if isinstance(exc, Failure) else type(exc).__name__
    finally:
        args.evidence.parent.mkdir(parents=True, exist_ok=True)
        text = scrub(json.dumps(evidence, indent=2), sensitive)
        fd = os.open(args.evidence, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, 'w') as output:
            output.write(text + '\n')
    summary = {key: evidence.get(key) for key in
               ('suite', 'passed', 'failure', 'final_counts', 'fixture_cleaned', 'server_stopped')}
    summary['passed_checks'] = sum(item.get('passed', False) for item in evidence['checks'])
    summary['checks'] = len(evidence['checks'])
    summary['evidence'] = str(args.evidence.resolve())
    print(json.dumps(summary, sort_keys=True))
    return 0 if evidence['passed'] else 1


if __name__ == '__main__':
    sys.exit(main())
