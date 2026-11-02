"""Retention-purge FK order and multi-child adult-erasure regression tests.

Two verified review findings on feat/local-postgresql-physical-schema:

1. 0005 ap_m1.purge_expired_location deletes location_event_dedup before the
    location_batch_items membership (0015) that references it, so any event
   still listed in an accepted batch raises 23503. A NEWER retained batch may
   legitimately contain an older event, so that event identity must survive
   while a retained reference exists.
2. 0014 request_account_erasure loops every GRANTED CORE consent with ONE
   shared request_id while consent_decision_audit is UNIQUE(actor_id,
   request_id), so an adult with CORE consent in two children aborts on the
   second consent with 23505.

The additive fix lives in .local-db/reconciliation-lifecycle.sql (two
CREATE OR REPLACE functions with identical signatures/owner/ACLs). These tests
are RED until that fragment is applied, then must be GREEN.

Synthetic data only: every identifier, device fingerprint, coordinate and
consent review below is invented for this disposable test database.
"""
import unittest
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import psycopg
from psycopg.types.json import Jsonb
try:
    from . import fixtures
except ImportError:
    import fixtures

def new_event(sequence, age_seconds=0):
    """Fresh synthetic location fix; aging is applied later via the admin role."""
    return dict(event_id=str(uuid4()), sequence=sequence,
                observed_at=(datetime.now(timezone.utc)-timedelta(seconds=age_seconds+2)).isoformat(),
                latitude=0.125, longitude=0.25, accuracy_m=12, provider='SYNTHETIC')


def location_domain():
    """Own child/device/policy: purge tests never mutate shared fixture children."""
    f = dict(fixtures.seed_core())
    f.update(child_a=uuid4(), device_a=uuid4(), review_a=uuid4(), consent_a=uuid4())
    with fixtures.admin_connection() as db:
        db.execute("insert into ap_m1.children(id,family_id,alias) values(%s,%s,'Synthetic retention child')",
                   (f['child_a'], f['family_a']))
        db.execute("insert into ap_m1.child_authority_reviews(id,child_id,adult_id,state,lawful_basis_version,"
                   "method_code,reviewed_at,expires_at) values(%s,%s,%s,'LOCAL_TEST_APPROVED','synthetic-v1',"
                   "'SYNTHETIC_FIXTURE',now(),now()+interval '1 day')", (f['review_a'], f['child_a'], f['a']))
        for purpose in ('CORE', 'LOCATION', 'USAGE', 'MEDIA'):
            cid = f['consent_a'] if purpose == 'CORE' else uuid4()
            db.execute("insert into ap_m1.consent_records(id,child_id,adult_id,purpose,status,authority_review_id,"
                       "notice_version,legal_state,expires_at) values(%s,%s,%s,%s,'GRANTED',%s,'synthetic-v1',"
                       "'LOCAL_TEST_APPROVED',now()+interval '1 day')", (cid, f['child_a'], f['a'], purpose, f['review_a']))
        db.execute("insert into ap_m1.child_access_grants_v2(child_id,adult_id,scope,consent_record_id,"
                   "authority_review_id,issued_by) select %s,adult_id,scope,%s,%s,issued_by from "
                   "ap_m1.child_access_grants_v2 where child_id=%s and adult_id=%s and revoked_at is null",
                   (f['child_a'], f['consent_a'], f['review_a'], fixtures.seed_core(db)['child_a'], f['a']))
        db.execute("insert into ap_m1.devices(id,family_id,child_id,spki_public_key,enrollment_state) "
                   "values(%s,%s,%s,%s,'ACTIVE')", (f['device_a'], f['family_a'], f['child_a'],
                                                     ('SYNTHETIC-NOT-CRYPTO-' + str(f['device_a'])).encode()*2))
        f['device_key_a'] = fixtures.seed_device_key(db, f['device_a'])
        # One hour of retention keeps the test cheap; aging is applied explicitly.
        db.execute("insert into ap_m1.location_collection_policies(child_id,enabled,retain_for,policy_reference) "
                   "values(%s,true,interval '1 hour','SYNTHETIC_FIXTURE_ONLY')", (f['child_a'],))
    return f


