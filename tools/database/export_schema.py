#!/usr/bin/env python3
"""Export PostgreSQL catalog facts and source-linked schema/API traceability.

Catalog only: no application rows, role passwords, tokens or connection strings.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ALIASES = {
 'adult_accounts':['parent_principals'], 'family_memberships':['guardian_memberships'],
 'family_revocation_epochs':['revocation_epochs'], 'child_devices':['devices'],
 'device_commands':['commands'], 'device_sessions':['trusted_sessions'],
 'parent_auth_sessions':['trusted_sessions'], 'app_usage_events':['app_usage_intervals'],
 'child_checkins':['child_signals'], 'sos_events':['child_signals'],
 'sos_acknowledgements':['signal_acknowledgements'], 'geofence_events':['alert_events'],
 'admin_principals':['admin_accounts'], 'admin_read_audit':['admin_support_read_audit'],
 'support_cases':['support_tickets'], 'export_requests':['export_jobs','media_export_requests'],
 'purpose_authorizations':['consent_records'], 'reconstruction_jobs':['ingestion_outbox'],

 'usage_permission_checks':['permission_snapshots','app_usage_intervals'],
 # Historical screen-register spellings; V2 is the current authorization source.
 'child_guardian_grants':['child_access_grants_v2'], 'child_parent_verifications':['child_authority_reviews'],
}
FUNCTION_ALIASES = {'history_visibility_rules':['can_read_location_history']}
HANDLERS = {'GET /parents/me':'profile', 'GET /children/{childId}':'child',
            'GET /families/{familyId}/children':'children', 'GET /children/{childId}/consents':'consents'}


def read_json(path):
    return json.loads(path.read_text())


def normalize(route):
    return re.sub(r'\{[^}]+\}','{id}',route)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


# Manual ownership is limited to runner-created schema bookkeeping. It does not
# declare those tables nonpersonal, nor approve any retention policy.
MANUAL_MODULE_OWNERS = {
    'ma_migrations.history': ['tools/database/manage.py:migrate migration history DDL'],
    'ma_migrations.lineage_history': ['tools/database/manage.py:migrate namespaced migration history DDL'],
}
AUDIT_SCHEMAS = {'ap_m1', 'ma_recovery', 'ma_migrations'}


def migration_table_owners(root):
    """Source traceability, NOT migration execution/discovery or lineage ordering.

    All declaring files are retained, including historical duplicate declarations.
    Unrecognized/dynamic DDL fails coverage instead of receiving a fallback owner.
    """
    owners = {key: list(value) for key, value in MANUAL_MODULE_OWNERS.items()}
    for path in sorted((root / 'backend/persistence/migrations').rglob('*.sql')):
        text = re.sub(r'/\*.*?\*/|--[^\n]*', '', path.read_text(), flags=re.S)
        for schema, name in re.findall(
                r'\bCREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?'
                r'(ap_m1|ma_recovery|ma_migrations)\.([a-z_][a-z_0-9]*)', text, re.I):
            key = schema.lower() + '.' + name.lower()
            source = str(path.relative_to(root))
            if source not in owners.setdefault(key, []):
                owners[key].append(source)
    return owners


def audit_metadata(data, owners):
    """Pure projection of schema/config facts; unknown is null, never approval.

    child_data=True means a direct child identifier or outbound FK path to one.
    No such path is NOT proof of nonpersonal data: child_data remains null.
    FK paths describe schema reachability, not authorization or row ownership.
    Time selection uses only explicitly named clocks; created_at/updated_at are
    deliberately not guessed to be observed/received/processed timestamps.
    """
    objects = {o['schema'] + '.' + o['name']: o for o in data['objects']
               if o['schema'] in AUDIT_SCHEMAS and o['kind'] in ('r', 'p')}
    missing = sorted(key for key in objects if not owners.get(key))
    if missing:
        raise ValueError('Missing explicit module owner: ' + ', '.join(missing))
    inventory = {r['table_name']: r for r in data.get('erasure_inventory', [])}
    edges = {}
    for fk in data.get('foreign_keys', []):
        key = fk['table_schema'] + '.' + fk['table']
        edges.setdefault(key, []).append(fk)

    def owner_path(start):
        queue = [(start, [])]
        seen = set()
        while queue:
            key, path = queue.pop(0)
            if key in seen or key not in objects:
                continue
            seen.add(key)
            obj = objects[key]
            columns = {c['name'] for c in obj['columns']}
            if key == 'ap_m1.children' or 'child_id' in columns:
                return {'kind': 'DIRECT' if not path else 'INDIRECT', 'foreign_keys': path,
                        'terminal': key + ('.id' if key == 'ap_m1.children' else '.child_id'),
                        'basis': 'CATALOG_COLUMN; child_id may intentionally lack FK (erasure tombstones)'}
            for fk in edges.get(key, []):
                queue.append((fk['target_schema'] + '.' + fk['target'], path + [fk]))
        return None

    retention = []
    typed = []
    for key, obj in sorted(objects.items()):
        path = owner_path(key)
        columns = {c['name']: c for c in obj['columns']}
        clock, time_column = 'configuration', None
        for column, clock_kind in [('observed_at', 'observed'), ('received_at', 'received'),
                                   ('closed_at', 'closed'), ('processed_at', 'processed')]:
            if column in columns and columns[column]['type'].startswith('timestamp'):
                clock, time_column = clock_kind, column
                break
        store = inventory.get(obj['name']) if obj['schema'] == 'ap_m1' else None
        retention.append({
            'schema': obj['schema'], 'table': key, 'module_owner': owners[key],
            'module_owner_basis': 'DECLARING_MIGRATION_FILES_OR_DOCUMENTED_MANUAL_MAP',
            'child_data': True if path else None, 'child_owner_path': path,
            'child_data_unknown_reason': None if path else 'No catalog child identifier/outbound FK path; manual classification required',
            'retention_category': 'CHILD_LINKED_POLICY_PENDING' if path else 'UNCLASSIFIED_POLICY_PENDING',
            'time_column': time_column, 'retention_clock': clock,
            'clock_basis': 'EXPLICIT_COLUMN_NAME' if time_column else 'NO_APPROVED_DATA_CLOCK; configuration placeholder, not TTL',
            'candidate_period': None, 'approval_state': 'OWNER_COUNSEL_PENDING',
            'erasure_strategy': None if store is None else {
                'source': 'ap_m1.erasure_store_inventory', 'key_kind': store['key_kind'],
                'purge_order': store['purge_order'], 'operation': 'CONFIGURED_PRIMARY_PURGE'},
            'erasure_strategy_unknown_reason': None if store else 'Not in captured inventory; null does not mean exempt or unimplemented',
            'backup_restore_effect': 'PRIMARY_PURGE_NOT_BACKUP_ERASURE; RESTORE_SUPPRESSION_REQUIRES_INDEPENDENT_LEDGER_AND_VERIFICATION',
            'audit_legal_hold_exception': 'PENDING_CONFIGURED_POLICY',
            'partition_policy': 'PARTITIONED' if obj['kind'] == 'p' else 'NONE',
            'partition_key': obj.get('partition_key'),
        })
        typed.append({'table': key, 'columns': obj['columns'],
                      'check_constraints': [dict(c, validated=c.get('validated'))
                                            for c in obj['constraints'] if c['kind'] == 'c'],
                      'foreign_keys': edges.get(key, []),
                      'value_interpretation': 'RAW_CATALOG_SQL_ONLY; no unchecked text values inferred'})
    return ({'real_child_release': 'OFF', 'policy_approval': 'NONE',
             'erasure_inventory_captured': 'erasure_inventory' in data,
             'table_count': len(retention), 'tables': retention},
            {'source': 'POSTGRESQL_CATALOG_NOT_APPLICATION_ROWS',
             'table_count': len(typed), 'tables': typed, 'enums': data.get('enums'),
             'enum_capture_state': 'CAPTURED' if 'enums' in data else 'UNKNOWN_LEGACY_CATALOG'})


def catalog(database):
    import manage
    with manage.connect(database,'admin') as conn:
        objects=[]
        for schema,name,kind,rls,forced in conn.execute("""SELECT n.nspname,c.relname,c.relkind,c.relrowsecurity,c.relforcerowsecurity
          FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
          WHERE n.nspname IN ('ap_m1','ma_migrations','ma_recovery') AND c.relkind IN ('r','p','v') ORDER BY n.nspname,c.relname"""):
            columns=conn.execute("""SELECT a.attname,format_type(a.atttypid,a.atttypmod),a.attnotnull,
              pg_get_expr(d.adbin,d.adrelid) FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum
              WHERE a.attrelid=(%s||'.'||%s)::regclass AND a.attnum>0 AND NOT a.attisdropped ORDER BY a.attnum""",(schema,name)).fetchall()
            constraints=conn.execute("SELECT conname,contype,pg_get_constraintdef(oid),convalidated FROM pg_constraint WHERE conrelid=(%s||'.'||%s)::regclass ORDER BY conname",(schema,name)).fetchall()
            objects.append({'schema':schema,'name':name,'kind':kind,'rls':rls,'forced_rls':forced,
                            'columns':[dict(name=v[0],type=v[1],not_null=v[2],default=v[3]) for v in columns],
                            'constraints':[dict(name=v[0],kind=v[1],definition=v[2],validated=v[3]) for v in constraints],
                            'partition_key': conn.execute('SELECT pg_get_partkeydef((%s||\'.\'||%s)::regclass)', (schema,name)).fetchone()[0]})
        indexes=[dict(schema=r[0],table=r[1],name=r[2],definition=r[3]) for r in conn.execute("SELECT schemaname,tablename,indexname,indexdef FROM pg_indexes WHERE schemaname IN ('ap_m1','ma_migrations','ma_recovery') ORDER BY schemaname,indexname")]
        policies=[dict(schema=r[0],table=r[1],name=r[2],roles=r[3],command=r[4],using=r[5],check=r[6]) for r in conn.execute("SELECT schemaname,tablename,policyname,roles::text[],cmd,qual,with_check FROM pg_policies WHERE schemaname IN ('ap_m1','ma_recovery') ORDER BY schemaname,tablename,policyname")]
        functions=[dict(schema=r[0],name=r[1],signature=r[2],security_definer=r[3],owner=r[4],settings=r[5]) for r in conn.execute("SELECT n.nspname,p.proname,pg_get_function_identity_arguments(p.oid),p.prosecdef,pg_get_userbyid(p.proowner),p.proconfig FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname IN ('ap_m1','ma_recovery') ORDER BY n.nspname,p.proname,p.oid")]
        foreign_keys=[dict(table_schema=r[0],table=r[1],target_schema=r[2],target=r[3],name=r[4],definition=r[5],columns=r[6],target_columns=r[7]) for r in conn.execute("""
            SELECT n.nspname,c.relname,rn.nspname,rc.relname,k.conname,pg_get_constraintdef(k.oid),
              ARRAY(SELECT a.attname FROM unnest(k.conkey) WITH ORDINALITY s(num,ord)
                    JOIN pg_attribute a ON a.attrelid=k.conrelid AND a.attnum=s.num ORDER BY s.ord),
              ARRAY(SELECT a.attname FROM unnest(k.confkey) WITH ORDINALITY s(num,ord)
                    JOIN pg_attribute a ON a.attrelid=k.confrelid AND a.attnum=s.num ORDER BY s.ord)
            FROM pg_constraint k JOIN pg_class c ON c.oid=k.conrelid
            JOIN pg_namespace n ON n.oid=c.relnamespace JOIN pg_class rc ON rc.oid=k.confrelid
            JOIN pg_namespace rn ON rn.oid=rc.relnamespace
            WHERE k.contype='f' AND n.nspname IN ('ap_m1','ma_recovery','ma_migrations')
            ORDER BY n.nspname,c.relname,k.conname""")]
        # This single allowlisted table is schema/configuration metadata, not child rows.
        erasure_inventory=[dict(table_name=r[0],key_kind=r[1],purge_order=r[2]) for r in conn.execute(
            'SELECT table_name,key_kind,purge_order FROM ap_m1.erasure_store_inventory ORDER BY purge_order')]
        enums=[dict(schema=r[0],name=r[1],labels=r[2]) for r in conn.execute("""
            SELECT n.nspname,t.typname,array_agg(e.enumlabel ORDER BY e.enumsortorder)
            FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace
            JOIN pg_enum e ON e.enumtypid=t.oid
            WHERE n.nspname IN ('ap_m1','ma_recovery','ma_migrations') OR EXISTS (
              SELECT 1 FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid
              JOIN pg_namespace cn ON cn.oid=c.relnamespace
              WHERE a.atttypid=t.oid AND a.attnum>0 AND NOT a.attisdropped
              AND cn.nspname IN ('ap_m1','ma_recovery','ma_migrations'))
            GROUP BY n.nspname,t.typname ORDER BY n.nspname,t.typname""")]
    return {'objects':objects,'indexes':indexes,'policies':policies,'functions':functions,
            'foreign_keys':foreign_keys,'erasure_inventory':erasure_inventory,'enums':enums}


def build(database):
    import manage
    root=manage.ROOT
    data=catalog(database)
    retention, typed = audit_metadata(data, migration_table_owners(root))
    names={o['name'] for o in data['objects'] if o['schema']=='ap_m1'}
    kinds={o['name']:o['kind'] for o in data['objects'] if o['schema']=='ap_m1'}
    functions={f['name'] for f in data['functions'] if f['schema']=='ap_m1'}
    model=read_json(root/'docs/data-model/MADALASA_ALARKA_FIGMA_LOGICAL_ERD_V1_2026.json')
    mappings=[];missing=[]
    for domain in model['domains']:
        for entity in domain['tables']:
            name=entity['name']
            targets=ALIASES.get(name,[name])
            fn=[]
            if not set(targets)<=names and name in FUNCTION_ALIASES:
                targets=[];fn=FUNCTION_ALIASES[name]
            absent=set(targets)-names | (set(fn)-functions)
            if absent:missing.append({'concept':name,'missing':sorted(absent)})
            mappings.append({'concept':name,'domain':domain['title'],'physical_objects':['ap_m1.'+v for v in targets],
                             'functions':['ap_m1.'+v for v in fn],
                             'representation':('DERIVED_VIEW' if any(kinds.get(t)=='v' for t in targets)
                                               else 'FUNCTION' if fn else 'DIRECT' if targets==[name] else 'NORMALIZED'),
                             'scope':'PHYSICAL_SCHEMA_NOT_API_OR_ANDROID_COMPLETION'})
    if missing:raise ValueError('Unmapped logical dependencies: '+json.dumps(missing))
    assert len(mappings)==len({m['concept'] for m in mappings})==model['tableCount']
    logical={m['concept']:m['physical_objects'] for m in mappings}
    coverage=read_json(root/'docs/audits/POST_REMEDIATION_SCREEN_API_DB_COVERAGE_2026-10-28.json')['screen_coverage']
    routes={}
    for screen in coverage:
        for route in set(screen['documented_routes_in_current_draft']+screen['supplemental_draft_routes']):
            value=routes.setdefault(normalize(route),{'screens':[],'objects':set(),'unmapped_screen_terms':set()})
            value['screens'].append({'source':screen['source'],'screen':screen['screen_key'],'figma_node_id':screen['figma_node_id']})
            for term in screen['related_logical_tables']:
                if term in logical:value['objects'].update(logical[term])
                elif term in ALIASES and set(ALIASES[term])<=names:value['objects'].update('ap_m1.'+v for v in ALIASES[term])
                elif term in names:value['objects'].add('ap_m1.'+term)
                else:value['unmapped_screen_terms'].add(term)
    spec=read_json(root/'docs/openapi.yaml');api=[]
    for path,item in spec['paths'].items():
        for method,operation in item.items():
            if method not in ('get','post','patch','put','delete'):continue
            key=method.upper()+' '+path
            match=routes.get(normalize(key),{'screens':[],'objects':set(),'unmapped_screen_terms':set()})
            api.append({'operation':key,'operation_id':operation['operationId'],'physical_dependencies':sorted(match['objects']),
                        'source_screens':match['screens'],'unmapped_historical_terms':sorted(match['unmapped_screen_terms']),
                        'mapping_method':'SCREEN_REGISTER_DEPENDENCY_NOT_HANDLER_BINDING',
                        'handler':'backend/src/Database.cc:'+HANDLERS[key] if key in HANDLERS else None,
                        'handler_status':'IMPLEMENTED_LOCAL_SESSION_ADAPTER' if key in HANDLERS else 'PENDING',
                        'http_acceptance':'SEE_EXECUTED_EVIDENCE' if key in HANDLERS else 'NOT_IMPLEMENTED',
                        'android_integration':'NOT_RUN'})
    manifest={'historical_0001_sha256':manage.BASELINE_SHA256,'runner':'tools/database/manage.py',
              'scope':'PINNED_SOURCE_LINEAGES_NOT_INSTALLED_HISTORY',
              'lineage_manifest':'backend/persistence/migration-lineages.json',
              'migrations':[{'version':entry['id'],'file':entry['path'],'sha256':digest(root/entry['path'])}
                            for entry in manage.load_migration_manifest()]}
    erd=['# Physical PostgreSQL foreign-key ERD','','Generated from actual catalog foreign keys, not conceptual table counts. Views and authorization functions are separately enumerated in physical-schema.json.','','```mermaid','erDiagram']
    seen=set()
    for fk in data['foreign_keys']:
        key=(fk['target'],fk['table'])
        if key in seen:continue
        seen.add(key)
        erd.append('  '+fk['target']+' ||--o{ '+fk['table']+' : references')
    erd+=['```','']
    return {'retention-ownership-manifest.json':json.dumps(retention,indent=2)+'\n',
            'typed-constraint-registry.json':json.dumps(typed,indent=2)+'\n',
            'physical-schema.json':json.dumps(data,indent=2)+'\n',
            'logical-to-physical.json':json.dumps({'concept_count':len(mappings),'source_model':model['fileKey'],'mappings':mappings},indent=2)+'\n',
            'api-to-table.json':json.dumps({'operation_count':len(api),'canonical_screen_count':len(coverage),'operations':api},indent=2)+'\n',
            'migration-manifest.json':json.dumps(manifest,indent=2)+'\n','PHYSICAL_ERD.md':'\n'.join(erd)}


def main():
    import manage
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--database',choices=manage.DATABASES,default='test')
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    destination=manage.ROOT/'docs/data-model/local-postgresql'
    result=build(args.database)
    for name,content in result.items():
        path=destination/name
        if args.check:
            if not path.exists() or path.read_text()!=content:raise ValueError('Catalog/traceability drift: '+name)
        else:path.write_text(content)
    print('Catalog and traceability '+('verified' if args.check else 'exported')+': '+str(len(result))+' artifacts')


if __name__=='__main__':main()
