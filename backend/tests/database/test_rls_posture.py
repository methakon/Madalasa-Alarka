"""E-01: row-level-security posture, service-role boundary and isolation negatives.

Synthetic disposable PostgreSQL only. These tests assert catalog posture and
runtime behaviour; they do not certify production traffic patterns or capacity.
"""
import json
import unittest
from uuid import uuid4

try:
    from . import fixtures
    from .test_location import domain_fixture, cleanup_domain
except ImportError:
    import fixtures
    from test_location import domain_fixture, cleanup_domain


RUNTIME_ROLES = ('ap_m1_api', 'ap_db_executor', 'ap_m1_auth')


def _rows(conn, sql, params=()):
    return conn.execute(sql, params).fetchall()


class RlsPostureTests(unittest.TestCase):
    """Catalog posture: every application table is forced-RLS with an explicit policy."""

    def test_privileged_membership_and_createrole_are_rejected(self):
        import psycopg
        mutations = (
            'GRANT ap_db_executor TO ap_m1_api',
            'GRANT ap_m1_auth TO ap_auth_issuer',
            'GRANT ap_m1_owner TO ap_service_worker',
            'ALTER ROLE madalasa_dev CREATEROLE',
            'ALTER ROLE madalasa_dev SUPERUSER',
            'ALTER ROLE madalasa_dev BYPASSRLS',
            'GRANT ap_db_executor TO madalasa_dev',
            'GRANT ap_m1_auth TO madalasa_dev',
            'GRANT ap_m1_owner TO madalasa_dev',
            'ALTER ROLE madalasa_auth BYPASSRLS',
            'ALTER ROLE madalasa_billing SUPERUSER',
        )
        for statement in mutations:
            with self.subTest(statement=statement), fixtures.admin_connection() as db:
                db.execute(statement)
                with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                    db.execute('SELECT ap_m1.assert_role_boundary()')
                db.rollback()
        with fixtures.admin_connection() as db:
            db.execute('SELECT ap_m1.assert_role_boundary()')

    def test_every_ap_m1_table_enables_and_forces_rls(self):
        with fixtures.admin_connection() as db:
            gaps = _rows(db, """
                SELECT c.relname, c.relrowsecurity, c.relforcerowsecurity
                FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                WHERE n.nspname = 'ap_m1' AND c.relkind = 'r'
                  AND (NOT c.relrowsecurity OR NOT c.relforcerowsecurity)
                ORDER BY c.relname""")
            total = _rows(db, """
                SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                WHERE n.nspname = 'ap_m1' AND c.relkind = 'r'""")[0][0]
        self.assertGreater(total, 100, 'expected the full application table catalog')
        self.assertEqual(gaps, [], f'tables missing forced RLS: {gaps}')

    def test_every_ap_m1_table_has_an_explicit_policy(self):
        """No policy means deny, but an invisible deny hides intent from review."""
        with fixtures.admin_connection() as db:
            gaps = _rows(db, """
                SELECT c.relname FROM pg_class c
                JOIN pg_namespace n ON n.oid = c.relnamespace
                WHERE n.nspname = 'ap_m1' AND c.relkind = 'r'
                  AND NOT EXISTS (SELECT 1 FROM pg_policy p WHERE p.polrelid = c.oid)
                ORDER BY c.relname""")
        self.assertEqual(gaps, [], f'tables without an explicit policy: {gaps}')

    def test_posture_function_agrees_with_catalog(self):
        with fixtures.admin_connection() as db:
            rows = _rows(db, 'SELECT * FROM ap_m1.rls_posture()')
            zero_policy = [r[0] for r in rows if r[3] == 0]
            unforced = [r[0] for r in rows if not (r[1] and r[2])]
            catalog = _rows(db, """
                SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                WHERE n.nspname = 'ap_m1' AND c.relkind = 'r'""")[0][0]
        self.assertEqual(len(rows), catalog)
        self.assertEqual(zero_policy, [])
        self.assertEqual(unforced, [])

    def test_no_login_role_can_bypass_rls(self):
        """BYPASSRLS belongs only to NOLOGIN definer bridges and no application role holds it."""
        with fixtures.admin_connection() as db:
            db.execute('SELECT ap_m1.assert_role_boundary()')
            offenders = _rows(db, """
                SELECT DISTINCT m.rolname FROM pg_auth_members am
                JOIN pg_roles m ON m.oid = am.member
                JOIN pg_roles r ON r.oid = am.roleid
                WHERE m.rolcanlogin AND (am.inherit_option OR am.set_option)
                  AND r.rolname IN ('ap_m1_api','ap_auth_issuer','ap_billing_verifier',
                                   'ap_privacy_worker','ap_service_worker',
                                   'madalasa_dev','madalasa_auth','madalasa_billing')
                  AND (m.rolsuper OR m.rolbypassrls OR m.rolcreaterole OR m.rolcreatedb OR m.rolreplication)
                UNION
                SELECT rolname FROM pg_roles
                WHERE rolname IN ('ap_m1_api','ap_auth_issuer','ap_billing_verifier',
                                 'ap_privacy_worker','ap_service_worker',
                                 'madalasa_dev','madalasa_auth','madalasa_billing',
                                 'ap_m1_api_user','ap_auth_issuer_user','ap_billing_user',
                                 'ap_privacy_user','ap_worker_user')
                  AND (rolsuper OR rolbypassrls OR rolcreaterole OR rolcreatedb OR rolreplication)
                ORDER BY rolname""")
            bridges = _rows(db, """
                SELECT rolname, rolcanlogin, rolbypassrls FROM pg_roles
                WHERE rolname IN ('ap_db_executor','ap_m1_auth') ORDER BY rolname""")
        self.assertEqual(offenders, [], f'application roles with administrative privileges: {offenders}')
        self.assertEqual(len(bridges), 2, 'definer bridge roles must exist')
        for name, can_login, bypass in bridges:
            self.assertFalse(can_login, f'{name} must not be login-capable')
            self.assertTrue(bypass, f'{name} must retain the documented BYPASSRLS bridge')


