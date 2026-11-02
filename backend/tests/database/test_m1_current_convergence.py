"""PR11 additive convergence. Default execution is PURE/SOURCE ONLY.

Parent owns isolated DB provisioning/replay. No DDL, runner, reset, secret-file
reads or automatic connection on import. Explicit opt-in AND all three explicit
DSNs required; fixtures validates the dedicated test destination.

Pure: python3 -m unittest discover -s backend/tests/database -p test_m1_current_convergence.py -v
DB: same command with PR11_ISOLATED_DB_AUTHORIZED=1 and MA_TEST_DSN,
MA_RUNTIME_DSN, MA_AUTH_DSN supplied privately by parent. Run after fresh V2,
M1-through-0004 upgrade, and M1-through-0006 upgrade independently. Never treat
source checks/skipped integration as PostgreSQL acceptance.
"""
import os
from pathlib import Path
import re
import unittest
from uuid import uuid4

ROOT = Path(__file__).resolve().parents[3]
MIGRATIONS = ROOT / 'backend/persistence/migrations'
BRIDGE = MIGRATIONS / 'compat/m1_pre_v2_0017.sql'
FIX = MIGRATIONS / '0020_m1_current_lineage_convergence.sql'
AUTHORIZED = (os.environ.get('PR11_ISOLATED_DB_AUTHORIZED') == '1'
              and all(os.environ.get(k) for k in ('MA_TEST_DSN', 'MA_RUNTIME_DSN', 'MA_AUTH_DSN')))


def seed_current_upgrade(conn):
    """DML-only parent hook BEFORE V2 on M1 0004 OR 0006. Caller commits.

    Uses actual historical fixture, and records every hold-bearing artifact.
    No automatic historical policy approval is expected after upgrade.
    """
    from test_m1_compatibility import seed_historical_compatibility
    expected = seed_historical_compatibility(conn)
    expected['holds'] = []
    has_holds = conn.execute("SELECT EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid='ap_m1.devices'::regclass AND attname='retention_hold' AND NOT attisdropped)").fetchone()[0]
    if has_holds:
        for table, pk, value in [('devices','id',expected['device']),
                                 ('device_credentials','id',expected['credential']),
                                 ('credential_renewal_challenges','id',expected['challenge'])]:
            conn.execute(f'UPDATE ap_m1.{table} SET retention_hold=true WHERE {pk}=%s', (value,))
            expected['holds'].append((table,pk,value))
    expected['audit'] = conn.execute("INSERT INTO ap_m1.audit_events(family_id,actor_device_id,action,result_code) SELECT family_id,id,'PR11_SYNTHETIC','PRESERVE' FROM ap_m1.devices WHERE id=%s RETURNING id,family_id,actor_device_id,action,result_code,observed_at", (expected['device'],)).fetchone()
    return expected


def assert_current_upgrade(conn, expected):
    """DML-free oracle AFTER 0020; invoke for BOTH populated M1 origins."""
    from test_m1_compatibility import assert_historical_compatibility
    assert_historical_compatibility(conn, expected)
    for table,pk,value in expected['holds']:
        assert conn.execute(f'SELECT retention_hold FROM ap_m1.{table} WHERE {pk}=%s', (value,)).fetchone() == (True,)
    assert conn.execute('SELECT id,family_id,actor_device_id,action,result_code,observed_at FROM ap_m1.audit_events WHERE id=%s', (expected['audit'][0],)).fetchone() == expected['audit']
    if expected['holds']:
        assert conn.execute('SELECT retention_hold FROM ap_m1.m1_renewal_hold_preservation WHERE challenge_id=%s', (expected['challenge'],)).fetchone() == (True,)