def cleanup_location(f):
    with fixtures.admin_connection() as db:
        for table in ('trip_routepoints', 'trip_revisions', 'trips', 'device_latest_positions',
                      'ingestion_outbox', 'location_observations', 'location_batch_items',
                      'location_event_dedup', 'location_ingest_batches'):
            db.execute('delete from ap_m1.' + table + ' where child_id=%s', (f['child_a'],))
        db.execute('delete from ap_m1.trusted_sessions where device_id=%s', (f['device_a'],))
        db.execute('delete from ap_m1.device_key_records where device_id=%s', (f['device_a'],))
        db.execute('delete from ap_m1.location_collection_policies where child_id=%s', (f['child_a'],))
        db.execute('delete from ap_m1.devices where id=%s', (f['device_a'],))
        db.execute('delete from ap_m1.child_access_grants_v2 where child_id=%s', (f['child_a'],))
        db.execute('delete from ap_m1.consent_records where child_id=%s', (f['child_a'],))
        db.execute('delete from ap_m1.child_authority_reviews where child_id=%s', (f['child_a'],))
        db.execute('delete from ap_m1.children where id=%s', (f['child_a'],))


def erasure_domain():
    """Private actor/family namespace plus a SECOND child for the same adult.

    seed_core() is re-seeded under a throwaway namespace (same pattern as
    test_account_erasure.py) so erasing actor ``a`` can never touch another
    test's household.
    """
    shared = fixtures.NS
    try:
        fixtures.NS = uuid4()
        f = dict(fixtures.seed_core())
    finally:
        fixtures.NS = shared
    f.update(child_second=uuid4(), review_second=uuid4(), consent_second=uuid4())
    with fixtures.admin_connection() as db:
        db.execute("insert into ap_m1.children(id,family_id,alias) values(%s,%s,'Synthetic second child')",
                   (f['child_second'], f['family_a']))
        db.execute("insert into ap_m1.child_authority_reviews(id,child_id,adult_id,state,lawful_basis_version,"
                   "method_code,reviewed_at,expires_at) values(%s,%s,%s,'LOCAL_TEST_APPROVED','synthetic-v1',"
                   "'SYNTHETIC_FIXTURE',now(),now()+interval '1 day')",
                   (f['review_second'], f['child_second'], f['a']))
        for purpose in ('CORE', 'LOCATION', 'USAGE', 'MEDIA'):
            cid = f['consent_second'] if purpose == 'CORE' else uuid4()
            db.execute("insert into ap_m1.consent_records(id,child_id,adult_id,purpose,status,authority_review_id,"
                       "notice_version,legal_state,expires_at) values(%s,%s,%s,%s,'GRANTED',%s,'synthetic-v1',"
                       "'LOCAL_TEST_APPROVED',now()+interval '1 day')",
                       (cid, f['child_second'], f['a'], purpose, f['review_second']))
        # Same live grants the adult already holds on the first child.
        db.execute("insert into ap_m1.child_access_grants_v2(child_id,adult_id,scope,consent_record_id,"
                   "authority_review_id,issued_by) select %s,adult_id,scope,%s,%s,issued_by from "
                   "ap_m1.child_access_grants_v2 where child_id=%s and adult_id=%s and revoked_at is null",
                   (f['child_second'], f['consent_second'], f['review_second'], f['child_a'], f['a']))
    return f


def cleanup_erasure(f):
    """Best-effort unwind of this run's private identifiers, in FK order.

    A cleanup problem must never disguise the regression result, so failures
    are reported instead of raised; every identifier here is a per-run UUID.
    """
    actor = f['a']
    families = (f['family_a'], f['family_b'])
    in_families = 'select id from ap_m1.children where family_id in (%s,%s)'
    statements = [
        ("delete from ap_m1.adult_erasure_jobs where request_id in "
         "(select id from ap_m1.adult_erasure_requests where principal_id=%s)", (actor,)),
        ("delete from ap_m1.adult_erasure_requests where principal_id=%s", (actor,)),
        ("delete from ap_m1.consent_decision_audit where actor_id=%s", (actor,)),
        ("delete from ap_m1.trusted_sessions where principal_id in (%s,%s,%s) or device_id=%s",
         (f['a'], f['b'], f['c'], f['device_a'])),
        ("delete from ap_m1.trusted_principal_verifications where principal_id in (%s,%s,%s)",
         (f['a'], f['b'], f['c'])),
        ("delete from ap_m1.child_access_grants_v2 where child_id in (" + in_families + ")", families),
        ("delete from ap_m1.consent_records where child_id in (" + in_families + ")", families),
        ("delete from ap_m1.child_authority_reviews where child_id in (" + in_families + ")", families),
        ("delete from ap_m1.device_key_records where device_id=%s", (f['device_a'],)),
        ("delete from ap_m1.devices where id=%s", (f['device_a'],)),
        ("delete from ap_m1.guardian_memberships where principal_id in (%s,%s)", (f['a'], f['b'])),
        ("delete from ap_m1.children where family_id in (%s,%s)", families),
        ("delete from ap_m1.families where id in (%s,%s)", families),
        ("delete from ap_m1.parent_principals where id in (%s,%s,%s)", (f['a'], f['b'], f['c'])),
    ]
    try:
        with fixtures.admin_connection() as db:
            for statement, params in statements:
                db.execute(statement, params)
    except psycopg.Error as exc:
        print('cleanup_erasure left private synthetic rows behind (safe, run-unique): '
              + str(exc.sqlstate))