class RlsIsolationTests(unittest.TestCase):
    """Behavioural negatives: cross-family, revoked and expired scope grants."""

    def setUp(self):
        self.f = domain_fixture()
        self.addCleanup(self._cleanup)
        self.child_a = self.f['child_a']

    def _cleanup(self):
        with fixtures.admin_connection() as admin:
            if admin.execute("SELECT to_regclass('ap_m1.location_batch_items')").fetchone()[0]:
                admin.execute('DELETE FROM ap_m1.location_batch_items WHERE child_id=%s', (self.child_a,))
        cleanup_domain(self.f)

    def _ingest(self, device, child):
        from datetime import datetime, timedelta, timezone
        from psycopg.types.json import Jsonb
        event = {
            'event_id': str(uuid4()), 'sequence': 8_100_000 + int(uuid4().int % 100_000),
            'observed_at': (datetime.now(timezone.utc) - timedelta(minutes=3)).isoformat(),
            'latitude': 22.5, 'longitude': 88.3, 'accuracy_m': 12, 'provider': 'SYNTHETIC',
        }
        conn = fixtures.runtime_connection()
        try:
            fixtures.as_parent(conn, None, None, device)
            conn.execute('SELECT ap_m1.ingest_location_batch(%s,%s,%s)', (device, uuid4(), Jsonb([event])))
            conn.commit()
        finally:
            conn.close()
        return event

    def test_other_family_cannot_read_child_rows(self):
        self._ingest(self.f['device_a'], self.child_a)
        with fixtures.runtime_connection() as db:
            fixtures.as_parent(db, self.f['b'], self.f['family_b'])
            probes = {
                'children': ('id', self.child_a),
                'devices': ('child_id', self.child_a),
                'location_observations': ('child_id', self.child_a),
                'device_latest_positions': ('child_id', self.child_a),
            }
            for table, (column, value) in probes.items():
                count = db.execute(
                    f'SELECT count(*) FROM ap_m1.{table} WHERE {column}=%s', (value,)
                ).fetchone()[0]
                self.assertEqual(count, 0, f'{table}: cross-family row visible')
            history = db.execute(
                "SELECT * FROM ap_m1.location_history(%s, now()-interval '6 hours', now(), 500)",
                (self.child_a,)).fetchall()
            self.assertEqual(history, [], 'cross-family history leak')
            db.rollback()

    def test_admission_gates_are_restrictive_never_grants(self):
        """A gate that only checks admission must narrow access, never widen it."""
        with fixtures.admin_connection() as db:
            gates = _rows(db, """
                SELECT tablename, permissive FROM pg_policies
                WHERE policyname = 'free_admission_read_gate' ORDER BY tablename""")
        self.assertTrue(gates, 'free-first admission gates must exist')
        widening = [t for t, permissive in gates if permissive != 'RESTRICTIVE']
        self.assertEqual(widening, [], f'admission gates must be RESTRICTIVE: {widening}')

    def test_revoked_scope_grant_denies_location_read(self):
        self._ingest(self.f['device_a'], self.child_a)
        def visible(scope_check):
            with fixtures.runtime_connection() as db:
                fixtures.as_parent(db, self.f['a'], self.f['family_a'])
                count = db.execute(scope_check, (self.child_a,)).fetchone()[0]
                db.rollback()
                return count

        observations = 'SELECT count(*) FROM ap_m1.location_observations WHERE child_id=%s'
        latest = 'SELECT count(*) FROM ap_m1.device_latest_positions WHERE child_id=%s'
        self.assertGreater(visible(observations), 0, 'guardian must see own child before revocation')
        self.assertGreater(visible(latest), 0, 'guardian must see own latest position before revocation')
        with fixtures.admin_connection() as admin:
            admin.execute("""UPDATE ap_m1.child_access_grants_v2 SET revoked_at=now()
                              WHERE child_id=%s AND adult_id=%s AND scope IN ('VIEW_HISTORY','VIEW_LOCATION')""",
                          (self.child_a, self.f['a']))
        try:
            history_after = visible(observations)
            latest_after = visible(latest)
        finally:
            with fixtures.admin_connection() as admin:
                admin.execute("""UPDATE ap_m1.child_access_grants_v2 SET revoked_at=NULL
                                  WHERE child_id=%s AND adult_id=%s AND scope IN ('VIEW_HISTORY','VIEW_LOCATION')""",
                              (self.child_a, self.f['a']))
        self.assertEqual(history_after, 0, 'revoked VIEW_HISTORY must deny location rows')
        self.assertEqual(latest_after, 0, 'revoked VIEW_LOCATION must deny latest position')

    def test_expired_scope_grant_denies_location_read(self):
        self._ingest(self.f['device_a'], self.child_a)
        with fixtures.admin_connection() as admin:
            admin.execute("""UPDATE ap_m1.child_access_grants_v2
                              SET created_at=now()-interval '2 hours',
                                  expires_at=now()-interval '1 hour'
                              WHERE child_id=%s AND adult_id=%s AND scope IN ('VIEW_HISTORY','VIEW_LOCATION')""",
                          (self.child_a, self.f['a']))
        try:
            with fixtures.runtime_connection() as db:
                fixtures.as_parent(db, self.f['a'], self.f['family_a'])
                history_rows = db.execute(
                    'SELECT count(*) FROM ap_m1.location_observations WHERE child_id=%s',
                    (self.child_a,)).fetchone()[0]
                latest_rows = db.execute(
                    'SELECT count(*) FROM ap_m1.device_latest_positions WHERE child_id=%s',
                    (self.child_a,)).fetchone()[0]
                db.rollback()
        finally:
            with fixtures.admin_connection() as admin:
                admin.execute("""UPDATE ap_m1.child_access_grants_v2
                                  SET created_at=now(), expires_at=now()+interval '1 day'
                                  WHERE child_id=%s AND adult_id=%s AND scope IN ('VIEW_HISTORY','VIEW_LOCATION')""",
                              (self.child_a, self.f['a']))
        self.assertEqual(history_rows, 0, 'expired VIEW_HISTORY must deny location rows')
        self.assertEqual(latest_rows, 0, 'expired VIEW_LOCATION must deny latest position')

    def test_child_scoped_history_uses_an_index(self):
        with fixtures.admin_connection() as db:
            db.execute('SET LOCAL enable_seqscan = off')
            plan = db.execute("""
                EXPLAIN (FORMAT JSON)
                SELECT * FROM ap_m1.location_observations
                WHERE child_id = gen_random_uuid()
                  AND observed_at BETWEEN now()-interval '6 hours' AND now()
                ORDER BY observed_at, event_id LIMIT 500""").fetchone()[0]
        text = json.dumps(plan)
        self.assertTrue('Index Scan' in text, f'child/time history must be index-backed: {text[:400]}')


if __name__ == '__main__':
    unittest.main()
