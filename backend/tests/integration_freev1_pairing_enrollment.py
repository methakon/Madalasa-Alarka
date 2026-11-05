#!/usr/bin/env python3
"""FreeV1 production-build HTTP + synthetic P-256 regression.

Offline: python3 SCRIPT --self-check [--crypto openssl]
Replay (coordinator only, disposable migrated DB):
  python3 SCRIPT /absolute/path/ma_backend --allow-disposable-db \
    --evidence /absolute/path/private-evidence.json
No migrations/builds. --help and --self-check never import DB helpers.
Not Android, TLS, Keystore, real GPS, production OIDC or release evidence.
"""
import argparse
import base64
import contextlib
from datetime import datetime
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from uuid import uuid4

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
DRAFT = ROOT / '.local-db/pairing-http'
CONTEXT = 'amar-pola-m1-device-enroll-v1'
ALPHABET = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'


class Failure(AssertionError):
    """Only fixed, non-sensitive labels belong in this exception."""


def require(condition, label):
    if not condition:
        raise Failure(label)


def b64url(data):
    return base64.urlsafe_b64encode(data).decode('ascii').rstrip('=')


@contextlib.contextmanager
def signer(provider):
    """Yield real DER SPKI and a SHA256/ECDSA DER signer; never persist key evidence."""
    DRAFT.mkdir(parents=True, exist_ok=True)
    if provider == 'auto':
        provider = 'cryptography' if importlib.util.find_spec('cryptography') else 'openssl'
    if provider == 'cryptography':
        from cryptography.hazmat.primitives import hashes, serialization
        from cryptography.hazmat.primitives.asymmetric import ec
        key = ec.generate_private_key(ec.SECP256R1())
        spki = key.public_key().public_bytes(serialization.Encoding.DER,
                                           serialization.PublicFormat.SubjectPublicKeyInfo)
        def sign(message):
            signature = key.sign(message, ec.ECDSA(hashes.SHA256()))
            key.public_key().verify(signature, message, ec.ECDSA(hashes.SHA256()))
            return signature
        yield spki, sign, provider
    else:
        require(shutil.which('openssl') is not None, 'openssl executable required')
        # Private directory, deleted on exit; all transient files stay inside draft.
        with tempfile.TemporaryDirectory(prefix='crypto-', dir=DRAFT) as directory:
            private = Path(directory) / 'private.pem'
            def run(args, data=None):
                result = subprocess.run(['openssl', *args], input=data, stdout=subprocess.PIPE,
                                        stderr=subprocess.DEVNULL, timeout=15, check=True)
                return result.stdout
            run(['genpkey', '-algorithm', 'EC', '-pkeyopt', 'ec_paramgen_curve:P-256',
                 '-out', str(private)])
            private.chmod(0o600)
            spki = run(['pkey', '-in', str(private), '-pubout', '-outform', 'DER'])
            def sign(message):
                return run(['dgst', '-sha256', '-sign', str(private)], message)
            yield spki, sign, 'openssl'


def self_check(provider):
    # No DB imports/config reads/server process. Verify signing, not HTTP behavior.
    with signer(provider) as (spki, sign, selected):
        message = (CONTEXT + ':offline-synthetic-nonce').encode('ascii')
        signature = sign(message)
        require(80 <= len(spki) <= 4096 and signature[0] == 0x30, 'SPKI/signature shape')
        if selected == 'openssl':
            with tempfile.TemporaryDirectory(prefix='verify-', dir=DRAFT) as directory:
                public = Path(directory) / 'public.der'
                sigfile = Path(directory) / 'signature.der'
                public.write_bytes(spki)
                sigfile.write_bytes(signature)
                def verify(data):
                    return subprocess.run(['openssl', 'dgst', '-sha256', '-verify', str(public),
                                           '-keyform', 'DER', '-signature', str(sigfile)],
                                          input=data, stdout=subprocess.DEVNULL,
                                          stderr=subprocess.DEVNULL, timeout=15).returncode
                require(verify(message) == 0 and verify(message + b'x') != 0,
                        'openssl verify and tamper rejection')
        else:
            from cryptography.exceptions import InvalidSignature
            from cryptography.hazmat.primitives import hashes, serialization
            from cryptography.hazmat.primitives.asymmetric import ec
            public = serialization.load_der_public_key(spki)
            require(isinstance(public, ec.EllipticCurvePublicKey), 'EC public key required')
            assert isinstance(public, ec.EllipticCurvePublicKey)
            try:
                public.verify(signature, message + b'x', ec.ECDSA(hashes.SHA256()))
            except InvalidSignature:
                pass
            else:
                raise Failure('cryptography must reject tampered message')
        print(json.dumps({'offline_crypto_check': True, 'provider': selected,
                          'http_db_executed': False}))


