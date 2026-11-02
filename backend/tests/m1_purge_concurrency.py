#!/usr/bin/env python3
"""Synthetic bounded multi-session purge tests; creates/drops only its own DB.
Requires psycopg 3 and migration-admin PG* settings. --baseline replays 0001..5
for honest historical RED (hold-column cases cannot run on that schema).
No cluster-role creation/deletion; purge_job.sh is a separate serialized gate.
"""
import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import uuid

import psycopg
from psycopg import sql

ROOT = Path(__file__).resolve().parents[2]
MIGRATIONS = (
    '0001_m1_identity.sql', '0002_m1_device_credentials.sql',
    '0003_m1_enrollment_and_credential_hardening.sql', '0004_m1_idempotency.sql',
    '0005_m1_family_provisioning.sql', '0006_m1_concurrency_and_retention_holds.sql',
)


def digest():
    return hashlib.sha256(uuid.uuid4().bytes).digest()


class Suite:
    def __init__(self, database):
        self.database = database
        self.connections = []
        self.pool = concurrent.futures.ThreadPoolExecutor(max_workers=3)
        self.monitor = self.connect()

    def connect(self, role=None):
        c = psycopg.connect(dbname=self.database, autocommit=True)
        c.execute("SET statement_timeout='8s'; SET lock_timeout='6s'")
        if role:
            c.execute(sql.SQL('SET ROLE {}').format(sql.Identifier(role)))
        self.connections.append(c)
        return c

    @staticmethod
    def one(c, query, args=()):
        return c.execute(query, args).fetchone()[0]

    def fixture(self, table='devices', old=True):
        c = self.connect()
        family = self.one(c, "INSERT INTO ap_m1.families(label) VALUES ('synthetic purge') RETURNING id")
        child = self.one(c, "INSERT INTO ap_m1.children(family_id,alias) VALUES (%s,'synthetic') RETURNING id", (family,))
        if table == 'pairing_codes':
            principal = self.one(c, "INSERT INTO ap_m1.parent_principals(oidc_issuer,oidc_subject) VALUES ('https://example.invalid',%s) RETURNING id", (str(uuid.uuid4()),))
            c.execute("INSERT INTO ap_m1.guardian_memberships(family_id,principal_id,membership_role) VALUES (%s,%s,'OWNER')", (family,principal))
            code = digest()
            row = self.one(c, "INSERT INTO ap_m1.pairing_codes(family_id,child_id,issued_by,code_sha256,created_at,expires_at) VALUES (%s,%s,%s,%s,clock_timestamp()-interval '100 days',clock_timestamp()+%s::interval) RETURNING id", (family,child,principal,code,'-90 days' if old else '1 hour'))
            return c, row, code
        device = self.one(c, "INSERT INTO ap_m1.devices(family_id,child_id,spki_public_key,enrollment_state,created_at) VALUES (%s,%s,%s,%s,clock_timestamp()-interval '100 days') RETURNING id", (family,child,digest()*3,'PENDING_PROOF' if table in ('devices','enrollment_challenges') else 'ACTIVE'))
        if table == 'devices':
            return c, device, device
        if table == 'enrollment_challenges':
            row = self.one(c, "INSERT INTO ap_m1.enrollment_challenges(device_id,nonce_sha256,created_at,expires_at) VALUES (%s,%s,clock_timestamp()-interval '90 days 1 minute',clock_timestamp()-interval '90 days') RETURNING id", (device,digest()))
        else:
            key = self.one(c, 'INSERT INTO ap_m1.device_key_records(device_id,fingerprint_sha256) VALUES (%s,%s) RETURNING key_id', (device,digest()))
            if table == 'device_credentials':
                row = self.one(c, "INSERT INTO ap_m1.device_credentials(device_id,key_id,token_sha256,issued_via,issued_at,expires_at) VALUES (%s,%s,%s,'ENROLLMENT',clock_timestamp()-interval '90 days 1 minute',clock_timestamp()-interval '90 days') RETURNING id", (device,key,digest()))
            else:
                row = self.one(c, "INSERT INTO ap_m1.credential_renewal_challenges(device_id,key_id,nonce_sha256,created_at,expires_at) VALUES (%s,%s,%s,clock_timestamp()-interval '90 days 1 minute',clock_timestamp()-interval '90 days') RETURNING id", (device,key,digest()))
        return c, row, device

    def purge(self, c, table):
        return c.execute("SELECT ap_m1.purge_pairing_codes(interval '1 day')" if table == 'pairing_codes' else 'SELECT * FROM ap_m1.purge_credential_artifacts()').fetchall()

    def hold(self, c, table, row):
        cur = c.execute(sql.SQL('UPDATE ap_m1.{} SET retention_hold=true WHERE id=%s RETURNING id').format(sql.Identifier(table)), (row,))
        if not cur.fetchone():
            raise LookupError('hold target missing; cannot report hold success')

    def lock(self, c, table, row):
        return c.execute(sql.SQL('SELECT id FROM ap_m1.{} WHERE id=%s FOR UPDATE NOWAIT').format(sql.Identifier(table)), (row,)).fetchone()

    def exists(self, c, table, row):
        return self.one(c, sql.SQL('SELECT count(*) FROM ap_m1.{} WHERE id=%s').format(sql.Identifier(table)), (row,)) == 1

    def wait(self, c, future, blocker):
        deadline = time.monotonic()+3
        while time.monotonic() < deadline:
            if self.one(self.monitor, 'SELECT %s=ANY(pg_blocking_pids(%s))', (blocker.info.backend_pid,c.info.backend_pid)):
                return
            if future.done():
                raise AssertionError(f'expected lock barrier; operation finished: {future.result()}')
            time.sleep(.01)
        raise AssertionError('pg_blocking_pids barrier deadline exceeded')

    def device_first(self, table):
        admin,row,device = self.fixture(table)
        purge = self.connect('ap_m1_owner'); probe = self.connect()
        admin.execute('BEGIN'); self.lock(admin,'devices',device)
        f = self.pool.submit(self.purge,purge,table)
        self.wait(purge,f,admin)
        probe.execute('BEGIN'); assert self.lock(probe,table,row); probe.execute('ROLLBACK')
        admin.execute('COMMIT'); f.result(timeout=8)
        assert not self.exists(admin,table,row)

    def hold_order(self, table, hold_first):
        admin,row,_ = self.fixture(table)
        purge = self.connect('ap_m1_owner'); holder = self.connect()
        if hold_first:
            holder.execute('BEGIN'); self.hold(holder,table,row)
            f = self.pool.submit(self.purge,purge,table)
            self.wait(purge,f,holder); holder.execute('COMMIT'); f.result(timeout=8)
            assert self.exists(admin,table,row)
            assert self.one(admin,sql.SQL('SELECT retention_hold FROM ap_m1.{} WHERE id=%s').format(sql.Identifier(table)),(row,))
        else:
            purge.execute('BEGIN'); self.purge(purge,table)
            f = self.pool.submit(self.hold,holder,table,row)
            self.wait(holder,f,purge); purge.execute('COMMIT')
            try:
                f.result(timeout=8)
            except LookupError:
                pass
            else:
                raise AssertionError('deleted row falsely reported hold success')
            assert not self.exists(admin,table,row)

    def pairing_redemption(self, action, redemption_first):
        admin,row,code = self.fixture('pairing_codes',old=False)
        api = self.connect('ap_m1_api'); actor = self.connect('ap_m1_owner' if action == 'purge' else None)
        query = 'SELECT * FROM ap_m1.redeem_pairing_code(%s,%s,%s,300)'
        args = (code,digest()*3,digest())
        if redemption_first:
            api.execute('BEGIN'); assert api.execute(query,args).fetchone()
            f = self.pool.submit(self.purge,actor,'pairing_codes') if action == 'purge' else self.pool.submit(self.hold,actor,'pairing_codes',row)
            self.wait(actor,f,api); api.execute('COMMIT'); f.result(timeout=8)
            assert self.exists(admin,'pairing_codes',row)
        else:
            actor.execute('BEGIN')
            if action == 'purge':
                # Make this code eligible before purge's row lock; redemption then
                # waits on the uncommitted delete and must return no enrollment.
                admin.execute("UPDATE ap_m1.pairing_codes SET expires_at=clock_timestamp()-interval '90 days' WHERE id=%s",(row,))
                self.purge(actor,'pairing_codes')
            else:
                self.hold(actor,'pairing_codes',row)
            f = self.pool.submit(lambda: api.execute(query,args).fetchall())
            self.wait(api,f,actor); actor.execute('COMMIT'); rows = f.result(timeout=8)
            assert bool(rows) == (action == 'hold'), rows
            assert self.exists(admin,'pairing_codes',row) == (action == 'hold')
        assert not api.execute(query,args).fetchall(), 'pairing replay accepted'

    def post_lock_clock(self, pairing=False):
        table = 'pairing_codes' if pairing else 'device_credentials'
        admin,row,_ = self.fixture(table,old=False)
        purge = self.connect('ap_m1_owner')
        column = 'expires_at'
        admin.execute('BEGIN'); self.lock(admin,table,row)
        grace = '1 day' if pairing else '30 days'
        if not pairing:
            admin.execute("UPDATE ap_m1.device_credentials SET issued_at=clock_timestamp()-interval '30 days 1 minute',expires_at=clock_timestamp()-interval '30 days'+interval '0.5 seconds' WHERE id=%s",(row,))
        else:
            admin.execute(sql.SQL("UPDATE ap_m1.{} SET {}=clock_timestamp()-%s::interval+interval '0.5 seconds' WHERE id=%s").format(sql.Identifier(table),sql.Identifier(column)), (grace,row))
        f = self.pool.submit(self.purge,purge,table); self.wait(purge,f,admin)
        # Intentional expiry crossing, only after an observed real lock wait.
        time.sleep(.7); admin.execute('COMMIT'); f.result(timeout=8)
        assert not self.exists(admin,table,row), 'purge used pre-lock transaction time'

    def runner(self):
        admin,row,_ = self.fixture('pairing_codes')
        _,held,_ = self.fixture('pairing_codes')
        _,recent,_ = self.fixture('pairing_codes',old=False)
        self.hold(admin,'pairing_codes',held)
        env = dict(os.environ, PGDATABASE=self.database, PGOPTIONS='-c role=ap_m1_owner', MA_PURGE_PAIRING_GRACE='1 day')
        result = subprocess.run(['bash',str(ROOT/'backend/scripts/run_purge.sh')], env=env, text=True, capture_output=True, timeout=25)
        assert result.returncode == 0, result.stderr
        rows = [json.loads(line) for line in result.stdout.splitlines()]
        assert [r['job'] for r in rows] == ['purge_credential_artifacts','purge_idempotency_keys','purge_pairing_codes'], rows
        assert rows[2]['pairing_codes_deleted'] == 1 and not self.exists(admin,'pairing_codes',row), rows
        assert self.exists(admin,'pairing_codes',held) and self.exists(admin,'pairing_codes',recent)
        replay = subprocess.run(['bash',str(ROOT/'backend/scripts/run_purge.sh')], env=env, text=True, capture_output=True, timeout=25)
        assert replay.returncode == 0 and json.loads(replay.stdout.splitlines()[2])['pairing_codes_deleted'] == 0, replay
        # The quoted value must remain data, including deliberately hostile SQL.
        for value in ['', '0 seconds', 'infinity', "1 day'); SELECT 1; --"]:
            env['MA_PURGE_PAIRING_GRACE'] = value
            result = subprocess.run(['bash',str(ROOT/'backend/scripts/run_purge.sh')], env=env, text=True, capture_output=True, timeout=25)
            rows = [json.loads(line) for line in result.stdout.splitlines()]
            assert result.returncode != 0 and rows[-1] == {'job':'purge_pairing_codes','status':'failed'}, (value,result.stdout,result.stderr)
        env.pop('MA_PURGE_PAIRING_GRACE')
        result = subprocess.run(['bash',str(ROOT/'backend/scripts/run_purge.sh')], env=env, text=True, capture_output=True, timeout=25)
        assert result.returncode == 0 and len(result.stdout.splitlines()) == 2, result

    def close_case(self, start):
        for c in self.connections[start:]:
            c.cancel()
        for c in self.connections[start:]:
            c.close()
        del self.connections[start:]

    def close(self):
        self.close_case(0)
        self.pool.shutdown(wait=True,cancel_futures=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline',action='store_true')
    parser.add_argument('--only',help='comma-separated case names')
    args = parser.parse_args()
    name = 'ma_pr9_purge_concurrency_'+uuid.uuid4().hex[:16]
    report = {'database':name,'command':[sys.executable,*sys.argv], 'tests':[], 'exit_code':1,
              'connection_environment':{k:os.environ.get(k) for k in ('PGHOST','PGPORT','PGUSER')},
              'baseline':args.baseline,'test_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
    control = psycopg.connect(dbname='postgres',autocommit=True)
    suite = None
    try:
        control.execute(sql.SQL('CREATE DATABASE {}').format(sql.Identifier(name)))
        suite = Suite(name)
        migrations = MIGRATIONS[:5] if args.baseline else MIGRATIONS
        report['migration_sha256'] = {}
        for filename in migrations:
            path = ROOT/'backend/persistence/migrations'/filename
            suite.monitor.execute(path.read_text())
            report['migration_sha256'][filename] = hashlib.sha256(path.read_bytes()).hexdigest()
        tests = {f'device_first_{t}':lambda t=t:suite.device_first(t) for t in ('enrollment_challenges','credential_renewal_challenges','device_credentials')}
        for table in ('devices','enrollment_challenges','credential_renewal_challenges','device_credentials','pairing_codes'):
            for first in (True,False):
                tests[f'{table}_{"hold_first" if first else "purge_first"}'] = lambda t=table,f=first:suite.hold_order(t,f)
        for action in ('hold','purge'):
            for first in (True,False):
                tests[f'pairing_{action}_{"redemption_first" if first else "action_first"}'] = lambda a=action,f=first:suite.pairing_redemption(a,f)
        tests.update(credential_post_lock_clock=suite.post_lock_clock,
                     pairing_post_lock_clock=lambda:suite.post_lock_clock(True), runner=suite.runner)
        selected = args.only.split(',') if args.only else list(tests)
        assert selected and not set(selected)-tests.keys(), 'unknown or empty case selection'
        for label in selected:
            # Each seam starts with an empty fixture population in this owned DB.
            suite.monitor.execute('TRUNCATE ap_m1.families, ap_m1.parent_principals CASCADE')
            start = len(suite.connections)
            try:
                tests[label](); row = {'name':label,'pass':True}
            except Exception as exc:
                row = {'name':label,'pass':False,'error':str(exc),'sqlstate':getattr(exc,'sqlstate',None)}
            finally:
                suite.close_case(start)
            report['tests'].append(row); print(json.dumps(row),flush=True)
        report['exit_code'] = int(any(not t['pass'] for t in report['tests']))
    except Exception as exc:
        report['setup_error'] = str(exc)
        raise
    finally:
        if suite:
            suite.close()
        control.execute(sql.SQL('DROP DATABASE IF EXISTS {}').format(sql.Identifier(name)))
        report['database_dropped'] = not control.execute('SELECT 1 FROM pg_database WHERE datname=%s',(name,)).fetchone()
        control.close()
        path = ROOT/'.dev-environment/pr9-phase2-purge-concurrency-results.json'
        history = json.loads(path.read_text()) if path.exists() else []
        history.append(report); path.write_text(json.dumps(history,indent=2)+'\n')
    return report['exit_code']


if __name__ == '__main__':
    raise SystemExit(main())
