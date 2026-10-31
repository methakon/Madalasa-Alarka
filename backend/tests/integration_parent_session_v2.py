#!/usr/bin/env python3
"""V2 HTTP end-to-end test of the ParentOIDC -> opaque session bridge.

Usage: integration_parent_session_v2.py /path/to/ma_backend   (built with -DMA_SYNTHETIC_AUTH=ON)

Runs the real Drogon server against the migrated V2 test database prepared by
tools/database/manage.py (CI: ci-config, create, migrate). The server connects
with the restricted runtime login AND the separate issuer login; synthetic
identities come from X-Synthetic-Subject in this test build only.
SYNTHETIC DATA ONLY. Never prints passwords, session tokens or credentials.
"""
import contextlib
import json
import os
import re
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'backend/tests/database'))
import fixtures  # noqa: E402
from psycopg.conninfo import conninfo_to_dict  # noqa: E402

UUID_RE = re.compile(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
TOKEN_RE = re.compile(r'^[0-9a-f]{64}$')
SECRETS = []  # every bearer/credential string seen; must never reach the server log


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
    return dict(MA_PG_HOST=str(runtime.get('host', '127.0.0.1')), MA_PG_PORT=str(runtime.get('port', 5432)),
                MA_PG_DB=runtime['dbname'], MA_PG_USER=runtime['user'], MA_PG_PASSWORD=runtime['password'],
                MA_PG_AUTH_USER=issuer['user'], MA_PG_AUTH_PASSWORD=issuer['password'])


def base_env(overrides):
    env = {k: v for k, v in os.environ.items() if not k.startswith(('MA_PG_', 'MA_PARENT_', 'MA_LISTEN_'))}
    env.update(MA_AUTH_MODE='synthetic_test', MA_LISTEN_ADDR='127.0.0.1')
    env.update(overrides)
    return env


@contextlib.contextmanager
def server(binary, overrides):
    port = free_port()
    env = base_env(dict(overrides, MA_LISTEN_PORT=str(port)))
    url = f'http://127.0.0.1:{port}'
    with tempfile.NamedTemporaryFile(dir=os.environ.get('TMPDIR'), delete=False) as log:
        log_path = Path(log.name)
    with open(log_path, 'wb') as log:
        proc = subprocess.Popen([binary], env=env, stdout=log, stderr=subprocess.STDOUT)
    try:
        for _ in range(150):
            if proc.poll() is not None:
                raise Failure('backend exited before health check: ' + log_path.read_text(errors='replace')[-2000:])
            try:
                with urllib.request.urlopen(url + '/healthz', timeout=.2) as response:
                    if response.status == 200:
                        break
            except (OSError, urllib.error.URLError):
                time.sleep(.05)
        else:
            raise Failure('backend health check did not become ready')
        try:
            yield url, log_path
        except BaseException:
            tail = log_path.read_text(errors='replace')[-4000:]
            for secret in SECRETS:
                if secret:
                    tail = tail.replace(secret, '[REDACTED]')
            print(f'--- backend exit={proc.poll()} log tail (redacted) ---\n{tail}', file=sys.stderr, flush=True)
            raise
        expect(proc.poll() is None, 'backend survived every request')
    finally:
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
            raise Failure('server log contains a bearer or credential value')


def call(url, method, path, headers=None, body=None, raw=None):
    data = raw if raw is not None else (None if body is None else json.dumps(body).encode())
    headers = dict(headers or {})
    if data is not None:
        headers.setdefault('Content-Type', 'application/json')
    request = urllib.request.Request(url + path, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            status, payload, response_headers = response.status, response.read(), response.headers
    except urllib.error.HTTPError as error:
        status, payload, response_headers = error.code, error.read(), error.headers
    if not UUID_RE.match(response_headers.get('X-Request-Id', '')):
        raise Failure(f'{method} {path}: missing server-generated X-Request-Id')
    parsed = json.loads(payload) if payload else None
    return status, parsed, response_headers


def bearer(token):
    SECRETS.append(token)
    return {'Authorization': 'Bearer ' + token}


def identity(subject, credential=None):
    credential = credential or 'synthetic.' + uuid.uuid4().hex + '.credential'
    SECRETS.append(credential)
    return {'X-Synthetic-Subject': subject, 'Authorization': 'Bearer ' + credential}


def error_code(result, status, code):
    actual, body, _ = result
    return actual == status and isinstance(body, dict) and body.get('code') == code \
        and set(body) == {'code', 'message', 'request_id', 'retryable'}


def login(url, subject=None, credential=None):
    subject = subject or 'e2e-' + str(uuid.uuid4())
    status, body, headers = call(url, 'POST', '/v1/auth/parent/google', identity(subject, credential))
    if status != 201:
        raise Failure(f'exchange expected 201, got {status}: {body}')
    SECRETS.append(body['session_token'])
    return body, headers


def startup_refusals(binary, db):
    cases = [('unknown parent auth mode', dict(db, MA_PARENT_AUTH_MODE='synthetic_test')),
             ('session lifetime below bound', dict(db, MA_PARENT_SESSION_TTL_SECONDS='299')),
             ('session lifetime above bound', dict(db, MA_PARENT_SESSION_TTL_SECONDS='43201')),
             ('issuer login equal to runtime login', dict(db, MA_PG_AUTH_USER=db['MA_PG_USER']))]
    for label, overrides in cases:
        env = base_env(dict(overrides, MA_LISTEN_PORT=str(free_port())))
        completed = subprocess.run([binary], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=20)
        expect(completed.returncode == 78, 'startup refused: ' + label)


def main(binary):
    db = database_env()
    f = fixtures.seed_core()  # explicit database-local synthetic opt-in
    startup_refusals(binary, db)

    with server(binary, {k: v for k, v in db.items() if not k.startswith('MA_PG_AUTH_')}) as (url, _):
        expect(error_code(call(url, 'POST', '/v1/auth/parent/google', identity('no-issuer-login')),
                          503, 'SERVICE_UNAVAILABLE'), 'exchange fails closed without the issuer login')

    with server(binary, db) as (url, _):
        # --- exchange negatives
        expect(error_code(call(url, 'POST', '/v1/auth/parent/google'), 401, 'UNAUTHENTICATED'),
               'exchange without any credential is 401')
        expect(error_code(call(url, 'POST', '/v1/auth/parent/google', {'X-Synthetic-Subject': 'no-bearer'}),
                          401, 'UNAUTHENTICATED'), 'exchange requires a bearer credential to bind replay')
        expect(error_code(call(url, 'POST', '/v1/auth/parent/google', identity('body-x'), body={'subject': 'x'}),
                          400, 'INVALID_REQUEST'), 'exchange rejects a non-empty body')
        # --- positive exchange
        credential = 'synthetic.' + uuid.uuid4().hex + '.replay'
        subject = 'e2e-' + str(uuid.uuid4())
        session, headers = login(url, subject, credential)
        expect(TOKEN_RE.match(session['session_token']) and UUID_RE.match(session['actor_id'])
               and session['kind'] == 'PARENT' and session['token_type'] == 'Bearer' and session['state'] == 'ACTIVE'
               and re.match(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$', session['expires_at']),
               'exchange returns an opaque server-generated session')
        expect(headers.get('Cache-Control') == 'no-store', 'exchange response is not cacheable')
        expect(error_code(call(url, 'POST', '/v1/auth/parent/google', identity(subject, credential)),
                          401, 'UNAUTHENTICATED'), 'replayed identity credential is refused')
        expect(error_code(call(url, 'POST', '/v1/auth/parent/google', bearer(session['session_token'])),
                          401, 'UNAUTHENTICATED'), 'a session token is not an identity assertion')
        token = session['session_token']

        # --- the session is identity only
        status, body, _ = call(url, 'GET', '/v1/families', bearer(token))
        expect(status == 200 and body == {'items': []}, 'new identity has no family membership')
        for label, headers_ in [('synthetic header without session', {'X-Synthetic-Subject': subject}),
                                ('identity credential on a resource route', identity(subject)),
                                ('forged random session', bearer(uuid.uuid4().hex + uuid.uuid4().hex)),
                                ('upper-case session', bearer(token.upper())),
                                ('truncated session', bearer(token[:-1])),
                                ('extended session', bearer(token + '0'))]:
            expect(error_code(call(url, 'GET', '/v1/families', headers_), 401, 'UNAUTHENTICATED'),
                   'resource route rejects ' + label)

        # --- family membership comes only from SQL create_family; still no child access
        status, family, _ = call(url, 'POST', '/v1/families', dict(bearer(token), **{'Idempotency-Key': str(uuid.uuid4())}),
                                 {'label': 'E2E synthetic family'})
        expect(status == 201 and UUID_RE.match(family['id']), 'session creates a family through SQL')
        status, body, _ = call(url, 'GET', '/v1/families', bearer(token))
        expect(status == 200 and [i['id'] for i in body['items']] == [family['id']]
               and body['items'][0]['membership_role'] == 'OWNER', 'listFamilies shows exactly the owned family')
        status, child, _ = call(url, 'POST', f"/v1/families/{family['id']}/children",
                                dict(bearer(token), **{'Idempotency-Key': str(uuid.uuid4())}), {'alias': 'E2E child'})
        expect(status == 201 and UUID_RE.match(child['id']), 'family owner creates a child via the path selector')
        expect(error_code(call(url, 'GET', f"/v1/children/{child['id']}", bearer(token)), 404, 'NOT_FOUND'),
               'ownership does not imply exact-child access (no grant/consent)')
        status, body, _ = call(url, 'GET', f"/v1/families/{family['id']}/children", bearer(token))
        expect(status == 200 and body == {'items': []}, 'child listing requires per-child VIEW_CHILD_PROFILE')
        expect(error_code(call(url, 'POST', f"/v1/children/{child['id']}/pairing-codes",
                               dict(bearer(token), **{'Idempotency-Key': str(uuid.uuid4())}),
                               {'requested_ttl_seconds': 300}), 404, 'NOT_FOUND'),
               'pairing requires PAIR_DEVICE on the exact child')

        # --- cross-parent isolation
        other, _ = login(url)
        other_token = other['session_token']
        expect(other['actor_id'] != session['actor_id'], 'second identity is a distinct principal')
        expect(error_code(call(url, 'GET', f"/v1/families/{family['id']}/children", bearer(other_token)),
                          404, 'NOT_FOUND'), 'other parent cannot list a foreign family')
        expect(call(url, 'POST', f"/v1/families/{family['id']}/children",
                    dict(bearer(other_token), **{'Idempotency-Key': str(uuid.uuid4())}),
                    {'alias': 'forged'})[0] == 404, 'other parent cannot create a child in a foreign family')
        for child_id in (child['id'], str(f['child_a'])):
            expect(error_code(call(url, 'GET', f'/v1/children/{child_id}', bearer(other_token)), 404, 'NOT_FOUND'),
                   'other parent cannot read a foreign child')
        expect(error_code(call(url, 'DELETE', f"/v1/devices/{f['device_a']}/pairing", bearer(other_token)),
                          404, 'NOT_FOUND'), 'other parent cannot revoke a foreign device')

        # --- the same _session() resolves an authorized guardian's exact-child grant
        guardian = fixtures.mint_session(f['a'])
        SECRETS.append(guardian)
        status, body, _ = call(url, 'GET', f"/v1/children/{f['child_a']}", bearer(guardian))
        expect(status == 200 and body['id'] == str(f['child_a']), 'granted guardian reads the exact child')
        expect(error_code(call(url, 'GET', f"/v1/children/{f['child_b']}", bearer(guardian)), 404, 'NOT_FOUND'),
               'granted guardian cannot read an ungranted child')

        # --- logout and expiry
        status, body, headers = call(url, 'DELETE', '/v1/auth/session', bearer(other_token))
        expect(status == 204 and body is None and headers.get('Cache-Control') == 'no-store', 'logout returns 204')
        expect(error_code(call(url, 'GET', '/v1/families', bearer(other_token)), 401, 'UNAUTHENTICATED'),
               'revoked session is refused')
        expect(error_code(call(url, 'DELETE', '/v1/auth/session', bearer(other_token)), 401, 'UNAUTHENTICATED'),
               'second logout is refused')
        expect(error_code(call(url, 'DELETE', '/v1/auth/session', bearer(guardian)), 401, 'UNAUTHENTICATED'),
               'parent logout cannot end a non-parent-OIDC session')
        with fixtures.admin_connection() as admin:
            admin.execute("UPDATE ap_m1.trusted_sessions SET created_at=now()-interval '2 hours', "
                          "expires_at=now()-interval '1 second' WHERE token_sha256=public.digest(%s,'sha256')", (token,))
        expect(error_code(call(url, 'GET', '/v1/families', bearer(token)), 401, 'UNAUTHENTICATED'),
               'expired session is refused')
    print('V2 parent session bridge HTTP end-to-end PASS', flush=True)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: integration_parent_session_v2.py /path/to/ma_backend')
    main(sys.argv[1])
