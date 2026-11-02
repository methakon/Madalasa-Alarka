#!/usr/bin/env python3
"""Real HTTP/PG failure regressions; SYNTHETIC AUTH build only.

python3 backend/tests/integration_db_failures.py /absolute/path/ma_backend --case missing
python3 backend/tests/integration_db_failures.py /absolute/path/ma_backend --case all
PG* must address an explicitly disposable local PG cluster, admin with CREATE DATABASE.
Creates/drops its own database; never uses the configured PGDATABASE as a fixture.
No Python packages required. No test handlers are compiled into the application.
"""
import argparse
import concurrent.futures
import contextlib
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time
import urllib.error
import urllib.request
import uuid


def free_port():
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        return sock.getsockname()[1]


def stop(proc):
    if proc is not None and proc.pid > 0 and proc.poll() is None:
        proc.terminate()
        try:
            proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=3)


def post(url, subject=None, label='Synthetic timeout fixture'):
    headers = {'Content-Type': 'application/json', 'Idempotency-Key': str(uuid.uuid4())}
    if subject is not None:
        headers['X-Synthetic-Subject'] = subject
    req = urllib.request.Request(url + '/v1/families', json.dumps({'label': label}).encode(), headers)
    started = time.monotonic()
    try:
        resp = urllib.request.urlopen(req, timeout=3)
    except urllib.error.HTTPError as exc:
        resp = exc
    with resp:
        return resp.status, json.load(resp), resp.headers, time.monotonic() - started


def error(result, status=503, code='SERVICE_UNAVAILABLE', bound=2.5):
    actual, body, headers, elapsed = result
    assert actual == status, (actual, body)
    assert set(body) == {'code', 'message', 'request_id', 'retryable'}, body
    assert body['code'] == code and body['retryable'] is True, body
    assert str(uuid.UUID(body['request_id'])) == body['request_id']
    assert headers['X-Request-Id'] == body['request_id']
    assert len(body['message']) <= 300
    assert elapsed < bound, elapsed


@contextlib.contextmanager
def server(binary, overrides):
    env = {k: v for k, v in os.environ.items() if not k.startswith('MA_PG_')}
    port = free_port()
    env.update(MA_AUTH_MODE='synthetic_test', MA_PARENT_AUTH_MODE='m1_direct_oidc', MA_LISTEN_ADDR='127.0.0.1', MA_LISTEN_PORT=str(port),
               MA_PG_TIMEOUT_MS='700', MA_PG_STATEMENT_TIMEOUT_MS='400', MA_PG_LOCK_TIMEOUT_MS='150')
    env.update(overrides)
    url = f'http://127.0.0.1:{port}'
    with tempfile.TemporaryFile(dir=os.environ.get('TMPDIR')) as log:
        proc = subprocess.Popen([binary], env=env, stdout=log, stderr=log)
        try:
            for _ in range(100):
                if proc.poll() is not None:
                    raise AssertionError('backend exited before health check')
                try:
                    with urllib.request.urlopen(url + '/healthz', timeout=.2) as response:
                        if response.status == 200:
                            break
                except (OSError, urllib.error.URLError):
                    time.sleep(.05)
            else:
                raise AssertionError('backend health check did not become ready')
            yield url
            assert proc.poll() is None, 'request crashed backend'
        finally:
            stop(proc)


def sql(db, text):
    return subprocess.check_output(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', db, '-c', text],
                                   text=True, timeout=10).strip()


@contextlib.contextmanager
def database():
    db = 'ma_deadlines_' + uuid.uuid4().hex
    runtime_role = db + '_api'
    sql('postgres', f'CREATE DATABASE {db}')
    try:
        migrations = Path(__file__).resolve().parents[1] / 'persistence/migrations'
        # Historical M1 only: never concatenate an independently numbered lineage.
        for name in ('0001_m1_identity.sql', '0002_m1_device_credentials.sql',
                     '0003_m1_enrollment_and_credential_hardening.sql',
                     '0004_m1_idempotency.sql', '0005_m1_family_provisioning.sql',
                     '0006_m1_concurrency_and_retention_holds.sql'):
            migration = migrations / name
            subprocess.run(['psql', '-X', '-q', '-v', 'ON_ERROR_STOP=1', '-d', db, '-f', str(migration)],
                           check=True, stdout=subprocess.DEVNULL, timeout=20)
        sql(db, f"CREATE ROLE {runtime_role} LOGIN NOSUPERUSER NOBYPASSRLS IN ROLE ap_m1_api PASSWORD 'synthetic_it_password'")
        yield db, {'MA_PG_DB': db, 'MA_PG_HOST': os.environ.get('PGHOST', '127.0.0.1'),
                   'MA_PG_PORT': os.environ.get('PGPORT', '5432'), 'MA_PG_USER': runtime_role,
                   'MA_PG_PASSWORD': 'synthetic_it_password', 'MA_PG_CONNECTIONS': '1'}
    finally:
        try:
            sql('postgres', f'DROP DATABASE IF EXISTS {db} WITH (FORCE)')
        finally:
            sql('postgres', f'DROP ROLE IF EXISTS {runtime_role}')


