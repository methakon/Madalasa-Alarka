"""Synthetic SQL regressions for 0028; run before/after coordinator-owned replay.

Uses existing guarded fixtures and real restricted runtime login for requests.
Restore loading/ledger attestation use the privileged synthetic connection;
suppression itself executes as ap_privacy_worker. No migrations run here.
"""
import unittest
from uuid import uuid4

import psycopg
import fixtures


class ErasureDependencyOrderTests(unittest.TestCase):
    def setUp(self):
        old_namespace = fixtures.NS
        try:
            fixtures.NS = uuid4()
            self.f = fixtures.seed_core()
        finally:
            fixtures.NS = old_namespace
        self.admin = fixtures.admin_connection()
        self.addCleanup(self.admin.close)
        self.addCleanup(self.admin.rollback)
        self.accounts = [uuid4(), uuid4()]
        for account in self.accounts:
            principal = uuid4()
            self.admin.execute(
                "INSERT INTO ap_m1.parent_principals(id,oidc_issuer,oidc_subject) VALUES(%s,'https://synthetic.example.invalid',%s)",
                (principal, 'synthetic-erasure-' + str(principal)))
            self.admin.execute(
                'INSERT INTO ap_m1.admin_accounts(id,principal_id,verified_email) VALUES(%s,%s,%s)',
                (account, principal, str(account) + '@synthetic.example.invalid'))
        self.rows = {}
        self.extra_holds = []
        for child, family in [('child_a', 'family_a'), ('sibling_a', 'family_a'), ('child_b', 'family_b')]:
            self.rows[child] = self.seed_case_bundle(self.f[child], self.f[family])
        self.admin.execute(
            "UPDATE ap_m1.devices SET reported_manufacturer='Synthetic',reported_model='Fixture',"
            "reported_android_api=35,reported_app_version='synthetic-1' WHERE id=%s",
            (self.f['device_a'],))
        # seed_core inserts ACTIVE directly, whereas the production log trigger
        # fires only on activation UPDATE. Explicitly seed the valid audit row.
        self.seed_pairing_log()
        self.admin.commit()
        self.addCleanup(self.cleanup_blockers)

    def cleanup_blockers(self):
        # Negative fixtures must not poison later full-ledger restore sweeps.
        self.admin.rollback()
        for hold in self.extra_holds:
            self.admin.execute('DELETE FROM ap_m1.retention_holds WHERE id=%s', (hold,))
        self.admin.execute('DELETE FROM ap_m1.retention_holds WHERE subject_ref=%s', (self.rows['child_a'][1],))
        self.admin.execute('DELETE FROM ap_m1.compliance_export_bundles WHERE requested_by_admin=%s AND child_id IS NULL', (self.accounts[0],))
        self.admin.commit()

    def seed_case_bundle(self, child, family):
        case = self.admin.execute(
            "INSERT INTO ap_m1.admin_cases(child_id,assigned_admin_id,approver_id,purpose,reason_code,expires_at) "
            "VALUES(%s,%s,%s,'ERASURE_METADATA','SYNTHETIC_FIXTURE',now()+interval '1 hour') RETURNING id",
            (child, *self.accounts)).fetchone()[0]
        bundle = self.admin.execute(
            "INSERT INTO ap_m1.compliance_export_bundles(case_id,requested_by_admin,export_type,target_family_id,child_id,expires_at) "
            "VALUES(%s,%s,'DSAR',%s,%s,now()+interval '1 hour') RETURNING id",
            (case, self.accounts[0], family, child)).fetchone()[0]
        return case, bundle

    def seed_pairing_log(self):
        self.admin.execute(
            'INSERT INTO ap_m1.child_device_pairing_log(child_id,family_id,device_id,pairing_method,'
            'reported_manufacturer,reported_model,reported_android_api,reported_app_version,key_fingerprint_sha256) '
            'SELECT child_id,family_id,id,pairing_method,reported_manufacturer,reported_model,'
            'reported_android_api,reported_app_version,sha256(spki_public_key) FROM ap_m1.devices WHERE id=%s '
            'ON CONFLICT(device_id) DO NOTHING', (self.f['device_a'],))

    def request(self, conn, key):
        return conn.execute('SELECT ap_m1.request_child_erasure(%s,%s)',
                            (self.f['child_a'], key)).fetchone()[0]

    def assert_other_subjects_preserved(self):
        for child in ('sibling_a', 'child_b'):
            case, bundle = self.rows[child]
            self.assertEqual(self.admin.execute('SELECT child_id FROM ap_m1.admin_cases WHERE id=%s', (case,)).fetchone(), (self.f[child],))
            self.assertEqual(self.admin.execute('SELECT child_id FROM ap_m1.compliance_export_bundles WHERE id=%s', (bundle,)).fetchone(), (self.f[child],))
            self.assertEqual(self.admin.execute('SELECT alias,deleted_at FROM ap_m1.children WHERE id=%s', (self.f[child],)).fetchone(), ('synthetic ' + child, None))

    def assert_target_purged(self):
        for table in ('admin_cases', 'compliance_export_bundles', 'child_device_pairing_log'):
            self.assertEqual(self.admin.execute('SELECT count(*) FROM ap_m1.' + table + ' WHERE child_id=%s', (self.f['child_a'],)).fetchone()[0], 0)
        self.assertEqual(self.admin.execute(
            'SELECT reported_manufacturer,reported_model,reported_android_api,reported_app_version '
            'FROM ap_m1.devices WHERE id=%s', (self.f['device_a'],)).fetchone(), (None, None, None, None))
        self.assert_other_subjects_preserved()

    def test_request_orders_dependents_and_is_idempotent(self):
        with fixtures.runtime_connection() as runtime:
            fixtures.as_parent(runtime, self.f['a'], self.f['family_a'])
            key = uuid4()
            request = self.request(runtime, key)
            self.assertEqual(self.request(runtime, key), request)
        self.assert_target_purged()
        self.assertEqual(self.admin.execute('SELECT state FROM ap_m1.account_deletion_requests WHERE id=%s', (request,)).fetchone()[0], 'PRIMARY_ERASED')
        self.assertEqual(self.admin.execute("SELECT target_store,state FROM ap_m1.erasure_jobs WHERE request_id=%s AND target_store<>'PRIMARY' ORDER BY target_store", (request,)).fetchall(), [('BACKUP', 'BLOCKED_POLICY'), ('EXTERNAL_REFERENCE', 'BLOCKED_POLICY')])
        self.assertEqual(self.admin.execute('SELECT category,rows_removed FROM ap_m1.erasure_job_targets WHERE job_id IN (SELECT id FROM ap_m1.erasure_jobs WHERE request_id=%s) AND category IN (%s,%s) ORDER BY category', (request, 'admin_cases', 'compliance_export_bundles')).fetchall(), [('admin_cases', 1), ('compliance_export_bundles', 1)])

    def prepare_restore(self):
        # Insert tombstone BEFORE stale pairing history is replayed. INSERT-only
        # tombstone cleanup must not be mistaken for suppression on every replay.
        self.admin.execute("INSERT INTO ap_m1.child_erasure_tombstones(child_id,reason_code) VALUES(%s,'SYNTHETIC_RESTORE')", (self.f['child_a'],))
        self.seed_pairing_log()
        backup = self.admin.execute('INSERT INTO ap_m1.backup_inventory(backup_ref,completed_at) VALUES(%s,now()) RETURNING id', (uuid4(),)).fetchone()[0]
        restore = self.admin.execute('INSERT INTO ap_m1.restore_runs(backup_id) VALUES(%s) RETURNING id', (backup,)).fetchone()[0]
        self.admin.execute("SELECT ap_m1.import_restore_ledger(%s,public.digest('SYNTHETIC_0028','sha256'))", (restore,))
        return restore

    def suppress(self, restore):
        with self.admin.transaction():
            self.admin.execute('SET LOCAL ROLE ap_privacy_worker')
            result = self.admin.execute('SELECT ap_m1.suppress_restore(%s)', (restore,)).fetchone()[0]
            self.admin.execute('RESET ROLE')
        return result

    def test_restore_existing_tombstone_purges_dependents_and_replayed_pairing(self):
        restore = self.prepare_restore()
        self.assertGreaterEqual(self.suppress(restore), 1)
        self.assert_target_purged()
        self.assertTrue(self.admin.execute('SELECT ap_m1.restore_can_open(%s)', (restore,)).fetchone()[0])
        # Repeat with another stale log after first suppression; no new tombstone.
        self.seed_pairing_log()
        self.assertGreaterEqual(self.suppress(restore), 1)
        self.assert_target_purged()

    def seed_unresolved_bundle(self):
        return self.admin.execute(
            "INSERT INTO ap_m1.compliance_export_bundles(requested_by_admin,export_type,target_family_id,expires_at) "
            "VALUES(%s,'DSAR',%s,now()+interval '1 hour') RETURNING id",
            (self.accounts[0], self.f['family_a'])).fetchone()[0]

    def assert_no_request_certificate(self):
        self.assertEqual(self.admin.execute('SELECT count(*) FROM ap_m1.account_deletion_requests WHERE child_id=%s', (self.f['child_a'],)).fetchone()[0], 0)
        self.assert_other_subjects_preserved()
        self.assertIsNotNone(self.admin.execute('SELECT id FROM ap_m1.admin_cases WHERE id=%s', (self.rows['child_a'][0],)).fetchone())
        self.assertIsNotNone(self.admin.execute('SELECT id FROM ap_m1.compliance_export_bundles WHERE id=%s', (self.rows['child_a'][1],)).fetchone())

    def test_unresolved_family_bundle_fails_closed_without_deleting_siblings(self):
        bundle = self.seed_unresolved_bundle()
        self.admin.commit()
        with fixtures.runtime_connection() as runtime:
            fixtures.as_parent(runtime, self.f['a'], self.f['family_a'])
            with self.assertRaises(psycopg.errors.ObjectNotInPrerequisiteState):
                with runtime.transaction():
                    self.request(runtime, uuid4())
        self.assert_no_request_certificate()
        self.assertEqual(self.admin.execute('SELECT child_id FROM ap_m1.compliance_export_bundles WHERE id=%s', (bundle,)).fetchone(), (None,))

    def test_unresolved_family_bundle_cannot_certify_restore_ready(self):
        self.seed_unresolved_bundle()
        restore = self.prepare_restore()
        with self.assertRaises(psycopg.errors.ObjectNotInPrerequisiteState):
            self.suppress(restore)
        self.assertEqual(self.admin.execute('SELECT state FROM ap_m1.restore_runs WHERE id=%s', (restore,)).fetchone()[0], 'QUARANTINED')
        self.assertFalse(self.admin.execute('SELECT ap_m1.restore_can_open(%s)', (restore,)).fetchone()[0])
        self.assertEqual(self.admin.execute('SELECT count(*) FROM ap_m1.restore_suppression_receipts WHERE restore_id=%s', (restore,)).fetchone()[0], 0)
        self.assert_other_subjects_preserved()

    def test_cross_family_request_cannot_erase_target(self):
        with fixtures.runtime_connection() as runtime:
            fixtures.as_parent(runtime, self.f['b'], self.f['family_b'])
            with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                with runtime.transaction():
                    self.request(runtime, uuid4())
        self.assert_no_request_certificate()

    def test_runtime_cannot_call_private_purge_or_hold_lock(self):
        with fixtures.runtime_connection() as runtime:
            fixtures.as_parent(runtime, self.f['a'], self.f['family_a'])
            with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                with runtime.transaction():
                    runtime.execute('SELECT ap_m1._purge_child_data(%s)', (self.f['child_a'],))
            with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                with runtime.transaction():
                    runtime.execute('SELECT ap_m1._lock_erasure_holds()')

    def test_unreleased_hold_cannot_certify_restore_ready(self):
        self.admin.execute("INSERT INTO ap_m1.retention_holds(category,subject_ref,legal_reference,review_by) VALUES('compliance_export_bundles',%s,'SYNTHETIC_ONLY',now()+interval '1 hour')", (self.rows['child_a'][1],))
        restore = self.prepare_restore()
        with self.assertRaises(psycopg.errors.ObjectNotInPrerequisiteState):
            self.suppress(restore)
        self.assertEqual(self.admin.execute('SELECT state FROM ap_m1.restore_runs WHERE id=%s', (restore,)).fetchone()[0], 'QUARANTINED')
        self.assertFalse(self.admin.execute('SELECT ap_m1.restore_can_open(%s)', (restore,)).fetchone()[0])
        self.assertEqual(self.admin.execute('SELECT count(*) FROM ap_m1.restore_suppression_receipts WHERE restore_id=%s', (restore,)).fetchone()[0], 0)
        self.assert_no_request_certificate()

    def test_unreleased_subject_hold_blocks_without_certifying_or_purging(self):
        self.admin.execute("INSERT INTO ap_m1.retention_holds(category,subject_ref,legal_reference,review_by) VALUES('compliance_export_bundles',%s,'SYNTHETIC_ONLY',now()+interval '1 hour')", (self.rows['child_a'][1],))
        self.admin.commit()
        with fixtures.runtime_connection() as runtime:
            fixtures.as_parent(runtime, self.f['a'], self.f['family_a'])
            with self.assertRaises(psycopg.errors.ObjectNotInPrerequisiteState):
                with runtime.transaction():
                    self.request(runtime, uuid4())
        self.assert_no_request_certificate()

    def seed_inventory_subject_hold(self, category):
        if category == 'location_ingest_batches':
            subject = uuid4()
            self.admin.execute(
                "INSERT INTO ap_m1.location_ingest_batches(id,child_id,device_id,payload_digest,item_count,state,membership_complete) "
                "VALUES(%s,%s,%s,%s,1,'PROCESSED',true)",
                (subject, self.f['child_a'], self.f['device_a'], b'x' * 32))
        else:
            request = self.admin.execute(
                "INSERT INTO ap_m1.media_command_requests(child_id,device_id,adult_id,kind) "
                "VALUES(%s,%s,%s,'IMAGE') RETURNING id",
                (self.f['child_a'], self.f['device_a'], self.f['a'])).fetchone()[0]
            subject = self.admin.execute(
                "INSERT INTO ap_m1.media_sessions(request_id,child_id,authorized_adult_id,exit_reason) "
                "VALUES(%s,%s,%s,'OS_REJECTED') RETURNING id",
                (request, self.f['child_a'], self.f['a'])).fetchone()[0]
        hold = self.admin.execute(
            "INSERT INTO ap_m1.retention_holds(category,subject_ref,legal_reference,created_at,review_by) "
            "VALUES(%s,%s,'SYNTHETIC_ONLY',now()-interval '2 hours',now()-interval '1 hour') RETURNING id",
            (category, subject)).fetchone()[0]
        self.extra_holds.append(hold)
        self.admin.commit()
        return subject

    def assert_inventory_hold_blocks_request(self, category):
        subject = self.seed_inventory_subject_hold(category)
        with fixtures.runtime_connection() as runtime:
            fixtures.as_parent(runtime, self.f['a'], self.f['family_a'])
            with self.assertRaises(psycopg.errors.ObjectNotInPrerequisiteState):
                with runtime.transaction():
                    self.request(runtime, uuid4())
        self.assert_no_request_certificate()
        self.assertIsNotNone(self.admin.execute(
            'SELECT id FROM ap_m1.' + category + ' WHERE id=%s', (subject,)).fetchone())

    def assert_inventory_hold_blocks_restore(self, category):
        self.seed_inventory_subject_hold(category)
        restore = self.prepare_restore()
        with self.assertRaises(psycopg.errors.ObjectNotInPrerequisiteState):
            self.suppress(restore)
        self.assertFalse(self.admin.execute(
            'SELECT ap_m1.restore_can_open(%s)', (restore,)).fetchone()[0])
        self.assertEqual(self.admin.execute(
            'SELECT count(*) FROM ap_m1.restore_suppression_receipts WHERE restore_id=%s',
            (restore,)).fetchone()[0], 0)

    def test_batch_id_hold_blocks_request(self):
        self.assert_inventory_hold_blocks_request('location_ingest_batches')

    def test_batch_id_hold_blocks_restore(self):
        self.assert_inventory_hold_blocks_restore('location_ingest_batches')

    def test_media_session_id_hold_blocks_request(self):
        self.assert_inventory_hold_blocks_request('media_sessions')

    def test_media_session_id_hold_blocks_restore(self):
        self.assert_inventory_hold_blocks_restore('media_sessions')

    def test_hold_guard_covers_every_existing_inventory_relation(self):
        missing = self.admin.execute("""SELECT i.table_name
            FROM ap_m1.erasure_store_inventory i
            WHERE to_regclass('ap_m1.'||i.table_name) IS NOT NULL
            AND NOT EXISTS(SELECT 1 FROM pg_trigger t
                WHERE t.tgrelid=to_regclass('ap_m1.'||i.table_name)
                AND t.tgname='refuse_held_inventory_delete' AND t.tgenabled='O')""").fetchall()
        self.assertEqual(missing, [])

    def test_repeatable_read_cannot_miss_newly_committed_hold(self):
        subject = self.seed_inventory_subject_hold('location_ingest_batches')
        self.admin.execute('DELETE FROM ap_m1.retention_holds WHERE id=%s', (self.extra_holds[-1],))
        self.admin.commit()
        with fixtures.admin_connection() as stale:
            stale.execute('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ')
            stale.execute('SELECT count(*) FROM ap_m1.retention_holds').fetchone()
            # A distinct connection commits the hold after the delete transaction
            # fixed its snapshot, but before it acquires the hold-table lock.
            hold = self.admin.execute(
                "INSERT INTO ap_m1.retention_holds(category,subject_ref,legal_reference,review_by) "
                "VALUES('location_ingest_batches',%s,'SYNTHETIC_ONLY',now()+interval '1 hour') RETURNING id",
                (subject,)).fetchone()[0]
            self.extra_holds.append(hold)
            self.admin.commit()
            stale.execute('SET LOCAL ROLE ap_db_executor')
            with self.assertRaises(psycopg.errors.ObjectNotInPrerequisiteState):
                with stale.transaction():
                    stale.execute('DELETE FROM ap_m1.location_ingest_batches WHERE id=%s', (subject,))
            stale.rollback()
        self.assertIsNotNone(self.admin.execute(
            'SELECT id FROM ap_m1.location_ingest_batches WHERE id=%s', (subject,)).fetchone())

    def test_released_batch_hold_does_not_prevent_authorized_erasure(self):
        self.seed_inventory_subject_hold('location_ingest_batches')
        self.admin.execute('UPDATE ap_m1.retention_holds SET released_at=clock_timestamp() WHERE id=%s',
                           (self.extra_holds[-1],))
        self.admin.commit()
        with fixtures.runtime_connection() as runtime:
            fixtures.as_parent(runtime, self.f['a'], self.f['family_a'])
            self.request(runtime, uuid4())
        self.assert_target_purged()
