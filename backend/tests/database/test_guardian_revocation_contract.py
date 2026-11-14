"""Issue32 B09/B18; synthetic-only, parent owns migration replay.

Offline only: python -m unittest discover -s backend/tests/database -p
 test_guardian_revocation_contract.py -k SourceContract -v
Runtime: same command without -k; requires restricted runtime/auth/billing logins.
Media lease tests are paid-feature metadata tests, NOT free-release gates.
"""
from concurrent.futures import ThreadPoolExecutor
from contextlib import contextmanager
from pathlib import Path
import time
import unittest
from uuid import uuid4

def load_runtime():
    # Offline source assertions must not require a driver or inspect DB config.
    global psycopg, admin_connection, runtime_connection, auth_connection, mint_session, World
    import psycopg
    from fixtures import admin_connection, runtime_connection, auth_connection, mint_session
    from test_billing import World

MIGRATIONS = Path(__file__).resolve().parents[2] / 'persistence' / 'migrations'


class SourceContract(unittest.TestCase):
    """Offline assertions only; these are not database behavioral proof."""
    def test_duplicate_validation_precedes_token_generation(self):
        source = '\n'.join(p.read_text() for p in sorted(MIGRATIONS.glob('*.sql')))
        body = source.rsplit('FUNCTION ap_m1.issue_child_invite(', 1)[1].split('END $f$;', 1)[0]
        self.assertIn('count(DISTINCT', body)
        self.assertLess(body.index('count(DISTINCT'), body.index('token:='))

    def test_accept_expiry_uses_post_lock_wall_clock(self):
        source = '\n'.join(p.read_text() for p in sorted(MIGRATIONS.glob('*.sql')))
        body = source.rsplit('FUNCTION ap_m1.accept_child_invite(', 1)[1].split('END $f$;', 1)[0]
        self.assertIn('i.expires_at<=clock_timestamp()', body)
        self.assertLess(body.index('FOR UPDATE'), body.index('i.expires_at<=clock_timestamp()'))


