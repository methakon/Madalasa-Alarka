"""Metadata-only enhancement guards; no pickup bearer or export delivery is enabled."""
import hashlib
import unittest
from uuid import uuid4
import psycopg
import fixtures
from test_location import domain_fixture,cleanup_domain


class EnhancementGuardTests(unittest.TestCase):
    def test_pickup_metadata_closes_when_location_scope_is_revoked(self):
        f=domain_fixture();pass_id=uuid4()
        try:
            with fixtures.admin_connection() as c:
                c.execute("INSERT INTO ap_m1.child_pickup_viewer_passes(id,child_id,created_by,pass_token_hash,expires_at) VALUES(%s,%s,%s,%s,now()+interval '10 minutes')",(pass_id,f['child_a'],f['a'],hashlib.sha256(uuid4().bytes).digest()))
            with fixtures.runtime_connection() as c:
                fixtures.as_parent(c,f['a'],f['family_a'])
                self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.child_pickup_viewer_passes WHERE id=%s',(pass_id,)).fetchone()[0],1)
            with fixtures.admin_connection() as c:
                c.execute("UPDATE ap_m1.child_access_grants_v2 SET revoked_at=now() WHERE child_id=%s AND adult_id=%s AND scope='VIEW_LOCATION'",(f['child_a'],f['a']))
            with fixtures.runtime_connection() as c:
                fixtures.as_parent(c,f['a'],f['family_a'])
                self.assertEqual(c.execute('SELECT count(*) FROM ap_m1.child_pickup_viewer_passes WHERE id=%s',(pass_id,)).fetchone()[0],0)
        finally:
            with fixtures.admin_connection() as c:c.execute('DELETE FROM ap_m1.child_pickup_viewer_passes WHERE id=%s',(pass_id,))
            cleanup_domain(f)

    def test_compliance_case_and_family_cannot_point_at_another_child(self):
        f=domain_fixture()
        try:
            with fixtures.admin_connection() as c:
                try:
                    admins=[uuid4(),uuid4()]
                    for admin,actor in zip(admins,(f['a'],f['b'])):
                        c.execute('INSERT INTO ap_m1.admin_accounts(id,principal_id,verified_email) VALUES(%s,%s,%s)',(admin,actor,str(admin)+'@synthetic.example.invalid'))
                    case=c.execute("INSERT INTO ap_m1.admin_cases(child_id,assigned_admin_id,approver_id,purpose,reason_code,expires_at) VALUES(%s,%s,%s,'ERASURE_METADATA','SYNTHETIC',now()+interval '1 hour') RETURNING id",(f['child_a'],*admins)).fetchone()[0]
                    args=(case,admins[0],f['family_a'],f['child_a'])
                    statement="INSERT INTO ap_m1.compliance_export_bundles(case_id,requested_by_admin,target_family_id,child_id,export_type,expires_at) VALUES(%s,%s,%s,%s,'DSAR',now()+interval '1 hour')"
                    c.execute(statement,args)
                    with self.assertRaises(psycopg.errors.ForeignKeyViolation):
                        with c.transaction():c.execute(statement,(case,admins[0],f['family_b'],f['child_a']))
                    with self.assertRaises(psycopg.errors.ForeignKeyViolation):
                        with c.transaction():c.execute(statement,(case,admins[0],f['family_b'],f['child_b']))
                finally:c.rollback()
        finally:cleanup_domain(f)
