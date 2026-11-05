#!/usr/bin/env python3
"""End-to-end HTTP integration test for Manual SOS and Child Safety Signals.

Verifies:
1. Device authentication with bearer token
2. Device POST /v1/devices/{deviceId}/signals -> 201 SERVER_ACCEPTED
3. Device GET /v1/devices/{deviceId}/signals/{eventId}/status -> 200 SERVER_ACCEPTED
4. Parent unauthenticated & cross-family negative access -> 401 / 403
5. Parent GET /v1/children/{childId}/signals -> 200 with active signal list
6. Parent POST /v1/children/{childId}/signals/{eventId}/ack -> 200 GUARDIAN_ACKNOWLEDGED
7. Device GET status polling updates to GUARDIAN_ACKNOWLEDGED
8. Idempotent re-send and conflict replay rejection
9. Zero credential/token leakage in server logs
"""
import contextlib
import hashlib
import json
import os
from pathlib import Path
import re
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

UUID_RE = re.compile(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
SECRETS = []


class Failure(AssertionError):
    pass


def expect(condition, label):
    if not condition:
        raise Failure(label)
    print('PASS ' + label, flush=True)


def free_port():
    with socket.socket() as s:
        s.bind(('127.0.0.1', 0))
        return s.getsockname()[1]


def database_env():
    runtime = conninfo_to_dict(fixtures._dsn('runtime'))
    issuer = conninfo_to_dict(fixtures._dsn('auth'))
    return dict(MA_PG_HOST=str(runtime.get('host', '127.0.0.1')),
                MA_PG_PORT=str(runtime.get('port', 5432)),
                MA_PG_DB=runtime['dbname'],
                MA_PG_USER=runtime['user'],
                MA_PG_PASSWORD=runtime.get('password', ''),
                MA_PG_AUTH_USER=issuer['user'],
                MA_PG_AUTH_PASSWORD=issuer.get('password', ''))


def base_env(overrides):
    env = {k: v for k, v in os.environ.items() if not k.startswith(('MA_PG_', 'MA_PARENT_', 'MA_LISTEN_'))}
    env.update(MA_RELEASE_PROFILE='FREE_ONLY',
               MA_PARENT_AUTH_MODE='v2_session',
               MA_LISTEN_ADDR='127.0.0.1')
    env.update(overrides)
    return env


@contextlib.contextmanager
def server(binary, db_env):
    port = free_port()
    env = base_env(dict(db_env, MA_LISTEN_PORT=str(port)))
    url = f'http://127.0.0.1:{port}'
    with tempfile.NamedTemporaryFile(dir=os.environ.get('TMPDIR', ROOT / '.local-db'), delete=False) as log:
        log_path = Path(log.name)
    with open(log_path, 'wb') as log:
        proc = subprocess.Popen([str(binary)], cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
    try:
        for _ in range(150):
            if proc.poll() is not None:
                raise Failure('backend exited before health check: ' + log_path.read_text(errors='replace')[-2000:])
            try:
                with urllib.request.urlopen(url + '/healthz', timeout=.2) as resp:
                    if resp.status == 200:
                        break
            except (OSError, urllib.error.URLError):
                time.sleep(.05)
        else:
            raise Failure('backend health check timed out')
        try:
            yield url, log_path
        except BaseException:
            tail = log_path.read_text(errors='replace')[-4000:]
            for secret in SECRETS:
                if secret:
                    tail = tail.replace(secret, '[REDACTED]')
            print(f'--- backend exit={proc.poll()} log tail ---\n{tail}', file=sys.stderr, flush=True)
            raise
        expect(proc.poll() is None, 'backend survived all test requests')
    finally:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
        log_text = log_path.read_text(errors='replace')
        log_path.unlink(missing_ok=True)
        leaked = [s for s in SECRETS if s and s in log_text]
        if leaked:
            raise Failure('server log leaked credential or token')


def http_call(url, method, path, headers=None, body=None):
    data = None if body is None else json.dumps(body).encode()
    hdr = dict(headers or {})
    if data is not None:
        hdr.setdefault('Content-Type', 'application/json')
    req = urllib.request.Request(url + path, data=data, method=method, headers=hdr)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            status, payload, resp_headers = resp.status, resp.read(), resp.headers
    except urllib.error.HTTPError as err:
        status, payload, resp_headers = err.code, err.read(), err.headers
    req_id = resp_headers.get('X-Request-Id', '')
    if not UUID_RE.match(req_id):
        raise Failure(f'{method} {path}: missing UUID X-Request-Id')
    parsed = json.loads(payload) if payload else None
    return status, parsed, resp_headers


def main():
    binary = ROOT / '.local-db/build/ma_backend'
    if not binary.is_file():
        raise Failure(f'binary not found at {binary}')

    db_cfg = database_env()
    for dsn_key in ('runtime', 'auth', 'admin'):
        dsn = fixtures._dsn(dsn_key)
        SECRETS.append(dsn)
        pwd = conninfo_to_dict(dsn).get('password')
        if pwd:
            SECRETS.append(pwd)

    f = domain_fixture()
    try:
        child_id = str(f['child_a'])
        device_id = str(f['device_a'])
        parent_a = f['a']
        parent_b = f['b']

        # Seed device bearer token
        dev_token = secrets.token_hex(32)
        dev_digest = hashlib.sha256(dev_token.encode()).digest()
        SECRETS.extend([dev_token, dev_digest.hex()])

        with fixtures.admin_connection() as db:
            db.execute(
                'INSERT INTO ap_m1.device_credentials(device_id,key_id,token_sha256,issued_via,expires_at,'
                'bound_key_generation,bound_key_fingerprint_sha256) '
                "SELECT %s,key_id,%s,'ENROLLMENT',clock_timestamp()+interval '1 hour',generation,fingerprint_sha256 "
                'FROM ap_m1.device_key_records WHERE key_id=%s RETURNING id',
                (device_id, dev_digest, f['device_key_a'])).fetchone()

        # Mint parent session tokens
        parent_token_a = fixtures.mint_session(parent_a, f['family_a'])
        parent_token_b = fixtures.mint_session(parent_b, f['family_b'])
        SECRETS.extend([parent_token_a, parent_token_b])

        with server(binary, db_cfg) as (base_url, _):
            # 1. Negative device unauthenticated
            ev_id = str(uuid4())
            t_now = "2026-11-05T15:00:00Z"
            st, body, _ = http_call(base_url, 'POST', f'/v1/devices/{device_id}/signals',
                                    body={'event_id': ev_id, 'kind': 'SOS', 'observed_at': t_now})
            expect(st == 401, 'unauthenticated device signal rejected with 401')

            # 2. Positive device SOS signal submission
            dev_headers = {'Authorization': f'Bearer {dev_token}'}
            st, body, _ = http_call(base_url, 'POST', f'/v1/devices/{device_id}/signals',
                                    headers=dev_headers,
                                    body={'event_id': ev_id, 'kind': 'SOS', 'observed_at': t_now})
            expect(st == 201 and body.get('stage') == 'SERVER_ACCEPTED',
                   'device manual SOS accepted with 201 SERVER_ACCEPTED')

            # 3. Device status poll -> SERVER_ACCEPTED, guardian not yet acknowledged
            st, body, _ = http_call(base_url, 'GET', f'/v1/devices/{device_id}/signals/{ev_id}/status',
                                    headers=dev_headers)
            print(f'POLL STATUS: {st}, {body}')
            expect(st == 200 and body.get('stage') == 'SERVER_ACCEPTED' and body.get('guardian_acknowledged') is False,
                   'device poll returns 200 SERVER_ACCEPTED and guardian_acknowledged=false')

            # 4. Guardian unauthenticated signal query -> 401
            st, body, _ = http_call(base_url, 'GET', f'/v1/children/{child_id}/signals')
            expect(st == 401, 'unauthenticated guardian signals query rejected with 401')

            # 5. Unrelated guardian (Parent B) signal query -> 403 (RLS / access scope isolation)
            st, body, _ = http_call(base_url, 'GET', f'/v1/children/{child_id}/signals',
                                    headers={'Authorization': f'Bearer {parent_token_b}'})
            expect(st == 403, 'cross-family guardian query rejected with 403 FORBIDDEN')

            # 6. Authorized guardian (Parent A) signal query -> 200 with list
            st, body, _ = http_call(base_url, 'GET', f'/v1/children/{child_id}/signals',
                                    headers={'Authorization': f'Bearer {parent_token_a}'})
            expect(st == 200 and isinstance(body.get('signals'), list),
                   'authorized guardian can query signals list')
            found = [s for s in body['signals'] if s['event_id'] == ev_id]
            expect(len(found) == 1 and found[0]['acknowledged'] is False,
                   'signal appears in guardian signal list as unacknowledged')

            # 7. Unrelated guardian acknowledge attempt -> 403
            st, body, _ = http_call(base_url, 'POST', f'/v1/children/{child_id}/signals/{ev_id}/ack',
                                    headers={'Authorization': f'Bearer {parent_token_b}'})
            expect(st == 403, 'cross-family guardian acknowledge rejected with 403')

            # 8. Authorized guardian acknowledge -> 200 GUARDIAN_ACKNOWLEDGED
            st, body, _ = http_call(base_url, 'POST', f'/v1/children/{child_id}/signals/{ev_id}/ack',
                                    headers={'Authorization': f'Bearer {parent_token_a}'})
            expect(st == 200 and body.get('stage') == 'GUARDIAN_ACKNOWLEDGED',
                   'authorized guardian acknowledges signal with 200 GUARDIAN_ACKNOWLEDGED')

            # 9. Device status poll -> now GUARDIAN_ACKNOWLEDGED!
            st, body, _ = http_call(base_url, 'GET', f'/v1/devices/{device_id}/signals/{ev_id}/status',
                                    headers=dev_headers)
            expect(st == 200 and body.get('stage') == 'GUARDIAN_ACKNOWLEDGED' and body.get('guardian_acknowledged') is True,
                   'device poll now reports GUARDIAN_ACKNOWLEDGED and guardian_acknowledged=true')

            # 10. Idempotency: re-submitting identical SOS event returns 201
            st, body, _ = http_call(base_url, 'POST', f'/v1/devices/{device_id}/signals',
                                    headers=dev_headers,
                                    body={'event_id': ev_id, 'kind': 'SOS', 'observed_at': t_now})
            expect(st == 201, 'duplicate SOS event submission is idempotent 201')

            # 11. Conflict replay: submitting same event_id with different kind returns 409 CONFLICT
            st, body, _ = http_call(base_url, 'POST', f'/v1/devices/{device_id}/signals',
                                    headers=dev_headers,
                                    body={'event_id': ev_id, 'kind': 'IM_SAFE', 'observed_at': t_now})
            expect(st == 409 and body.get('code') == 'CONFLICT', 'replay of event_id with conflicting kind rejected with 409 CONFLICT')

            print('\nALL 11 END-TO-END MANUAL SOS HTTP INTEGRATION CHECKS PASSED!')
    finally:
        with fixtures.admin_connection() as db:
            db.execute('DELETE FROM ap_m1.device_credentials WHERE device_id=%s', (f['device_a'],))
        cleanup_domain(f)


if __name__ == '__main__':
    main()