class RetentionPurgeTests(unittest.TestCase):
    """purge_expired_location must honour FK order and retained references."""

    def setUp(self):
        self.f = location_domain()
        self.addCleanup(cleanup_location, self.f)
        self.child = self.f['child_a']
        self.device = self.f['device_a']
        self.db = fixtures.runtime_connection()
        self.addCleanup(self.db.close)
        self.addCleanup(self.db.rollback)
        self.admin = fixtures.admin_connection()
        self.addCleanup(self.admin.close)
        self.addCleanup(self.admin.rollback)

    def ingest(self, events, batch):
        fixtures.as_parent(self.db, None, None, self.device)
        return self.db.execute('select ap_m1.ingest_location_batch(%s,%s,%s)',
                               (self.device, batch, Jsonb(events))).fetchone()[0]

    def age(self, *, events, batches, days=3):
        """Synthetic aging: mutate accepted timestamps instead of waiting."""
        shift = "interval '%d days'" % days
        for event in events:
            self.admin.execute("update ap_m1.location_event_dedup set first_seen_at=first_seen_at-" + shift +
                               " where child_id=%s and event_id=%s", (self.child, event))
            self.admin.execute("update ap_m1.location_observations set observed_at=observed_at-" + shift +
                               ",received_at=received_at-" + shift + " where child_id=%s and event_id=%s",
                               (self.child, event))
        for batch in batches:
            self.admin.execute("update ap_m1.location_ingest_batches set accepted_at=accepted_at-" + shift +
                               " where id=%s", (batch,))
        self.admin.commit()

    def purge(self):
        try:
            return self.admin.execute('select ap_m1.purge_expired_location(%s)', (self.child,)).fetchone()[0]
        except psycopg.errors.ForeignKeyViolation as exc:
            self.fail('purge_expired_location deleted an event identity that accepted batch membership '
                      'still references (finding 1): ' + str(exc.diag.message_primary))

    def event_rows(self, event_id, table):
        return self.admin.execute('select count(*) from ap_m1.' + table +
                                  ' where child_id=%s and event_id=%s', (self.child, event_id)).fetchone()[0]

    def batch_exists(self, batch):
        return self.admin.execute('select count(*) from ap_m1.location_ingest_batches where id=%s and child_id=%s',
                                  (batch, self.child)).fetchone()[0]

    def test_shared_event_in_retained_newer_batch_survives_expired_purge(self):
        # Same event accepted in an old batch and again in a NEWER retained batch:
        # the replay records exact membership in both batches but only one
        # observation, so the event identity must outlive the old batch.
        event = new_event(7000001)
        old_batch, new_batch = uuid4(), uuid4()
        self.ingest([event], old_batch)
        self.ingest([event], new_batch)
        self.db.commit()
        self.age(events=[event['event_id']], batches=[old_batch])

        self.assertEqual(1, self.purge())
        self.assertEqual(0, self.event_rows(event['event_id'], 'location_observations'))
        self.assertEqual(1, self.event_rows(event['event_id'], 'location_event_dedup'),
                         'expired event identity is still referenced by retained batch membership')
        self.assertEqual(0, self.batch_exists(old_batch))
        self.assertEqual(0, self.admin.execute('select count(*) from ap_m1.location_batch_items where batch_id=%s',
                                               (old_batch,)).fetchone()[0])
        self.assertEqual(1, self.batch_exists(new_batch))
        self.assertTrue(self.admin.execute('select membership_complete from ap_m1.location_ingest_batches '
                                          'where id=%s', (new_batch,)).fetchone()[0])
        self.assertEqual(1, self.admin.execute('select count(*) from ap_m1.location_batch_items where batch_id=%s',
                                               (new_batch,)).fetchone()[0])
        # No membership row may ever outlive its event identity.
        self.assertEqual(0, self.admin.execute(
            'select count(*) from ap_m1.location_batch_items i left join ap_m1.location_event_dedup d '
            'on (d.child_id,d.device_id,d.event_id)=(i.child_id,i.device_id,i.event_id) '
            'where i.child_id=%s and d.event_id is null', (self.child,)).fetchone()[0])
        # The expired batch's queued work left with it; the retained one did not.
        self.assertEqual(0, self.admin.execute('select count(*) from ap_m1.ingestion_outbox where batch_id=%s',
                                               (old_batch,)).fetchone()[0])
        self.assertEqual(1, self.admin.execute('select count(*) from ap_m1.ingestion_outbox where batch_id=%s',
                                               (new_batch,)).fetchone()[0])

        # Once the newer batch expires too, the retained identity goes with it:
        # nothing is retained forever.
        self.age(events=[], batches=[new_batch])
        self.assertEqual(0, self.purge())
        self.assertEqual(0, self.event_rows(event['event_id'], 'location_event_dedup'))
        self.assertEqual(0, self.batch_exists(new_batch))

    def test_expired_batch_membership_event_purged_and_recent_rows_retained(self):
        aged, recent = new_event(7000101), new_event(7000102)
        aged_batch, recent_batch = uuid4(), uuid4()
        self.ingest([aged], aged_batch)
        self.ingest([recent], recent_batch)
        self.db.commit()
        self.age(events=[aged['event_id']], batches=[aged_batch])

        self.assertEqual(1, self.purge())
        self.assertEqual(0, self.event_rows(aged['event_id'], 'location_observations'))
        self.assertEqual(0, self.event_rows(aged['event_id'], 'location_event_dedup'))
        self.assertEqual(0, self.batch_exists(aged_batch))
        # Recent evidence inside retention is untouched.
        self.assertEqual(1, self.event_rows(recent['event_id'], 'location_event_dedup'))
        self.assertEqual(1, self.event_rows(recent['event_id'], 'location_observations'))
        self.assertEqual(1, self.batch_exists(recent_batch))
        self.assertEqual(1, self.admin.execute('select count(*) from ap_m1.location_batch_items where batch_id=%s',
                                               (recent_batch,)).fetchone()[0])
        self.assertEqual(1, self.admin.execute('select count(*) from ap_m1.device_latest_positions '
                                               'where device_id=%s and event_id=%s',
                                               (self.device, recent['event_id'])).fetchone()[0])
        # A second purge with nothing expired is a no-op, not an error.
        self.assertEqual(0, self.purge())


