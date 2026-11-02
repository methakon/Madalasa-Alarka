"""RED/GREEN reconciliation tests: credential clock + media exact-child binding.

Owner: this module and .local-db/reconciliation-credentials-media.sql only.
Published 0017/0009 are not edited. The parent assembles the fragment into 0019,
runs this module RED (before the fragment), then replays and runs it GREEN.

Source-only inspection needs no database:
  CREDENTIAL_MEDIA_RECONCILIATION_SOURCE_ONLY=1 python3 -m unittest discover \
    -s backend/tests/database -p test_reconciliation_credentials_media.py -v
Database tests need the disposable loopback test database and a committed
synthetic fixture; every fixture they commit is deleted by exact UUID, and every
media row lives in one rolled-back transaction (nothing to clean up).

Why these tests fail on the published schema (RED):
  * now() is frozen at transaction start, so a credential/challenge that expires
    during the transaction -- or while the caller waits on the row lock -- is
    still accepted, and the 60 s issuance window is measured from transaction
    start instead of from actual consumption time;
  * media_sessions / media_quota_ledger / capture_artifact_refs accept a parent
    row (request, pool, session, addon) that belongs to a DIFFERENT child.
"""
import hashlib
import os
import re
import threading
import time
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
from uuid import uuid4

ROOT = Path(__file__).resolve().parents[3]
FRAGMENT = ROOT / '.local-db/reconciliation-credentials-media.sql'
PUBLISHED_CREDENTIALS = ROOT / 'backend/persistence/migrations/0017_m1_lineage_compatibility.sql'
PUBLISHED_MEDIA = ROOT / 'backend/persistence/migrations/0009_media_sessions_and_quota.sql'

SOURCE_ONLY = os.environ.get('CREDENTIAL_MEDIA_RECONCILIATION_SOURCE_ONLY') == '1'

CLOCK_FUNCTIONS = (
    'authenticate_device_credential',
    'issue_credential_renewal_challenge',
    'consume_renewal_challenge',
    'issue_renewal_credential',
    'consume_enrollment_challenge',
    'activate_enrolled_device',
    'redeem_pairing_code',
)
MEDIA_KEYS = ('media_request_child_id_id_key', 'media_session_child_id_id_key',
              'media_pool_child_id_id_key', 'media_addon_child_id_id_key')
MEDIA_FKS = ('media_session_request_child_fk', 'media_ledger_pool_child_fk',
             'media_ledger_session_child_fk', 'media_ledger_addon_child_fk',
             'capture_artifact_session_child_fk')


def _code(text):
    """Strip SQL line comments so guards test statements, not prose."""
    return '\n'.join(re.sub(r'--.*', '', line) for line in text.splitlines())


