"""Real restricted-login identity regression tests, synthetic fixtures only.

Run: .local-db/venv/bin/python -m unittest discover -s backend/tests/database -p test_identity.py -v
The historical M1 SQL regression must run BEFORE applying V2: raw GUC trust is
intentionally retired, so rerunning the old positive GUC assertions after V2 is invalid.
"""
from contextlib import contextmanager
from uuid import uuid4
import unittest
import psycopg
from psycopg import sql
from fixtures import admin_connection, runtime_connection, auth_connection, seed_core, as_parent, mint_session


@contextmanager
def changed(table, key, value, column, replacement):
    """Committed mutation visible to independent real logins; restore exactly."""
    query = sql.SQL('SELECT {} FROM ap_m1.{} WHERE {}=%s').format(sql.Identifier(column),sql.Identifier(table),sql.Identifier(key))
    update = sql.SQL('UPDATE ap_m1.{} SET {}=%s WHERE {}=%s').format(sql.Identifier(table),sql.Identifier(column),sql.Identifier(key))
    with admin_connection() as c:
        old = c.execute(query,(value,)).fetchone()[0]
        c.execute(update,(replacement,value))
    try:
        yield
    finally:
        with admin_connection() as c:
            c.execute(update,(old,value))


class IdentityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.f = seed_core()

    def setUp(self):
        self.invites = []

    def tearDown(self):
        with admin_connection() as c:
            for token in self.invites:
                c.execute("DELETE FROM ap_m1.child_access_grants_v2 WHERE origin_invite_id IN (SELECT id FROM ap_m1.child_access_invites WHERE one_time_secret_hash=public.digest(%s,'sha256'))",(token,))
                c.execute("DELETE FROM ap_m1.child_access_invites WHERE one_time_secret_hash=public.digest(%s,'sha256')",(token,))

    def invite(self, scopes=None):
        with runtime_connection() as c:
            as_parent(c,self.f['a'],self.f['family_a'])
            token = c.execute('SELECT ap_m1.issue_child_invite(%s,%s,%s)',(self.f['child_a'],self.f['b'],scopes or ['VIEW_CHILD_PROFILE','VIEW_CHILD_DEVICES'])).fetchone()[0]
        self.invites.append(token)
        return token

    def accept(self, token, actor='b'):
        with runtime_connection() as c:
            as_parent(c,self.f[actor], self.f['family_b'] if actor=='b' else None)
            return c.execute('SELECT ap_m1.accept_child_invite(%s)',(token,)).fetchone()[0]

    def visible(self, actor='b', family=None):
        with runtime_connection() as c:
            as_parent(c,self.f[actor],self.f[family] if family else None)
            return {r[0] for r in c.execute('SELECT id FROM ap_m1.children')}

    def invite_id(self,token):
        with admin_connection() as c:
            return c.execute("SELECT id FROM ap_m1.child_access_invites WHERE one_time_secret_hash=public.digest(%s,'sha256')",(token,)).fetchone()[0]

    def test_01_uuid_guc_cannot_impersonate(self):
        with runtime_connection() as c:
            c.execute("SELECT set_config('ap.principal_id',%s,true),set_config('ap.family_id',%s,true),set_config('ap.device_id',%s,true)",(str(self.f['a']),str(self.f['family_a']),str(self.f['device_a'])))
            self.assertEqual(c.execute('SELECT ap_m1.ctx_principal(),ap_m1.ctx_family(),ap_m1.ctx_device()').fetchone(),(None,None,None))
            self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.children').fetchone()[0],0)

    def test_02_same_family_ungranted_sibling_hidden(self):
        self.assertEqual(self.visible('a','family_a'),{self.f['child_a']})
        with runtime_connection() as c:
            as_parent(c,self.f['a'],self.f['family_a'])
            rows=c.execute('SELECT child_id,purpose FROM ap_m1.consent_records').fetchall()
            self.assertEqual({r[0] for r in rows},{self.f['child_a']})
            self.assertEqual({r[1] for r in rows},{'CORE','LOCATION','USAGE','MEDIA'})

    def test_03_cross_family_exact_child_without_membership(self):
        token=self.invite(); self.accept(token)
        self.assertEqual(self.visible('b','family_b'),{self.f['child_a'],self.f['child_b']})
        with runtime_connection() as c:
            as_parent(c,self.f['b'],self.f['family_b'])
            self.assertEqual(c.execute('SELECT id FROM ap_m1.families').fetchall(),[(self.f['family_b'],)])
            self.assertEqual(c.execute('SELECT family_id FROM ap_m1.guardian_memberships').fetchall(),[(self.f['family_b'],)])
            self.assertEqual(c.execute('SELECT id FROM ap_m1.devices').fetchall(),[(self.f['device_a'],)])

    def test_04_wrong_principal_cannot_accept(self):
        token=self.invite()
        with self.assertRaises(psycopg.errors.InsufficientPrivilege): self.accept(token,'c')
        self.assertEqual(self.visible('c'),set())

    def test_05_random_invite_denied(self):
        with self.assertRaises(psycopg.errors.InsufficientPrivilege): self.accept('0'*64)

    def test_06_invite_replay_denied(self):
        token=self.invite(); self.accept(token)
        with self.assertRaises(psycopg.errors.InsufficientPrivilege): self.accept(token)

    def test_07_expired_invite_denied(self):
        token=self.invite()
        with admin_connection() as c:
            c.execute("UPDATE ap_m1.child_access_invites SET created_at='2000-01-01T00:00:00Z' WHERE id=%s",(self.invite_id(token),))
        with changed('child_access_invites','id',self.invite_id(token),'expires_at','2000-01-02T00:00:00Z'):
            with self.assertRaises(psycopg.errors.InsufficientPrivilege): self.accept(token)

    def test_08_revoked_invite_denied(self):
        token=self.invite()
        with runtime_connection() as c:
            as_parent(c,self.f['a'],self.f['family_a'])
            c.execute('SELECT ap_m1.revoke_child_invite(%s)',(self.invite_id(token),))
        with self.assertRaises(psycopg.errors.InsufficientPrivilege): self.accept(token)

    def test_09_api_cannot_mint_or_write_sessions(self):
        with runtime_connection() as c:
            for statement,args in [('SELECT ap_m1.mint_session(%s)',(self.f['a'],)),
                                   ('SELECT ap_m1.revoke_session(%s)',('0'*64,)),
                                   ("UPDATE ap_m1.local_test_settings SET enabled=true",()),
                                   ('SELECT * FROM ap_m1.trusted_sessions',())]:
                with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                    with c.transaction(): c.execute(statement,args)

    def test_10_issuer_family_membership_checked(self):
        with self.assertRaises(psycopg.errors.InsufficientPrivilege):
            mint_session(self.f['b'],self.f['family_a'])

    def test_11_revoked_device_cannot_mint(self):
        with changed('devices','id',self.f['device_a'],'enrollment_state','REVOKED'):
            with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                mint_session(self.f['a'],self.f['family_a'],self.f['device_a'])

    def test_12_session_expiry_and_revoke_live(self):
        token=mint_session(self.f['a'])
        with runtime_connection() as c:
            c.execute("SELECT set_config('ap.session_token',%s,true)",(token,))
            self.assertEqual(c.execute('SELECT ap_m1.ctx_principal()').fetchone()[0],self.f['a'])
            with auth_connection() as issuer: issuer.execute('SELECT ap_m1.revoke_session(%s)',(token,))
            self.assertIsNone(c.execute('SELECT ap_m1.ctx_principal()').fetchone()[0])
        token=mint_session(self.f['a'])
        with admin_connection() as a:
            a.execute("UPDATE ap_m1.trusted_sessions SET created_at=statement_timestamp()-interval '2 hours',expires_at=statement_timestamp()-interval '1 hour' WHERE token_sha256=public.digest(%s,'sha256')",(token,))
        with runtime_connection() as c:
            c.execute("SELECT set_config('ap.session_token',%s,true)",(token,))
            self.assertIsNone(c.execute('SELECT ap_m1.ctx_principal()').fetchone()[0])

    def test_13_grant_revoke_closes_existing_transaction(self):
        token=self.invite(); self.accept(token)
        with runtime_connection() as c:
            as_parent(c,self.f['b'])
            self.assertIn(self.f['child_a'],{r[0] for r in c.execute('SELECT id FROM ap_m1.children')})
            with runtime_connection() as owner:
                as_parent(owner,self.f['a'],self.f['family_a'])
                owner.execute('SELECT ap_m1.revoke_child_invite(%s)',(self.invite_id(token),))
            self.assertNotIn(self.f['child_a'],{r[0] for r in c.execute('SELECT id FROM ap_m1.children')})

    def test_14_disputed_authority_denies(self):
        token=self.invite(); self.accept(token)
        with changed('child_authority_reviews','id',self.f['review_b'],'state','DISPUTED'):
            self.assertNotIn(self.f['child_a'],self.visible())

    def test_15_withdrawn_consent_denies(self):
        with changed('consent_records','id',self.f['consent_a'],'status','WITHDRAWN'):
            self.assertEqual(self.visible('a'),set())

    def test_16_protected_local_opt_in_required(self):
        with changed('local_test_settings','singleton',True,'enabled',False):
            with self.assertRaises(psycopg.errors.InsufficientPrivilege): mint_session(self.f['a'])
            with runtime_connection() as c:
                c.execute("SELECT set_config('ap.local_test_approved','true',true)")
                self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.children').fetchone()[0],0)

    def test_17_live_issuer_manage_grants_required_at_acceptance(self):
        token=self.invite()
        with admin_connection() as c:
            grant=c.execute("SELECT id FROM ap_m1.child_access_grants_v2 WHERE child_id=%s AND adult_id=%s AND scope='MANAGE_CHILD_GRANTS' AND revoked_at IS NULL",(self.f['child_a'],self.f['a'])).fetchone()[0]
        with changed('child_access_grants_v2','id',grant,'revoked_at','2026-01-01T00:00:00Z'):
            with self.assertRaises(psycopg.errors.InsufficientPrivilege): self.accept(token)

    def test_18_api_cannot_self_approve_or_gain_membership(self):
        statements=[("INSERT INTO ap_m1.guardian_memberships(family_id,principal_id,membership_role) VALUES(%s,%s,'OWNER')",(self.f['family_a'],self.f['c'])),
                    ("UPDATE ap_m1.child_authority_reviews SET state='LOCAL_TEST_APPROVED'",()),
                    ("UPDATE ap_m1.consent_records SET status='GRANTED'",()),
                    ("INSERT INTO ap_m1.children(family_id,alias) VALUES(%s,'bad')",(self.f['family_b'],))]
        with runtime_connection() as c:
            as_parent(c,self.f['c'])
            for stmt,args in statements:
                with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                    with c.transaction(): c.execute(stmt,args)

    def test_19_create_child_requires_owner_and_grants_nothing(self):
        with runtime_connection() as c:
            as_parent(c,self.f['a'],self.f['family_a'])
            child=c.execute("SELECT ap_m1.create_child('synthetic pending review')").fetchone()[0]
            self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.children WHERE id=%s',(child,)).fetchone()[0],0)
            c.rollback()
        with runtime_connection() as c:
            as_parent(c,self.f['c'])
            with self.assertRaises(psycopg.errors.InsufficientPrivilege): c.execute("SELECT ap_m1.create_child('bad')")

    def test_20_no_privilege_delegation_by_invite(self):
        with runtime_connection() as c:
            as_parent(c,self.f['a'],self.f['family_a'])
            with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                c.execute('SELECT ap_m1.issue_child_invite(%s,%s,%s)',(self.f['child_a'],self.f['b'],['MANAGE_CHILD_GRANTS']))

    def test_21_tombstone_and_deleted_child_deny(self):
        with changed('children','id',self.f['child_a'],'deleted_at','2026-01-01T00:00:00Z'):
            self.assertEqual(self.visible('a'),set())
            with self.assertRaises(psycopg.errors.InsufficientPrivilege): mint_session(None,device=self.f['device_a'])
        # A committed tombstone also enters the independent recovery ledger.
        # Use an owned child: removing an application tombstone must NOT revive
        # a shared fixture in a later backup/restore test.
        from test_location import domain_fixture, cleanup_domain
        own=domain_fixture()
        try:
            self.assertIn(own['child_a'],self.visible('a'))
            with admin_connection() as c:
                c.execute("INSERT INTO ap_m1.child_erasure_tombstones(child_id,reason_code) VALUES(%s,'SYNTHETIC_TEST')",(own['child_a'],))
            self.assertNotIn(own['child_a'],self.visible('a'))
            self.assertIn(self.f['child_a'],self.visible('a'))
        finally:cleanup_domain(own)

    def test_22_definer_acl_and_forced_rls(self):
        with admin_connection() as c:
            self.assertEqual(c.execute("SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='ap_m1' AND c.relkind IN ('r','p') AND (NOT c.relrowsecurity OR NOT c.relforcerowsecurity)").fetchone()[0],0)
            self.assertEqual(c.execute("SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='ap_m1' AND p.prosecdef AND (p.proconfig IS NULL OR NOT EXISTS(SELECT 1 FROM unnest(p.proconfig) s WHERE s LIKE 'search_path=%') OR EXISTS(SELECT 1 FROM aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a WHERE a.grantee=0 AND a.privilege_type='EXECUTE'))").fetchone()[0],0)
            self.assertFalse(c.execute("SELECT pg_has_role('madalasa_dev','ap_db_executor','MEMBER')").fetchone()[0])
        with runtime_connection() as c:
            self.assertFalse(c.execute("SELECT rolsuper OR rolbypassrls FROM pg_roles WHERE rolname=current_user").fetchone()[0])

    def test_23_transaction_context_does_not_leak_and_hash_only(self):
        with runtime_connection() as c:
            token=as_parent(c,self.f['a'])
            c.execute("SELECT set_config('ap.principal_id',%s,true)",(str(self.f['b']),))
            self.assertEqual(c.execute('SELECT ap_m1.ctx_principal()').fetchone()[0],self.f['a'])
            c.commit()
            self.assertIsNone(c.execute('SELECT ap_m1.ctx_principal()').fetchone()[0])
        with admin_connection() as c:
            row=c.execute("SELECT token_sha256 FROM ap_m1.trusted_sessions WHERE token_sha256=public.digest(%s,'sha256')",(token,)).fetchone()
            self.assertEqual(len(row[0]),32)
            self.assertNotEqual(bytes(row[0]),token.encode())


if __name__ == '__main__':
    unittest.main()
