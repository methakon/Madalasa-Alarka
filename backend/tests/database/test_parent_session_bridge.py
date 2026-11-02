"""ParentOIDC -> V2 opaque session bridge (migration 0021), real separate logins.

SYNTHETIC DATA ONLY. Proves, against PostgreSQL with forced RLS:
  * only the issuer login exchanges a verified identity for a session;
  * the runtime role cannot mint sessions, resolve identities or write sessions;
  * a session is identity only: no membership, grant, consent or verification;
  * UUID/family GUCs cannot escalate; family selection needs a live membership;
  * replay, untrusted issuers, malformed inputs, expiry, logout, local-test
    opt-out and account erasure all fail closed;
  * historical LOCAL_TEST sessions keep their exact semantics.
Run: python3 tools/database/manage.py test --pattern test_parent_session_bridge.py
"""
from contextlib import contextmanager
import hashlib
import os
import unittest
from uuid import UUID, uuid4

import psycopg

from fixtures import admin_connection, runtime_connection, auth_connection, seed_core, mint_session

SYNTHETIC_ISSUER = 'https://synthetic.invalid'
GOOGLE_ISSUER = 'https://accounts.google.com'
DENIED = psycopg.errors.InsufficientPrivilege


def digest():
    return hashlib.sha256(os.urandom(32)).digest()


_RANDOM = object()


def exchange(subject=_RANDOM, credential=None, issuer=SYNTHETIC_ISSUER, lifetime=3600):
    if subject is _RANDOM:
        subject = 'bridge-' + str(uuid4())
    with auth_connection() as issuer_conn:
        row = issuer_conn.execute(
            'SELECT session_token, principal_id, expires_at FROM ap_m1.exchange_parent_oidc_session(%s,%s,%s,%s)',
            (issuer, subject, credential or digest(), lifetime)).fetchone()
    return row[0], row[1], subject


@contextmanager
def as_session(token, family=None):
    with runtime_connection() as conn:
        conn.execute("SELECT set_config('ap.session_token',%s,true)", (token,))
        if family is not None:
            conn.execute("SELECT set_config('ap.family_id',%s,true)", (str(family),))
        yield conn
        conn.rollback()


def principal_of(token, family=None):
    with as_session(token, family) as conn:
        return conn.execute('SELECT ap_m1.ctx_principal(), ap_m1.ctx_family()').fetchone()


@contextmanager
def local_test_disabled():
    with admin_connection() as c:
        c.execute('UPDATE ap_m1.local_test_settings SET enabled=false WHERE singleton')
    try:
        yield
    finally:
        with admin_connection() as c:
            c.execute('UPDATE ap_m1.local_test_settings SET enabled=true WHERE singleton')


class ParentSessionBridgeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.f = seed_core()

    def test_01_exchange_is_identity_only(self):
        token, principal, subject = exchange()
        self.assertRegex(token, r'^[0-9a-f]{64}$')
        self.assertEqual(principal_of(token), (principal, None))
        with admin_connection() as a:
            row = a.execute("SELECT origin, oidc_issuer, family_id, device_id, expires_at-created_at "
                            "FROM ap_m1.trusted_sessions WHERE token_sha256=public.digest(%s,'sha256')",
                            (token,)).fetchone()
            self.assertEqual(row[:4], ('PARENT_OIDC', SYNTHETIC_ISSUER, None, None))
            self.assertEqual(row[4].total_seconds(), 3600)
            # Stored as a hash only; no column holds the plaintext bearer.
            self.assertEqual(a.execute("SELECT count(*) FROM ap_m1.trusted_sessions t "
                                       "WHERE position(%s in t::text)>0", (token,)).fetchone()[0], 0)
            self.assertEqual(a.execute('SELECT oidc_issuer, oidc_subject FROM ap_m1.parent_principals WHERE id=%s',
                                       (principal,)).fetchone(), (SYNTHETIC_ISSUER, subject))
            for table, column in [('guardian_memberships', 'principal_id'), ('child_access_grants_v2', 'adult_id'),
                                  ('consent_records', 'adult_id'), ('child_authority_reviews', 'adult_id'),
                                  ('trusted_principal_verifications', 'principal_id')]:
                self.assertEqual(a.execute(f'SELECT count(*) FROM ap_m1.{table} WHERE {column}=%s',
                                           (principal,)).fetchone()[0], 0, table)
        with as_session(token) as c:
            self.assertFalse(c.execute("SELECT ap_m1.has_child_scope_v2(%s,'VIEW_CHILD_PROFILE')",
                                       (self.f['child_a'],)).fetchone()[0])
            self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.children').fetchone()[0], 0)
            self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.list_my_families()').fetchone()[0], 0)

    def test_02_runtime_cannot_mint_resolve_or_write(self):
        with runtime_connection() as c:
            for statement, args in [
                    ('SELECT * FROM ap_m1.exchange_parent_oidc_session(%s,%s,%s,%s)',
                     (SYNTHETIC_ISSUER, 'runtime-' + str(uuid4()), digest(), 3600)),
                    ('SELECT ap_m1.resolve_parent_principal(%s,%s)', (SYNTHETIC_ISSUER, 'runtime-x')),
                    ('SELECT ap_m1.mint_session(%s)', (self.f['a'],)),
                    ('SELECT ap_m1._parent_oidc_issuer_trusted(%s)', (GOOGLE_ISSUER,)),
                    ("INSERT INTO ap_m1.trusted_sessions(token_sha256,principal_id,expires_at,origin,oidc_issuer,"
                     "oidc_credential_sha256) VALUES(%s,%s,now()+interval '1 hour','PARENT_OIDC',%s,%s)",
                     (digest(), self.f['a'], SYNTHETIC_ISSUER, digest())),
                    ('UPDATE ap_m1.trusted_sessions SET expires_at=now()', ()),
                    ('SELECT * FROM ap_m1.trusted_sessions', ())]:
                with self.assertRaises(DENIED, msg=statement):
                    with c.transaction():
                        c.execute(statement, args)
            c.rollback()

    def test_03_credential_replay_denied(self):
        credential = digest()
        token, principal, subject = exchange(credential=credential)
        with self.assertRaises(DENIED):
            exchange(subject=subject, credential=credential)
        with self.assertRaises(DENIED):  # same captured token, different claimed subject
            exchange(credential=credential)
        self.assertEqual(principal_of(token)[0], principal)

    def test_04_untrusted_issuer_and_malformed_inputs(self):
        bad = [dict(issuer='https://attacker.invalid'), dict(issuer='https://synthetic.example.invalid'),
               dict(issuer='accounts.google.com'), dict(issuer=None),
               dict(subject=''), dict(subject='has space'), dict(subject='x' * 256), dict(subject='tab\there'),
               dict(credential=b'\x00' * 31), dict(credential=b'\x00' * 33),
               dict(lifetime=299), dict(lifetime=43201), dict(lifetime=0), dict(lifetime=None)]
        bad.append(dict(subject=None))
        for override in bad:
            args = dict(subject='bad-' + str(uuid4()), credential=digest(), issuer=SYNTHETIC_ISSUER, lifetime=3600)
            args.update(override)
            with self.assertRaises(DENIED, msg=str(override)):
                exchange(**args)
        with local_test_disabled():  # synthetic issuer only while opted in
            with self.assertRaises(DENIED):
                exchange()
        # Boundaries accepted.
        for lifetime in (300, 43200):
            self.assertIsNotNone(principal_of(exchange(lifetime=lifetime)[0])[0])

    def test_05_identity_gucs_cannot_escalate(self):
        token, principal, _ = exchange()
        with as_session(token) as c:
            c.execute("SELECT set_config('ap.principal_id',%s,true)", (str(self.f['a']),))
            self.assertEqual(c.execute('SELECT ap_m1.ctx_principal()').fetchone()[0], principal)
            c.execute("SELECT set_config('ap.family_id',%s,true)", (str(self.f['family_a']),))
            self.assertIsNone(c.execute('SELECT ap_m1.ctx_family()').fetchone()[0])
            self.assertFalse(c.execute('SELECT ap_m1.family_owner(%s)', (self.f['family_a'],)).fetchone()[0])
            with self.assertRaises(DENIED):
                with c.transaction():
                    c.execute("SELECT ap_m1.create_child('forged')")
            for malformed in ('not-a-uuid', "'; DROP TABLE x; --", '', str(self.f['family_a']).upper() + 'x'):
                c.execute("SELECT set_config('ap.family_id',%s,true)", (malformed,))
                self.assertEqual(c.execute('SELECT ap_m1.ctx_principal(), ap_m1.ctx_family()').fetchone(),
                                 (principal, None))

    def test_06_family_selection_requires_live_membership_not_child_access(self):
        token, principal, _ = exchange()
        with as_session(token) as c:
            family = c.execute("SELECT id FROM ap_m1.create_family('bridge family')").fetchone()[0]
            c.commit()
        self.assertEqual(principal_of(token, family), (principal, family))
        self.assertEqual(principal_of(token, str(family).upper()), (principal, family))
        with as_session(token, family) as c:
            self.assertTrue(c.execute('SELECT ap_m1.family_owner(%s)', (family,)).fetchone()[0])
            child = c.execute("SELECT ap_m1.create_child('bridge child')").fetchone()[0]
            # Membership and ownership never imply exact-child access.
            self.assertFalse(c.execute("SELECT ap_m1.has_child_scope_v2(%s,'VIEW_CHILD_PROFILE')",
                                       (child,)).fetchone()[0])
            self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.children WHERE id=%s', (child,)).fetchone()[0], 0)
            c.rollback()
        other_token, other, _ = exchange()
        self.assertEqual(principal_of(other_token, family), (other, None))
        with as_session(other_token, family) as c:
            self.assertFalse(c.execute('SELECT ap_m1.family_owner(%s)', (family,)).fetchone()[0])
            self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.list_my_families()').fetchone()[0], 0)
            self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.guardian_memberships').fetchone()[0], 0)
        with admin_connection() as a:
            a.execute('UPDATE ap_m1.guardian_memberships SET revoked_at=now() WHERE family_id=%s', (family,))
        self.assertEqual(principal_of(token, family), (principal, None))

    def test_07_logout_expiry_issuer_optout_and_erasure(self):
        token, principal, _ = exchange()
        with as_session(token) as c:
            self.assertTrue(c.execute('SELECT ap_m1.revoke_current_parent_session()').fetchone()[0])
            c.commit()
        self.assertEqual(principal_of(token), (None, None))
        with as_session(token) as c:
            self.assertFalse(c.execute('SELECT ap_m1.revoke_current_parent_session()').fetchone()[0])
        with runtime_connection() as c:  # no presented token revokes nothing
            self.assertFalse(c.execute('SELECT ap_m1.revoke_current_parent_session()').fetchone()[0])
        # LOCAL_TEST sessions are not ended by the parent logout function.
        local = mint_session(self.f['a'])
        with as_session(local) as c:
            self.assertFalse(c.execute('SELECT ap_m1.revoke_current_parent_session()').fetchone()[0])

        token, principal, _ = exchange()
        with admin_connection() as a:
            a.execute("UPDATE ap_m1.trusted_sessions SET created_at=now()-interval '2 hours', "
                      "expires_at=now()-interval '1 second' WHERE token_sha256=public.digest(%s,'sha256')", (token,))
        self.assertEqual(principal_of(token), (None, None))

        token, principal, _ = exchange()
        with local_test_disabled():
            self.assertEqual(principal_of(token), (None, None))
        self.assertEqual(principal_of(token)[0], principal)

        token, principal, subject = exchange()
        with as_session(token) as c:
            c.execute('SELECT ap_m1.request_account_erasure(%s)', (uuid4(),))
            c.commit()
        self.assertEqual(principal_of(token), (None, None))
        # A later login creates a fresh identity; the erased row is never resurrected.
        fresh_token, fresh, _ = exchange(subject=subject)
        self.assertNotEqual(fresh, principal)
        self.assertEqual(principal_of(fresh_token)[0], fresh)

    def test_08_live_session_cap(self):
        subject = 'cap-' + str(uuid4())
        tokens = [exchange(subject=subject)[0] for _ in range(11)]
        self.assertEqual(principal_of(tokens[0]), (None, None))
        live = [t for t in tokens if principal_of(t)[0] is not None]
        self.assertEqual(live, tokens[1:])

    def test_09_local_test_sessions_unchanged(self):
        token = mint_session(self.f['a'], self.f['family_a'])
        self.assertEqual(principal_of(token), (self.f['a'], self.f['family_a']))
        # The per-request selector applies to PARENT_OIDC sessions only.
        self.assertEqual(principal_of(token, self.f['family_b']), (self.f['a'], self.f['family_a']))
        unbound = mint_session(self.f['a'])
        self.assertEqual(principal_of(unbound, self.f['family_a']), (self.f['a'], None))
        with as_session(unbound) as c:
            self.assertTrue(c.execute("SELECT ap_m1.has_child_scope_v2(%s,'VIEW_CHILD_PROFILE')",
                                      (self.f['child_a'],)).fetchone()[0])

    def test_10_function_acl_catalog(self):
        with admin_connection() as a:
            def can(role, sig):
                return a.execute("SELECT has_function_privilege(%s,%s,'EXECUTE')", (role, sig)).fetchone()[0]
            exchange_sig = 'ap_m1.exchange_parent_oidc_session(text,text,bytea,integer)'
            logout_sig = 'ap_m1.revoke_current_parent_session()'
            issuer_sig = 'ap_m1._parent_oidc_issuer_trusted(text)'
            resolve_sig = 'ap_m1.resolve_parent_principal(text,text)'
            self.assertTrue(can('ap_auth_issuer', exchange_sig))
            self.assertFalse(can('ap_m1_api', exchange_sig))
            self.assertFalse(can('ap_m1_auth', exchange_sig))
            self.assertTrue(can('ap_m1_api', logout_sig))
            self.assertFalse(can('ap_auth_issuer', logout_sig))
            self.assertFalse(can('ap_m1_api', issuer_sig))
            self.assertFalse(can('ap_m1_api', resolve_sig))
            self.assertTrue(can('ap_auth_issuer', resolve_sig))
            rows = a.execute("""SELECT p.proname, p.prosecdef, p.proconfig, r.rolname,
                EXISTS(SELECT 1 FROM aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) x
                       WHERE x.grantee=0 AND x.privilege_type='EXECUTE')
                FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace JOIN pg_roles r ON r.oid=p.proowner
                WHERE n.nspname='ap_m1' AND p.proname IN
                ('exchange_parent_oidc_session','revoke_current_parent_session','_parent_oidc_issuer_trusted','_session')""").fetchall()
            owners = {r[0]: r[3] for r in rows}
            self.assertEqual(owners, {'exchange_parent_oidc_session': 'ap_db_executor',
                                      'revoke_current_parent_session': 'ap_db_executor',
                                      '_parent_oidc_issuer_trusted': 'ap_m1_auth', '_session': 'ap_m1_auth'})
            for name, definer, config, _, public in rows:
                self.assertTrue(definer, name)
                self.assertFalse(public, name)
                self.assertTrue(any(v.startswith('search_path=pg_catalog, ap_m1, public') for v in config), name)
            # The issuer login is a dedicated, unprivileged role.
            self.assertEqual(a.execute("""SELECT count(*) FROM pg_roles r WHERE r.rolname='madalasa_auth'
                AND NOT r.rolsuper AND NOT r.rolbypassrls AND pg_has_role(r.oid,'ap_auth_issuer','MEMBER')
                AND NOT pg_has_role(r.oid,'ap_m1_api','MEMBER')""").fetchone()[0], 1)

    def test_11_superuser_or_runtime_member_cannot_exchange(self):
        with self.assertRaises(DENIED):  # privileged migration/admin login is not the issuer
            with admin_connection() as a:
                a.execute('SELECT * FROM ap_m1.exchange_parent_oidc_session(%s,%s,%s,3600)',
                          (SYNTHETIC_ISSUER, 'admin-' + str(uuid4()), digest()))

    def test_12_google_issuer_is_accepted_without_local_test(self):
        # Synthetic subject string only; no real Google account is involved.
        with local_test_disabled():
            token, principal, _ = exchange(issuer=GOOGLE_ISSUER, subject='1' + str(uuid4().int)[:20])
            self.assertEqual(principal_of(token), (principal, None))
        with admin_connection() as a:  # untrusting the stored issuer kills the session
            a.execute("UPDATE ap_m1.parent_principals SET oidc_issuer='https://erased.example.invalid' WHERE id=%s",
                      (principal,))
        self.assertEqual(principal_of(token), (None, None))


if __name__ == '__main__':
    unittest.main()