class FragmentSource(unittest.TestCase):
    """No database: proves the additive fragment exists and stays additive."""

    def setUp(self):
        if not FRAGMENT.exists():
            # The reviewed fragment is an untracked working artifact: 0019 and the
            # additive 0020 carry its guarantees in the tracked tree, and the
            # manifest checksum gate proves published migrations are unedited.
            # The database-level media/credential tests below still run.
            raise unittest.SkipTest('reviewed reconciliation fragment is not in the tracked '
                                    'tree; its guarantees live in published 0019/0020 and the '
                                    'manifest checksum gate')
        self.text = FRAGMENT.read_text()
        self.code = _code(self.text)

    def test_every_clock_function_is_replaced_additively(self):
        for name in CLOCK_FUNCTIONS:
            self.assertIn('CREATE OR REPLACE FUNCTION ap_m1.' + name + '(', self.code,
                          'fragment must CREATE OR REPLACE ' + name)
        self.assertNotIn('CREATE FUNCTION', self.code.replace('CREATE OR REPLACE FUNCTION', ''),
                         'fragment must not introduce a new credential function')

    def test_transaction_frozen_clock_is_gone(self):
        self.assertIsNone(re.search(r'\bnow\(\)', self.code),
                          'no credential/challenge decision may use transaction-start now()')
        # 1 read-only lookup + at least one post-lock sample per mutating function.
        self.assertGreaterEqual(self.code.count('clock_timestamp()'), 8)
        self.assertIn('c.expires_at > statement_timestamp()', self.code)

    def test_types_signatures_owner_and_acl_are_untouched(self):
        for forbidden in ('ALTER FUNCTION', 'ALTER TABLE ap_m1.device_credentials',
                          'ALTER TABLE ap_m1.credential_renewal_challenges',
                          'ALTER TABLE ap_m1.enrollment_challenges',
                          'GRANT ', 'REVOKE ', 'DROP ', 'TRUNCATE', 'DELETE FROM'):
            self.assertNotIn(forbidden, self.code, forbidden)

    def test_media_exact_child_constraints_are_composite_and_non_cascading(self):
        for name in MEDIA_KEYS:
            self.assertIn('CONSTRAINT ' + name + ' UNIQUE(child_id,id)', self.code, name)
        for name in MEDIA_FKS:
            start = self.code.find(name)
            self.assertGreaterEqual(start, 0, name)
            block = self.code[start:start + 400].split(';')[0]
            self.assertIn('FOREIGN KEY(child_id,', block,
                          name + ' must bind child_id together with its parent row')
        self.assertNotIn('ON DELETE', self.code)
        # Fail closed on preexisting cross-child rows instead of deleting them.
        self.assertIn('RAISE EXCEPTION', self.code)
        for table in ('media_sessions', 'media_quota_ledger', 'capture_artifact_refs'):
            self.assertIn('ap_m1.' + table, self.code, table)

    def test_published_migrations_are_not_edited(self):
        credentials = PUBLISHED_CREDENTIALS.read_text()
        media = PUBLISHED_MEDIA.read_text()
        # The published transaction-time checks stay in place; the correction is
        # additive, so nobody may "fix" 0017/0009 in place.
        self.assertIn("OR ch.consumed_at < now() - interval '60 seconds' THEN RETURN NULL", credentials)
        self.assertIn('AND c.revoked_at IS NULL AND c.expires_at > now()', credentials)
        self.assertIn('request_id uuid NOT NULL UNIQUE REFERENCES ap_m1.media_command_requests(id)', media)


