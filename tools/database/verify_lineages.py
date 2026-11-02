#!/usr/bin/env python3
"""Destructive acceptance replay on the explicitly configured synthetic test DB only.

Exercises historical M1, populated upgrade, immutable-history adoption and clean
V2 convergence. Never targets development/production or clears recovery ledgers.
Run with the project's database virtualenv after building the native backend.
"""
from pathlib import Path
import subprocess
import sys
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'backend/tests/database'))
sys.path.insert(0, str(ROOT / 'backend/tests'))
import manage as db

from test_m1_current_convergence import seed_current_upgrade, assert_current_upgrade
from physical_schema import physical_tables


def application_shape(conn):
    columns = conn.execute("""SELECT table_schema,table_name,column_name,data_type,udt_name,is_nullable,column_default
      FROM information_schema.columns WHERE table_schema IN ('ap_m1','ma_recovery')
      ORDER BY table_schema,table_name,ordinal_position""").fetchall()
    acl = conn.execute("""SELECT n.nspname,c.relname,c.relkind,c.relrowsecurity,c.relforcerowsecurity,c.reloptions,
      pg_get_userbyid(c.relowner),ARRAY(SELECT concat(a.grantee,':',a.grantor,':',a.privilege_type,':',a.is_grantable)
        FROM aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) a
        ORDER BY a.grantee,a.grantor,a.privilege_type,a.is_grantable) FROM pg_class c
      JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname IN ('ap_m1','ma_recovery') AND c.relkind IN ('r','p','v') ORDER BY n.nspname,c.relname""").fetchall()
    constraints = conn.execute("""SELECT n.nspname,c.relname,k.conname,k.contype,k.convalidated,
      pg_get_constraintdef(k.oid) FROM pg_constraint k JOIN pg_class c ON c.oid=k.conrelid
      JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN ('ap_m1','ma_recovery')
      ORDER BY n.nspname,c.relname,k.conname""").fetchall()
    indexes = conn.execute("SELECT schemaname,indexname,indexdef FROM pg_indexes WHERE schemaname IN ('ap_m1','ma_recovery') ORDER BY schemaname,indexname").fetchall()
    functions = conn.execute("""SELECT n.nspname,p.proname,pg_get_function_identity_arguments(p.oid),pg_get_functiondef(p.oid),
      p.prosecdef,p.proconfig,p.provolatile,pg_get_userbyid(p.proowner),
      ARRAY(SELECT concat(a.grantee,':',a.grantor,':',a.privilege_type,':',a.is_grantable)
        FROM aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
        ORDER BY a.grantee,a.grantor,a.privilege_type,a.is_grantable)
      FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname IN ('ap_m1','ma_recovery')
      ORDER BY n.nspname,p.proname,pg_get_function_identity_arguments(p.oid)""").fetchall()
    policies=conn.execute("""SELECT schemaname,tablename,policyname,permissive,roles::text[],cmd,qual,with_check
      FROM pg_policies WHERE schemaname IN ('ap_m1','ma_recovery') ORDER BY schemaname,tablename,policyname""").fetchall()
    views=conn.execute("SELECT schemaname,viewname,definition FROM pg_views WHERE schemaname IN ('ap_m1','ma_recovery') ORDER BY schemaname,viewname").fetchall()
    column_acl=conn.execute("""SELECT n.nspname,c.relname,a.attname,a.attacl::text
      FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname IN ('ap_m1','ma_recovery') AND a.attnum>0 AND NOT a.attisdropped
      ORDER BY n.nspname,c.relname,a.attnum""").fetchall()
    roles=conn.execute("""SELECT rolname,rolsuper,rolinherit,rolcreaterole,rolcreatedb,rolcanlogin,rolreplication,rolbypassrls,rolconfig
      FROM pg_roles WHERE rolname LIKE 'ap\\_%' ESCAPE '\\' OR rolname LIKE 'madalasa\\_%' ESCAPE '\\' ORDER BY rolname""").fetchall()
    memberships=conn.execute("""SELECT r.rolname,u.rolname,m.admin_option,
      to_jsonb(m)->'inherit_option',to_jsonb(m)->'set_option'
      FROM pg_auth_members m JOIN pg_roles r ON r.oid=m.roleid JOIN pg_roles u ON u.oid=m.member
      WHERE r.rolname LIKE 'ap\\_%' ESCAPE '\\' OR u.rolname LIKE 'madalasa\\_%' ESCAPE '\\' ORDER BY r.rolname,u.rolname""").fetchall()
    schema_acl=conn.execute("""SELECT nspname,pg_get_userbyid(nspowner),nspacl::text FROM pg_namespace
      WHERE nspname IN ('ap_m1','ma_recovery') ORDER BY nspname""").fetchall()
    return dict(columns=columns,acl=acl,constraints=constraints,indexes=indexes,functions=functions,
                policies=policies,views=views,column_acl=column_acl,roles=roles,memberships=memberships,schema_acl=schema_acl)