class SourceContract(unittest.TestCase):
    def test_additive_files_and_private_bridge(self):
        sql = BRIDGE.read_text()
        self.assertIn('FORCE ROW LEVEL SECURITY', sql)
        self.assertIn('m1_historical_renewal_challenges', sql)
        self.assertIn('SELECT id,retention_hold', sql)
        self.assertNotIn('CREATE POLICY', sql)
        self.assertNotIn('TO ap_m1_api', sql)

    def test_no_unsafe_runtime_identity_or_audit_deletion(self):
        sql = FIX.read_text()
        self.assertNotIn("current_setting('ap.principal_id'", sql)
        self.assertNotIn('GRANT EXECUTE ON ALL', sql)
        for table in ('audit_events','child_erasure_tombstones','ma_recovery.erasure_ledger'):
            self.assertNotIn('DELETE FROM ' + ('ap_m1.' if '.' not in table else '') + table, sql)
        self.assertIn("'resolve_parent_principal(text,text)'", sql)
        self.assertIn('TO ap_auth_issuer', sql)

    def test_device_first_and_post_credential_lock_clock(self):
        sql = FIX.read_text()
        body = sql.split('FUNCTION ap_m1.issue_renewal_credential(',1)[1].split('END $fn$;',1)[0]
        self.assertLess(body.index('FROM ap_m1.devices'), body.index('FROM ap_m1.credential_renewal_challenges'))
        self.assertLess(body.index('ORDER BY c.id FOR UPDATE'), body.index('v_now := clock_timestamp()'))
        self.assertIn('ch.expires_at<=v_now', body)
        self.assertIn('bound_key_generation', body)

    def test_no_session_issuance_authority_added(self):
        """Architect ruling: convergence must not create a production OIDC path."""
        for path in (FIX, BRIDGE):
            sql = path.read_text()
            self.assertNotIn('issue_verified_parent_session', sql)
            self.assertNotRegex(sql, r'CREATE( OR REPLACE)? FUNCTION ap_m1\.(mint_session|_session|revoke_session)\b')
            self.assertNotIn('local_test_settings', sql)
            self.assertNotIn('trusted_principal_verifications', sql)
            for stmt in ('INSERT INTO ap_m1.trusted_sessions', 'UPDATE ap_m1.trusted_sessions'):
                self.assertNotIn(stmt, sql)
        # The preserved M1 contract must not lose its existing runtime EXECUTE.
        self.assertIn('resolve_parent_principal(text,text) TO ap_auth_issuer, ap_m1_api', FIX.read_text())

    def test_hold_provenance_never_invented(self):
        sql = FIX.read_text()
        # A converged history that already ran published 0017 lost the column by
        # DDL; the fallback must be an empty snapshot plus a NOTICE, never true.
        self.assertIn('RAISE NOTICE', sql)
        self.assertNotRegex(sql, r'retention_hold\s*=\s*true')
        self.assertNotIn('DEFAULT true', sql)

    def test_purge_invariants(self):
        sql = FIX.read_text()
        self.assertIn('NOT isfinite(p_credential_grace)', sql)
        self.assertIn('IF d.retention_hold THEN CONTINUE', sql)
        self.assertIn('_m1_device_has_dependents', sql)
        self.assertIn('pg_constraint', sql)
        self.assertIn('NOT ch.retention_hold', sql)
        self.assertIn('m1_renewal_hold_preservation', sql)