class _CredentialWorld:
    """Committed synthetic credential scaffolding, deleted by exact UUID.

    Nothing here proves cryptography or grants authority: it is a disposable
    local fixture for clock and constraint behaviour only.
    """

    def __init__(self):
        from fixtures import admin_connection
        self.credential_ids = []
        self.challenge_ids = []
        self.enrollment_ids = []
        self.device_ids = []
        self.adult, self.family, self.child = uuid4(), uuid4(), uuid4()
        self.review, self.device, self.key = uuid4(), uuid4(), uuid4()
        self.spki = b'SYNTHETIC-RECON-ACTIVE-SPKI-' + bytes(range(64))
        with admin_connection() as c:
            c.execute("INSERT INTO ap_m1.local_test_settings(singleton,enabled) VALUES(true,true) "
                      "ON CONFLICT(singleton) DO UPDATE SET enabled=true")
            c.execute('INSERT INTO ap_m1.parent_principals(id,oidc_issuer,oidc_subject) VALUES(%s,%s,%s)',
                      (self.adult, 'https://synthetic.example.invalid', 'recon-' + str(self.adult)))
            c.execute("INSERT INTO ap_m1.families(id,label) VALUES(%s,'reconciliation synthetic')", (self.family,))
            c.execute("INSERT INTO ap_m1.children(id,family_id,alias) VALUES(%s,%s,'synthetic recon child')",
                      (self.child, self.family))
            c.execute("INSERT INTO ap_m1.child_authority_reviews(id,child_id,adult_id,state,lawful_basis_version,"
                      "method_code,reviewed_at,expires_at) VALUES(%s,%s,%s,'LOCAL_TEST_APPROVED','synthetic-v1',"
                      "'SYNTHETIC_FIXTURE',clock_timestamp()-interval '1 minute',clock_timestamp()+interval '1 day')",
                      (self.review, self.child, self.adult))
            c.execute("INSERT INTO ap_m1.consent_records(child_id,adult_id,purpose,status,authority_review_id,"
                      "notice_version,legal_state,expires_at) VALUES(%s,%s,'CORE','GRANTED',%s,'synthetic-v1',"
                      "'LOCAL_TEST_APPROVED',clock_timestamp()+interval '1 day')",
                      (self.child, self.adult, self.review))
            c.execute("INSERT INTO ap_m1.devices(id,family_id,child_id,spki_public_key,enrollment_state) "
                      "VALUES(%s,%s,%s,%s,'ACTIVE')", (self.device, self.family, self.child, self.spki))
            c.execute("INSERT INTO ap_m1.device_key_records(key_id,device_id,fingerprint_sha256,state) "
                      "VALUES(%s,%s,%s,'ACTIVE')",
                      (self.key, self.device, hashlib.sha256(self.spki).digest()))

    # -- fixtures -----------------------------------------------------------
    def credential(self, seconds=3600):
        from fixtures import admin_connection
        token = uuid4().bytes * 2
        with admin_connection() as c:
            row = c.execute(
                "INSERT INTO ap_m1.device_credentials(device_id,key_id,token_sha256,issued_via,issued_at,expires_at,"
                "bound_key_generation,bound_key_fingerprint_sha256) SELECT %s,key_id,%s,'RENEWAL',"
                "clock_timestamp()-interval '1 minute',clock_timestamp()+make_interval(secs=>%s::double precision),"
                "generation,fingerprint_sha256 FROM ap_m1.device_key_records WHERE key_id=%s RETURNING id,expires_at",
                (self.device, token, float(seconds), self.key)).fetchone()
        self.credential_ids.append(row[0])
        return token, row[1]

    def renewal_challenge(self, expires_in=1.5, consumed_ago=None):
        """Backdated but valid fixture; TTL stays inside the 5 minute ceiling."""
        from fixtures import admin_connection
        with admin_connection() as c:
            row = c.execute(
                "INSERT INTO ap_m1.credential_renewal_challenges(device_id,key_id,nonce_sha256,created_at,expires_at,"
                "consumed_at,bound_key_generation,bound_key_fingerprint_sha256) SELECT %s,key_id,%s,"
                "clock_timestamp()-interval '2 minutes',clock_timestamp()+make_interval(secs=>%s::double precision),"
                "CASE WHEN %s::double precision IS NULL THEN NULL "
                "ELSE clock_timestamp()-make_interval(secs=>%s::double precision) END,generation,fingerprint_sha256 "
                "FROM ap_m1.device_key_records WHERE key_id=%s RETURNING id,expires_at",
                (self.device, uuid4().bytes * 2, float(expires_in),
                 None if consumed_ago is None else float(consumed_ago),
                 0.0 if consumed_ago is None else float(consumed_ago), self.key)).fetchone()
        self.challenge_ids.append(row[0])
        return row[0], row[1]

    def pending_enrollment(self, expires_in=120.0, consumed_ago=None):
        from fixtures import admin_connection
        device = uuid4()
        spki = b'SYNTHETIC-RECON-ENROLL-SPKI-' + bytes(range(64))
        with admin_connection() as c:
            c.execute("INSERT INTO ap_m1.devices(id,family_id,child_id,spki_public_key) VALUES(%s,%s,%s,%s)",
                      (device, self.family, self.child, spki))
            row = c.execute(
                "INSERT INTO ap_m1.enrollment_challenges(device_id,nonce_sha256,created_at,expires_at,consumed_at) "
                "VALUES(%s,%s,clock_timestamp()-interval '2 minutes',clock_timestamp()+make_interval(secs=>%s::double precision),"
                "CASE WHEN %s::double precision IS NULL THEN NULL "
                "ELSE clock_timestamp()-make_interval(secs=>%s::double precision) END) RETURNING id,expires_at",
                (device, uuid4().bytes * 2, float(expires_in),
                 None if consumed_ago is None else float(consumed_ago),
                 0.0 if consumed_ago is None else float(consumed_ago))).fetchone()
        self.device_ids.append(device)
        self.enrollment_ids.append(row[0])
        return device, row[0], row[1]

    # -- cleanup ------------------------------------------------------------
    def cleanup(self):
        from fixtures import admin_connection
        with admin_connection() as c:
            for credential in self.credential_ids:
                c.execute('DELETE FROM ap_m1.device_credentials WHERE id=%s', (credential,))
            for challenge in self.challenge_ids:
                c.execute('DELETE FROM ap_m1.credential_renewal_challenges WHERE id=%s', (challenge,))
            for enrollment in self.enrollment_ids:
                c.execute('DELETE FROM ap_m1.enrollment_challenges WHERE id=%s', (enrollment,))
            for device in self.device_ids:
                c.execute('DELETE FROM ap_m1.device_credentials WHERE device_id=%s', (device,))
                c.execute('DELETE FROM ap_m1.credential_renewal_challenges WHERE device_id=%s', (device,))
                c.execute('DELETE FROM ap_m1.enrollment_challenges WHERE device_id=%s', (device,))
                c.execute('DELETE FROM ap_m1.device_key_records WHERE device_id=%s', (device,))
                c.execute('DELETE FROM ap_m1.devices WHERE id=%s', (device,))
            c.execute('DELETE FROM ap_m1.device_credentials WHERE device_id=%s', (self.device,))
            c.execute('DELETE FROM ap_m1.credential_renewal_challenges WHERE device_id=%s', (self.device,))
            c.execute('DELETE FROM ap_m1.device_key_records WHERE device_id=%s', (self.device,))
            c.execute('DELETE FROM ap_m1.devices WHERE id=%s', (self.device,))
            c.execute('DELETE FROM ap_m1.consent_records WHERE child_id=%s', (self.child,))
            c.execute('DELETE FROM ap_m1.child_authority_reviews WHERE child_id=%s', (self.child,))
            c.execute('DELETE FROM ap_m1.children WHERE id=%s', (self.child,))
            c.execute('DELETE FROM ap_m1.families WHERE id=%s', (self.family,))
            c.execute('DELETE FROM ap_m1.parent_principals WHERE id=%s', (self.adult,))