class GuardianInviteContract(unittest.TestCase):
    def setUp(self):
        load_runtime()
        self.w = World()
        self.addCleanup(self.w.cleanup)
        self.addCleanup(self.clean_invites)
        with admin_connection() as c:
            for scope in ('MANAGE_CHILD_GRANTS', 'MANAGE_CONSENT', 'VIEW_ALERTS'):
                c.execute('INSERT INTO ap_m1.child_access_grants_v2(child_id,adult_id,scope,consent_record_id,authority_review_id,issued_by) VALUES(%s,%s,%s,%s,%s,%s)',
                          (self.w.child,self.w.actor,scope,self.w.consent,self.w.review,self.w.actor))

    def clean_invites(self):
        with admin_connection() as c:
            c.execute('DELETE FROM ap_m1.child_access_grants_v2 WHERE origin_invite_id IN (SELECT id FROM ap_m1.child_access_invites WHERE child_id=%s)', (self.w.child,))
            c.execute('DELETE FROM ap_m1.child_access_invites WHERE child_id=%s', (self.w.child,))
            c.execute('DELETE FROM ap_m1.consent_decision_audit WHERE consent_id IN (SELECT id FROM ap_m1.consent_records WHERE child_id=%s)', (self.w.child,))
            c.execute('DELETE FROM ap_m1.audit_events WHERE family_id=%s', (self.w.family,))

    def invite(self, scopes=None):
        with self.w.runtime() as c:
            return c.execute('SELECT ap_m1.issue_child_invite(%s,%s,%s)',
                             (self.w.child,self.w.other,scopes or ['VIEW_ALERTS'])).fetchone()[0]

    def accept(self, token):
        with self.w.runtime(self.w.other, family=False) as c:
            c.execute("SET LOCAL statement_timeout='8s'")
            return c.execute('SELECT ap_m1.accept_child_invite(%s)', (token,)).fetchone()[0]

    def test_duplicate_scopes_denied_without_invite_or_audit(self):
        with admin_connection() as a:
            before = a.execute('SELECT count(*) FROM ap_m1.child_access_invites WHERE child_id=%s', (self.w.child,)).fetchone()
            audit = a.execute("SELECT count(*) FROM ap_m1.audit_events WHERE family_id=%s AND action='CHILD_INVITE_ISSUED'", (self.w.family,)).fetchone()
        with self.assertRaises(psycopg.errors.InsufficientPrivilege):
            self.invite(['VIEW_ALERTS','VIEW_ALERTS'])
        with admin_connection() as a:
            self.assertEqual(a.execute('SELECT count(*) FROM ap_m1.child_access_invites WHERE child_id=%s', (self.w.child,)).fetchone(), before)
            self.assertEqual(a.execute("SELECT count(*) FROM ap_m1.audit_events WHERE family_id=%s AND action='CHILD_INVITE_ISSUED'", (self.w.family,)).fetchone(), audit)

    def wait_for_lock(self, pid):
        deadline = time.monotonic()+5
        with admin_connection(autocommit=True) as c:
            while time.monotonic()<deadline:
                if c.execute("SELECT wait_event_type='Lock' FROM pg_stat_activity WHERE pid=%s", (pid,)).fetchone() == (True,):
                    return
                time.sleep(.01)
        self.fail('accept did not reach the held invite row lock')

    def test_concurrent_accept_same_invite_exactly_one_success(self):
        token = self.invite()
        # First accept remains uncommitted. Second must wait on the invite row,
        # then observe ACCEPTED, not insert duplicate grants or return success.
        with self.w.runtime(self.w.other, family=False) as winner:
            self.assertEqual(winner.execute('SELECT ap_m1.accept_child_invite(%s)', (token,)).fetchone()[0], self.w.child)
            with self.w.runtime(self.w.other, family=False) as loser:
                loser.execute("SET LOCAL statement_timeout='8s'")
                pid = loser.info.backend_pid
                with ThreadPoolExecutor(max_workers=1) as pool:
                    future = pool.submit(loser.execute, 'SELECT ap_m1.accept_child_invite(%s)', (token,))
                    try:
                        self.wait_for_lock(pid)
                    finally:
                        winner.commit()
                    with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                        future.result(timeout=8)
                loser.rollback()
        with admin_connection() as c:
            self.assertEqual(c.execute("SELECT count(*) FROM ap_m1.child_access_grants_v2 WHERE child_id=%s AND adult_id=%s AND scope='VIEW_ALERTS'", (self.w.child,self.w.other)).fetchone()[0], 1)
            self.assertEqual(c.execute("SELECT count(*) FROM ap_m1.audit_events WHERE family_id=%s AND action='CHILD_INVITE_ACCEPTED'", (self.w.family,)).fetchone()[0], 1)

    def test_expiry_during_invite_row_lock_denied(self):
        token = self.invite()
        with admin_connection() as holder:
            holder.execute("SELECT id FROM ap_m1.child_access_invites WHERE one_time_secret_hash=public.digest(%s,'sha256') FOR UPDATE", (token,))
            with self.w.runtime(self.w.other, family=False) as caller:
                caller.execute("SET LOCAL statement_timeout='8s'")
                with ThreadPoolExecutor(max_workers=1) as pool:
                    future = pool.submit(caller.execute, 'SELECT ap_m1.accept_child_invite(%s)', (token,))
                    try:
                        self.wait_for_lock(caller.info.backend_pid)
                        # Set expiry after the waiting statement's start, but
                        # before unlock. No production TTL or clock is changed.
                        holder.execute("UPDATE ap_m1.child_access_invites SET expires_at=clock_timestamp()+interval '100 milliseconds' WHERE one_time_secret_hash=public.digest(%s,'sha256')", (token,))
                        holder.execute('SELECT pg_sleep(.2)')
                    finally:
                        holder.commit()
                    with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                        future.result(timeout=8)
                caller.rollback()
        with admin_connection() as c:
            self.assertEqual(c.execute("SELECT state FROM ap_m1.child_access_invites WHERE one_time_secret_hash=public.digest(%s,'sha256')", (token,)).fetchone()[0], 'PENDING')
            self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.child_access_grants_v2 WHERE origin_invite_id IN (SELECT id FROM ap_m1.child_access_invites WHERE child_id=%s)', (self.w.child,)).fetchone()[0], 0)

    def test_withdrawal_grant_metadata_changes_once(self):
        with admin_connection() as c:
            c.execute("UPDATE ap_m1.child_access_grants_v2 SET revoked_at=clock_timestamp() WHERE child_id=%s AND adult_id=%s AND scope='VIEW_MEDIA'", (self.w.child,self.w.actor))
            before = dict((r[0],r[1:]) for r in c.execute('SELECT id,revocation_epoch,revision,updated_at,revoked_at FROM ap_m1.child_access_grants_v2 WHERE child_id=%s', (self.w.child,)))
        request = uuid4()
        first = None
        for attempt in range(2):
            with self.w.runtime() as c:
                c.execute('SELECT ap_m1.withdraw_consent(%s,%s)', (self.w.consent,request))
            with admin_connection() as c:
                after = {r[0]:r[1:] for r in c.execute('SELECT id,revocation_epoch,revision,updated_at,revoked_at FROM ap_m1.child_access_grants_v2 WHERE child_id=%s', (self.w.child,))}
            if attempt == 0:
                for key, row in after.items():
                    if before[key][3] is not None:
                        self.assertEqual(row, before[key])
                        continue
                    self.assertEqual(row[:2], (before[key][0]+1,before[key][1]+1))
                    self.assertGreaterEqual(row[2], before[key][2])
                    self.assertIsNotNone(row[3])
                first = after
            else:
                self.assertEqual(after, first)