class AdultErasureLifecycleTests(unittest.TestCase):
    """One erasure request must withdraw CORE consent in every child exactly once."""

    def setUp(self):
        self.f = erasure_domain()
        self.addCleanup(cleanup_erasure, self.f)
        self.admin = fixtures.admin_connection()
        self.addCleanup(self.admin.close)
        self.addCleanup(self.admin.rollback)

    def test_multi_child_core_consent_erasure_completes(self):
        f, request_key = self.f, uuid4()
        with fixtures.runtime_connection() as runtime:
            fixtures.as_parent(runtime, f['a'], f['family_a'])
            try:
                request_id = runtime.execute('select ap_m1.request_account_erasure(%s)',
                                             (request_key,)).fetchone()[0]
            except psycopg.errors.UniqueViolation as exc:
                self.fail('one erasure request reused a single request_id for every CORE consent '
                          '(consent_decision_audit_actor_id_request_id_key, finding 2): '
                          + str(exc.diag.message_primary))
        self.assertIsNotNone(request_id)

        consents = self.admin.execute(
            "select child_id,status,withdrawn_at from ap_m1.consent_records "
            "where adult_id=%s and purpose='CORE' order by child_id", (f['a'],)).fetchall()
        self.assertEqual(2, len(consents), 'fixture must hold CORE consent in exactly two children')
        for child_id, status, withdrawn_at in consents:
            self.assertEqual('WITHDRAWN', status, child_id)
            self.assertIsNotNone(withdrawn_at, child_id)

        audit = self.admin.execute(
            "select consent_id,request_id,action from ap_m1.consent_decision_audit where actor_id=%s",
            (f['a'],)).fetchall()
        self.assertEqual(2, len(audit), 'one withdrawal audit row per withdrawn CORE consent')
        self.assertEqual({'WITHDRAWN'}, {row[2] for row in audit})
        audited_keys = {row[1] for row in audit}
        self.assertEqual(2, len(audited_keys), 'per-consent audit keys must be distinct')
        self.assertNotIn(request_key, audited_keys)
        # Deterministic derivation: the same request produces the same keys, so a
        # replay cannot insert a second conflicting audit row for a consent.
        expected = set()
        for consent_id, _, _ in audit:
            expected.add(self.admin.execute("select md5(%s||':consent-withdrawal:'||%s::text)::uuid",
                                            (str(request_key), str(consent_id))).fetchone()[0])
        self.assertEqual(expected, audited_keys)

        request = self.admin.execute(
            'select state,request_key,primary_minimized_at from ap_m1.adult_erasure_requests '
            'where id=%s and principal_id=%s', (request_id, f['a'])).fetchone()
        self.assertEqual(('BLOCKED_POLICY', request_key), request[0:2])
        self.assertIsNotNone(request[2])

        self.assertEqual(('https://erased.example.invalid', 'erased:' + str(f['a'])),
                         self.admin.execute('select oidc_issuer,oidc_subject from ap_m1.parent_principals '
                                            'where id=%s', (f['a'],)).fetchone())
        self.assertEqual(0, self.admin.execute(
            'select count(*) from ap_m1.trusted_sessions where principal_id=%s and revoked_at is null',
            (f['a'],)).fetchone()[0])
        self.assertEqual(0, self.admin.execute(
            'select count(*) from ap_m1.child_access_grants_v2 where adult_id=%s and revoked_at is null',
            (f['a'],)).fetchone()[0])
        self.assertGreaterEqual(self.admin.execute(
            'select count(*) from ap_m1.child_access_grants_v2 where adult_id=%s', (f['a'],)).fetchone()[0], 1)
        self.assertEqual(0, self.admin.execute(
            'select count(*) from ap_m1.guardian_memberships where principal_id=%s and revoked_at is null',
            (f['a'],)).fetchone()[0])
        jobs = self.admin.execute('select category,state from ap_m1.adult_erasure_jobs where request_id=%s',
                                  (request_id,)).fetchall()
        self.assertEqual({'FINANCIAL', 'SUPPORT', 'SECURITY_AUDIT', 'BACKUPS', 'CHILD_AUTHORITY'},
                         {row[0] for row in jobs})
        self.assertEqual({'BLOCKED_POLICY'}, {row[1] for row in jobs})

    def test_same_request_key_withdrawal_replay_keeps_one_audit_row(self):
        f, request_key = self.f, uuid4()
        with fixtures.runtime_connection() as runtime:
            fixtures.as_parent(runtime, f['a'], f['family_a'])
            # Same derived key twice: the second call must be an idempotent no-op.
            for _ in range(2):
                runtime.execute('select ap_m1.withdraw_consent(%s,%s)', (f['consent_a'], request_key))
        self.assertEqual('WITHDRAWN', self.admin.execute(
            'select status from ap_m1.consent_records where id=%s', (f['consent_a'],)).fetchone()[0])
        self.assertEqual(1, self.admin.execute(
            'select count(*) from ap_m1.consent_decision_audit where consent_id=%s and actor_id=%s',
            (f['consent_a'], f['a'])).fetchone()[0])


