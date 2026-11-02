"""Synthetic completion acceptance. Parent replays SQL before database execution.
Source-only RED: SCHEMA_COMPLETION_SOURCE_ONLY=1 python3 -m unittest discover
-s backend/tests/database -p test_schema_completion.py -v
"""
import json
import os
import re
from pathlib import Path
import unittest
from uuid import uuid4

ROOT = Path(__file__).resolve().parents[3]
MIGRATION = ROOT / 'backend/persistence/migrations/0012_screen_dependency_completion.sql'
TABLES = ('commute_plans', 'commute_plan_revisions', 'installed_app_inventory',
          'usage_categories', 'scheduled_child_tasks', 'media_request_device_approvals',
          'tracking_policy_revisions', 'trip_legs', 'stops', 'admin_cases',
          'admin_case_scopes', 'notification_preferences')


# Full normalization is logical_to_physical(); unchanged logical names map to
# their exact table/view. Tuples identify normalized storage, not invented tables.
NORMALIZED_ALIASES = {
    'adult_accounts': ('parent_principals', 'trusted_principal_verifications'),
    'family_memberships': ('guardian_memberships',),
    'family_revocation_epochs': ('revocation_epochs',),
    'child_devices': ('devices', 'capability_snapshots', 'device_health'),
    'device_commands': ('commands', 'command_receipts'),
    'device_sessions': ('trusted_sessions',),  # session_kind = DEVICE
    'parent_auth_sessions': ('trusted_sessions',),  # session_kind = PARENT
    'app_usage_events': ('app_usage_intervals',),
    'child_checkins': ('child_signals',),  # kind <> SOS
    'sos_events': ('child_signals',),  # kind = SOS
    'sos_acknowledgements': ('signal_acknowledgements',),  # join SOS child_signals
    'admin_principals': ('admin_accounts', 'admin_sessions', 'admin_role_grants'),
    'support_cases': ('support_tickets',),
    'export_requests': ('export_jobs',),
    'reconstruction_jobs': ('ingestion_outbox',),

    'geofence_events': ('alert_events',),  # kind in ARRIVE, EXIT, UNKNOWN
    'usage_permission_checks': ('permission_snapshots', 'capability_snapshots', 'feature_release_gates'),
    'purpose_authorizations': ('consent_records', 'child_authority_reviews'),
    'admin_read_audit': ('admin_support_read_audit', 'admin_action_audit'),
}
# Representation is not acceptance of every aspirational logical column.
GENUINE_GAPS = {
    'reconstruction_jobs': '0015 adds durable membership, affected ranges and lease-fenced claim/completion; no autonomous reconstruction consumer is wired.',
    'admin_read_audit': 'Support reads are audited; metadata-only case SELECT has no automatic case-bound digest audit. No raw-child case access is enabled.',
    'scheduled_child_tasks': 'Disabled future metadata only: no scheduler or constrained task mutation interface.',
    'tracking_policy_revisions': 'Blocked policy metadata only: no cadence worker or device acknowledgement mutation.',
    'media_request_device_approvals': 'No real UI/device approval handler or capture release; synthetic/negative metadata only.',
    'notification_preferences': 'Preference persistence only: no constrained preference mutation or provider-dispatch integration.',
    'trip_legs': 'Observed-endpoint annotation store only: no inference worker or computed distances.',
    'stops': 'Observed-endpoint annotation store only: no stop detector, invented center or fake exact arrival.',
}


def logical_to_physical():
    source = json.loads((ROOT / 'docs/data-model/MADALASA_ALARKA_FIGMA_LOGICAL_ERD_V1_2026.json').read_text())
    return {table['name']: NORMALIZED_ALIASES.get(table['name'], (table['name'],))
            for domain in source['domains'] for table in domain['tables']}


