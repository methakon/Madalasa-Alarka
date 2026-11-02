"""M1/V2 convergence: source guard + rollback-only synthetic role regressions.

Parent exclusively owns migration replay. No DDL/reset in this module.
Run: python -m unittest discover -s backend/tests/database -p test_m1_compatibility.py -v
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[3]
MIGRATION = ROOT / 'backend/persistence/migrations/0017_m1_lineage_compatibility.sql'


def seed_historical_compatibility(conn):
    """Parent replay hook: call after original M1 0001..0004, BEFORE V2.

    DML only; caller owns commit/rollback. Returns the exact preservation oracle.
    Never creates schema, applies migrations, or guesses approved V2 authority.
    """
    from uuid import uuid4
    actor, family, child, device, key, credential, challenge = [uuid4() for _ in range(7)]
    spki = b'SYNTHETIC-HISTORICAL-SPKI-' * 4
    token, nonce, idem = uuid4().bytes*2, uuid4().bytes*2, uuid4().bytes*2
    conn.execute('INSERT INTO ap_m1.parent_principals(id,oidc_issuer,oidc_subject) VALUES(%s,%s,%s)', (actor,'https://synthetic.example.invalid',str(actor)))
    conn.execute("INSERT INTO ap_m1.families(id,label) VALUES(%s,'Historical synthetic')", (family,))
    conn.execute("INSERT INTO ap_m1.guardian_memberships(family_id,principal_id,membership_role) VALUES(%s,%s,'OWNER')", (family,actor))
    conn.execute("INSERT INTO ap_m1.children(id,family_id,alias) VALUES(%s,%s,'Synthetic legacy')", (child,family))
    conn.execute("INSERT INTO ap_m1.devices(id,family_id,child_id,spki_public_key,enrollment_state) VALUES(%s,%s,%s,%s,'ACTIVE')", (device,family,child,spki))
    conn.execute('INSERT INTO ap_m1.device_key_records(key_id,device_id,fingerprint_sha256) VALUES(%s,%s,sha256(%s))', (key,device,spki))
    conn.execute("INSERT INTO ap_m1.device_credentials(id,device_id,key_id,token_sha256,issued_via,expires_at) VALUES(%s,%s,%s,%s,'ENROLLMENT',now()+interval '1 hour')", (credential,device,key,token))
    conn.execute("INSERT INTO ap_m1.credential_renewal_challenges(id,device_id,key_id,nonce_sha256,expires_at,consumed_at,redeemed_at) VALUES(%s,%s,%s,%s,now()+interval '3 minutes',now(),now())", (challenge,device,key,nonce))
    conn.execute("INSERT INTO ap_m1.idempotency_keys(actor_id,namespace,key_sha256,request_sha256,response_status,response_body,completed_at,expires_at) VALUES(%s,'POST /families',%s,%s,201,'{\"synthetic\":true}',now(),now()+interval '24 hours')", (actor,idem,idem))
    renewal = conn.execute('SELECT id,device_id,key_id,nonce_sha256,created_at,expires_at,consumed_at,redeemed_at FROM ap_m1.credential_renewal_challenges WHERE id=%s', (challenge,)).fetchone()
    claim = conn.execute("SELECT actor_id,namespace,key_sha256,request_sha256,response_status,response_body,body_omitted,created_at,completed_at,expires_at FROM ap_m1.idempotency_keys WHERE actor_id=%s", (actor,)).fetchone()
    return dict(actor=actor,device=device,key=key,credential=credential,challenge=challenge,token=token,renewal=renewal,claim=claim)


def assert_historical_compatibility(conn, expected):
    """Parent replay hook: executed after 0017; asserts data AND fail-closed auth."""
    assert conn.execute('SELECT id,device_id,key_id,nonce_sha256,created_at,expires_at,consumed_at,redeemed_at FROM ap_m1.credential_renewal_challenges WHERE id=%s', (expected['challenge'],)).fetchone() == expected['renewal']
    assert conn.execute('SELECT actor_id,namespace,key_sha256,request_sha256,response_status,response_body,body_omitted,created_at,completed_at,expires_at FROM ap_m1.idempotency_keys WHERE actor_id=%s', (expected['actor'],)).fetchone() == expected['claim']
    row = conn.execute('SELECT device_id,key_id,token_sha256,revoked_at FROM ap_m1.device_credentials WHERE id=%s', (expected['credential'],)).fetchone()
    assert row[:3] == (expected['device'],expected['key'],expected['token'])
    assert row[3] is not None, 'legacy token must require fresh proof, not invented generation'
    assert conn.execute('SELECT * FROM ap_m1.authenticate_device_credential(%s)', (expected['token'],)).fetchall() == []
    assert conn.execute('SELECT enrollment_state,revoked_at FROM ap_m1.devices WHERE id=%s', (expected['device'],)).fetchone() == ('ACTIVE',None)
    assert conn.execute('SELECT state,revoked_at FROM ap_m1.device_key_records WHERE key_id=%s', (expected['key'],)).fetchone() == ('ACTIVE',None)


class CompatibilitySource(unittest.TestCase):
    def test_bridge_exists_and_rejects_unconvertible_rows(self):
        self.assertTrue(MIGRATION.exists(), 'additive compatibility interface is missing')
        sql = MIGRATION.read_text()
        self.assertIn('unconvertible V2 renewal challenge', sql)
        self.assertNotIn('GRANT EXECUTE ON ALL FUNCTIONS', sql)
        self.assertNotIn('DELETE FROM ap_m1.devices', sql)


class CompatibilityDatabase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from fixtures import admin_connection, seed_core
        cls.admin_connection = staticmethod(admin_connection)
        # Persist only the shared synthetic fixture; individual tests roll back.
        cls.f = seed_core()

    def test_canonical_types_and_inventory(self):
        with self.admin_connection() as c:
            types = dict(c.execute("SELECT column_name,data_type FROM information_schema.columns WHERE table_schema='ap_m1' AND table_name='credential_renewal_challenges'").fetchall())
            self.assertEqual(types['key_id'], 'uuid')
            self.assertEqual(types['nonce_sha256'], 'bytea')
            self.assertIn('redeemed_at', types)
            rows = c.execute("SELECT table_name,key_kind,purge_order FROM ap_m1.erasure_store_inventory WHERE table_name IN ('device_credentials','credential_renewal_challenges')").fetchall()
            self.assertEqual(len(rows), 2)
            self.assertTrue(all(r[1] == 'DEVICE' and r[2] < 410 for r in rows))
            c.rollback()

    def test_runtime_and_lookup_cannot_mutate_or_issue(self):
        from fixtures import runtime_connection
        signatures = ['activate_enrolled_device(uuid,bytea,integer)', 'consume_enrollment_challenge(uuid)',
                      'consume_renewal_challenge(uuid,uuid)', 'issue_renewal_credential(uuid,uuid,bytea,integer)',
                      'redeem_pairing_code(bytea,bytea,bytea,integer)',
                      'issue_credential_renewal_challenge(uuid,bytea,bytea,integer)',
                      'mint_session(uuid,uuid,uuid,interval)']
        with runtime_connection() as c:
            for sig in signatures:
                self.assertFalse(c.execute("SELECT has_function_privilege(current_user,%s,'EXECUTE')", ('ap_m1.' + sig,)).fetchone()[0], sig)
            for table in ('device_credentials', 'credential_renewal_challenges', 'devices', 'device_key_records', 'idempotency_keys'):
                for privilege in ('INSERT', 'UPDATE', 'DELETE'):
                    self.assertFalse(c.execute('SELECT has_table_privilege(current_user,%s,%s)', ('ap_m1.'+table, privilege)).fetchone()[0])
            c.rollback()
        with self.admin_connection() as c:
            for table in ('device_credentials', 'credential_renewal_challenges', 'devices', 'device_key_records', 'idempotency_claims'):
                self.assertFalse(c.execute("SELECT has_table_privilege('ap_m1_auth',%s,'INSERT,UPDATE,DELETE')", ('ap_m1.'+table,)).fetchone()[0])
            c.rollback()

    def test_idempotency_actor_binding_replay_and_mismatch(self):
        import psycopg
        from fixtures import parent_connection
        f = self.f
        with parent_connection(f['a'], f['family_a']) as c:
            args = (f['a'], 'POST /families', bytes([73])*32, bytes([74])*32)
            self.assertEqual(c.execute('SELECT outcome FROM ap_m1.idempotency_claim(%s,%s,%s,%s)', args).fetchone()[0], 'NEW')
            self.assertTrue(c.execute("SELECT ap_m1.idempotency_record(%s,%s,%s,201,'{}'::jsonb)", args[:3]).fetchone()[0])
            self.assertEqual(c.execute('SELECT outcome FROM ap_m1.idempotency_claim(%s,%s,%s,%s)', args).fetchone()[0], 'REPLAY')
            self.assertEqual(c.execute('SELECT outcome FROM ap_m1.idempotency_claim(%s,%s,%s,%s)', (*args[:3], bytes([75])*32)).fetchone()[0], 'MISMATCH')
            for actor in (f['b'], None):
                with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                    with c.transaction():
                        c.execute('SELECT * FROM ap_m1.idempotency_claim(%s,%s,%s,%s)', (actor,*args[1:]))
                with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                    with c.transaction():
                        c.execute("SELECT ap_m1.idempotency_record(%s,%s,%s,201,'{}'::jsonb)", (actor,*args[1:3]))

    def test_runtime_actual_calls_and_direct_dml_fail(self):
        import psycopg
        from fixtures import runtime_connection
        f = self.f
        statements = [
            ("SELECT ap_m1.mint_session(%s)", (f['a'],)),
            ("SELECT ap_m1.activate_enrolled_device(%s,%s,3600)", (f['device_a'], bytes(32))),
            ("SELECT ap_m1.issue_renewal_credential(%s,%s,%s,3600)", (f['device_a'], f['device_a'], bytes(32))),
            ("UPDATE ap_m1.devices SET enrollment_state='ACTIVE' WHERE id=%s", (f['device_a'],)),
            ("DELETE FROM ap_m1.device_credentials WHERE device_id=%s", (f['device_a'],)),
            ("DELETE FROM ap_m1.credential_renewal_challenges WHERE device_id=%s", (f['device_a'],))]
        with runtime_connection() as c:
            for sql, args in statements:
                with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                    with c.transaction():
                        c.execute(sql,args)
            c.rollback()

    def test_issuer_renewal_once_and_proof_consumption_once(self):
        from uuid import uuid4
        from fixtures import auth_connection
        f = self.f
        with self.admin_connection() as c:
            fingerprint = c.execute('SELECT fingerprint_sha256 FROM ap_m1.device_key_records WHERE key_id=%s', (f['device_key_a'],)).fetchone()[0]
            c.rollback()
        # Synthetic proof authorization only, not real cryptographic verification.
        # Keep all writes rolled back. Production must COMMIT consume before proof.
        with auth_connection() as c:
            challenge = c.execute('SELECT ap_m1.issue_credential_renewal_challenge(%s,%s,%s,120)', (f['device_a'],fingerprint,uuid4().bytes*2)).fetchone()[0]
            self.assertIsNotNone(challenge)
            args = (f['device_a'],challenge)
            self.assertEqual(len(c.execute('SELECT * FROM ap_m1.consume_renewal_challenge(%s,%s)', args).fetchall()),1)
            self.assertEqual(c.execute('SELECT * FROM ap_m1.consume_renewal_challenge(%s,%s)', args).fetchall(),[])
            issue = (*args,uuid4().bytes*2)
            self.assertIsNotNone(c.execute('SELECT ap_m1.issue_renewal_credential(%s,%s,%s,3600)', issue).fetchone()[0])
            self.assertIsNone(c.execute('SELECT ap_m1.issue_renewal_credential(%s,%s,%s,3600)', issue).fetchone()[0])
            c.rollback()

    def test_bound_credential_positive_and_key_only_revocation(self):
        from uuid import uuid4
        f = self.f
        with self.admin_connection() as c:
            token = uuid4().bytes * 2
            c.execute("INSERT INTO ap_m1.device_credentials(device_id,key_id,token_sha256,issued_via,expires_at,bound_key_generation,bound_key_fingerprint_sha256) SELECT d.id,k.key_id,%s,'RENEWAL',now()+interval '1 hour',k.generation,k.fingerprint_sha256 FROM ap_m1.devices d JOIN ap_m1.device_key_records k ON k.device_id=d.id WHERE d.id=%s AND k.state='ACTIVE'", (token,f['device_a']))
            self.assertEqual(len(c.execute('SELECT * FROM ap_m1.authenticate_device_credential(%s)', (token,)).fetchall()), 1)
            c.execute("UPDATE ap_m1.device_key_records SET state='REVOKED',revoked_at=now() WHERE key_id=%s", (f['device_key_a'],))
            self.assertEqual(c.execute('SELECT * FROM ap_m1.authenticate_device_credential(%s)', (token,)).fetchall(), [])
            c.rollback()

    def test_cleanup_retains_pending_device_with_v2_dependents(self):
        from uuid import uuid4
        f = self.f
        with self.admin_connection() as c:
            device, snapshot = uuid4(), uuid4()
            c.execute("INSERT INTO ap_m1.devices(id,family_id,child_id,spki_public_key,created_at) VALUES(%s,%s,%s,%s,now()-interval '30 days')", (device,f['family_a'],f['child_a'],b'SYNTHETIC-PENDING-KEY'*8))
            c.execute("INSERT INTO ap_m1.enrollment_challenges(device_id,nonce_sha256,created_at,expires_at) VALUES(%s,%s,now()-interval '30 days',now()-interval '30 days'+interval '5 minutes')", (device,uuid4().bytes*2))
            c.execute("INSERT INTO ap_m1.capability_snapshots(id,device_id,observed_at,android_api,device_mode) VALUES(%s,%s,now(),35,'STANDARD')", (snapshot,device))
            result = c.execute('SELECT * FROM ap_m1.purge_credential_artifacts()').fetchone()
            self.assertEqual(result[3],0)
            self.assertEqual(c.execute('SELECT enrollment_state FROM ap_m1.devices WHERE id=%s', (device,)).fetchone()[0], 'PENDING_PROOF')
            self.assertIsNotNone(c.execute('SELECT id FROM ap_m1.capability_snapshots WHERE id=%s', (snapshot,)).fetchone())
            c.rollback()

    def test_generation_fingerprint_consent_and_tombstone_deny(self):
        from uuid import uuid4
        f = self.f
        with self.admin_connection() as c:
            token = uuid4().bytes * 2
            c.execute("INSERT INTO ap_m1.device_credentials(device_id,key_id,token_sha256,issued_via,expires_at,bound_key_generation,bound_key_fingerprint_sha256) SELECT device_id,key_id,%s,'RENEWAL',now()+interval '1 hour',generation,fingerprint_sha256 FROM ap_m1.device_key_records WHERE key_id=%s", (token,f['device_key_a']))
            changes = [
                ("UPDATE ap_m1.device_key_records SET generation=generation+1 WHERE key_id=%s", (f['device_key_a'],)),
                ("UPDATE ap_m1.device_key_records SET fingerprint_sha256=%s WHERE key_id=%s", (uuid4().bytes*2,f['device_key_a'])),
                ("UPDATE ap_m1.consent_records SET status='WITHDRAWN',withdrawn_at=now() WHERE child_id=%s", (f['child_a'],)),
                ("INSERT INTO ap_m1.child_erasure_tombstones(child_id,reason_code) VALUES(%s,'SYNTHETIC_TEST')", (f['child_a'],))]
            for sql, args in changes:
                c.execute('SAVEPOINT denial')
                c.execute(sql,args)
                self.assertEqual(c.execute('SELECT * FROM ap_m1.authenticate_device_credential(%s)', (token,)).fetchall(), [])
                c.execute('ROLLBACK TO SAVEPOINT denial')
            c.rollback()


if __name__ == '__main__':
    unittest.main()