class ReconciliationFunctionContractTests(unittest.TestCase):
    """The additive fragment must not alter signatures, owner, search_path or ACLs."""

    def contract(self, name):
        with fixtures.admin_connection() as admin:
            self.assertIsNotNone(admin.execute('select to_regprocedure(%s)', ('ap_m1.' + name,)).fetchone()[0],
                                 name + ' must exist')
            return admin.execute(
                "select pg_get_function_identity_arguments(p.oid),p.prosecdef,r.rolname,p.proconfig,"
                "coalesce((select bool_or(a.grantee=0 and a.privilege_type='EXECUTE') "
                " from aclexplode(p.proacl) a),false),"
                "coalesce((select bool_or(g.rolname='ap_m1_api' and a.privilege_type='EXECUTE') "
                " from aclexplode(p.proacl) a join pg_roles g on g.oid=a.grantee),false) "
                "from pg_proc p join pg_roles r on r.oid=p.proowner "
                "where p.oid='ap_m1." + name + "'::regprocedure").fetchone()

    def test_purge_and_erasure_contract_preserved(self):
        arguments, secdef, owner, config, public_execute, api_execute = self.contract('purge_expired_location(uuid)')
        self.assertEqual('c uuid', arguments)
        self.assertTrue(secdef)
        self.assertEqual('ap_db_executor', owner)
        self.assertIn('search_path=pg_catalog, ap_m1, public', config)
        self.assertFalse(public_execute)
        self.assertFalse(api_execute, 'retention purge stays internal to worker/migration roles')

        arguments, secdef, owner, config, public_execute, api_execute = self.contract(
            'request_account_erasure(uuid)')
        self.assertEqual('request_key uuid', arguments)
        self.assertTrue(secdef)
        self.assertEqual('ap_db_executor', owner)
        self.assertIn('search_path=pg_catalog, ap_m1', config)
        self.assertFalse(public_execute)
        self.assertTrue(api_execute, 'the requesting adult calls erasure through the runtime role')


if __name__ == '__main__':
    unittest.main()