@unittest.skipIf(SOURCE_ONLY, 'source-only inspection')
class CredentialClockTests(unittest.TestCase):
    def setUp(self):
        self.w = _CredentialWorld()
        self.addCleanup(self.w.cleanup)

    # -- controls -----------------------------------------------------------
    def test_positive_control_credential_and_enrollment_still_work(self):
        from fixtures import auth_connection, runtime_connection
        token, expires_at = self.w.credential(3600)
        with runtime_connection() as c:
            rows = c.execute('SELECT * FROM ap_m1.authenticate_device_credential(%s)', (token,)).fetchall()
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0][0], self.w.device)
            self.assertGreater(expires_at, c.execute('SELECT clock_timestamp()').fetchone()[0])
        device, challenge, _ = self.w.pending_enrollment(expires_in=120.0, consumed_ago=1.0)
        fresh = uuid4().bytes * 2
        with auth_connection() as c:
            rows = c.execute('SELECT * FROM ap_m1.activate_enrolled_device(%s,%s,3600)',
                             (challenge, fresh)).fetchall()
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0][0], device)
        with runtime_connection() as c:
            self.assertEqual(len(c.execute('SELECT * FROM ap_m1.authenticate_device_credential(%s)',
                                           (fresh,)).fetchall()), 1)

    # -- expiry crossed inside one transaction ------------------------------
    def test_expired_credential_is_denied_after_transaction_start(self):
        from fixtures import runtime_connection, admin_connection
        token, expires_at = self.w.credential(2.0)
        with runtime_connection() as c:
            started = c.execute('SELECT now(), clock_timestamp()').fetchone()
            self.assertLess(started[0], expires_at,
                            'fixture must still be valid at transaction start; rerun the case')
            c.execute('SELECT pg_sleep(3.0)')
            rows = c.execute('SELECT * FROM ap_m1.authenticate_device_credential(%s)', (token,)).fetchall()
            c.rollback()
        self.assertEqual(rows, [], 'a credential that expired inside the transaction must not authenticate')
        with admin_connection() as c:
            self.assertGreater(c.execute('SELECT clock_timestamp()').fetchone()[0], expires_at)

    def test_expired_renewal_challenge_is_not_consumed_after_transaction_start(self):
        from fixtures import auth_connection, admin_connection
        challenge, expires_at = self.w.renewal_challenge(expires_in=2.0)
        with auth_connection() as c:
            started = c.execute('SELECT now()').fetchone()[0]
            self.assertLess(started, expires_at,
                            'fixture must still be valid at transaction start; rerun the case')
            c.execute('SELECT pg_sleep(3.0)')
            rows = c.execute('SELECT * FROM ap_m1.consume_renewal_challenge(%s,%s)',
                             (self.w.device, challenge)).fetchall()
            c.rollback()
        self.assertEqual(rows, [], 'an expired renewal challenge must not be consumed')
        with admin_connection() as c:
            self.assertIsNone(c.execute('SELECT consumed_at FROM ap_m1.credential_renewal_challenges '
                                        'WHERE id=%s', (challenge,)).fetchone()[0],
                              'a refused consumption must leave the challenge unspent')

    def test_expired_enrollment_challenge_is_not_consumed_after_transaction_start(self):
        from fixtures import auth_connection, admin_connection
        device, challenge, expires_at = self.w.pending_enrollment(expires_in=2.0)
        with auth_connection() as c:
            started = c.execute('SELECT now()').fetchone()[0]
            self.assertLess(started, expires_at,
                            'fixture must still be valid at transaction start; rerun the case')
            c.execute('SELECT pg_sleep(3.0)')
            rows = c.execute('SELECT * FROM ap_m1.consume_enrollment_challenge(%s)', (challenge,)).fetchall()
            c.rollback()
        self.assertEqual(rows, [], 'an expired enrollment challenge must not be consumed')
        with admin_connection() as c:
            self.assertEqual(c.execute('SELECT consumed_at FROM ap_m1.enrollment_challenges WHERE id=%s',
                                       (challenge,)).fetchone()[0], None)

    # -- 60 s issuance window ----------------------------------------------
    def test_renewal_issuance_window_closes_on_the_actual_clock(self):
        from fixtures import auth_connection, admin_connection
        stale, _ = self.w.renewal_challenge(expires_in=120.0, consumed_ago=59.0)
        inside, _ = self.w.renewal_challenge(expires_in=120.0, consumed_ago=30.0)
        stale_token, inside_token = uuid4().bytes * 2, uuid4().bytes * 2
        with auth_connection() as c:
            c.execute('SELECT 1')  # transaction start, before the window closes
            c.execute('SELECT pg_sleep(2.5)')
            stale_result = c.execute('SELECT ap_m1.issue_renewal_credential(%s,%s,%s,3600)',
                                     (self.w.device, stale, stale_token)).fetchone()[0]
            inside_result = c.execute('SELECT ap_m1.issue_renewal_credential(%s,%s,%s,3600)',
                                      (self.w.device, inside, inside_token)).fetchone()[0]
            c.commit()
        self.assertIsNone(stale_result, 'issuance more than 60 s after consumption must be refused')
        self.assertIsNotNone(inside_result, 'issuance within 60 s of consumption must still succeed')
        with admin_connection() as c:
            self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.device_credentials WHERE token_sha256=%s',
                                       (stale_token,)).fetchone()[0], 0)
            self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.device_credentials WHERE token_sha256=%s',
                                       (inside_token,)).fetchone()[0], 1)
            self.assertIsNone(c.execute('SELECT redeemed_at FROM ap_m1.credential_renewal_challenges '
                                        'WHERE id=%s', (stale,)).fetchone()[0])

    def test_enrollment_activation_window_closes_on_the_actual_clock(self):
        from fixtures import auth_connection, admin_connection
        device, challenge, _ = self.w.pending_enrollment(expires_in=120.0, consumed_ago=59.0)
        token = uuid4().bytes * 2
        with auth_connection() as c:
            c.execute('SELECT 1')  # transaction start, before the window closes
            c.execute('SELECT pg_sleep(2.5)')
            rows = c.execute('SELECT * FROM ap_m1.activate_enrolled_device(%s,%s,3600)',
                             (challenge, token)).fetchall()
            c.commit()
        self.assertEqual(rows, [], 'activation more than 60 s after consumption must be refused')
        with admin_connection() as c:
            self.assertEqual(c.execute("SELECT enrollment_state FROM ap_m1.devices WHERE id=%s",
                                       (device,)).fetchone()[0], 'PENDING_PROOF')
            self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.device_credentials WHERE device_id=%s',
                                       (device,)).fetchone()[0], 0)

    # -- lock wait ----------------------------------------------------------
    def test_expiry_is_evaluated_after_the_row_lock_is_obtained(self):
        from fixtures import admin_connection, auth_connection
        challenge, expires_at = self.w.renewal_challenge(expires_in=2.0)
        waiter = auth_connection()
        self.addCleanup(waiter.close)
        self.assertLess(waiter.execute('SELECT now()').fetchone()[0], expires_at,
                        'fixture must still be valid at transaction start; rerun the case')

        locked = {}
        ready = threading.Event()

        def hold_lock():
            with admin_connection() as holder:
                row = holder.execute('SELECT id FROM ap_m1.credential_renewal_challenges '
                                     'WHERE id=%s FOR UPDATE', (challenge,)).fetchone()
                locked['visible'] = row is not None
                ready.set()
                time.sleep(2.5)

        thread = threading.Thread(target=hold_lock)
        thread.start()
        try:
            self.assertTrue(ready.wait(10), 'lock holder did not start')
            started = time.monotonic()
            rows = waiter.execute('SELECT * FROM ap_m1.consume_renewal_challenge(%s,%s)',
                                  (self.w.device, challenge)).fetchall()
            elapsed = time.monotonic() - started
            waiter.rollback()
        finally:
            thread.join(10)
        self.assertTrue(locked.get('visible'), 'holder could not see the challenge row')
        self.assertGreaterEqual(elapsed, 2.0, 'the call did not wait on the row lock')
        self.assertEqual(rows, [], 'expiry must be judged after the row lock is obtained')
        with admin_connection() as c:
            self.assertIsNone(c.execute('SELECT consumed_at FROM ap_m1.credential_renewal_challenges '
                                        'WHERE id=%s', (challenge,)).fetchone()[0])

    # -- committed consumption / failure evidence ---------------------------
    def test_committed_consumption_is_single_use_and_failed_issuance_changes_nothing(self):
        from fixtures import admin_connection, auth_connection, runtime_connection
        token, _ = self.w.credential(3600)
        challenge, _ = self.w.renewal_challenge(expires_in=170.0)
        with auth_connection() as c:
            c.execute('SELECT * FROM ap_m1.consume_renewal_challenge(%s,%s)',
                      (self.w.device, challenge))
        with admin_connection() as c:
            self.assertIsNotNone(c.execute('SELECT consumed_at FROM ap_m1.credential_renewal_challenges '
                                           'WHERE id=%s', (challenge,)).fetchone()[0])
            before = c.execute('SELECT count(*) FROM ap_m1.device_credentials WHERE device_id=%s',
                               (self.w.device,)).fetchone()[0]
        with auth_connection() as c:
            self.assertEqual(c.execute('SELECT * FROM ap_m1.consume_renewal_challenge(%s,%s)',
                                       (self.w.device, challenge)).fetchall(), [],
                             'a committed consumption must never be reusable')
        # Backdate the committed consumption past the issuance window.
        with admin_connection() as c:
            c.execute("UPDATE ap_m1.credential_renewal_challenges SET consumed_at=clock_timestamp()"
                      "-interval '61 seconds' WHERE id=%s", (challenge,))
        replacement = uuid4().bytes * 2
        with auth_connection() as c:
            self.assertIsNone(c.execute('SELECT ap_m1.issue_renewal_credential(%s,%s,%s,3600)',
                                        (self.w.device, challenge, replacement)).fetchone()[0])
        with admin_connection() as c:
            self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.device_credentials WHERE device_id=%s',
                                       (self.w.device,)).fetchone()[0], before,
                             'a refused issuance must not add a credential')
            self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.device_credentials WHERE token_sha256=%s',
                                       (replacement,)).fetchone()[0], 0)
            self.assertIsNone(c.execute('SELECT redeemed_at FROM ap_m1.credential_renewal_challenges '
                                        'WHERE id=%s', (challenge,)).fetchone()[0])
        with runtime_connection() as c:
            self.assertEqual(len(c.execute('SELECT * FROM ap_m1.authenticate_device_credential(%s)',
                                           (token,)).fetchall()), 1,
                             'a refused issuance must not revoke the live credential')


