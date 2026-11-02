#!/usr/bin/env python3
"""Finite synthetic PostgreSQL concurrency regressions. Requires psycopg 3.
Creates/replays/drops ONLY a uniquely named ma_pr9_concurrency_* database.
Use --migration backend/persistence/migrations/0006_m1_concurrency_and_retention_holds.sql
for GREEN; omit for historical RED. No shared-role modifications beyond original migrations.
"""
import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import time
import uuid
import psycopg
from psycopg import sql

ROOT = Path(__file__).resolve().parents[2]
MIGRATIONS = ["0001_m1_identity.sql", "0002_m1_device_credentials.sql",
              "0003_m1_enrollment_and_credential_hardening.sql", "0004_m1_idempotency.sql",
              "0005_m1_family_provisioning.sql"]
ENV = ROOT / '.dev-environment'

def connect_db(database):
    # libpq reads PGHOST/PGPORT/PGUSER/PGPASSWORD, including CI's disposable service.
    return psycopg.connect(dbname=database, autocommit=True)

def digest():
    return hashlib.sha256(uuid.uuid4().bytes).digest()

class Suite:
    def __init__(self, database):
        self.database = database
        self.connections = []
        self.pool = concurrent.futures.ThreadPoolExecutor(max_workers=12)

    def connect(self, api=False):
        c = connect_db(self.database)
        c.execute("SET statement_timeout='8s'; SET lock_timeout='6s'")
        if api:
            c.execute('SET ROLE ap_m1_api')
        self.connections.append(c)
        return c

    def one(self, c, query, args=()):
        return c.execute(query, args).fetchone()[0]

    def fixture(self, pending=False):
        c = self.connect()
        family = self.one(c, "INSERT INTO ap_m1.families(label) VALUES ('synthetic concurrency') RETURNING id")
        child = self.one(c, "INSERT INTO ap_m1.children(family_id,alias) VALUES (%s,'synthetic') RETURNING id", (family,))
        device = self.one(c, "INSERT INTO ap_m1.devices(family_id,child_id,spki_public_key,enrollment_state) VALUES (%s,%s,%s,%s) RETURNING id", (family, child, digest()*3, 'PENDING_PROOF' if pending else 'ACTIVE'))
        if pending:
            challenge = self.one(c, "INSERT INTO ap_m1.enrollment_challenges(device_id,nonce_sha256,expires_at) VALUES (%s,%s,clock_timestamp()+interval '300 seconds') RETURNING id", (device,digest()))
            return c, device, challenge
        fp = digest()
        key = self.one(c, 'INSERT INTO ap_m1.device_key_records(device_id,fingerprint_sha256) VALUES (%s,%s) RETURNING key_id', (device,fp))
        c.execute("INSERT INTO ap_m1.device_credentials(device_id,key_id,token_sha256,issued_via,expires_at) VALUES (%s,%s,%s,'ENROLLMENT',clock_timestamp()+interval '1 hour')", (device,key,digest()))
        return c, device, fp

    def challenge(self, c, d, fp, consumed=False):
        ch = self.one(c, 'SELECT ap_m1.issue_credential_renewal_challenge(%s,%s,%s,300)', (d,fp,digest()))
        assert ch
        if consumed:
            assert c.execute('SELECT * FROM ap_m1.consume_renewal_challenge(%s,%s)', (d,ch)).fetchone()
        return ch

    def issue(self, c, d, ch, token=None, lifetime=300):
        return self.one(c, 'SELECT ap_m1.issue_renewal_credential(%s,%s,%s,%s)', (d,ch,token or digest(),lifetime))

    def wait(self, c, future, blocker):
        deadline = time.monotonic()+3
        while time.monotonic()<deadline:
            if self.one(self.monitor, 'SELECT %s = ANY(pg_blocking_pids(%s))', (blocker.info.backend_pid,c.info.backend_pid)):
                return True
            if future.done():
                future.result()
                return False
            time.sleep(.01)
        raise AssertionError('readiness barrier: no expected blocker within 3 seconds')

    def distinct_renewals(self):
        admin,d,fp=self.fixture(); a=self.connect(True); b=self.connect(True)
        x=self.challenge(a,d,fp,True); y=self.challenge(a,d,fp,True)
        a.execute('BEGIN'); assert self.issue(a,d,x)
        f=self.pool.submit(self.issue,b,d,y)
        assert self.wait(b,f,a), 'S2 must wait for uncommitted S1'
        a.execute('COMMIT'); assert f.result(timeout=8)
        live=self.one(admin,'SELECT count(*) FROM ap_m1.device_credentials WHERE device_id=%s AND revoked_at IS NULL',(d,))
        assert live==1, f'distinct challenge snapshot left {live} unrevoked credentials (baseline: 2)'

    def cap(self):
        admin,d,fp=self.fixture(); a=self.connect(True); b=self.connect(True)
        for _ in range(4): self.challenge(a,d,fp)
        a.execute('BEGIN'); self.challenge(a,d,fp)
        f=self.pool.submit(self.one,b,'SELECT ap_m1.issue_credential_renewal_challenge(%s,%s,%s,300)',(d,fp,digest()))
        blocked=self.wait(b,f,a); a.execute('COMMIT'); result=f.result(timeout=8)
        count=self.one(admin,'SELECT count(*) FROM ap_m1.credential_renewal_challenges WHERE device_id=%s AND consumed_at IS NULL',(d,))
        assert count==5 and result is None and blocked, f'cap: {count} challenges, blocked={blocked} (baseline: 6)'

    def burst(self):
        admin,d,fp=self.fixture()
        clients=[self.connect(True) for _ in range(12)]
        fs=[self.pool.submit(self.one,c,'SELECT ap_m1.issue_credential_renewal_challenge(%s,%s,%s,300)',(d,fp,digest())) for c in clients]
        assert sum(f.result(timeout=8) is not None for f in fs)==5
        for row in admin.execute('SELECT id FROM ap_m1.credential_renewal_challenges WHERE device_id=%s',(d,)):
            assert clients[0].execute('SELECT * FROM ap_m1.consume_renewal_challenge(%s,%s)',(d,row[0])).fetchone()
        ids=[r[0] for r in admin.execute('SELECT id FROM ap_m1.credential_renewal_challenges WHERE device_id=%s',(d,))]
        fs=[self.pool.submit(self.issue,clients[i],d,ch) for i,ch in enumerate(ids)]
        assert all(f.result(timeout=8) for f in fs)
        assert self.one(admin,'SELECT count(*) FROM ap_m1.device_credentials WHERE device_id=%s AND revoked_at IS NULL',(d,))==1

    def replay_rollback(self):
        admin,d,fp=self.fixture(); a=self.connect(True)
        ch=self.challenge(a,d,fp,True)
        assert not a.execute('SELECT * FROM ap_m1.consume_renewal_challenge(%s,%s)',(d,ch)).fetchall()
        a.execute('BEGIN'); assert self.issue(a,d,ch); a.execute('ROLLBACK')
        assert self.one(admin,'SELECT consumed_at IS NOT NULL AND redeemed_at IS NULL FROM ap_m1.credential_renewal_challenges WHERE id=%s',(ch,))
        assert self.issue(a,d,ch)
        assert self.issue(a,d,ch) is None
        assert self.issue(a,uuid.uuid4(),ch) is None

    def delayed(self, enrollment=False, redeem=False):
        if enrollment:
            admin,d,ch=self.fixture(True); table='enrollment_challenges'
        else:
            admin,d,fp=self.fixture(); ch=self.challenge(self.connect(True),d,fp); table='credential_renewal_challenges'
        a=self.connect(True)
        if redeem:
            query='SELECT * FROM ap_m1.consume_enrollment_challenge(%s)' if enrollment else 'SELECT * FROM ap_m1.consume_renewal_challenge(%s,%s)'
            assert a.execute(query,(ch,) if enrollment else (d,ch)).fetchone()
        admin.execute('BEGIN')
        admin.execute(f'SELECT id FROM ap_m1.{table} WHERE id=%s FOR UPDATE',(ch,))
        if redeem:
            query='SELECT * FROM ap_m1.activate_enrolled_device(%s,%s,86400)' if enrollment else 'SELECT ap_m1.issue_renewal_credential(%s,%s,%s,86400)'
            args=(ch,digest()) if enrollment else (d,ch,digest())
        else:
            query='SELECT * FROM ap_m1.consume_enrollment_challenge(%s)' if enrollment else 'SELECT * FROM ap_m1.consume_renewal_challenge(%s,%s)'
            args=(ch,) if enrollment else (d,ch)
        f=self.pool.submit(lambda: a.execute(query,args).fetchall())
        assert self.wait(a,f,admin)
        if redeem:
            admin.execute(f"UPDATE ap_m1.{table} SET consumed_at=clock_timestamp()-interval '59.8 seconds' WHERE id=%s",(ch,))
        else:
            admin.execute(f"UPDATE ap_m1.{table} SET created_at=clock_timestamp()-interval '100 seconds',expires_at=clock_timestamp()+interval '0.2 seconds' WHERE id=%s",(ch,))
        time.sleep(.4); admin.execute('COMMIT')
        rows=f.result(timeout=8)
        assert rows==[] or rows==[(None,)], f'post-lock expired {table} redeem={redeem} accepted: {rows}'

    def device_first(self, enrollment=False):
        if enrollment:
            admin,d,ch=self.fixture(True); table='enrollment_challenges'
        else:
            admin,d,fp=self.fixture(); ch=self.challenge(self.connect(True),d,fp); table='credential_renewal_challenges'
        a=self.connect(True); probe=self.connect()
        admin.execute('BEGIN'); admin.execute('SELECT id FROM ap_m1.devices WHERE id=%s FOR UPDATE',(d,))
        query='SELECT * FROM ap_m1.consume_enrollment_challenge(%s)' if enrollment else 'SELECT * FROM ap_m1.consume_renewal_challenge(%s,%s)'
        f=self.pool.submit(lambda: a.execute(query,(ch,) if enrollment else (d,ch)).fetchall())
        blocked=self.wait(a,f,admin)
        try:
            probe.execute('BEGIN'); probe.execute(f'SELECT id FROM ap_m1.{table} WHERE id=%s FOR UPDATE NOWAIT',(ch,)); probe.execute('ROLLBACK')
            admin.execute("UPDATE ap_m1.devices SET revoked_at=clock_timestamp(),enrollment_state='REVOKED' WHERE id=%s",(d,))
        finally:
            admin.execute('COMMIT')
        rows=f.result(timeout=8)
        assert blocked and not rows, f'device-first revocation failed blocked={blocked}, rows={rows}'

    def pairing(self, expire=False):
        admin,d,ch=self.fixture(True)
        family,child=admin.execute('SELECT family_id,child_id FROM ap_m1.devices WHERE id=%s',(d,)).fetchone()
        principal=self.one(admin,"INSERT INTO ap_m1.parent_principals(oidc_issuer,oidc_subject) VALUES ('synthetic-issuer',%s) RETURNING id",(str(uuid.uuid4()),))
        admin.execute("INSERT INTO ap_m1.guardian_memberships(family_id,principal_id,membership_role) VALUES (%s,%s,'OWNER')",(family,principal))
        code=digest()
        pc=self.one(admin,"INSERT INTO ap_m1.pairing_codes(family_id,child_id,issued_by,code_sha256,expires_at) VALUES (%s,%s,%s,%s,clock_timestamp()+interval '300 seconds') RETURNING id",(family,child,principal,code))
        api=self.connect(True)
        admin.execute('BEGIN'); admin.execute('SELECT id FROM ap_m1.pairing_codes WHERE id=%s FOR UPDATE',(pc,))
        query='SELECT * FROM ap_m1.redeem_pairing_code(%s,%s,%s,600)'
        values=(code,digest()*3,digest())
        f=self.pool.submit(lambda:api.execute(query,values).fetchall())
        assert self.wait(api,f,admin)
        if expire:
            admin.execute("UPDATE ap_m1.pairing_codes SET created_at=clock_timestamp()-interval '100 seconds',expires_at=clock_timestamp()+interval '0.2 seconds' WHERE id=%s",(pc,))
        time.sleep(.4)
        released=self.one(admin,'SELECT clock_timestamp()')
        admin.execute('COMMIT'); rows=f.result(timeout=8)
        if expire:
            assert not rows, 'expired pairing code accepted after wait'
        else:
            assert len(rows)==1
            enrollment,device=rows[0]
            created,expiry=admin.execute('SELECT created_at,expires_at FROM ap_m1.enrollment_challenges WHERE id=%s',(enrollment,)).fetchone()
            assert created>=released and (expiry-created).total_seconds()==600
            assert not api.execute(query,values).fetchall(), 'pairing code replay'
            assert api.execute('SELECT * FROM ap_m1.consume_enrollment_challenge(%s)',(enrollment,)).fetchone()
            assert not api.execute('SELECT * FROM ap_m1.consume_enrollment_challenge(%s)',(enrollment,)).fetchall()
            api.execute('BEGIN')
            assert api.execute('SELECT * FROM ap_m1.activate_enrolled_device(%s,%s,86400)',(enrollment,digest())).fetchone()
            api.execute('ROLLBACK')
            assert self.one(admin,'SELECT consumed_at IS NOT NULL AND redeemed_at IS NULL FROM ap_m1.enrollment_challenges WHERE id=%s',(enrollment,))
            assert api.execute('SELECT * FROM ap_m1.activate_enrolled_device(%s,%s,86400)',(enrollment,digest())).fetchone()
            assert not api.execute('SELECT * FROM ap_m1.activate_enrolled_device(%s,%s,86400)',(enrollment,digest())).fetchall()
            assert self.one(admin,'SELECT count(*) FROM ap_m1.device_credentials WHERE device_id=%s AND revoked_at IS NULL',(device,))==1

    def fresh_issue_clock(self, enrollment=False):
        if enrollment:
            admin,d,ch=self.fixture(True); table='enrollment_challenges'
        else:
            admin,d,fp=self.fixture(); ch=self.challenge(self.connect(True),d,fp); table='credential_renewal_challenges'
        api=self.connect(True)
        if enrollment:
            assert api.execute('SELECT * FROM ap_m1.consume_enrollment_challenge(%s)',(ch,)).fetchone()
            query='SELECT * FROM ap_m1.activate_enrolled_device(%s,%s,86400)'; args=(ch,digest())
        else:
            assert api.execute('SELECT * FROM ap_m1.consume_renewal_challenge(%s,%s)',(d,ch)).fetchone()
            query='SELECT ap_m1.issue_renewal_credential(%s,%s,%s,86400)'; args=(d,ch,digest())
        admin.execute('BEGIN'); admin.execute(f'SELECT id FROM ap_m1.{table} WHERE id=%s FOR UPDATE',(ch,))
        f=self.pool.submit(lambda:api.execute(query,args).fetchall())
        assert self.wait(api,f,admin)
        time.sleep(.1); released=self.one(admin,'SELECT clock_timestamp()'); admin.execute('COMMIT')
        assert f.result(timeout=8)
        issued,expiry=admin.execute('SELECT issued_at,expires_at FROM ap_m1.device_credentials WHERE device_id=%s AND revoked_at IS NULL',(d,)).fetchone()
        assert issued>=released and (expiry-issued).total_seconds()==86400, 'issuance used transaction-frozen clock'

    def credential_wait_expiry(self):
        admin,d,fp=self.fixture(); api=self.connect(True)
        ch=self.challenge(api,d,fp,True)
        admin.execute("UPDATE ap_m1.credential_renewal_challenges SET consumed_at=clock_timestamp()-interval '59 seconds' WHERE id=%s",(ch,))
        admin.execute('BEGIN')
        admin.execute('SELECT id FROM ap_m1.device_credentials WHERE device_id=%s FOR UPDATE',(d,))
        f=self.pool.submit(self.issue,api,d,ch)
        assert self.wait(api,f,admin)
        time.sleep(1.2); admin.execute('COMMIT')
        assert f.result(timeout=8) is None, 'redemption expired while waiting for credential lock'

    def negative_authority(self):
        admin,d,fp=self.fixture(); api=self.connect(True)
        assert api.execute("SELECT current_user, r.rolsuper, r.rolbypassrls FROM pg_roles r WHERE rolname=current_user").fetchone()==('ap_m1_api',False,False)
        assert self.one(api,'SELECT ap_m1.issue_credential_renewal_challenge(%s,%s,%s,300)',(d,digest(),digest())) is None
        ch=self.challenge(api,d,fp,True)
        admin.execute("UPDATE ap_m1.device_key_records SET state='REVOKED',revoked_at=clock_timestamp() WHERE device_id=%s",(d,))
        assert self.issue(api,d,ch) is None
        assert not api.execute('SELECT * FROM ap_m1.consume_renewal_challenge(%s,%s)',(d,ch)).fetchall()
        assert self.one(api,'SELECT ap_m1.issue_credential_renewal_challenge(%s,%s,%s,300)',(d,fp,digest())) is None

    def holds(self):
        c=self.connect()
        for table in ['devices','device_credentials','credential_renewal_challenges','enrollment_challenges','pairing_codes']:
            row=c.execute("SELECT is_nullable,column_default FROM information_schema.columns WHERE table_schema='ap_m1' AND table_name=%s AND column_name='retention_hold'",(table,)).fetchone()
            assert row==('NO','false'), (table,row)
            for privilege in ['INSERT','UPDATE']:
                assert not self.one(c,'SELECT has_column_privilege(%s,%s,%s,%s)',('ap_m1_api','ap_m1.'+table,'retention_hold',privilege))
        assert self.one(c,"SELECT has_column_privilege('ap_m1_api','ap_m1.devices','revoked_at','UPDATE')")
        assert self.one(c,"SELECT has_column_privilege('ap_m1_api','ap_m1.pairing_codes','code_sha256','INSERT')")

    def close(self):
        for c in self.connections:
            try: c.cancel()
            except Exception: pass
        self.pool.shutdown(wait=True, cancel_futures=True)
        for c in self.connections: c.close()

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--migration',type=Path)
    parser.add_argument('--only')
    args=parser.parse_args()
    ENV.mkdir(exist_ok=True)
    name='ma_pr9_concurrency_'+uuid.uuid4().hex[:16]
    control=connect_db('postgres')
    results={'database':name,'migration':str(args.migration) if args.migration else None,'tests':[], 'exit_code':1,
             'test_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
             'migration_sha256':hashlib.sha256(args.migration.read_bytes()).hexdigest() if args.migration else None}
    suite=Suite(name)
    try:
        control.execute(sql.SQL('CREATE DATABASE {}').format(sql.Identifier(name)))
        c=suite.connect()
        for filename in MIGRATIONS:
            c.execute((ROOT/'backend/persistence/migrations'/filename).read_text())
        catalog_sql="""SELECT p.proname,pg_get_function_identity_arguments(p.oid),
            pg_get_function_result(p.oid),p.proowner,p.proacl::text,p.proconfig,
            p.prosecdef,pg_get_expr(p.proargdefaults,0)
            FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
            WHERE n.nspname='ap_m1' AND p.proname=ANY(%s) ORDER BY p.proname"""
        functions=['issue_credential_renewal_challenge','consume_renewal_challenge','issue_renewal_credential','redeem_pairing_code','consume_enrollment_challenge','activate_enrolled_device']
        before=c.execute(catalog_sql,(functions,)).fetchall()
        if args.migration: c.execute(args.migration.read_text())
        after=c.execute(catalog_sql,(functions,)).fetchall()
        assert len(before)==6 and before==after, 'function contract/owner/ACL/search_path changed'
        results['function_contracts_unchanged']=True
        results['original_sha256']={filename:hashlib.sha256((ROOT/'backend/persistence/migrations'/filename).read_bytes()).hexdigest() for filename in MIGRATIONS}
        suite.monitor=suite.connect()
        tests={'distinct_renewals':suite.distinct_renewals,'cap':suite.cap,'burst':suite.burst,'replay_rollback':suite.replay_rollback,'renewal_expiry':lambda:suite.delayed(), 'renewal_60s':lambda:suite.delayed(redeem=True),'enrollment_expiry':lambda:suite.delayed(enrollment=True),'enrollment_60s':lambda:suite.delayed(enrollment=True,redeem=True),'renewal_device_first':suite.device_first,'enrollment_device_first':lambda:suite.device_first(True),'holds':suite.holds,'pairing_expiry':lambda:suite.pairing(True),'pairing_enrollment_replay_rollback':suite.pairing,'renewal_fresh_clock':suite.fresh_issue_clock,'enrollment_fresh_clock':lambda:suite.fresh_issue_clock(True),'negative_authority':suite.negative_authority}
        tests['credential_wait_expiry']=suite.credential_wait_expiry
        if args.only:
            unknown=set(args.only.split(','))-tests.keys()
            if unknown: raise ValueError(f'Unknown tests: {sorted(unknown)}')
        for label,fn in tests.items():
            if args.only and label not in args.only.split(','): continue
            start=len(suite.connections)
            try:
                fn(); row={'name':label,'pass':True}
            except Exception as exc:
                row={'name':label,'pass':False,'error':str(exc)}
            finally:
                for connection in suite.connections[start:]:
                    connection.cancel()
                    connection.close()
                del suite.connections[start:]
            results['tests'].append(row); print(json.dumps(row),flush=True)
        results['exit_code']=int(any(not t['pass'] for t in results['tests']))
    finally:
        suite.close()
        control.execute(sql.SQL('DROP DATABASE IF EXISTS {}').format(sql.Identifier(name)))
        results['database_dropped']=not control.execute('SELECT 1 FROM pg_database WHERE datname=%s',(name,)).fetchone()
        control.close()
        path=ENV/'pr9-phase2-concurrency-results.json'
        history=json.loads(path.read_text()) if path.exists() else []
        import sys
        results['command']=' '.join([sys.executable,*sys.argv])
        history.append(results); path.write_text(json.dumps(history,indent=2)+'\n')
    return results['exit_code']

if __name__=='__main__':
    raise SystemExit(main())
