"""Synthetic privacy/admin tests. Requires parent's applied disposable DB.

Run: .local-db/venv/bin/python -m unittest discover -s backend/tests/database
     -p test_privacy_admin.py -v
No SET ROLE, fabricated UUID identity GUC, real people, device capture or billing.
Every test transaction rolls back; class-scoped synthetic staff setup is removed.
"""
import unittest
from pathlib import Path
from uuid import uuid4

import psycopg
from fixtures import admin_connection, runtime_connection, auth_connection, seed_core, as_parent

ROOT = Path(__file__).resolve().parents[2] / 'persistence' / 'migrations'


class MigrationContract(unittest.TestCase):
    def test_privacy_domains_are_present(self):
        for name in ('0003_consent_authority_and_retention.sql',
                     '0008_admin_identity_rbac_and_support.sql',
                     '0010_erasure_audit_and_recovery.sql'):
            self.assertTrue((ROOT / name).is_file(), name)


class PrivacyAdminTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.f = seed_core()
        cls.accounts = {}
        cls.tokens = {}
        with admin_connection() as c:
            c.execute("INSERT INTO ap_m1.owner_identity_allowlist(issuer,subject) VALUES "
                      "('https://synthetic.example.invalid',%s) ON CONFLICT DO NOTHING",
                      ('fixture-' + str(cls.f['c']),))
        # Privileged synthetic setup. Since 0022 the issuer login can no longer call
        # register_admin/mint_admin_session directly (only the verified exchange).
        for name in ('a', 'b', 'c'):
            with admin_connection() as c:
                cls.accounts[name] = c.execute('SELECT ap_m1.register_admin(%s,%s)',
                    (cls.f[name], name + '@synthetic.example.invalid')).fetchone()[0]
        # Synthetic privileged setup: no API can activate accounts or grant roles.
        with admin_connection() as c:
            c.execute("UPDATE ap_m1.admin_accounts SET state='ACTIVE' WHERE id=%s", (cls.accounts['b'],))
            for role in ('SUPPORT_AGENT', 'FAQ_EDITOR'):
                c.execute('INSERT INTO ap_m1.admin_role_grants(admin_id,role_code,granted_by) '
                          'VALUES(%s,%s,%s) ON CONFLICT(admin_id,role_code) WHERE revoked_at IS NULL DO NOTHING', (cls.accounts['b'], role, cls.accounts['c']))
        for name in ('a', 'b', 'c'):
            with admin_connection() as c:
                cls.tokens[name] = c.execute("SELECT ap_m1.mint_admin_session(%s,now()+interval '30 minutes',"
                    "now()+interval '10 minutes')", (cls.accounts[name],)).fetchone()[0]
        with admin_connection() as c:
            cls.no_mfa = c.execute("SELECT ap_m1.mint_admin_session(%s,now()+interval '30 minutes')",
                                  (cls.accounts['c'],)).fetchone()[0]

    @classmethod
    def tearDownClass(cls):
        with admin_connection() as c:
            ids = list(cls.accounts.values())
            c.execute('DELETE FROM ap_m1.admin_sessions WHERE admin_id=ANY(%s)', (ids,))
            c.execute('DELETE FROM ap_m1.admin_role_grants WHERE admin_id=ANY(%s)', (ids,))
            c.execute('DELETE FROM ap_m1.admin_accounts WHERE id=ANY(%s)', (ids,))
            c.execute("DELETE FROM ap_m1.owner_identity_allowlist WHERE issuer='https://synthetic.example.invalid' AND subject=%s",
                      ('fixture-' + str(cls.f['c']),))

    def setUp(self):
        self.c = runtime_connection()
        self.addCleanup(self.c.close)
        self.addCleanup(self.c.rollback)

    def admin_actor(self, name, token=None):
        self.c.execute("SELECT set_config('ap.session_token','',true),set_config('ap.admin_session_token',%s,true)",
                       (token or self.tokens[name],))

    def parent(self, name):
        self.c.execute("SELECT set_config('ap.admin_session_token','',true)")
        as_parent(self.c, self.f[name], self.f['family_a' if name == 'a' else 'family_b'])

    def denied(self, sql, params=()):
        with self.assertRaises(psycopg.errors.InsufficientPrivilege):
            with self.c.transaction():
                self.c.execute(sql, params).fetchall()

    def test_16_ordinary_admin_has_no_raw_child_access(self):
        self.admin_actor('b')
        self.assertTrue(self.c.execute("SELECT ap_m1.has_admin_permission('SUPPORT_READ')").fetchone()[0])
        for table in ('children', 'devices', 'location_observations', 'app_usage_intervals', 'media_sessions'):
            try:
                with self.c.transaction():
                    count = self.c.execute('SELECT count(*) FROM ap_m1.' + table).fetchone()[0]
                self.assertEqual(count, 0, table)
            except psycopg.errors.InsufficientPrivilege:
                pass  # ACL deny is stronger than an empty forced-RLS projection.
        self.denied("INSERT INTO ap_m1.owner_identity_allowlist VALUES('https://attacker.invalid','self',now())")
        self.denied("SELECT ap_m1.mint_admin_session(%s,now()+interval '1 hour')", (self.accounts['b'],))

    def test_17_parent_ticket_isolation_and_idempotent_replies(self):
        self.parent('a')
        tid = self.c.execute("SELECT ap_m1.create_support_ticket('Synthetic support question')").fetchone()[0]
        key = uuid4()
        mid = self.c.execute('SELECT ap_m1.support_reply(%s,%s,%s)', (tid, 'Plain text only', key)).fetchone()[0]
        self.assertEqual(self.c.execute('SELECT ap_m1.support_reply(%s,%s,%s)', (tid, 'Plain text only', key)).fetchone()[0], mid)
        self.parent('b')
        self.assertEqual(self.c.execute('SELECT count(*) FROM ap_m1.support_tickets WHERE id=%s', (tid,)).fetchone()[0], 0)
        self.assertEqual(self.c.execute('SELECT count(*) FROM ap_m1.support_messages WHERE ticket_id=%s', (tid,)).fetchone()[0], 0)
        self.denied('SELECT ap_m1.support_reply(%s,%s,%s)', (tid, 'Intrusion', uuid4()))
        self.admin_actor('b')
        self.denied('SELECT * FROM ap_m1.read_support_messages(%s)', (tid,))
        self.admin_actor('c')
        self.c.execute('SELECT ap_m1.update_support_ticket(%s,1,%s,%s,%s)',
                       (tid, 'IN_PROGRESS', self.accounts['b'], 'NORMAL'))
        self.admin_actor('b')
        self.assertEqual(self.c.execute('SELECT body FROM ap_m1.read_support_messages(%s)', (tid,)).fetchall(), [('Plain text only',)])

    def test_18_role_revoke_denies_existing_session(self):
        self.admin_actor('c')
        # Grant ID is hidden from runtime; owner selects it through an owner-only
        # audited API in production. Synthetic fixture obtains the exact seeded ID.
        with admin_connection() as c:
            gid = c.execute("SELECT id FROM ap_m1.admin_role_grants WHERE admin_id=%s AND role_code='SUPPORT_AGENT' AND revoked_at IS NULL",
                            (self.accounts['b'],)).fetchone()[0]
        self.c.execute('SELECT ap_m1.revoke_admin_grant(%s)', (gid,))
        self.admin_actor('b')
        self.assertFalse(self.c.execute("SELECT ap_m1.has_admin_permission('SUPPORT_READ')").fetchone()[0])
        self.assertIsNone(self.c.execute('SELECT ap_m1.ctx_admin()').fetchone()[0])

    def test_19_withdrawal_revokes_access_and_existing_device_token(self):
        device_token = None
        with auth_connection() as issuer:
            device_token = issuer.execute("SELECT ap_m1.mint_session(NULL,NULL,%s,interval '1 hour')",
                                          (self.f['device_a'],)).fetchone()[0]
        self.parent('a')
        self.assertTrue(self.c.execute("SELECT ap_m1.has_child_scope_v2(%s,'VIEW_LOCATION')", (self.f['child_a'],)).fetchone()[0])
        key = uuid4()
        self.c.execute('SELECT ap_m1.withdraw_consent(%s,%s)', (self.f['consent_a'], key))
        self.c.execute('SELECT ap_m1.withdraw_consent(%s,%s)', (self.f['consent_a'], key))
        self.assertFalse(self.c.execute("SELECT ap_m1.has_child_scope_v2(%s,'VIEW_LOCATION')", (self.f['child_a'],)).fetchone()[0])
        self.c.execute("SELECT set_config('ap.session_token',%s,true)", (device_token,))
        self.denied('SELECT ap_m1.ingest_location_batch(%s,%s,%s::jsonb)', (self.f['device_a'], uuid4(), '[]'))
        self.assertFalse(self.c.execute('SELECT ap_m1.owns_active_device(%s)', (self.f['device_a'],)).fetchone()[0])

    def test_20_primary_erasure_idempotent_and_late_upload_denied(self):
        with auth_connection() as issuer:
            token = issuer.execute("SELECT ap_m1.mint_session(NULL,NULL,%s,interval '1 hour')", (self.f['device_a'],)).fetchone()[0]
        self.parent('a')
        key = uuid4()
        rid = self.c.execute('SELECT ap_m1.request_child_erasure(%s,%s)', (self.f['child_a'], key)).fetchone()[0]
        self.assertEqual(self.c.execute('SELECT ap_m1.request_child_erasure(%s,%s)', (self.f['child_a'], key)).fetchone()[0], rid)
        self.assertEqual(self.c.execute('SELECT state FROM ap_m1.account_deletion_requests WHERE id=%s', (rid,)).fetchone()[0], 'PRIMARY_ERASED')
        self.assertEqual(self.c.execute('SELECT count(*) FROM ap_m1.children WHERE id=%s', (self.f['child_a'],)).fetchone()[0], 0)
        self.c.execute("SELECT set_config('ap.session_token',%s,true)", (token,))
        self.denied('SELECT ap_m1.ingest_location_batch(%s,%s,%s::jsonb)', (self.f['device_a'], uuid4(), '[]'))

    def test_21_restore_suppression_reapplies_durable_tombstone(self):
        # Privileged restore loader simulates stale identity data in quarantine.
        # Nothing is committed; suppression is an actual SECURITY DEFINER SQL call.
        with admin_connection() as c:
            try:
                backup = c.execute('INSERT INTO ap_m1.backup_inventory(backup_ref,completed_at) VALUES(%s,now()) RETURNING id', (uuid4(),)).fetchone()[0]
                restore = c.execute('INSERT INTO ap_m1.restore_runs(backup_id) VALUES(%s) RETURNING id', (backup,)).fetchone()[0]
                event = uuid4()
                c.execute("INSERT INTO ap_m1.location_event_dedup(child_id,device_id,event_id,sequence,payload_digest) "
                          "VALUES(%s,%s,%s,9223372036854775000,decode(repeat('00',32),'hex'))",
                          (self.f['child_a'],self.f['device_a'],event))
                c.execute("INSERT INTO ap_m1.location_observations(child_id,device_id,event_id,sequence,observed_at,latitude,longitude,position,accuracy_m,provider,quality) "
                          "VALUES(%s,%s,%s,9223372036854775000,now(),0,0,public.ST_SetSRID(public.ST_MakePoint(0,0),4326)::public.geography,5,'SYNTHETIC','QUALIFIED')",
                          (self.f['child_a'],self.f['device_a'],event))
                c.execute("INSERT INTO ap_m1.child_erasure_tombstones(child_id,reason_code) VALUES(%s,'SYNTHETIC_RESTORE')", (self.f['child_a'],))
                self.assertFalse(c.execute('SELECT ap_m1.restore_can_open(%s)', (restore,)).fetchone()[0])
                c.execute("SELECT ap_m1.import_restore_ledger(%s,public.digest('LOCAL_SYNTHETIC_LEDGER','sha256'))", (restore,))
                self.assertGreaterEqual(c.execute('SELECT ap_m1.suppress_restore(%s)', (restore,)).fetchone()[0], 1)
                self.assertTrue(c.execute('SELECT ap_m1.restore_can_open(%s)', (restore,)).fetchone()[0])
                self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.location_observations WHERE child_id=%s', (self.f['child_a'],)).fetchone()[0], 0)
                self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.location_event_dedup WHERE child_id=%s', (self.f['child_a'],)).fetchone()[0], 0)
                self.assertEqual(c.execute('SELECT alias,state,deleted_at IS NOT NULL FROM ap_m1.children WHERE id=%s',
                                          (self.f['child_a'],)).fetchone(), ('Deleted child', 'SUSPENDED', True))
            finally:
                c.rollback()
        self.denied('SELECT ap_m1.suppress_restore(%s)', (uuid4(),))

    def test_22_faq_immutable_revisions_cas_and_public_pointer(self):
        self.admin_actor('b')
        fid = uuid4()
        old = self.c.execute('SELECT ap_m1.faq_draft(%s,%s,%s,%s,%s,0)',
                             (fid, 'synthetic-' + fid.hex, 'setup', 'Synthetic FAQ', 'A safe answer')).fetchone()[0]
        self.c.execute("SELECT ap_m1.faq_transition(%s,%s,1,'PUBLISHED')", (fid, old))
        new = self.c.execute('SELECT ap_m1.faq_draft(%s,%s,%s,%s,%s,2)',
                             (fid, 'synthetic-' + fid.hex, 'setup', 'New draft', 'Not public yet')).fetchone()[0]
        with self.assertRaises(psycopg.errors.SerializationFailure):
            with self.c.transaction():
                self.c.execute('SELECT ap_m1.faq_draft(%s,%s,%s,%s,%s,2)',
                               (fid, 'synthetic-' + fid.hex, 'setup', 'Stale draft', 'conflict'))
        self.denied('UPDATE ap_m1.faq_revisions SET safe_body=%s WHERE id=%s', ('tampered', old))
        self.c.execute("SELECT set_config('ap.admin_session_token','',true)")
        self.assertEqual(self.c.execute('SELECT id FROM ap_m1.faq_revisions WHERE faq_id=%s', (fid,)).fetchall(), [(old,)])
        self.assertNotEqual(old, new)

    def test_23_no_default_retention_no_export_and_metadata_only_views(self):
        self.parent('a')
        self.denied('SELECT ap_m1.request_child_export(%s,%s)', (self.f['child_a'], uuid4()))
        self.admin_actor('b')
        self.assertEqual(self.c.execute('SELECT count(*) FROM ap_m1.admin_subscription_support').fetchone()[0], 0)
        for table in ('parent_service_usage_events', 'admin_subscription_support', 'admin_billing_reconciliation'):
            with admin_connection() as c:
                cols = {r[0] for r in c.execute('SELECT column_name FROM information_schema.columns WHERE table_schema=%s AND table_name=%s', ('ap_m1', table))}
            self.assertTrue(cols)
            self.assertFalse(cols & {'latitude', 'longitude', 'position', 'token_sha256', 'delivery_ref_encrypted', 'alias', 'child_id'})

    def test_owner_requires_mfa_and_no_access_session_does_not_upgrade(self):
        self.admin_actor('c', self.no_mfa)
        self.assertFalse(self.c.execute("SELECT ap_m1.has_admin_permission('OWNER_MANAGE')").fetchone()[0])
        self.admin_actor('a')
        self.assertFalse(self.c.execute("SELECT ap_m1.has_admin_permission('SUPPORT_READ')").fetchone()[0])
        self.c.execute("SELECT ap_m1.save_admin_profile('Synthetic applicant','a@synthetic.example.invalid','synthetic-v1',0)")
        rid = self.c.execute('SELECT ap_m1.submit_admin_request(1)').fetchone()[0]
        self.assertEqual(self.c.execute('SELECT ap_m1.submit_admin_request(1)').fetchone()[0], rid)
        self.denied('SELECT ap_m1.decide_admin_request(%s,1,true,%s,%s)', (rid, ['SUPPORT_AGENT'], 'self approval'))
        self.admin_actor('c')
        self.c.execute('SELECT ap_m1.decide_admin_request(%s,1,true,%s,%s)', (rid, ['SUPPORT_AGENT'], 'Synthetic approval'))
        self.admin_actor('a')
        self.assertIsNone(self.c.execute('SELECT ap_m1.ctx_admin()').fetchone()[0])

    def test_withdrawal_revokes_paid_viewer_without_changing_billing(self):
        with admin_connection() as c:
            try:
                as_parent(c, self.f['a'], self.f['family_a'])
                intent = c.execute("SELECT ap_m1.create_checkout(%s,'local_prepaid_month',%s::uuid[])",
                                   (self.f['family_a'],[self.f['child_a']])).fetchone()[0]
                c.execute("SELECT ap_m1.record_local_verified_purchase(%s,public.digest(%s,'sha256'),"
                          "public.digest('SYNTHETIC_PRIVACY_TEST','sha256'),'LOCAL_SYNTHETIC',now()-interval '1 minute')",
                          (intent,str(uuid4())))
                # This test starts with an already-active prepaid fixture, not a
                # just-purchased-in-this-transaction billing activation test.
                c.execute("UPDATE ap_m1.child_paid_entitlements e SET valid_from=now()-interval '1 minute' "
                          "FROM ap_m1.child_seat_assignments s JOIN ap_m1.prepaid_family_batches b ON b.id=s.batch_id "
                          "JOIN ap_m1.play_purchase_records p ON p.id=b.purchase_id "
                          "WHERE e.assignment_id=s.id AND p.checkout_intent_id=%s", (intent,))
                session = uuid4()
                lease = c.execute("SELECT ap_m1.acquire_viewer_lease(%s,%s,'PREMIUM_MAP')",
                                  (self.f['child_a'],session)).fetchone()[0]
                self.assertTrue(c.execute('SELECT ap_m1.has_paid_access(%s)', (self.f['child_a'],)).fetchone()[0])
                c.execute('SELECT ap_m1.withdraw_consent(%s,%s)', (self.f['consent_a'],uuid4()))
                self.assertTrue(c.execute('SELECT ap_m1.has_paid_access(%s)', (self.f['child_a'],)).fetchone()[0])
                self.assertFalse(c.execute("SELECT ap_m1.has_child_scope_v2(%s,'VIEW_HISTORY')", (self.f['child_a'],)).fetchone()[0])
                self.assertTrue(c.execute('SELECT revoked_at IS NOT NULL FROM ap_m1.premium_viewer_leases WHERE id=%s', (lease,)).fetchone()[0])
                with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                    with c.transaction():
                        c.execute('SELECT ap_m1.heartbeat_viewer_lease(%s,%s)', (lease,session))
            finally:
                c.rollback()

    def test_audit_retention_is_disabled_without_policy(self):
        with admin_connection() as c:
            try:
                marker = c.execute("INSERT INTO ap_m1.admin_action_audit(action,outcome,occurred_at) "
                                   "VALUES('SYNTHETIC_OLD_AUDIT','SUCCESS',now()-interval '100 years') RETURNING id").fetchone()[0]
                c.execute('SELECT ap_m1.purge_expired_privacy_audit()')
                self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.admin_action_audit WHERE id=%s', (marker,)).fetchone()[0], 1)
                self.assertIsNone(c.execute("SELECT ap_m1.retention_deadline('SYNTHETIC_UNAPPROVED',now())").fetchone()[0])
                with self.assertRaises(psycopg.errors.CheckViolation):
                    with c.transaction():
                        c.execute("INSERT INTO ap_m1.retention_policy_versions(category,version,state,clock_basis,purpose,deletion_method) "
                                  "VALUES('SYNTHETIC_UNAPPROVED','test','APPROVED','CREATED_AT','synthetic','purge')")
            finally:
                c.rollback()
        self.denied('SELECT ap_m1.purge_expired_privacy_audit()')

    def test_forced_rls_and_no_public_definers(self):
        with admin_connection() as c:
            names = ['consent_policy_versions','consent_documents','retention_policy_versions','admin_accounts',
                     'admin_sessions','admin_action_audit','faq_entries','faq_revisions','support_tickets','support_messages',
                     'account_deletion_requests','erasure_jobs','erasure_evidence','backup_erasure_manifests','restore_runs','export_jobs']
            rows = c.execute('SELECT relname,relrowsecurity,relforcerowsecurity FROM pg_class '
                             "WHERE relnamespace='ap_m1'::regnamespace AND relname=ANY(%s)", (names,)).fetchall()
            self.assertEqual(len(rows), len(names))
            self.assertTrue(all(r[1] and r[2] for r in rows))
            bad = c.execute("SELECT proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
                            "CROSS JOIN LATERAL aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a "
                            "WHERE n.nspname='ap_m1' AND p.prosecdef AND a.grantee=0 AND a.privilege_type='EXECUTE'").fetchall()
            self.assertEqual(bad, [])
        self.assertEqual(self.c.execute('SELECT rolsuper,rolbypassrls FROM pg_roles WHERE rolname=current_user').fetchone(), (False, False))


if __name__ == '__main__':
    unittest.main()