def exercise(binary, evidence, sensitive, provider):
    # Deferred imports are essential: offline source review must not touch the DB.
    sys.path.insert(0, str(ROOT / 'backend/tests'))
    import integration_device_ingestion_v2 as ingestion
    import integration_parent_session_v2 as parent
    fixtures = ingestion.fixtures
    parent.SECRETS = sensitive
    cache = binary.parent / 'CMakeCache.txt'
    require(binary.is_file() and os.access(binary, os.X_OK), 'executable backend required')
    require(cache.is_file() and re.search(r'^MA_SYNTHETIC_AUTH:BOOL=OFF$',
                                        cache.read_text(), re.MULTILINE) is not None,
            'adjacent CMakeCache must declare MA_SYNTHETIC_AUTH=OFF')
    evidence['binary_sha256'] = hashlib.sha256(binary.read_bytes()).hexdigest()
    evidence['source_head'] = subprocess.check_output(
        ['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip()
    evidence['cache_synthetic_auth'] = 'OFF'
    evidence['release_profile'] = 'FREE_ONLY'
    evidence['binary_provenance_limit'] = 'cache declaration does not certify binary matches source'
    runtime = ingestion.conninfo_to_dict(fixtures._dsn('runtime'))
    for kind in ('runtime', 'admin', 'auth'):
        dsn = fixtures._dsn(kind)  # Existing target/private-config guards; never bypass.
        sensitive.extend((dsn, ingestion._dsn_secret(dsn)))
    with fixtures.runtime_connection() as db:
        role = db.execute('SELECT rolsuper,rolbypassrls FROM pg_roles WHERE rolname=current_user').fetchone()
        require(role == (False, False), 'runtime must be NOSUPERUSER NOBYPASSRLS')
    evidence['restricted_runtime'] = True
    f = ingestion.domain_fixture()
    child = f['child_a']
    guardian = None
    issued_keys = []
    try:
        foreign_device = fixtures.seed_core()['device_a']
        # domain_fixture owns its child/device but seeds an invented ACTIVE SPKI.
        # Remove ONLY that owned unused synthetic device/key. The HTTP enrollment,
        # never a fixture insert, must create its replacement and credential.
        with fixtures.admin_connection() as db:
            require(db.execute('SELECT admission_state FROM ap_m1.free_child_admissions '
                               'WHERE child_id=%s', (child,)).fetchone() == ('ADMITTED',),
                    'fixture requires an available admitted slot; do not alter capacity')
            db.execute('DELETE FROM ap_m1.device_key_records WHERE device_id=%s', (f['device_a'],))
            db.execute('DELETE FROM ap_m1.devices WHERE id=%s', (f['device_a'],))
            require(db.execute("SELECT count(*) FROM ap_m1.child_access_grants_v2 "
                               "WHERE child_id=%s AND adult_id=%s AND scope='PAIR_DEVICE' "
                               "AND revoked_at IS NULL", (child, f['a'])).fetchone()[0] == 1,
                    'owned fixture must contain exact-child pairing authority')
        guardian = fixtures.mint_session(f['a'])  # Protected local_test_settings only.
        sensitive.append(guardian)
        evidence['guardian_auth'] = 'guarded local fixture session, NOT production identity'

        def state():
            counts = ingestion.snapshot(child)
            with fixtures.admin_connection() as db:
                counts.update({table: db.execute('SELECT count(*) FROM ap_m1.' + table +
                                                 ' WHERE child_id=%s', (child,)).fetchone()[0]
                               for table in ('devices', 'pairing_codes', 'child_device_pairing_log')})
                for table in ('device_credentials', 'device_key_records', 'enrollment_challenges'):
                    counts[table] = db.execute('SELECT count(*) FROM ap_m1.' + table +
                        ' WHERE device_id IN (SELECT id FROM ap_m1.devices WHERE child_id=%s)',
                        (child,)).fetchone()[0]
            return counts

        def request(label, method, path, status, body=None, token=None, code=None, key=None,
                    unchanged=False):
            before = state() if unchanged else None
            headers = parent.bearer(token) if token else {}
            if key:
                headers['Idempotency-Key'] = key
            actual, payload, _ = parent.call(url, method, path, headers, body)
            # Never serialize paths, requests, responses, headers or exception bodies.
            if isinstance(payload, dict):
                for name in ('credential_token', 'pairing_code', 'nonce_base64url'):
                    if isinstance(payload.get(name), str):
                        sensitive.append(payload[name])
            check = dict(label=label, status=actual, passed=False)
            if isinstance(payload, dict):
                for reason in ('nonce does not match challenge', 'signature verification failed',
                               'challenge not found, expired or already spent'):
                    if payload.get('message') == reason:
                        check['denial_reason'] = reason
            evidence['checks'].append(check)
            require(actual == status, label + ': HTTP status')
            if code:
                require(isinstance(payload, dict) and payload.get('code') == code,
                        label + ': error code')
            if unchanged:
                require(state() == before, label + ': denied/replayed request mutated row counts')
                check['row_counts_unchanged'] = True
            check['passed'] = True
            return payload

        def issue(label):
            key = str(uuid4())
            issued_keys.append(key)
            payload = request(label, 'POST', f'/v1/children/{child}/pairing-codes', 201,
                              {'requested_ttl_seconds': 300}, guardian, key=key)
            code = payload.get('pairing_code')
            require(isinstance(code, str) and len(code) == 10 and set(code) <= set(ALPHABET),
                    'backend must issue exact ten-character pairing code')
            require(payload.get('child_id') == str(child), 'pairing code exact-child binding')
            return code, key

        with signer(provider) as (spki, sign, selected):
            evidence['crypto_provider'] = selected
            enrollment = dict(public_key_spki_base64=base64.b64encode(spki).decode('ascii'),
                              algorithm='ECDSA_P256_SHA256', app_version='source-http-harness',
                              android_api=35)
            # Existing guarded startup clears ambient MA_* and explicitly uses
            # v2_session / FREE_ONLY, restricted runtime, no synthetic auth headers.
            with ingestion.server(binary, runtime, evidence, sensitive,
                                  auth=ingestion.conninfo_to_dict(fixtures._dsn('auth'))) as url:
                request('wrong_child_pairing', 'POST', f"/v1/children/{f['child_b']}/pairing-codes",
                        404, {'requested_ttl_seconds': 300}, guardian, code='NOT_FOUND',
                        key=str(uuid4()), unchanged=True)
                request('wrong_child_latest', 'GET', f"/v1/children/{f['child_b']}/location/latest",
                        404, token=guardian, code='NOT_FOUND', unchanged=True)
                # Mutate only the owned admission and restore the complete saved row state.
                with fixtures.admin_connection() as db:
                    saved = db.execute('SELECT admission_state,admitted_at,released_at '
                                       'FROM ap_m1.free_child_admissions WHERE child_id=%s',
                                       (child,)).fetchone()
                    db.execute("UPDATE ap_m1.free_child_admissions SET admission_state='WAITLISTED',"
                               'admitted_at=NULL,released_at=NULL WHERE child_id=%s', (child,))
                try:
                    request('unadmitted_pairing', 'POST', f'/v1/children/{child}/pairing-codes',
                            403, {'requested_ttl_seconds': 300}, guardian, code='FORBIDDEN',
                            key=str(uuid4()), unchanged=True)
                    request('unadmitted_latest', 'GET', f'/v1/children/{child}/location/latest',
                            404, token=guardian, code='NOT_FOUND', unchanged=True)
                finally:
                    with fixtures.admin_connection() as db:
                        db.execute('UPDATE ap_m1.free_child_admissions SET admission_state=%s,'
                                   'admitted_at=%s,released_at=%s WHERE child_id=%s', (*saved, child))
                expired, _ = issue('issue_expiring_code')
                with fixtures.admin_connection() as db:
                    db.execute("UPDATE ap_m1.pairing_codes SET created_at=clock_timestamp()-interval '10 minutes',"
                               "expires_at=clock_timestamp()-interval '1 second' WHERE child_id=%s "
                               "AND code_sha256=public.digest(%s,'sha256')", (child, expired))
                request('expired_code', 'POST', '/v1/enrollment', 404,
                        dict(enrollment, pairing_code=expired), code='NOT_FOUND', unchanged=True)
                code, key = issue('issue_live_code')
                request('pairing_issue_idempotency_replay', 'POST', f'/v1/children/{child}/pairing-codes',
                        409, {'requested_ttl_seconds': 300}, guardian, code='CONFLICT', key=key,
                        unchanged=True)
                challenge = request('redeem_exact_backend_code', 'POST', '/v1/enrollment', 201,
                                    dict(enrollment, pairing_code=code))
                require(challenge.get('challenge_context') == CONTEXT, 'canonical context must match server')
                device = challenge['device_id']
                f['device_a'] = device  # cleanup_domain must target the server-created device.
                enrollment_id = challenge['enrollment_id']
                request('redeemed_code_replay', 'POST', '/v1/enrollment', 404,
                        dict(enrollment, pairing_code=code), code='NOT_FOUND', unchanged=True)
                nonce = challenge['nonce_base64url']
                with fixtures.admin_connection() as db:
                    stored = bytes(db.execute('SELECT nonce_sha256 FROM ap_m1.enrollment_challenges WHERE id=%s',
                                              (enrollment_id,)).fetchone()[0])
                require(stored == hashlib.sha256(nonce.encode('ascii')).digest(),
                        'issued nonce must match the persisted challenge hash')
                # Canonical server message: literal context + colon + literal URL-safe nonce.
                # Do NOT decode nonce bytes or concatenate IDs/JSON into this message.
                proof = dict(nonce_base64url=nonce,
                             signature_base64url=b64url(sign((CONTEXT + ':' + nonce).encode('ascii'))))
                sensitive.append(proof['signature_base64url'])
                credential = request('canonical_p256_proof', 'POST',
                                     f'/v1/enrollment/{enrollment_id}/proof', 201, proof)
                token = credential['credential_token']
                require(credential.get('device_id') == device and isinstance(token, str) and
                        re.fullmatch(r'[A-Za-z0-9_-]{43}', token) is not None,
                        'proof must yield server DeviceBearer bound to returned device')
                with fixtures.admin_connection() as db:
                    binding = db.execute('SELECT d.child_id,d.spki_public_key,c.issued_via '
                        'FROM ap_m1.devices d JOIN ap_m1.device_credentials c ON c.device_id=d.id '
                        "WHERE d.id=%s AND c.token_sha256=public.digest(%s,'sha256')",
                        (device, token)).fetchone()
                    require(binding is not None and binding[0] == child and bytes(binding[1]) == spki
                            and binding[2] == 'ENROLLMENT', 'persisted child/SPKI/credential binding')
                request('proof_replay', 'POST', f'/v1/enrollment/{enrollment_id}/proof', 401,
                        proof, code='UNAUTHENTICATED', unchanged=True)
                event = ingestion.event(8100001)
                body = {'batch_id': str(uuid4()), 'events': [event]}
                request('missing_device_bearer', 'POST', f'/v1/devices/{device}/locations:batch',
                        401, body, code='UNAUTHENTICATED', unchanged=True)
                request('wrong_device_bearer', 'POST', f'/v1/devices/{foreign_device}/locations:batch',
                        403, body, token, code='FORBIDDEN', unchanged=True)
                receipt = request('enrolled_bearer_location_batch', 'POST',
                                  f'/v1/devices/{device}/locations:batch', 202, body, token)
                require(receipt == dict(batch_id=body['batch_id'], accepted_count=1, duplicate_count=0,
                                       rejected_count=0, processing='QUEUED',
                                       durable_stage='RAW_OBSERVATIONS_COMMITTED'), 'durable ingest receipt')
                before_replay = ingestion.snapshot(child)
                replay = request('batch_replay', 'POST', f'/v1/devices/{device}/locations:batch',
                                 202, body, token, unchanged=True)
                require(replay.get('accepted_count') == 0 and replay.get('duplicate_count') == 1,
                        'batch replay must deduplicate')
                require(before_replay['location_observations'] == 1, 'one durable observation only')
                latest = request('guardian_latest_from_enrolled_device', 'GET',
                                 f'/v1/children/{child}/location/latest', 200, token=guardian)
                location = latest.get('location') or {}
                require(latest.get('child_id') == str(child) and latest.get('server_verified') is True
                        and latest.get('history_window_hours') == 6 and latest.get('state') == 'LAST_KNOWN'
                        and location.get('source_device_id') == device
                        and location.get('latitude_e6') == round(event['latitude'] * 1000000)
                        and location.get('longitude_e6') == round(event['longitude'] * 1000000)
                        and isinstance(location.get('observed_at_epoch_ms'), int)
                        and abs(location['observed_at_epoch_ms'] -
                                datetime.fromisoformat(event['observed_at']).timestamp() * 1000) <= 1
                        and location.get('accuracy_meters') == event['accuracy_m'],
                        'guardian latest must reflect enrolled device synthetic observation')
                request('guardian_revoke_pairing', 'DELETE', f'/v1/devices/{device}/pairing',
                        204, token=guardian)
                with fixtures.admin_connection() as db:
                    require(db.execute('SELECT enrollment_state,revoked_at IS NOT NULL '
                                       'FROM ap_m1.devices WHERE id=%s', (device,)).fetchone()
                            == ('REVOKED', True), 'read back guardian device revocation')
                request('revoked_device_bearer', 'POST', f'/v1/devices/{device}/locations:batch',
                        401, {'batch_id': str(uuid4()), 'events': [ingestion.event(8100002)]},
                        token, code='UNAUTHENTICATED', unchanged=True)
                evidence['final_counts'] = state()
    finally:
        # Server helper already scrubs log text; do not retain ANY raw log fields,
        # request IDs, fixture IDs, token digests, coordinate values or subprocess PIDs.
        evidence['sqlstates'] = sorted(set(re.findall(r'state=([A-Z0-9]{5})', evidence.get('server_log', ''))))
        evidence.pop('server_log', None)
        evidence.pop('server_pid', None)
        with fixtures.admin_connection() as db:
            owned_devices = db.execute('SELECT id FROM ap_m1.devices WHERE child_id=%s',
                                       (child,)).fetchall()
            require(len(owned_devices) <= 1, 'unexpected owned-device count during cleanup')
            if owned_devices:
                f['device_a'] = owned_devices[0][0]
            if guardian:
                db.execute("DELETE FROM ap_m1.trusted_sessions WHERE token_sha256=public.digest(%s,'sha256')",
                           (guardian,))
            # Remove enrollment-only dependencies absent from cleanup_domain.
            for table in ('device_credentials', 'enrollment_challenges'):
                db.execute('DELETE FROM ap_m1.' + table + ' WHERE device_id IN '
                           '(SELECT id FROM ap_m1.devices WHERE child_id=%s)', (child,))
            db.execute('DELETE FROM ap_m1.pairing_codes WHERE child_id=%s', (child,))
            db.execute('DELETE FROM ap_m1.child_device_pairing_log WHERE child_id=%s', (child,))
            # Only completed pairing claims owned by this invocation; no shared actor sweep.
            for key in issued_keys:
                db.execute('DELETE FROM ap_m1.idempotency_claims WHERE actor_id=%s '
                           'AND namespace=%s AND key_sha256=public.digest(%s,\'sha256\')',
                           (f['a'], 'POST /children/pairing-codes', key))
        ingestion.cleanup_domain(f)
        with fixtures.admin_connection() as db:
            require(db.execute('SELECT count(*) FROM ap_m1.children WHERE id=%s',
                               (child,)).fetchone()[0] == 0, 'owned child cleanup readback')
        evidence['fixture_cleaned'] = True
        evidence['shared_seed_limit'] = 'seed_core shared synthetic actors/settings remain, as in existing fixtures'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path, nargs='?')
    parser.add_argument('--evidence', type=Path)
    parser.add_argument('--allow-disposable-db', action='store_true')
    parser.add_argument('--self-check', action='store_true')
    parser.add_argument('--crypto', choices=('auto', 'cryptography', 'openssl'), default='auto')
    args = parser.parse_args()
    if args.self_check:
        self_check(args.crypto)
        return 0
    if not args.allow_disposable_db or args.binary is None or args.evidence is None:
        parser.error('HTTP replay needs binary, --evidence and explicit --allow-disposable-db')
    evidence = dict(suite='freev1-production-http-pairing-enrollment', passed=False, checks=[],
                    scope='HTTP+synthetic crypto only; no Android/TLS/Keystore/production OIDC claims')
    sensitive = []
    try:
        exercise(args.binary.resolve(), evidence, sensitive, args.crypto)
        evidence['passed'] = True
    except Exception as exc:
        # Driver/helper exceptions can embed raw DSNs, IDs or response bodies.
        evidence['failure'] = str(exc) if isinstance(exc, Failure) else type(exc).__name__
    finally:
        evidence.pop('server_log', None)
        evidence.pop('server_pid', None)
        evidence['passed_checks'] = sum(c['passed'] for c in evidence['checks'])
        text = json.dumps(evidence, indent=2)
        # Defense in depth; output is allowlisted aggregates, never raw HTTP/DB data.
        for value in sorted(set(sensitive), key=len, reverse=True):
            if value:
                text = text.replace(value, '[REDACTED]')
        args.evidence.parent.mkdir(parents=True, exist_ok=True)
        fd = os.open(args.evidence, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, 'w') as output:
            output.write(text + '\n')
    print(json.dumps({k: evidence[k] for k in ('suite', 'passed', 'passed_checks')}))
    return 0 if evidence['passed'] else 1


if __name__ == '__main__':
    sys.exit(main())