class StoredLeaseContract(unittest.TestCase):
    """Paid-feature metadata only; never changes real-media release gates."""
    def setUp(self):
        load_runtime()
        self.w = World()
        self.addCleanup(self.w.cleanup)
        self.w.purchase()
        self.token = mint_session(self.w.actor, self.w.family)
        self.other_token = mint_session(self.w.other)

    @contextmanager
    def session(self, token):
        with runtime_connection() as c:
            c.execute("SELECT set_config('ap.session_token',%s,true)", (token,))
            yield c

    def acquire(self, token=None, kind='PREMIUM_MAP'):
        with self.session(token or self.token) as c:
            return c.execute('SELECT ap_m1.acquire_viewer_lease(%s,%s,%s)', (self.w.child,uuid4(),kind)).fetchone()[0]

    def row(self, lease):
        with admin_connection() as c:
            return c.execute('SELECT revoked_at,revision,updated_at FROM ap_m1.premium_viewer_leases WHERE id=%s', (lease,)).fetchone()

    def test_revoked_session_releases_only_bound_lease(self):
        lease = self.acquire()
        before = self.row(lease)
        with auth_connection() as c:
            c.execute('SELECT ap_m1.revoke_session(%s)', (self.token,))
        after = self.row(lease)
        self.assertIsNotNone(after[0])
        self.assertEqual(after[1], before[1]+1)
        self.acquire(self.other_token)
        with self.session(self.other_token) as c:
            self.assertEqual(c.execute('SELECT ap_m1.ctx_principal()').fetchone()[0], self.w.other)

    def test_expired_session_does_not_hold_capacity(self):
        self.token = mint_session(self.w.actor, self.w.family, lifetime='2 seconds')
        lease = self.acquire()
        with admin_connection() as c:
            # Natural expiry (no UPDATE trigger): acquisition must collect the
            # stale stored row rather than count it as a second live viewer.
            c.execute('SELECT pg_sleep(2.1)')
        self.acquire(self.other_token)
        self.assertIsNotNone(self.row(lease)[0])

    def test_grant_revocation_invalidates_lease_not_other_adult(self):
        self.w.purchase(sku='local_extra_viewer_100d')
        lease = self.acquire()
        other = self.acquire(self.other_token)
        with admin_connection() as c:
            c.execute("UPDATE ap_m1.child_access_grants_v2 SET revoked_at=clock_timestamp() WHERE child_id=%s AND adult_id=%s AND scope='VIEW_HISTORY'", (self.w.child,self.w.actor))
        self.assertIsNotNone(self.row(lease)[0])
        self.assertIsNone(self.row(other)[0])
        with self.session(self.token) as c:
            self.assertEqual(c.execute('SELECT ap_m1.ctx_principal()').fetchone()[0], self.w.actor)

    def test_authority_dispute_invalidates_only_affected_adult(self):
        self.w.purchase(sku='local_extra_viewer_100d')
        lease = self.acquire(self.other_token)
        owner = self.acquire()
        with admin_connection() as c:
            c.execute("UPDATE ap_m1.child_authority_reviews SET state='DISPUTED' WHERE id=%s", (self.w.other_review,))
        self.assertIsNotNone(self.row(lease)[0])
        self.assertIsNone(self.row(owner)[0])

    def test_core_consent_revocation_invalidates_stored_lease(self):
        lease = self.acquire()
        with admin_connection() as c:
            c.execute("UPDATE ap_m1.consent_records SET legal_state='REVOKED' WHERE id=%s", (self.w.consent,))
        self.assertIsNotNone(self.row(lease)[0])

    def test_grant_loss_preserves_same_adult_other_child_lease(self):
        other = World()
        self.addCleanup(other.cleanup)
        other.purchase()
        with admin_connection() as c:
            review = uuid4()
            c.execute("INSERT INTO ap_m1.child_authority_reviews(id,child_id,adult_id,state,lawful_basis_version,method_code,reviewed_at,expires_at) VALUES(%s,%s,%s,'LOCAL_TEST_APPROVED','synthetic-v1','SYNTHETIC_FIXTURE',now(),now()+interval '1 day')", (review,other.child,self.w.actor))
            c.execute("INSERT INTO ap_m1.child_access_grants_v2(child_id,adult_id,scope,consent_record_id,authority_review_id,issued_by) VALUES(%s,%s,'VIEW_HISTORY',%s,%s,%s)", (other.child,self.w.actor,other.consent,review,self.w.actor))
        lease = self.acquire()
        with self.session(self.token) as c:
            unaffected = c.execute("SELECT ap_m1.acquire_viewer_lease(%s,%s,'PREMIUM_MAP')", (other.child,uuid4())).fetchone()[0]
        with admin_connection() as c:
            c.execute("UPDATE ap_m1.child_access_grants_v2 SET revoked_at=clock_timestamp() WHERE child_id=%s AND adult_id=%s AND scope='VIEW_HISTORY'", (self.w.child,self.w.actor))
        self.assertIsNotNone(self.row(lease)[0])
        self.assertIsNone(self.row(unaffected)[0])

    def test_unrelated_grant_change_does_not_revoke_map_lease(self):
        lease = self.acquire()
        before = self.row(lease)
        with admin_connection() as c:
            c.execute("UPDATE ap_m1.child_access_grants_v2 SET revoked_at=clock_timestamp() WHERE child_id=%s AND adult_id=%s AND scope='VIEW_MEDIA'", (self.w.child,self.w.actor))
        self.assertEqual(self.row(lease), before)

    def test_helper_is_not_runtime_callable(self):
        with self.session(self.token) as c:
            self.assertFalse(c.execute("SELECT has_function_privilege(current_user,'ap_m1.invalidate_guardian_viewer_leases()','EXECUTE')").fetchone()[0])
            self.assertFalse(c.execute('SELECT rolsuper OR rolbypassrls FROM pg_roles WHERE rolname=current_user').fetchone()[0])

    def test_media_withdrawal_keeps_map_lease_and_gates_closed(self):
        self.w.purchase(sku='local_extra_viewer_100d')
        media = self.acquire(kind='AUTHORIZED_MEDIA')
        map_lease = self.acquire(self.other_token)
        with admin_connection() as c:
            c.execute("UPDATE ap_m1.consent_records SET status='WITHDRAWN' WHERE child_id=%s AND purpose='MEDIA'", (self.w.child,))
            self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.media_capability_gates WHERE released OR real_capture_enabled').fetchone()[0], 0)
        self.assertIsNotNone(self.row(media)[0])
        self.assertIsNone(self.row(map_lease)[0])


if __name__ == '__main__':
    unittest.main()
