"""Account erasure revokes credentials without pretending financial retention is approved."""
import unittest
from uuid import uuid4
import fixtures


class AccountErasureTests(unittest.TestCase):
    def test_account_request_schema_and_credential_revocation(self):
        with fixtures.admin_connection() as admin:
            self.assertIsNotNone(admin.execute("SELECT to_regprocedure('ap_m1.request_account_erasure(uuid)')").fetchone()[0])
        # Distinct synthetic identities: do not erase shared test actors.
        old_namespace=fixtures.NS
        try:
            fixtures.NS=uuid4()
            f=fixtures.seed_core()
        finally:
            fixtures.NS=old_namespace
        with fixtures.runtime_connection() as runtime:
            fixtures.as_parent(runtime,f['a'],f['family_a'])
            request_id=runtime.execute('SELECT ap_m1.request_account_erasure(%s)',(uuid4(),)).fetchone()[0]
            self.assertIsNotNone(request_id)
            self.assertIsNone(runtime.execute('SELECT ap_m1.ctx_principal()').fetchone()[0])
        with fixtures.admin_connection() as admin:
            self.assertEqual(admin.execute('SELECT state FROM ap_m1.adult_erasure_requests WHERE id=%s',(request_id,)).fetchone()[0],'BLOCKED_POLICY')
            self.assertEqual(admin.execute('SELECT oidc_subject FROM ap_m1.parent_principals WHERE id=%s',(f['a'],)).fetchone()[0],'erased:'+str(f['a']))
            self.assertEqual(admin.execute('SELECT count(*) FROM ap_m1.adult_erasure_jobs WHERE request_id=%s',(request_id,)).fetchone()[0],5)

    def test_account_request_cannot_target_another_adult(self):
        with fixtures.admin_connection() as admin:
            self.assertIsNotNone(admin.execute("SELECT to_regclass('ap_m1.adult_erasure_requests')").fetchone()[0])
        with fixtures.runtime_connection() as runtime:
            f=fixtures.seed_core()
            fixtures.as_parent(runtime,f['b'],f['family_b'])
            self.assertEqual(runtime.execute('SELECT count(*) FROM ap_m1.adult_erasure_requests WHERE principal_id=%s',(f['a'],)).fetchone()[0],0)