@unittest.skipUnless(AUTHORIZED, 'parent isolated-DB authorization + explicit DSNs required; no connections opened')
class DatabaseContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from fixtures import admin_connection, seed_core
        cls.admin = staticmethod(admin_connection)
        cls.f = seed_core()

    def test_runtime_cannot_assert_identity_or_write_holds(self):
        import psycopg
        from fixtures import runtime_connection
        with runtime_connection() as c:
            c.execute("SELECT set_config('ap.principal_id',%s,true)", (str(self.f['a']),))
            self.assertIsNone(c.execute('SELECT ap_m1.ctx_principal()').fetchone()[0])
            # V2 0021 retired the historical runtime grant: identity rows are
            # created only by the separate issuer login during session exchange.
            with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                with c.transaction():
                    c.execute("SELECT ap_m1.resolve_parent_principal('https://synthetic.example.invalid','pr11-runtime')")
            self.assertIsNone(c.execute('SELECT ap_m1.ctx_principal()').fetchone()[0])
            for sql,args in [
                ('SELECT ap_m1.mint_session(%s)',(self.f['a'],)),
                ("SELECT * FROM ap_m1.create_family('forged')",()),
                ('UPDATE ap_m1.devices SET retention_hold=false WHERE id=%s',(self.f['device_a'],)),
                ('SELECT * FROM ap_m1.m1_renewal_hold_preservation',())]:
                with self.assertRaises(psycopg.Error):
                    with c.transaction(): c.execute(sql,args)
            for table in ('devices','pairing_codes','device_credentials','credential_renewal_challenges','enrollment_challenges'):
                self.assertFalse(c.execute("SELECT has_column_privilege(current_user,%s,'retention_hold','UPDATE')", ('ap_m1.'+table,)).fetchone()[0])
            c.rollback()

    def test_family_actual_issuer_session_and_cap(self):
        import psycopg
        from fixtures import auth_connection, runtime_connection, mint_session
        # resolve_parent_principal is issuer-only, idempotent; it is NOT legal approval.
        with auth_connection() as issuer:
            actor = issuer.execute('SELECT ap_m1.resolve_parent_principal(%s,%s)', ('https://synthetic.example.invalid','pr11-'+str(uuid4()))).fetchone()[0]
            issuer.rollback()
        # Use already approved synthetic actor for the existing issuer API.
        token = mint_session(self.f['c'])
        with runtime_connection() as c:
            c.execute("SELECT set_config('ap.session_token',%s,true)",(token,))
            for i in range(10):
                row = c.execute('SELECT * FROM ap_m1.create_family(%s)',('PR11 '+str(i),)).fetchone()
                self.assertEqual(row[2],'ACTIVE')
            with self.assertRaises(psycopg.errors.ConfigurationLimitExceeded):
                with c.transaction(): c.execute("SELECT * FROM ap_m1.create_family('eleventh')")
            c.rollback()
        self.assertIsNotNone(actor)

    def test_issuer_renewal_real_interfaces_and_invalid_binding(self):
        from fixtures import auth_connection
        f = self.f
        with self.admin() as c:
            fp = c.execute('SELECT fingerprint_sha256 FROM ap_m1.device_key_records WHERE key_id=%s',(f['device_key_a'],)).fetchone()[0]
        with auth_connection() as c:
            self.assertIsNone(c.execute('SELECT ap_m1.issue_credential_renewal_challenge(%s,%s,%s,120)',(f['device_a'],uuid4().bytes*2,uuid4().bytes*2)).fetchone()[0])
            ch = c.execute('SELECT ap_m1.issue_credential_renewal_challenge(%s,%s,%s,120)',(f['device_a'],fp,uuid4().bytes*2)).fetchone()[0]
            self.assertIsNotNone(ch)
            self.assertEqual(len(c.execute('SELECT * FROM ap_m1.consume_renewal_challenge(%s,%s)',(f['device_a'],ch)).fetchall()),1)
            self.assertEqual(c.execute('SELECT * FROM ap_m1.consume_renewal_challenge(%s,%s)',(f['device_a'],ch)).fetchall(),[])
            args = (f['device_a'],ch,uuid4().bytes*2)
            self.assertIsNotNone(c.execute('SELECT ap_m1.issue_renewal_credential(%s,%s,%s,300)',args).fetchone()[0])
            self.assertIsNone(c.execute('SELECT ap_m1.issue_renewal_credential(%s,%s,%s,300)',args).fetchone()[0])
            c.rollback()  # Synthetic SQL authorization only, not proof verification.

    def test_held_and_unheld_artifacts_pending_dependent_and_audit(self):
        f=self.f
        with self.admin() as c:
            ids=[]
            for held,dependent in [(False,False),(True,False),(False,True)]:
                dev=uuid4(); ids.append(dev)
                c.execute("INSERT INTO ap_m1.devices(id,family_id,child_id,spki_public_key,created_at,retention_hold) VALUES(%s,%s,%s,%s,now()-interval '40 days',%s)",(dev,f['family_a'],f['child_a'],b'SYNTHETIC-PR11'*9,held))
                c.execute("INSERT INTO ap_m1.enrollment_challenges(device_id,nonce_sha256,created_at,expires_at) VALUES(%s,%s,now()-interval '40 days',now()-interval '40 days'+interval '5 minutes')",(dev,uuid4().bytes*2))
                if dependent:
                    c.execute("INSERT INTO ap_m1.audit_events(family_id,actor_device_id,action,result_code) VALUES(%s,%s,'PR11','PRESERVE')",(f['family_a'],dev))
            before=c.execute('SELECT count(*) FROM ap_m1.audit_events').fetchone()[0]
            ledger=c.execute('SELECT count(*) FROM ma_recovery.erasure_ledger').fetchone()[0]
            c.execute('SELECT * FROM ap_m1.purge_credential_artifacts()')
            self.assertIsNone(c.execute('SELECT id FROM ap_m1.devices WHERE id=%s',(ids[0],)).fetchone())
            for dev in ids[1:]: self.assertIsNotNone(c.execute('SELECT id FROM ap_m1.devices WHERE id=%s',(dev,)).fetchone())
            self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.audit_events').fetchone()[0],before)
            self.assertEqual(c.execute('SELECT count(*) FROM ma_recovery.erasure_ledger').fetchone()[0],ledger)
            self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.enrollment_challenges WHERE device_id=%s',(ids[1],)).fetchone()[0],1)
            c.rollback()

    def test_purge_invalid_intervals_and_pairing_hold(self):
        import psycopg
        with self.admin() as c:
            for value in (None,'0 seconds','-1 day'):
                for call in ['SELECT ap_m1.purge_pairing_codes(%s::interval)', 'SELECT * FROM ap_m1.purge_credential_artifacts(%s::interval)']:
                    with self.assertRaises(psycopg.errors.InvalidParameterValue):
                        with c.transaction(): c.execute(call,(value,))
            ids=[]
            for held in (True,False):
                ident=uuid4(); ids.append(ident)
                c.execute("INSERT INTO ap_m1.pairing_codes(id,family_id,child_id,issued_by,code_sha256,created_at,expires_at,retention_hold) VALUES(%s,%s,%s,%s,%s,now()-interval '40 days',now()-interval '39 days',%s)",(ident,self.f['family_a'],self.f['child_a'],self.f['a'],uuid4().bytes*2,held))
            c.execute("SELECT ap_m1.purge_pairing_codes(interval '1 day')")
            self.assertIsNotNone(c.execute('SELECT id FROM ap_m1.pairing_codes WHERE id=%s',(ids[0],)).fetchone())
            self.assertIsNone(c.execute('SELECT id FROM ap_m1.pairing_codes WHERE id=%s',(ids[1],)).fetchone())
            c.rollback()


if __name__ == '__main__':
    unittest.main()
