"""Hermetic metadata fixtures; no provider, database, or application rows."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('schema_export', ROOT / 'tools/database/export_schema.py')
assert spec is not None and spec.loader is not None
export = importlib.util.module_from_spec(spec)
spec.loader.exec_module(export)


def table(name, columns=(), schema='ap_m1', **extra):
    return dict(schema=schema, name=name, kind='r', columns=list(columns), constraints=[], **extra)


class MetadataTests(unittest.TestCase):
    def test_derived_views_are_not_classified_as_direct_tables(self):
        data=json.loads((ROOT/'docs/data-model/local-postgresql/physical-schema.json').read_text())
        kinds={o['schema']+'.'+o['name']:o['kind'] for o in data['objects']}
        mapping=json.loads((ROOT/'docs/data-model/local-postgresql/logical-to-physical.json').read_text())
        for row in mapping['mappings']:
            if any(kinds[target]=='v' for target in row['physical_objects']):
                self.assertEqual(row['representation'],'DERIVED_VIEW',row['concept'])

    def test_pending_policy_and_catalog_only_types(self):
        data = {'objects': [table('children', [{'name': 'id', 'type': 'uuid', 'not_null': True, 'default': None}])], 'foreign_keys': []}
        retention, typed = export.audit_metadata(data, {'ap_m1.children': ['fixture.sql']})
        row = retention['tables'][0]
        self.assertEqual(row['table'], 'ap_m1.children')
        self.assertEqual(row['module_owner'], ['fixture.sql'])
        self.assertTrue(row['child_data'])
        self.assertIsNone(row['candidate_period'])
        self.assertEqual(row['approval_state'], 'OWNER_COUNSEL_PENDING')
        self.assertEqual(row['partition_policy'], 'NONE')
        self.assertEqual(retention['real_child_release'], 'OFF')
        self.assertIsNone(row['erasure_strategy'])
        self.assertEqual(typed['tables'][0]['columns'], data['objects'][0]['columns'])

    def test_missing_owner_fails_closed(self):
        with self.assertRaisesRegex(ValueError, 'module owner'):
            export.audit_metadata({'objects': [table('new_unmapped')], 'foreign_keys': []}, {})
    def test_fk_path_cycle_unknown_and_view_exclusion(self):
        fk = dict(table_schema='ap_m1', table='device_credentials', target_schema='ap_m1', target='devices', name='credential_device_fk', columns=['device_id'], target_columns=['id'])
        data = {'objects': [table('devices', [{'name': 'child_id', 'type': 'uuid'}]),
                            table('device_credentials'), table('unclassified'),
                            dict(schema='ap_m1', name='idempotency_keys', kind='v')],
                'foreign_keys': [fk, dict(fk, table='unclassified', target='unclassified')]}
        retention, typed = export.audit_metadata(data, {f'ap_m1.{n}': ['fixture.sql'] for n in ['devices', 'device_credentials', 'unclassified']})
        rows = {r['table']: r for r in retention['tables']}
        self.assertEqual(retention['table_count'], 3)
        self.assertEqual(typed['table_count'], 3)
        self.assertEqual(rows['ap_m1.device_credentials']['child_owner_path']['foreign_keys'], [fk])
        self.assertEqual(rows['ap_m1.device_credentials']['child_owner_path']['kind'], 'INDIRECT')
        self.assertIsNone(rows['ap_m1.unclassified']['child_data'])
        self.assertIsNone(rows['ap_m1.unclassified']['child_owner_path'])

    def test_raw_check_sql_validation_enum_and_inventory_preserved(self):
        raw = "CHECK ((state = ANY (ARRAY['PENDING'::text, 'DONE'::text])))"
        obj = table('queue', [{'name': 'state', 'type': 'text', 'not_null': True, 'default': None},
                              {'name': 'received_at', 'type': 'timestamp with time zone'}])
        obj['constraints'] = [dict(name='queue_state', kind='c', definition=raw, validated=False)]
        enums = [dict(schema='ap_m1', name='event_kind', labels=['FIRST', 'SECOND'])]
        inventory = [dict(table_name='queue', key_kind='DEVICE', purge_order=5)]
        retention, typed = export.audit_metadata({'objects': [obj], 'erasure_inventory': inventory, 'enums': enums}, {'ap_m1.queue': ['fixture.sql']})
        self.assertEqual(typed['tables'][0]['check_constraints'][0]['definition'], raw)
        self.assertIs(typed['tables'][0]['check_constraints'][0]['validated'], False)
        self.assertEqual(typed['enums'], enums)
        self.assertNotIn('allowed_values', typed['tables'][0])
        self.assertEqual(retention['tables'][0]['erasure_strategy']['key_kind'], 'DEVICE')
        self.assertEqual(retention['tables'][0]['retention_clock'], 'received')
        self.assertEqual(retention['tables'][0]['time_column'], 'received_at')
        self.assertIsNone(retention['tables'][0]['candidate_period'])

    def test_partition_and_legacy_unknowns(self):
        obj = table('events', [{'name': 'created_at', 'type': 'timestamp with time zone'}], partition_key='RANGE (created_at)')
        obj['kind'] = 'p'
        obj['constraints'] = [dict(name='old', kind='c', definition='CHECK (n > 0)')]
        retention, typed = export.audit_metadata({'objects': [obj]}, {'ap_m1.events': ['fixture.sql']})
        self.assertEqual(retention['tables'][0]['partition_policy'], 'PARTITIONED')
        self.assertEqual(retention['tables'][0]['partition_key'], 'RANGE (created_at)')
        self.assertIsNone(retention['tables'][0]['time_column'])
        self.assertIsNone(typed['enums'])
        self.assertIsNone(typed['tables'][0]['check_constraints'][0]['validated'])
        self.assertFalse(retention['erasure_inventory_captured'])

    def test_source_mapping_keeps_colliding_lineage_declarations(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            migrations = root / 'backend/persistence/migrations'
            migrations.mkdir(parents=True)
            for filename in ['0002_m1.sql', '0017_compat.sql']:
                (migrations / filename).write_text('CREATE TABLE IF NOT EXISTS ap_m1.device_credentials (id uuid);')
            (migrations / '0004_m1.sql').write_text('CREATE TABLE ap_m1.idempotency_keys (id uuid);\n-- CREATE TABLE ap_m1.not_real (id uuid);')
            owners = export.migration_table_owners(root)
            self.assertEqual(len(owners['ap_m1.device_credentials']), 2)
            self.assertIn('ap_m1.idempotency_keys', owners)
            self.assertNotIn('ap_m1.not_real', owners)

    def test_offline_catalog_complete_coverage_and_dropped_owner_control(self):
        data = json.loads((ROOT / 'docs/data-model/local-postgresql/physical-schema.json').read_text())
        owners = export.migration_table_owners(ROOT)
        retention, typed = export.audit_metadata(data, owners)
        expected = {o['schema'] + '.' + o['name'] for o in data['objects'] if o['schema'] in export.AUDIT_SCHEMAS and o['kind'] in ('r', 'p')}
        self.assertEqual({r['table'] for r in retention['tables']}, expected)
        self.assertEqual({r['table'] for r in typed['tables']}, expected)
        self.assertEqual(retention['table_count'], len(expected))
        for name in ['device_credentials', 'credential_renewal_challenges', 'idempotency_keys']:
            self.assertTrue(owners['ap_m1.' + name])
        for row in retention['tables']:
            self.assertIsNone(row['candidate_period'])
            self.assertEqual(row['approval_state'], 'OWNER_COUNSEL_PENDING')
        del owners[sorted(expected)[0]]
        with self.assertRaisesRegex(ValueError, 'module owner'):
            export.audit_metadata(data, owners)


if __name__ == '__main__':
    unittest.main()
