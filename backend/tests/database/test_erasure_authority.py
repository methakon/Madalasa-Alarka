"""Billing ownership is not continuing authority to erase a child."""
import unittest
from uuid import uuid4
import psycopg
import fixtures
from test_location import domain_fixture,cleanup_domain


class ErasureAuthorityTests(unittest.TestCase):
    def setUp(self):
        self.f=domain_fixture()
        self.addCleanup(cleanup_domain,self.f)
        self.addCleanup(self.cleanup_audit)
        self.db=fixtures.runtime_connection()
        self.addCleanup(self.db.close)
        self.addCleanup(self.db.rollback)
        fixtures.as_parent(self.db,self.f['a'],self.f['family_a'])

    def cleanup_audit(self):
        with fixtures.admin_connection() as admin:
            admin.execute('DELETE FROM ap_m1.consent_decision_audit WHERE consent_id IN (SELECT id FROM ap_m1.consent_records WHERE child_id=%s)',(self.f['child_a'],))

    def assert_erasure_denied(self):
        with self.assertRaises(psycopg.errors.InsufficientPrivilege):
            with self.db.transaction():
                self.db.execute('SELECT ap_m1.request_child_erasure(%s,%s)',(self.f['child_a'],uuid4()))

    def test_revoked_grants_do_not_fall_back_to_billing_ownership(self):
        with fixtures.admin_connection() as admin:
            admin.execute('UPDATE ap_m1.child_access_grants_v2 SET revoked_at=now() WHERE child_id=%s',(self.f['child_a'],))
        self.assert_erasure_denied()

    def test_disputed_authority_cannot_erase(self):
        with fixtures.admin_connection() as admin:
            admin.execute("UPDATE ap_m1.child_authority_reviews SET state='DISPUTED' WHERE id=%s",(self.f['review_a'],))
        self.assert_erasure_denied()

    def test_revoked_authority_cannot_erase(self):
        with fixtures.admin_connection() as admin:
            admin.execute("UPDATE ap_m1.child_authority_reviews SET state='REVOKED',revoked_at=now() WHERE id=%s",(self.f['review_a'],))
        self.assert_erasure_denied()

    def test_valid_authority_can_erase_after_own_voluntary_withdrawal(self):
        self.db.execute('SELECT ap_m1.withdraw_consent(%s,%s)',(self.f['consent_a'],uuid4()))
        self.assertFalse(self.db.execute("SELECT ap_m1.has_child_scope_v2(%s,'MANAGE_CONSENT')",(self.f['child_a'],)).fetchone()[0])
        result=self.db.execute('SELECT ap_m1.request_child_erasure(%s,%s)',(self.f['child_a'],uuid4())).fetchone()[0]
        self.assertIsNotNone(result)

    def test_withdrawal_does_not_override_subsequent_authority_dispute(self):
        # Make the voluntary withdrawal durable before independently disputing it.
        self.db.execute('SELECT ap_m1.withdraw_consent(%s,%s)',(self.f['consent_a'],uuid4()))
        self.db.commit()
        with fixtures.admin_connection() as admin:
            admin.execute("UPDATE ap_m1.child_authority_reviews SET state='DISPUTED' WHERE id=%s",(self.f['review_a'],))
        fixtures.as_parent(self.db,self.f['a'],self.f['family_a'])
        self.assert_erasure_denied()
