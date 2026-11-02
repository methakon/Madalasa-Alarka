"""Durable batch membership and fenced reconstruction work, without inferred routes."""
from datetime import datetime,timedelta,timezone
import unittest
from uuid import UUID,uuid4
import psycopg
from psycopg.types.json import Jsonb
import fixtures
from test_location import domain_fixture,cleanup_domain


class IngestionPipelineTests(unittest.TestCase):
    def test_reassignment_cannot_relabel_existing_location(self):
        f=domain_fixture()
        try:
            event={'event_id':str(uuid4()),'sequence':1,'observed_at':(datetime.now(timezone.utc)-timedelta(seconds=2)).isoformat(),
                   'latitude':0.125,'longitude':0.25,'accuracy_m':5,'provider':'SYNTHETIC'}
            with fixtures.runtime_connection() as runtime:
                fixtures.as_parent(runtime,None,None,f['device_a'])
                runtime.execute('SELECT ap_m1.ingest_location_batch(%s,%s,%s)',(f['device_a'],uuid4(),Jsonb([event])))
                runtime.commit()
                with fixtures.admin_connection() as admin:
                    with self.assertRaises(psycopg.errors.ForeignKeyViolation):
                        with admin.transaction():
                            admin.execute('UPDATE ap_m1.devices SET child_id=%s,family_id=%s WHERE id=%s',(f['child_b'],f['family_b'],f['device_a']))
                    admin.rollback()
                fixtures.as_parent(runtime,f['a'],f['family_a'])
                self.assertEqual(runtime.execute('SELECT child_id,event_id FROM ap_m1.location_observations WHERE device_id=%s',(f['device_a'],)).fetchall(),[(f['child_a'],UUID(event['event_id']))])
                runtime.rollback()
                fixtures.as_parent(runtime,f['b'],f['family_b'])
                self.assertEqual(runtime.execute('SELECT count(*) FROM ap_m1.location_observations WHERE device_id=%s',(f['device_a'],)).fetchone()[0],0)
                runtime.rollback()
        finally:self.cleanup(f)

    def test_worker_roles_have_only_their_constrained_interfaces(self):
        with fixtures.admin_connection() as db:
            for role,call in [('ap_service_worker','SELECT * FROM ap_m1.claim_ingestion_jobs(%s,1)'),
                              ('ap_privacy_worker','SELECT ap_m1.restore_can_open(%s)')]:
                db.execute('SET LOCAL ROLE '+role)
                self.assertEqual(db.execute('SELECT current_user').fetchone()[0],role)
                self.assertFalse(db.execute('SELECT rolsuper OR rolbypassrls FROM pg_roles WHERE rolname=current_user').fetchone()[0])
                db.execute(call,(uuid4(),)).fetchall()
                for denied in ('SELECT * FROM ap_m1.location_observations',
                               'SELECT ap_m1.mint_session(NULL::uuid,NULL::uuid,NULL::uuid,interval \'1 hour\')'):
                    with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                        with db.transaction():db.execute(denied)
                db.execute('RESET ROLE')
            db.rollback()

    def cleanup(self,f):
        with fixtures.admin_connection() as admin:
            if admin.execute("SELECT to_regclass('ap_m1.location_batch_items')").fetchone()[0]:
                admin.execute('DELETE FROM ap_m1.location_batch_items WHERE child_id=%s',(f['child_a'],))
        cleanup_domain(f)

    def test_batch_events_have_durable_ordered_membership(self):
        f=domain_fixture()
        try:
            with fixtures.runtime_connection() as runtime:
                fixtures.as_parent(runtime,None,None,f['device_a'])
                event={'event_id':str(uuid4()),'sequence':1,'observed_at':(datetime.now(timezone.utc)-timedelta(seconds=2)).isoformat(),
                       'latitude':0.125,'longitude':0.25,'accuracy_m':5,'provider':'SYNTHETIC'}
                batch=uuid4()
                for _ in range(2):
                    fixtures.as_parent(runtime,None,None,f['device_a'])
                    runtime.execute('SELECT ap_m1.ingest_location_batch(%s,%s,%s)',(f['device_a'],batch,Jsonb([event])))
                    runtime.commit()
                with fixtures.admin_connection() as admin:
                    self.assertIsNotNone(admin.execute("SELECT to_regclass('ap_m1.location_batch_items')").fetchone()[0])
                    self.assertEqual(admin.execute('SELECT item_no,event_id FROM ap_m1.location_batch_items WHERE batch_id=%s',(batch,)).fetchall(),[(1,UUID(event['event_id']))])
                with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                    with runtime.transaction():runtime.execute('SELECT * FROM ap_m1.location_batch_items')
                runtime.rollback()
        finally:self.cleanup(f)

    def test_worker_job_fence_rejects_stale_completion(self):
        with fixtures.admin_connection() as admin:
            self.assertIsNotNone(admin.execute("SELECT to_regprocedure('ap_m1.claim_ingestion_jobs(uuid,integer)')").fetchone()[0])
        f=domain_fixture()
        try:
            with fixtures.admin_connection() as admin:
                batch=uuid4()
                admin.execute("INSERT INTO ap_m1.location_ingest_batches(id,child_id,device_id,payload_digest,item_count,state,membership_complete) VALUES(%s,%s,%s,%s,1,'PROCESSED',true)",(batch,f['child_a'],f['device_a'],b'x'*32))
                job=admin.execute('INSERT INTO ap_m1.ingestion_outbox(child_id,device_id,batch_id) VALUES(%s,%s,%s) RETURNING id',(f['child_a'],f['device_a'],batch)).fetchone()[0]
                worker=uuid4()
                claimed=admin.execute('SELECT job_id,lease_fence FROM ap_m1.claim_ingestion_jobs(%s,50)',(worker,)).fetchall()
                fence=next(row[1] for row in claimed if row[0]==job)
                self.assertFalse(admin.execute('SELECT ap_m1.complete_ingestion_job(%s,%s,%s)',(job,worker,fence+1)).fetchone()[0])
                self.assertTrue(admin.execute('SELECT ap_m1.complete_ingestion_job(%s,%s,%s)',(job,worker,fence)).fetchone()[0])
                admin.rollback()
        finally:self.cleanup(f)
