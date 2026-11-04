#!/usr/bin/env python3
"""Parent-owned, append-only synthetic fixture for the queued FF07 harness.

Creates N synthetic children/devices with LOCAL_TEST_APPROVED authority/consent
(explicit synthetic opt-in, never a legal-approval claim), active keys and
credentials, then writes an owner-only private fixture file. Never deletes or
resets existing rows; refuses if the target already holds load fixtures.
"""
from __future__ import annotations
import argparse, hashlib, json, os, secrets, sys
from pathlib import Path
from uuid import UUID, uuid5

import psycopg

ROOT = Path(__file__).resolve().parents[3]
NAMESPACE = UUID('6f1d7d64-1f2c-5a4a-8a49-3d0c9a6f0e51')


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--devices', type=int, default=108)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--connection', type=Path, default=ROOT / '.local-db/connection.json')
    args = ap.parse_args()
    if not 1 <= args.devices <= 108:
        raise SystemExit('refusing more than 108 synthetic devices')
    if args.output.exists():
        raise SystemExit('refusing to overwrite an existing fixture file')
    cfg = json.loads(args.connection.read_text())['test']
    runtime_dsn, proof_dsn = cfg['runtime'], cfg['migration']

    family = uuid5(NAMESPACE, 'family')
    guardian = uuid5(NAMESPACE, 'guardian')
    devices = []
    with psycopg.connect(cfg['admin']) as con:
        # Explicit synthetic opt-in required by the LOCAL_TEST_APPROVED path.
        con.execute('INSERT INTO ap_m1.local_test_settings(singleton,enabled) VALUES(true,true) '
                    'ON CONFLICT(singleton) DO UPDATE SET enabled=true')
        con.execute("INSERT INTO ap_m1.parent_principals(id,oidc_issuer,oidc_subject) "
                    "VALUES(%s,'https://synthetic.invalid',%s) ON CONFLICT DO NOTHING",
                    (guardian, 'ff07-' + str(family)))
        con.execute("INSERT INTO ap_m1.families(id,label) VALUES(%s,'synthetic ff07 load') "
                    'ON CONFLICT DO NOTHING', (family,))
        con.execute("INSERT INTO ap_m1.guardian_memberships(family_id,principal_id,membership_role) "
                    "VALUES(%s,%s,'OWNER') ON CONFLICT DO NOTHING", (family, guardian))
        existing = con.execute("SELECT count(*) FROM ap_m1.children WHERE family_id=%s", (family,)).fetchone()[0]
        if existing:
            raise SystemExit('family already has children; refusing to create a second load generation')

        for index in range(args.devices):
            child = uuid5(NAMESPACE, f'child-{index}')
            device = uuid5(NAMESPACE, f'device-{index}')
            review = uuid5(NAMESPACE, f'review-{index}')
            con.execute(
                "INSERT INTO ap_m1.children(id,family_id,alias) VALUES(%s,%s,%s)",
                (child, family, f'synthetic-load-{index:03d}'))
            con.execute(
                'INSERT INTO ap_m1.child_authority_reviews(id,child_id,adult_id,state,lawful_basis_version,'
                "method_code,reviewed_at,expires_at) VALUES(%s,%s,%s,'LOCAL_TEST_APPROVED','synthetic-v1',"
                "'SYNTHETIC_FIXTURE',now(),now()+interval '1 day')", (review, child, guardian))
            for purpose in ('CORE', 'LOCATION'):
                con.execute(
                    'INSERT INTO ap_m1.consent_records(id,child_id,adult_id,purpose,status,authority_review_id,'
                    "notice_version,legal_state,expires_at) VALUES(%s,%s,%s,%s,'GRANTED',%s,'synthetic-v1',"
                    "'LOCAL_TEST_APPROVED',now()+interval '1 day')",
                    (uuid5(NAMESPACE, f'consent-{index}-{purpose}'), child, guardian, purpose, review))
            con.execute(
                'INSERT INTO ap_m1.devices(id,family_id,child_id,spki_public_key,enrollment_state) '
                "VALUES(%s,%s,%s,%s,'ACTIVE')",
                (device, family, child, ('SYNTHETIC-FF07-' + str(device)).encode() * 2))
            key = con.execute(
                'INSERT INTO ap_m1.device_key_records(device_id,fingerprint_sha256,state) '
                "SELECT %s,public.digest(spki_public_key,'sha256'),'ACTIVE' FROM ap_m1.devices WHERE id=%s "
                'RETURNING key_id', (device, device)).fetchone()[0]
            con.execute(
                'INSERT INTO ap_m1.location_collection_policies(child_id,enabled,retain_for,policy_reference) '
                "VALUES(%s,true,interval '7 days','SYNTHETIC_FF07_LOAD')", (child,))
            bearer = secrets.token_hex(24)
            con.execute(
                'INSERT INTO ap_m1.device_credentials(device_id,key_id,token_sha256,issued_via,expires_at,'
                'bound_key_generation,bound_key_fingerprint_sha256) '
                "SELECT %s,%s,%s,'ENROLLMENT',now()+interval '3 hours',k.generation,k.fingerprint_sha256 "
                'FROM ap_m1.device_key_records k WHERE k.key_id=%s',
                (device, key, hashlib.sha256(bearer.encode()).digest(), key))
            devices.append({'device_id': str(device), 'child_id': str(child),
                            'credential': bearer, 'sequence_start': 1})

    fixture = {'synthetic_only': True, 'runtime_dsn': runtime_dsn, 'proof_dsn': proof_dsn,
               'device_guc': 'ap.device_credential_sha256', 'devices': devices}
    fd = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'w') as handle:
        json.dump(fixture, handle)
    print(json.dumps({'devices': len(devices), 'family': str(family),
                      'fixture_mode': oct(args.output.stat().st_mode & 0o777)}))
    return 0


if __name__ == '__main__':
    sys.exit(main())
