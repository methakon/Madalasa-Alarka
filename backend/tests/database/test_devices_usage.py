"""Restricted-login integration tests. All actors, apps and events are synthetic."""
import unittest
from datetime import datetime, timedelta, timezone
from uuid import uuid4
import psycopg
from psycopg.types.json import Jsonb
try:
    from . import fixtures
except ImportError:
    import fixtures


try:
    from .test_location import domain_fixture, cleanup_domain
except ImportError:
    from test_location import domain_fixture, cleanup_domain


class DevicesUsageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.f = domain_fixture()

    @classmethod
    def tearDownClass(cls):
        cleanup_domain(cls.f)

    def setUp(self):
        self.db = fixtures.runtime_connection()
        self.addCleanup(self.db.close)
        self.addCleanup(self.db.rollback)
        self.device = self.f['device_a']
        self.child = self.f['child_a']
        self.now = datetime.now(timezone.utc)-timedelta(seconds=3)

    def device_actor(self):
        fixtures.as_parent(self.db, None, None, self.device)

    def parent_actor(self):
        fixtures.as_parent(self.db, self.f['a'], self.f['family_a'])

    def test_14_usage_unknown_is_not_zero(self):
        self.device_actor()
        eid = uuid4()
        start = self.now-timedelta(minutes=5)
        for quality, value in [('UNKNOWN',None), ('COMPLETE',0)]:
            result = self.db.execute('select ap_m1.record_usage_interval(%s,%s,%s,%s,%s,%s,%s)',
                (self.device,eid,'invalid.synthetic.app',start,self.now,value,quality)).fetchone()[0]
            self.assertEqual(eid, result)
            self.db.rollback()
            self.device_actor()
        with self.assertRaises(psycopg.Error):
            with self.db.transaction():
                self.db.execute('select ap_m1.record_usage_interval(%s,%s,%s,%s,%s,0,%s)',
                    (self.device,eid,'invalid.synthetic.app',start,self.now,'UNKNOWN'))

    def test_15_usage_retry_overlap_and_scope(self):
        self.device_actor()
        args = (self.device,uuid4(),'invalid.synthetic.app',self.now-timedelta(minutes=5),self.now,1000,'PARTIAL')
        self.db.execute('select ap_m1.record_usage_interval(%s,%s,%s,%s,%s,%s,%s)', args)
        self.db.execute('select ap_m1.record_usage_interval(%s,%s,%s,%s,%s,%s,%s)', args)
        with self.assertRaises(psycopg.Error):
            with self.db.transaction():
                self.db.execute('select ap_m1.record_usage_interval(%s,%s,%s,%s,%s,%s,%s)', (args[0],uuid4(),*args[2:]))
        self.parent_actor()
        self.assertEqual(1, self.db.execute('select count(*) from ap_m1.app_usage_intervals where event_id=%s', (args[1],)).fetchone()[0])
        self.assertEqual(0,self.db.execute('select count(*) from ap_m1.app_usage_intervals where child_id=%s',(self.f['child_b'],)).fetchone()[0])

    def test_16_sos_delivery_is_not_acknowledgement(self):
        self.device_actor()
        eid = uuid4()
        args=(self.device,eid,'SOS',self.now)
        self.assertEqual(eid,self.db.execute('select ap_m1.record_child_signal(%s,%s,%s,%s)',args).fetchone()[0])
        self.db.execute('select ap_m1.record_child_signal(%s,%s,%s,%s)',args)
        self.parent_actor()
        self.assertEqual(0,self.db.execute('select count(*) from ap_m1.signal_acknowledgements where event_id=%s',(eid,)).fetchone()[0])
        self.db.execute('select ap_m1.acknowledge_child_signal(%s,%s)',(self.child,eid))
        self.assertEqual(1,self.db.execute('select count(*) from ap_m1.signal_acknowledgements where event_id=%s',(eid,)).fetchone()[0])

    def test_17_permission_revision_never_rolls_back(self):
        self.device_actor()
        args=(self.device,1,1000001,self.now,Jsonb({'location':'REVOKED','usage':'DENIED'}))
        a=self.db.execute('select ap_m1.report_permissions(%s,%s,%s,%s,%s)',args).fetchone()[0]
        self.assertEqual(a,self.db.execute('select ap_m1.report_permissions(%s,%s,%s,%s,%s)',args).fetchone()[0])
        with self.assertRaises(psycopg.Error):
            with self.db.transaction():
                self.db.execute('select ap_m1.report_permissions(%s,1,1,%s,%s)',(self.device,self.now,Jsonb({'location':'GRANTED'})))

    def test_18_command_requires_device_receipt(self):
        self.parent_actor()
        cmd=uuid4()
        self.db.execute('select ap_m1.request_device_command(%s,%s,%s,%s,%s)',
            (self.child,self.device,cmd,'REFRESH_CAPABILITIES',self.now+timedelta(minutes=5)))
        self.assertEqual('QUEUED',self.db.execute('select command_state from ap_m1.commands where id=%s',(cmd,)).fetchone()[0])
        with self.assertRaises(psycopg.Error):
            with self.db.transaction():
                self.db.execute('select ap_m1.record_command_receipt(%s,%s,1,%s,%s,%s)',
                    (self.device,cmd,'COMPLETED',self.now,'SYNTHETIC'))
        self.device_actor()
        for version,state in [(1,'DELIVERED'),(2,'ACCEPTED'),(3,'COMPLETED')]:
            self.db.execute('select ap_m1.record_command_receipt(%s,%s,%s,%s,%s,%s)',
                (self.device,cmd,version,state,self.now,'SYNTHETIC'))
        self.assertEqual('COMPLETED',self.db.execute('select command_state from ap_m1.commands where id=%s',(cmd,)).fetchone()[0])
        with self.assertRaises(psycopg.Error):
            with self.db.transaction():
                self.db.execute('select ap_m1.record_command_receipt(%s,%s,4,%s,%s,%s)',
                    (self.device,cmd,'FAILED',self.now,'SYNTHETIC'))


    def test_23_rules_are_intents_not_applied_and_revocation_cancels(self):
        self.parent_actor()
        rule=uuid4()
        self.db.execute('select ap_m1.save_screen_time_rule(%s,%s,0,%s,60,%s)',
            (self.child,rule,'invalid.synthetic.app',Jsonb({'timezone':'UTC'})))
        self.assertEqual('BLOCKED',self.db.execute('select legal_gate from ap_m1.screen_time_rules where id=%s',(rule,)).fetchone()[0])
        with self.assertRaises(psycopg.Error):
            with self.db.transaction():
                self.db.execute('select ap_m1.assign_screen_time_rule(%s,%s,%s,%s)',
                    (self.child,self.device,rule,self.now+timedelta(minutes=10)))
        cmd=uuid4()
        self.db.execute('select ap_m1.request_device_command(%s,%s,%s,%s,%s)',
            (self.child,self.device,cmd,'REFRESH_CAPABILITIES',self.now+timedelta(minutes=5)))
        self.db.execute('select ap_m1.revoke_domain_device(%s,%s,null)',(self.child,self.device))
        self.assertEqual('CANCELLED',self.db.execute('select command_state from ap_m1.commands where id=%s',(cmd,)).fetchone()[0])
        self.device_actor()
        with self.assertRaises(psycopg.Error):
            with self.db.transaction():
                self.db.execute('select ap_m1.report_permissions(%s,1,1,%s,%s)',(self.device,self.now,Jsonb({'location':'GRANTED'})))


if __name__ == '__main__':
    unittest.main()