def ledger_rows(conn):
    return conn.execute('SELECT version,filename,checksum,status,executed_at FROM ma_migrations.lineage_history ORDER BY version').fetchall()


def assert_current_m1_ledger(conn):
    ids = [r[0] for r in conn.execute('SELECT version FROM ma_migrations.lineage_history ORDER BY version')]
    assert ids == ['common:0001'] + ['m1:%04d' % n for n in range(2, 7)], ids


def assert_runtime_closed(database, closed):
    with db.connect(database, 'admin') as conn:
        for kind in ('runtime', 'auth', 'billing'):
            granted = conn.execute("SELECT has_database_privilege(%s,current_database(),'CONNECT')", (db.ROLES[kind][0],)).fetchone()[0]
            assert granted is not closed, kind
    assert db.quarantine_marker(database).exists() is closed


def legacy_converged_plan(conn):
    """Read-only: a published 0004-converged ledger must never replay history late.

    Applies to any ledger that mixes historical M1 with V2 rows, including the
    older 0002..0004 checkpoint produced by the previous published runner.
    """
    rows = conn.execute('SELECT version,filename,checksum,status FROM ma_migrations.lineage_history').fetchall()
    if not rows:
        return None
    entries = db.load_migration_manifest()
    applied = db.validate_migration_history(entries, [], rows)
    if not any(i.startswith('m1:') for i in applied) or not any(i.startswith('v2:') for i in applied):
        return None
    plan = [e['id'] for e in db.migration_plan(entries, applied=applied)]
    assert not any(i.startswith(('m1:', 'compat:')) for i in plan), 'late historical replay on converged ledger'
    print('Converged ledger: no late historical replay; pending ' + str(plan), flush=True)
    return plan