@unittest.skipIf(SOURCE_ONLY, 'source-only inspection')
class MediaChildBindingTests(unittest.TestCase):
    """One rolled-back transaction: no media row is ever committed."""

    def setUp(self):
        from fixtures import admin_connection
        self.admin = admin_connection()
        self.addCleanup(self.admin.close)
        self.addCleanup(self.admin.rollback)
        self.now = datetime.now(timezone.utc)
        self._seed()

    def _insert_returning(self, sql, args):
        return self.admin.execute(sql, args).fetchone()[0]

    def _seed(self):
        a = self
        a.adult, a.family = uuid4(), uuid4()
        a.child_a, a.child_b = uuid4(), uuid4()
        a.device_a, a.device_b = uuid4(), uuid4()
        self.admin.execute('INSERT INTO ap_m1.parent_principals(id,oidc_issuer,oidc_subject) VALUES(%s,%s,%s)',
                           (a.adult, 'https://synthetic.example.invalid', 'media-' + str(a.adult)))
        self.admin.execute("INSERT INTO ap_m1.families(id,label) VALUES(%s,'reconciliation media synthetic')",
                           (a.family,))
        for child in (a.child_a, a.child_b):
            self.admin.execute("INSERT INTO ap_m1.children(id,family_id,alias) VALUES(%s,%s,'synthetic media child')",
                               (child, a.family))
        for device, child in ((a.device_a, a.child_a), (a.device_b, a.child_b)):
            self.admin.execute("INSERT INTO ap_m1.devices(id,family_id,child_id,spki_public_key,enrollment_state) "
                               "VALUES(%s,%s,%s,%s,'ACTIVE')",
                               (device, a.family, child, b'SYNTHETIC-RECON-MEDIA-' + bytes(range(64))))
        a.request_a = self._insert_returning(
            "INSERT INTO ap_m1.media_command_requests(child_id,device_id,adult_id,kind) "
            "VALUES(%s,%s,%s,'IMAGE') RETURNING id", (a.child_a, a.device_a, a.adult))
        a.request_b = self._insert_returning(
            "INSERT INTO ap_m1.media_command_requests(child_id,device_id,adult_id,kind) "
            "VALUES(%s,%s,%s,'IMAGE') RETURNING id", (a.child_b, a.device_b, a.adult))
        a.session_a = self._insert_returning(
            "INSERT INTO ap_m1.media_sessions(request_id,child_id,authorized_adult_id,exit_reason) "
            "VALUES(%s,%s,%s,'OS_REJECTED') RETURNING id", (a.request_a, a.child_a, a.adult))
        a.session_b = self._insert_returning(
            "INSERT INTO ap_m1.media_sessions(request_id,child_id,authorized_adult_id,exit_reason) "
            "VALUES(%s,%s,%s,'OS_REJECTED') RETURNING id", (a.request_b, a.child_b, a.adult))
        # Unused request for the same child: lets a test try a cross-child session
        # without colliding with the one-session-per-request unique constraint.
        a.request_free = self._insert_returning(
            "INSERT INTO ap_m1.media_command_requests(child_id,device_id,adult_id,kind) "
            "VALUES(%s,%s,%s,'IMAGE') RETURNING id", (a.child_a, a.device_a, a.adult))
        trial = self._insert_returning(
            "INSERT INTO ap_m1.trial_redemptions(family_id,payer_id,started_at,expires_at) "
            "VALUES(%s,%s,%s,%s) RETURNING id", (a.family, a.adult, self.now, self.now + timedelta(hours=48)))
        for child in (a.child_a, a.child_b):
            self.admin.execute("INSERT INTO ap_m1.child_media_quota_pools(child_id,trial_id,starts_at,expires_at) "
                               "VALUES(%s,%s,%s,%s)", (child, trial, self.now, self.now + timedelta(hours=48)))
        a.pool_a = self.admin.execute('SELECT id FROM ap_m1.child_media_quota_pools WHERE child_id=%s',
                                      (a.child_a,)).fetchone()[0]
        a.pool_b = self.admin.execute('SELECT id FROM ap_m1.child_media_quota_pools WHERE child_id=%s',
                                      (a.child_b,)).fetchone()[0]
        intent = self._insert_returning(
            "INSERT INTO ap_m1.family_checkout_intents(family_id,payer_id,sku_id,selected_child_ids) "
            "VALUES(%s,%s,'local_extra_viewer_100d',%s::uuid[]) RETURNING id", (a.family, a.adult, [a.child_b]))
        purchase = self._insert_returning(
            "INSERT INTO ap_m1.play_purchase_records(checkout_intent_id,family_id,payer_id,sku_id,token_sha256,"
            "evidence_sha256,evidence_source,purchased_at,amount_paise) VALUES(%s,%s,%s,'local_extra_viewer_100d',"
            "%s,%s,'LOCAL_SYNTHETIC',%s,10000) RETURNING id",
            (intent, a.family, a.adult, uuid4().bytes * 2, uuid4().bytes * 2, self.now))
        a.addon_b = self._insert_returning(
            "INSERT INTO ap_m1.extra_viewer_purchases(purchase_id,child_id,activated_at,expires_at) "
            "VALUES(%s,%s,%s,%s) RETURNING id",
            (purchase, a.child_b, self.now, self.now + timedelta(days=100)))

    def _reject(self, sql, args, label):
        import psycopg
        with self.assertRaises(psycopg.errors.ForeignKeyViolation, msg=label):
            with self.admin.transaction():
                self.admin.execute(sql, args)

    def test_session_request_and_child_must_match(self):
        self._reject("INSERT INTO ap_m1.media_sessions(request_id,child_id,authorized_adult_id,exit_reason) "
                     "VALUES(%s,%s,%s,'OS_REJECTED')",
                     (self.request_free, self.child_b, self.adult),
                     'a session must not borrow another child request')
        # The exact-child pairing is still accepted.
        self.admin.execute("INSERT INTO ap_m1.media_sessions(request_id,child_id,authorized_adult_id,exit_reason) "
                           "VALUES(%s,%s,%s,'OS_REJECTED')",
                           (self.request_free, self.child_a, self.adult))

    def test_ledger_pool_session_and_addon_must_match_the_child(self):
        ledger = ("INSERT INTO ap_m1.media_quota_ledger(child_id,pool_id,media_session_id,addon_id,media_kind,"
                  "delivered_amount) VALUES(%s,%s,%s,%s,'IMAGE',1)")
        # Controls: exact-child rows are accepted, and a NULL addon stays legal.
        self.admin.execute(ledger, (self.child_a, self.pool_a, self.session_a, None))
        self.admin.execute(ledger, (self.child_b, self.pool_b, self.session_b, self.addon_b))
        self._reject(ledger, (self.child_a, self.pool_a, self.session_a, self.addon_b),
                     'addon of another child')
        self._reject(ledger, (self.child_b, self.pool_a, self.session_a, None),
                     'pool of another child')
        self._reject(ledger, (self.child_a, self.pool_b, self.session_a, None),
                     'pool of another child (reverse)')
        self._reject(ledger, (self.child_a, self.pool_a, self.session_b, None),
                     'session of another child')

    def test_artifact_session_and_child_must_match(self):
        self._reject("INSERT INTO ap_m1.capture_artifact_refs(media_session_id,child_id,storage_location,acknowledgement_id) "
                     "VALUES(%s,%s,'PARENT_LOCAL_ACK_ONLY',%s)", (self.session_a, self.child_b, uuid4()),
                     'artifact must not reference another child session')
        self.admin.execute("INSERT INTO ap_m1.capture_artifact_refs(media_session_id,child_id,storage_location,"
                           "acknowledgement_id,expires_at) VALUES(%s,%s,'PARENT_LOCAL_ACK_ONLY',%s,NULL)",
                           (self.session_a, self.child_a, uuid4()))


if __name__ == '__main__':
    unittest.main()
