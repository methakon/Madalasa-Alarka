"""Admin login challenge, session bridge, CSRF and back-office reads (migration 0022).

Real separate logins against PostgreSQL with forced RLS. SYNTHETIC DATA ONLY.
Run: python3 tools/database/manage.py test --pattern test_admin_session_bridge.py
"""
import unittest
from uuid import uuid4

import psycopg

from fixtures import admin_connection, runtime_connection, auth_connection, seed_core

SYN = 'https://synthetic.invalid'
DENIED = psycopg.errors.InsufficientPrivilege


def challenge():
    with auth_connection() as c:
        return c.execute('SELECT nonce, login_state FROM ap_m1.issue_admin_login_challenge()').fetchone()


def exchange(subject, email=None, nonce_state=None, issuer=SYN, lifetime=1800):
    nonce, state = nonce_state or challenge()
    with auth_connection() as c:
        return c.execute('SELECT session_token, csrf_token, admin_id, account_state '
                         'FROM ap_m1.exchange_admin_oidc_session(%s,%s,%s,%s,%s,%s)',
                         (issuer, subject, email or subject + '@example.invalid', nonce, state, lifetime)).fetchone()


def as_admin(conn, token):
    conn.execute("SELECT set_config('ap.admin_session_token',%s,true)", (token,))


def state_of(token):
    with runtime_connection() as c:
        as_admin(c, token)
        row = c.execute('SELECT ap_m1.ctx_admin(), (SELECT role_codes FROM ap_m1.admin_session_state())').fetchone()
        c.rollback()
        return row


class AdminSessionBridgeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.f = seed_core()  # enables the database-local synthetic opt-in

    def owner(self):
        subject = 'owner-' + str(uuid4())
        with admin_connection() as a:
            a.execute('INSERT INTO ap_m1.owner_identity_allowlist(issuer,subject) VALUES(%s,%s)', (SYN, subject))
        return subject

    def test_01_login_is_identity_only(self):
        token, csrf, admin, state = exchange('applicant-' + str(uuid4()))
        self.assertRegex(token, '^[0-9a-f]{64}$')
        self.assertRegex(csrf, '^[0-9a-f]{64}$')
        self.assertNotEqual(token, csrf)
        self.assertEqual(state, 'NO_ACCESS')
        self.assertEqual(state_of(token), (admin, []))
        with runtime_connection() as c:
            as_admin(c, token)
            for permission in ('FAQ_EDIT', 'SUPPORT_READ', 'BILLING_READ', 'USAGE_READ', 'OWNER_MANAGE', 'AUDIT_READ'):
                self.assertFalse(c.execute('SELECT ap_m1.has_admin_permission(%s)', (permission,)).fetchone()[0])
        with admin_connection() as a:
            row = a.execute("SELECT authorized_at_issue, mfa_until, csrf_sha256=public.digest(%s,'sha256') "
                            "FROM ap_m1.admin_sessions WHERE token_hash=public.digest(%s,'sha256')", (csrf, token)).fetchone()
            self.assertEqual(row, (False, None, True))
            self.assertEqual(a.execute("SELECT count(*) FROM ap_m1.admin_sessions s WHERE position(%s in s::text)>0",
                                       (token,)).fetchone()[0], 0)
            self.assertEqual(a.execute("SELECT count(*) FROM ap_m1.admin_login_challenges c WHERE position(%s in c::text)>0",
                                       (token,)).fetchone()[0], 0)

    def test_02_challenge_is_single_use_and_state_bound(self):
        nonce, state = challenge()
        exchange('once-' + str(uuid4()), nonce_state=(nonce, state))
        with self.assertRaises(DENIED):  # replay
            exchange('once-' + str(uuid4()), nonce_state=(nonce, state))
        other_nonce, other_state = challenge()
        with self.assertRaises(DENIED):  # nonce from one challenge, state from another
            exchange('mix-' + str(uuid4()), nonce_state=(other_nonce, state))
        with self.assertRaises(DENIED):
            exchange('mix-' + str(uuid4()), nonce_state=(nonce, other_state))
        exchange('mix-ok-' + str(uuid4()), nonce_state=(other_nonce, other_state))
        nonce, state = challenge()
        with admin_connection() as a:
            a.execute("UPDATE ap_m1.admin_login_challenges SET created_at=now()-interval '10 minutes', "
                      "expires_at=now()-interval '6 minutes' WHERE nonce_sha256=public.digest(%s,'sha256')", (nonce,))
        with self.assertRaises(DENIED):  # expired
            exchange('late-' + str(uuid4()), nonce_state=(nonce, state))

    def test_03_inputs_and_issuer_trust(self):
        for kwargs in [dict(issuer='https://attacker.invalid'), dict(issuer='accounts.google.com'),
                       dict(email='no-at-sign'), dict(email='@example.invalid'), dict(lifetime=299), dict(lifetime=3601)]:
            with self.assertRaises(DENIED, msg=str(kwargs)):
                exchange('bad-' + str(uuid4()), **kwargs)
        for subject in ('', 'has space', 'x' * 256, None):
            with self.assertRaises(DENIED, msg=repr(subject)):
                exchange(subject, email='s@example.invalid')

    def test_04_role_separation(self):
        with runtime_connection() as c:
            for statement, args in [('SELECT * FROM ap_m1.issue_admin_login_challenge()', ()),
                                    ('SELECT * FROM ap_m1.exchange_admin_oidc_session(%s,%s,%s,%s,%s,1800)',
                                     (SYN, 'r', 'r@example.invalid', 'a' * 64, 'b' * 64)),
                                    ('SELECT ap_m1.register_admin(%s,%s)', (self.f['a'], 'x@example.invalid')),
                                    ("SELECT ap_m1.mint_admin_session(%s,now()+interval '10 minutes')", (uuid4(),)),
                                    ('SELECT * FROM ap_m1.admin_login_challenges', ())]:
                with self.assertRaises(DENIED, msg=statement):
                    with c.transaction():
                        c.execute(statement, args)
        with auth_connection() as c:  # raw issuer primitives are retired from the issuer login
            for statement, args in [('SELECT ap_m1.register_admin(%s,%s)', (self.f['a'], 'x@example.invalid')),
                                    ("SELECT ap_m1.mint_admin_session(%s,now()+interval '10 minutes')", (uuid4(),)),
                                    ('SELECT ap_m1.admin_csrf_valid(%s)', ('a' * 64,))]:
                with self.assertRaises(DENIED, msg=statement):
                    with c.transaction():
                        c.execute(statement, args)
        with self.assertRaises(DENIED):  # superuser/migration login is a runtime member too
            with admin_connection() as a:
                a.execute('SELECT * FROM ap_m1.issue_admin_login_challenge()')

    def test_05_csrf_rotation_and_logout(self):
        token, csrf, _, _ = exchange('csrf-' + str(uuid4()))
        other_token, other_csrf, _, _ = exchange('csrf-other-' + str(uuid4()))
        with runtime_connection() as c:
            as_admin(c, token)
            self.assertTrue(c.execute('SELECT ap_m1.admin_csrf_valid(%s)', (csrf,)).fetchone()[0])
            for bad in (other_csrf, csrf.upper(), '', None, csrf[:-1]):
                self.assertFalse(c.execute('SELECT ap_m1.admin_csrf_valid(%s)', (bad,)).fetchone()[0], bad)
            rotated = c.execute('SELECT ap_m1.rotate_admin_csrf()').fetchone()[0]
            c.commit()
        with runtime_connection() as c:
            as_admin(c, token)
            self.assertFalse(c.execute('SELECT ap_m1.admin_csrf_valid(%s)', (csrf,)).fetchone()[0])
            self.assertTrue(c.execute('SELECT ap_m1.admin_csrf_valid(%s)', (rotated,)).fetchone()[0])
            self.assertTrue(c.execute('SELECT ap_m1.revoke_current_admin_session()').fetchone()[0])
            c.commit()
        self.assertIsNone(state_of(token)[0])
        self.assertIsNotNone(state_of(other_token)[0])
        with runtime_connection() as c:
            as_admin(c, token)
            self.assertFalse(c.execute('SELECT ap_m1.revoke_current_admin_session()').fetchone()[0])
            self.assertFalse(c.execute('SELECT ap_m1.admin_csrf_valid(%s)', (rotated,)).fetchone()[0])
            with self.assertRaises(psycopg.errors.InvalidAuthorizationSpecification):
                with c.transaction():
                    c.execute('SELECT ap_m1.rotate_admin_csrf()')

    def test_06_owner_without_mfa_has_no_step_up(self):
        subject = self.owner()
        token, _, admin, state = exchange(subject)
        self.assertEqual(state, 'ACTIVE')
        self.assertEqual(state_of(token), (admin, ['ROOT_OWNER']))
        with runtime_connection() as c:
            as_admin(c, token)
            self.assertTrue(c.execute("SELECT ap_m1.has_admin_permission('SUPPORT_READ')").fetchone()[0])
            for permission in ('OWNER_MANAGE', 'FAQ_PUBLISH', 'AUDIT_READ'):
                self.assertFalse(c.execute('SELECT ap_m1.has_admin_permission(%s)', (permission,)).fetchone()[0])
            with self.assertRaises(DENIED):
                with c.transaction():
                    c.execute('SELECT * FROM ap_m1.admin_read_action_audit()')
        with admin_connection() as a:  # test-only stand-in for a future MFA step-up
            a.execute("UPDATE ap_m1.admin_sessions SET mfa_until=expires_at WHERE token_hash=public.digest(%s,'sha256')",
                      (token,))
        with runtime_connection() as c:
            as_admin(c, token)
            actions = {r[3] for r in c.execute('SELECT * FROM ap_m1.admin_read_action_audit(NULL,100)')}
            self.assertIn('ADMIN_LOGIN', actions)
            with self.assertRaises(psycopg.errors.InvalidParameterValue):
                with c.transaction():
                    c.execute('SELECT * FROM ap_m1.admin_read_action_audit(NULL,101)')

    def test_07_suspended_and_revoked_accounts_cannot_log_in(self):
        subject = 'suspend-' + str(uuid4())
        token, _, admin, _ = exchange(subject)
        with admin_connection() as a:
            a.execute("UPDATE ap_m1.admin_accounts SET state='SUSPENDED',session_revocation_epoch=session_revocation_epoch+1 "
                      "WHERE id=%s", (admin,))
        self.assertIsNone(state_of(token)[0])
        with self.assertRaises(DENIED):
            exchange(subject)

    def test_08_support_queue_scoping(self):
        agent_subject = 'agent-' + str(uuid4())
        _, _, agent, _ = exchange(agent_subject)
        owner_subject = self.owner()
        _, _, owner, _ = exchange(owner_subject)
        with admin_connection() as a:
            a.execute("UPDATE ap_m1.admin_accounts SET state='ACTIVE' WHERE id=%s", (agent,))
            a.execute("INSERT INTO ap_m1.admin_role_grants(admin_id,role_code,granted_by) VALUES(%s,'SUPPORT_AGENT',%s)",
                      (agent, owner))
            mine = a.execute("INSERT INTO ap_m1.support_tickets(requester_id,subject,assigned_admin_id) "
                             "VALUES(%s,'Synthetic assigned',%s) RETURNING id", (self.f['a'], agent)).fetchone()[0]
            theirs = a.execute("INSERT INTO ap_m1.support_tickets(requester_id,subject) VALUES(%s,'Synthetic other') "
                               "RETURNING id", (self.f['b'],)).fetchone()[0]
        agent_token = exchange(agent_subject)[0]  # grants bump the epoch; log in again
        owner_token = exchange(owner_subject)[0]
        with runtime_connection() as c:
            as_admin(c, agent_token)
            rows = {r[0]: r[4] for r in c.execute('SELECT * FROM ap_m1.admin_list_support_tickets(NULL,100)')}
            self.assertIn(mine, rows)
            self.assertTrue(rows[mine])
            self.assertNotIn(theirs, rows)
            c.commit()
        with runtime_connection() as c:
            as_admin(c, owner_token)
            rows = {r[0] for r in c.execute('SELECT * FROM ap_m1.admin_list_support_tickets(NULL,100)')}
            self.assertTrue({mine, theirs} <= rows)
            c.rollback()
        applicant = exchange('noperm-' + str(uuid4()))[0]
        with runtime_connection() as c:
            as_admin(c, applicant)
            with self.assertRaises(DENIED):
                with c.transaction():
                    c.execute('SELECT * FROM ap_m1.admin_list_support_tickets()')

    def test_09_session_cap(self):
        subject = 'cap-' + str(uuid4())
        tokens = [exchange(subject)[0] for _ in range(6)]
        self.assertIsNone(state_of(tokens[0])[0])
        self.assertTrue(all(state_of(t)[0] for t in tokens[1:]))

    def test_10_function_acl_catalog(self):
        expected = {'issue_admin_login_challenge': 'ap_db_executor', 'exchange_admin_oidc_session': 'ap_db_executor',
                    'rotate_admin_csrf': 'ap_db_executor', 'revoke_current_admin_session': 'ap_db_executor',
                    'admin_list_support_tickets': 'ap_db_executor', 'admin_read_action_audit': 'ap_db_executor',
                    'admin_csrf_valid': 'ap_m1_auth', 'admin_session_state': 'ap_m1_auth'}
        with admin_connection() as a:
            rows = a.execute("""SELECT p.proname, r.rolname, p.prosecdef, p.proconfig,
                EXISTS(SELECT 1 FROM aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) x
                       WHERE x.grantee=0 AND x.privilege_type='EXECUTE'),
                has_function_privilege('ap_m1_api',p.oid,'EXECUTE'),
                has_function_privilege('ap_auth_issuer',p.oid,'EXECUTE')
                FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace JOIN pg_roles r ON r.oid=p.proowner
                WHERE n.nspname='ap_m1' AND p.proname=ANY(%s)""", (list(expected),)).fetchall()
            self.assertEqual({r[0]: r[1] for r in rows}, expected)
            issuer_only = {'issue_admin_login_challenge', 'exchange_admin_oidc_session'}
            for name, _, definer, config, public, api, issuer in rows:
                self.assertTrue(definer, name)
                self.assertFalse(public, name)
                self.assertTrue(any(v.startswith('search_path=pg_catalog, ap_m1, public') for v in config), name)
                self.assertEqual(issuer, name in issuer_only, name)
                self.assertEqual(api, name not in issuer_only, name)
            self.assertEqual(a.execute("SELECT relrowsecurity AND relforcerowsecurity FROM pg_class "
                                       "WHERE oid='ap_m1.admin_login_challenges'::regclass").fetchone()[0], True)


if __name__ == '__main__':
    unittest.main()