def missing(binary):
    with server(binary, {}) as url:
        # Authenticated request is essential: the old fixture stopped at 401.
        error(post(url, 'deadline-missing'))
        assert post(url)[0] == 401


def invalid_config(binary):
    for name, value in [('MA_PG_TIMEOUT_MS', '0'), ('MA_PG_TIMEOUT_MS', '-1'),
                        ('MA_PG_TIMEOUT_MS', 'nan'), ('MA_PG_STATEMENT_TIMEOUT_MS', '60001'),
                        ('MA_PG_LOCK_TIMEOUT_MS', '400'), ('MA_PG_CONNECTIONS', '0'),
                        ('MA_PG_CONNECTIONS', '65'), ('MA_PG_PORT', '65536')]:
        env = {k: v for k, v in os.environ.items() if not k.startswith('MA_PG_')}
        env.update(MA_PG_STATEMENT_TIMEOUT_MS='400', MA_PG_LOCK_TIMEOUT_MS='150')
        env[name] = value
        proc = subprocess.Popen([binary], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            assert proc.wait(timeout=2) == 78, f'invalid {name} must fail closed'
        finally:
            stop(proc)


def unreachable(binary):
    # Reserve a non-listening socket so no other service can take this port.
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        with server(binary, {'MA_PG_DB': 'synthetic_unreachable', 'MA_PG_HOST': '127.0.0.1',
                             'MA_PG_PORT': str(sock.getsockname()[1])}) as url:
            error(post(url, 'deadline-unreachable'))


def pg_cases(binary, selected):
    with database() as (db, env):
        # Trigger only exists in this freshly created disposable database. Its
        # non-locking pg_sleep tests statement_timeout independently of lock_timeout.
        sql(db, """CREATE FUNCTION ap_m1.deadline_fixture() RETURNS trigger LANGUAGE plpgsql AS $$
        BEGIN PERFORM pg_sleep(6); RETURN NEW; END $$;
        CREATE TRIGGER deadline_fixture BEFORE INSERT ON ap_m1.families
        FOR EACH ROW EXECUTE FUNCTION ap_m1.deadline_fixture();""")
        try:
            if selected in ('all', 'slow'):
                with server(binary, env) as url:
                    error(post(url, 'deadline-slow'))
                assert sql(db, 'SELECT count(*) FROM ap_m1.families') == '0'
                assert sql(db, 'SELECT count(*) FROM ap_m1.idempotency_keys') == '0'
                print('PASS slow non-locking statement', flush=True)
            if selected in ('all', 'pool'):
                # Keep the only pool connection busy longer than acquisition timeout.
                occupied_env = dict(env, MA_PG_STATEMENT_TIMEOUT_MS='2000', MA_PG_TIMEOUT_MS='1000')
                with server(binary, occupied_env) as url, concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
                    first = pool.submit(post, url, 'deadline-pool-holder')
                    until = time.monotonic() + 2
                    while time.monotonic() < until:
                        if sql(db, "SELECT count(*) FROM pg_stat_activity WHERE datname=current_database() AND wait_event='PgSleep'") != '0':
                            break
                        time.sleep(.02)
                    else:
                        raise AssertionError('pool holder never entered pg_sleep')
                    error(post(url, 'deadline-pool-waiter'))
                    error(first.result(timeout=3))
                assert sql(db, 'SELECT count(*) FROM ap_m1.families') == '0'
                print('PASS pool acquisition', flush=True)
        finally:
            sql(db, 'DROP TRIGGER deadline_fixture ON ap_m1.families; DROP FUNCTION ap_m1.deadline_fixture()')
        if selected in ('all', 'lock'):
            holder = None
            try:
                holder = subprocess.Popen(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', db],
                                          stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                holder.stdin.write('BEGIN; LOCK TABLE ap_m1.families IN ACCESS EXCLUSIVE MODE; SELECT \'locked\';\n')
                holder.stdin.flush()
                # The query emits exactly one line once the lock has been acquired.
                import select
                assert select.select([holder.stdout], [], [], 3)[0], 'lock fixture did not start'
                assert holder.stdout.readline().strip() == 'locked'
                with server(binary, env) as url:
                    error(post(url, 'deadline-lock'), 409, 'CONFLICT', bound=1.5)
            finally:
                stop(holder)
            assert sql(db, 'SELECT count(*) FROM ap_m1.families') == '0'
            print('PASS lock timeout', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=lambda value: str(Path(value).resolve()))
    parser.add_argument('--case', choices=['missing', 'unreachable', 'slow', 'pool', 'lock', 'config', 'all'], default='all')
    args = parser.parse_args()
    if args.case in ('all', 'config'):
        invalid_config(args.binary)
        print('PASS invalid configuration fails closed', flush=True)
    if args.case in ('all', 'missing'):
        missing(args.binary)
        print('PASS authenticated missing DB', flush=True)
    if args.case in ('all', 'unreachable'):
        unreachable(args.binary)
        print('PASS unreachable DB', flush=True)
    if args.case in ('all', 'slow', 'pool', 'lock'):
        pg_cases(args.binary, args.case)


if __name__ == '__main__':
    main()