class CompletionSourceTests(unittest.TestCase):
    def test_all_logical_entities_have_explicit_normalization(self):
        mapping = logical_to_physical()
        source = json.loads((ROOT / 'docs/data-model/MADALASA_ALARKA_FIGMA_LOGICAL_ERD_V1_2026.json').read_text())
        self.assertEqual(len(mapping), source.get('tableCount', 124))
        sql = '\n'.join(file.read_text() for file in sorted(MIGRATION.parent.glob('*.sql')))
        physical = set(re.findall(r'CREATE\s+(?:TABLE|VIEW|FUNCTION)\s+ap_m1\.(\w+)', sql, re.I))
        for name, targets in mapping.items():
            for target in targets:
                self.assertIn(target, physical, (name, target))

    def test_completion_ddl_is_present(self):
        self.assertTrue(MIGRATION.exists(), 'completion migration is missing')
        sql = MIGRATION.read_text()
        for table in TABLES:
            self.assertIn('CREATE TABLE ap_m1.' + table, sql)
        for view in ('usage_period_summaries', 'route_geometry', 'history_visibility_rules'):
            self.assertIn('CREATE VIEW ap_m1.' + view + ' WITH(security_invoker=true)', sql)


@unittest.skipIf(os.environ.get('SCHEMA_COMPLETION_SOURCE_ONLY') == '1', 'source-only inspection')
class SchemaCompletionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        try:
            from . import fixtures
        except ImportError:
            import fixtures
        cls.fixtures = fixtures
        cls.core = fixtures.seed_core()

    def setUp(self):
        self.db = self.fixtures.runtime_connection()
        self.addCleanup(self.db.close)
        self.addCleanup(self.db.rollback)
        self.admin = self.fixtures.admin_connection()
        self.addCleanup(self.admin.close)
        self.addCleanup(self.admin.rollback)
        self.c = self.core['child_a']
        self.d = self.core['device_a']

    def parent(self):
        self.fixtures.as_parent(self.db, self.core['a'], self.core['family_a'])

    def test_tables_force_rls_and_runtime_has_no_direct_mutation(self):
        import psycopg
        for name in TABLES:
            with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                with self.db.transaction():
                    self.db.execute('DELETE FROM ap_m1.'+name+' WHERE false')
            row = self.admin.execute("SELECT relrowsecurity,relforcerowsecurity FROM pg_class WHERE oid=%s::regclass", ('ap_m1.'+name,)).fetchone()
            self.assertEqual(row, (True, True), name)
            for privilege in ('INSERT', 'UPDATE', 'DELETE'):
                self.assertFalse(self.admin.execute('SELECT has_table_privilege(\'ap_m1_api\',%s,%s)', ('ap_m1.'+name,privilege)).fetchone()[0], (name,privilege))
            self.assertEqual(self.db.execute('SELECT count(*) FROM ap_m1.'+name).fetchone()[0], 0, name)

    def test_commute_revision_cas_and_unauthorized_mutation(self):
        import psycopg
        from psycopg.types.json import Jsonb
        plan = uuid4()
        args = (self.c, plan, 0, None, None, Jsonb({'timezone':'Asia/Kolkata','days_of_week':[1,2], 'expected_arrival_from':'08:00','expected_arrival_to':'09:00'}), 'synthetic create')
        with self.assertRaises(psycopg.errors.InsufficientPrivilege):
            with self.db.transaction():
                self.db.execute('SELECT ap_m1.save_commute_plan(%s,%s,%s,%s,%s,%s,%s)',args)
        self.parent()
        self.assertEqual(self.db.execute('SELECT ap_m1.save_commute_plan(%s,%s,%s,%s,%s,%s,%s)',args).fetchone()[0],1)
        update = (self.c,plan,1,*args[3:])
        self.assertEqual(self.db.execute('SELECT ap_m1.save_commute_plan(%s,%s,%s,%s,%s,%s,%s)',update).fetchone()[0],2)
        with self.assertRaises(psycopg.errors.SerializationFailure):
            with self.db.transaction():
                self.db.execute('SELECT ap_m1.save_commute_plan(%s,%s,%s,%s,%s,%s,%s)',update)
        self.assertEqual(self.db.execute('SELECT count(*) FROM ap_m1.commute_plan_revisions WHERE plan_id=%s',(plan,)).fetchone()[0],2)
        self.db.execute('SET CONSTRAINTS ALL IMMEDIATE')

    def test_usage_unknown_is_not_zero_and_inventory_device_binding(self):
        import psycopg
        self.fixtures.as_parent(self.db,None,None,self.d)
        package = 'invalid.synthetic.' + uuid4().hex
        self.db.execute("SELECT ap_m1.record_usage_interval(%s,%s,%s,now()-interval '20 minutes',now()-interval '10 minutes',NULL,'UNKNOWN')",(self.d,uuid4(),package))
        self.db.execute("SELECT ap_m1.report_installed_app(%s,%s,NULL,'PARTIAL',now()-interval '1 second')",(self.d,package))
        self.parent()
        row = self.db.execute('SELECT observed_seconds,coverage_quality FROM ap_m1.usage_period_summaries WHERE child_id=%s AND package_name=%s',(self.c,package)).fetchone()
        self.assertEqual(row,(None,'UNKNOWN'))
        self.assertEqual(self.db.execute('SELECT count(*) FROM ap_m1.installed_app_inventory WHERE package_name=%s',(package,)).fetchone()[0],1)
        with self.assertRaises(psycopg.errors.InsufficientPrivilege):
            with self.db.transaction():
                self.db.execute("SELECT ap_m1.report_installed_app(%s,%s,NULL,'PARTIAL',now())",(self.d,package))
        self.fixtures.as_parent(self.db,self.core['b'],self.core['family_b'])
        self.assertEqual(self.db.execute('SELECT count(*) FROM ap_m1.usage_period_summaries WHERE package_name=%s',(package,)).fetchone()[0],0)
        self.assertEqual(self.db.execute('SELECT count(*) FROM ap_m1.installed_app_inventory WHERE package_name=%s',(package,)).fetchone()[0],0)

    def test_media_approval_cannot_bind_another_child_or_device(self):
        import psycopg
        request = uuid4()
        self.admin.execute("INSERT INTO ap_m1.media_command_requests(id,child_id,device_id,adult_id,kind) VALUES(%s,%s,%s,%s,'IMAGE')",(request,self.c,self.d,self.core['a']))
        with self.assertRaises(psycopg.errors.ForeignKeyViolation):
            with self.admin.transaction():
                self.admin.execute("INSERT INTO ap_m1.media_request_device_approvals(child_id,request_id,device_id,device_ui_consent_state,os_decision_reason) VALUES(%s,%s,%s,'NOT_REQUESTED','FEATURE_NOT_RELEASED')",(self.core['child_b'],request,self.d))
        self.admin.execute("INSERT INTO ap_m1.media_request_device_approvals(child_id,request_id,device_id,device_ui_consent_state,os_decision_reason) VALUES(%s,%s,%s,'NOT_REQUESTED','FEATURE_NOT_RELEASED')",(self.c,request,self.d))
        # A second device of the SAME child is still the wrong device for a request
        # bound to the first one; approval rows are one per request, so use a new request.
        other_device=uuid4()
        self.admin.execute("INSERT INTO ap_m1.devices(id,family_id,child_id,spki_public_key,enrollment_state) VALUES(%s,%s,%s,%s,'ACTIVE')",(other_device,self.core['family_a'],self.c,('SYNTHETIC-NOT-CRYPTO-'+str(other_device)).encode()*2))
        second_request=uuid4()
        self.admin.execute("INSERT INTO ap_m1.media_command_requests(id,child_id,device_id,adult_id,kind) VALUES(%s,%s,%s,%s,'IMAGE')",(second_request,self.c,self.d,self.core['a']))
        with self.assertRaises(psycopg.errors.ForeignKeyViolation):
            with self.admin.transaction():
                self.admin.execute("INSERT INTO ap_m1.media_request_device_approvals(child_id,request_id,device_id,device_ui_consent_state,os_decision_reason) VALUES(%s,%s,%s,'NOT_REQUESTED','FEATURE_NOT_RELEASED')",(self.c,second_request,other_device))
        self.admin.execute('DELETE FROM ap_m1.media_command_requests WHERE id=%s',(second_request,))
        self.admin.execute('DELETE FROM ap_m1.devices WHERE id=%s',(other_device,))
        with self.assertRaises(psycopg.errors.UniqueViolation):
            with self.admin.transaction():
                self.admin.execute("INSERT INTO ap_m1.media_request_device_approvals(child_id,request_id,device_id,device_ui_consent_state,os_decision_reason) VALUES(%s,%s,%s,'NOT_REQUESTED','FEATURE_NOT_RELEASED')",(self.c,request,self.d))

    def test_composite_place_child_and_revision_constraints(self):
        import psycopg
        place = uuid4()
        self.admin.execute("INSERT INTO ap_m1.named_places(id,child_id,created_by,title,position,radius_m) VALUES(%s,%s,%s,'Synthetic',public.ST_SetSRID(public.ST_MakePoint(0,0),4326)::public.geography,100)",(place,self.core['child_b'],self.core['b']))
        with self.assertRaises(psycopg.errors.ForeignKeyViolation):
            with self.admin.transaction():
                self.admin.execute('INSERT INTO ap_m1.commute_plans(id,child_id,created_by,start_place_id) VALUES(%s,%s,%s,%s)',(uuid4(),self.c,self.core['a'],place))
        with self.assertRaises(psycopg.errors.ForeignKeyViolation):
            with self.admin.transaction():
                self.admin.execute("INSERT INTO ap_m1.tracking_policy_revisions(child_id,device_id,policy_version,frequency_class,effective_at,expires_at) VALUES(%s,%s,1,'DISABLED',now(),now()+interval '1 hour')",(self.core['child_b'],self.d))

    def test_new_columns_function_hardening_and_typed_sessions(self):
        columns = {
            'trusted_sessions': {'session_kind'},
            'commute_plans': {'child_id','revision','start_place_id','end_place_id','legal_history_gate'},
            'commute_plan_revisions': {'supersedes_revision','timezone','days_of_week','expected_window'},
            'installed_app_inventory': {'visibility_mode','category_id','observed_at','revision'},
            'media_request_device_approvals': {'request_id','device_id','child_id','real_capture_enabled'},
        }
        for table, expected in columns.items():
            actual = {row[0] for row in self.admin.execute("SELECT attname FROM pg_attribute WHERE attrelid=%s::regclass AND attnum>0 AND NOT attisdropped",('ap_m1.'+table,))}
            self.assertTrue(expected <= actual,(table,expected-actual))
        for name in ('save_commute_plan','report_installed_app'):
            row = self.admin.execute("SELECT p.prosecdef,r.rolname,p.proconfig,EXISTS(SELECT 1 FROM aclexplode(p.proacl) a WHERE a.grantee=0 AND a.privilege_type='EXECUTE') FROM pg_proc p JOIN pg_roles r ON r.oid=p.proowner JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='ap_m1' AND p.proname=%s",(name,)).fetchone()
            self.assertEqual(row[0:2],(True,'ap_db_executor'))
            self.assertTrue(any(value.startswith('search_path=pg_catalog, ap_m1, public') for value in row[2]))
            self.assertFalse(row[3])

    def test_invoker_views_and_erasure_inventory(self):
        for view in ('route_geometry','usage_period_summaries','history_visibility_rules'):
            options = self.admin.execute('SELECT reloptions FROM pg_class WHERE oid=%s::regclass',('ap_m1.'+view,)).fetchone()[0]
            self.assertIn('security_invoker=true',options)
        self.admin.execute('SET LOCAL ROLE ap_db_executor')
        rows = dict(self.admin.execute('SELECT table_name,purge_order FROM ap_m1.erasure_store_inventory').fetchall())
        for name in set(TABLES)-{'usage_categories'}:
            self.assertIn(name,rows)
        self.assertLess(rows['commute_plan_revisions'],rows['commute_plans'])
        self.assertLess(rows['commute_plans'],rows['named_places'])
        self.assertLess(rows['trip_legs'],rows['trip_routepoints'])
        self.assertLess(rows['stops'],rows['trip_routepoints'])
        self.assertLess(rows['admin_case_scopes'],rows['admin_cases'])
        self.assertNotIn('usage_period_summaries',rows)
        self.admin.execute('RESET ROLE')


if __name__ == '__main__':
    unittest.main()