def main():
    if db.ci_mode():
        raise RuntimeError('verify_lineages replays historical M1 through docker exec and is local/PR11 only; run the unit suites in CI')
    for role in ('admin', *db.ROLES):
        target = db.conninfo_to_dict(db.configuration()['test'][role])
        db.validate_target(target)
        if target['dbname'] != db.DATABASES['test']:
            raise RuntimeError('refusing non-test database')
    db.assert_container('test')
    print('RESETTING ONLY synthetic test database; recovery ledger retained', flush=True)
    db.reset('test')
    db.create(targets=['test'])
    db.migrate('test', lineage='m1')
    container = db.container_for('test')
    # Original scripts retain their exact upstream bytes. Role switches inside
    # SQL exercise restricted M1 API roles; fixtures alone use local admin.
    for name in ('m1_tenant_isolation.sql', 'm1_credential_lifecycle.sql', 'm1_enrollment.sql', 'm1_idempotency.sql'):
        subprocess.run(['docker','exec','-i',container,'psql','-X','-v','ON_ERROR_STOP=1',
                '-U','postgres','-d',db.DATABASES['test']], input=(ROOT/'backend/tests'/name).read_text(), text=True, check=True, timeout=30)
    subprocess.run(['docker','exec','-i',container,'env','PGUSER=postgres','PGDATABASE='+db.DATABASES['test'],
            'bash','-s'], input=(ROOT/'backend/tests/m1_idempotency_concurrency.sh').read_text(), text=True, check=True, timeout=30)
    with db.connect('test','admin',autocommit=False) as conn:
        actual = {r[0]: set() for r in conn.execute("SELECT tablename FROM pg_tables WHERE schemaname='ap_m1'")}
        for table, col in conn.execute("SELECT table_name,column_name FROM information_schema.columns WHERE table_schema='ap_m1'"):
            if table in actual:
                actual[table].add(col)
        assert actual == physical_tables(), 'historical M1 live/static catalog divergence'
        assert len(actual) == 18, 'historical checkpoint is exactly 18 tables'
        assert_current_m1_ledger(conn)
        expected = seed_current_upgrade(conn)
        conn.commit()
    print('Historical M1: original SQL + concurrency + 18-table live catalog + m1 0002..0006 ledger PASS', flush=True)
    historical_backup = db.backup('test')
    # Staged completion: the database must stay closed until the final bridge is
    # applied, and a second run must be a no-op rather than a replay.
    db.migrate('test', through='0019')
    assert_runtime_closed('test', True)
    print('Upgrade through 0019: runtime still closed, bridge 0020 pending PASS', flush=True)
    db.migrate('test')
    assert_runtime_closed('test', False)
    db.verify_lineage_security('test')
    with db.connect('test','admin',autocommit=False) as conn:
        assert_current_upgrade(conn, expected)
        upgraded_shape = application_shape(conn)
        first = ledger_rows(conn)
        assert any(r[0] == 'v2:0020' for r in first), 'final convergence migration not applied'
        conn.commit()
    db.migrate('test')
    with db.connect('test','admin') as conn:
        assert ledger_rows(conn) == first, 'repeat migrate rewrote the ledger'
        legacy_converged_plan(conn)
    print('Idempotent re-migrate: ledger bytes unchanged; no late historical replay PASS', flush=True)
    print('Populated M1 -> V2: rows, device/key state and fail-closed credentials PASS', flush=True)
    db.restore('test',historical_backup,lineage='m1')
    with db.connect('test','admin') as conn:
        assert conn.execute("SELECT count(*) FROM pg_tables WHERE schemaname='ap_m1'").fetchone()[0] == 18
        for kind in ('runtime','auth','billing'):
            assert not conn.execute("SELECT has_database_privilege(%s,current_database(),'CONNECT')",(db.ROLES[kind][0],)).fetchone()[0]
    migrate = db.migrate
    def observe_closed_upgrade(*args, **kwargs):
        result = migrate(*args, **kwargs)
        with db.connect('test','admin') as conn:
            for kind in ('runtime','auth','billing'):
                assert not conn.execute("SELECT has_database_privilege(%s,current_database(),'CONNECT')",(db.ROLES[kind][0],)).fetchone()[0], 'restore reopened during migration before suppression'
        return result
    with patch.object(db,'migrate',side_effect=observe_closed_upgrade):
        db.restore('test',historical_backup)
    with db.connect('test','admin') as conn:
        assert_current_upgrade(conn,expected)
    print('Historical restore selection + V2 upgrade closed until ledger suppression PASS',flush=True)
    db.reset('test')
    db.create(targets=['test'])
    db.migrate('test')
    db.verify_lineage_security('test')
    with db.connect('test','admin',autocommit=False) as conn:
        fresh = application_shape(conn)
        for category in fresh:
            if fresh[category] != upgraded_shape[category]:
                expected = {repr(row) for row in upgraded_shape[category]}
                actual = {repr(row) for row in fresh[category]}
                print('UPGRADE ONLY',category,sorted(expected-actual),flush=True)
                print('FRESH ONLY',category,sorted(actual-expected),flush=True)
                raise AssertionError('fresh/upgrade schema or ACL divergence: '+category)
        old = conn.execute('SELECT * FROM ma_migrations.history ORDER BY version').fetchall()
        conn.execute('TRUNCATE ma_migrations.lineage_history')
        conn.commit()
    db.migrate('test')
    with db.connect('test','admin',autocommit=False) as conn:
        assert conn.execute('SELECT * FROM ma_migrations.history ORDER BY version').fetchall() == old
        assert conn.execute('SELECT count(*) FROM ma_migrations.lineage_history').fetchone()[0] == 21
    print('Clean V2 convergence + exact legacy adoption without history mutation PASS', flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
