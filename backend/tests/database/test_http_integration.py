"""Real HTTP → Drogon → restricted PostgreSQL integration (synthetic only)."""
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import time
import unittest
import urllib.error
import urllib.request

import psycopg
from psycopg.conninfo import conninfo_to_dict
import fixtures

ROOT = Path(__file__).resolve().parents[3]


class HttpIntegration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ids = fixtures.seed_core()
        cls.tokens = {}
        with psycopg.connect(os.environ['MA_AUTH_DSN'], autocommit=True) as issuer:
            for actor, family in [('a', 'family_a'), ('b', 'family_b')]:
                cls.tokens[actor] = issuer.execute('SELECT ap_m1.mint_session(%s::uuid,%s::uuid,NULL)', (cls.ids[actor], cls.ids[family])).fetchone()[0]
        executable = Path(os.environ.get('MA_PROBE_BINARY') or ROOT / '.local-db/build/ma_local_db_read_probe')
        if not executable.exists():
            if fixtures.ci_mode():
                # The CI database job intentionally does not link Drogon; the real
                # probe HTTP acceptance is built and executed in local evidence.
                raise unittest.SkipTest('probe binary is not built in the CI database job; '
                                         'local probe HTTP acceptance is recorded separately')
            raise RuntimeError('Build the real probe first (tools/database/build_backend.py --probe); no mock server substituted')
        with socket.socket() as probe:
            # Allow binding over a TIME_WAIT socket from an immediately preceding
            # run; a live listener still refuses the bind on Linux.
            probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            probe.bind(('127.0.0.1',18080))
        sys.path.insert(0,str(ROOT/'tools/database'))
        import build_backend
        env=build_backend.environment(build_backend.prefixes())
        connection=conninfo_to_dict(os.environ['MA_RUNTIME_DSN'])
        env.update(DB_HOST=connection['host'],DB_PORT=connection['port'],DB_NAME=connection['dbname'],DB_USER=connection['user'],DB_PASSWORD=connection['password'])
        logfile=ROOT/'.local-db/backend-http-test.log'
        cls.log=logfile.open('w');logfile.chmod(0o600)
        cls.process=subprocess.Popen([str(executable)],env=env,stdout=cls.log,stderr=cls.log)
        deadline=time.monotonic()+20
        while time.monotonic()<deadline:
            if cls.process.poll() is not None:
                cls.log.close();raise RuntimeError('Real backend startup failed; private log .local-db/backend-http-test.log')
            try:
                status,_=cls.request('/v1/parents/me')
                if status==401:return
            except OSError:
                pass
            time.sleep(0.1)
        cls.process.terminate();cls.process.wait(timeout=5);cls.log.close()
        raise RuntimeError('Real backend did not become ready')

    @classmethod
    def tearDownClass(cls):
        if hasattr(cls,'process'):
            cls.process.terminate()
            try:cls.process.wait(timeout=5)
            except subprocess.TimeoutExpired:cls.process.kill();cls.process.wait(timeout=5)
            cls.log.close()

    @classmethod
    def request(cls,path,actor=None,headers=None):
        values={} if actor is None else {'Authorization':'Bearer '+cls.tokens[actor]}
        values.update(headers or {})
        request=urllib.request.Request('http://127.0.0.1:18080'+path,headers=values)
        try:
            with urllib.request.urlopen(request,timeout=8) as response:
                return response.status,json.load(response)
        except urllib.error.HTTPError as response:
            return response.code,json.load(response)

    def test_01_unauthenticated_and_forged_actor_denied(self):
        status,body=self.request('/v1/parents/me',headers={'X-Principal-Id':str(self.ids['a']),'Authorization':'Bearer '+'f'*64})
        self.assertEqual(status,401);self.assertEqual(body['code'],'AUTHENTICATION_REQUIRED')

    def test_02_profile_is_actual_session_identity(self):
        for actor in ['a','b']:
            status,body=self.request('/v1/parents/me',actor)
            self.assertEqual(status,200);self.assertEqual(body['adult_id'],str(self.ids[actor]))
            self.assertEqual(set(body),{'adult_id','family_ids'})

    def test_03_child_visible_sibling_hidden(self):
        status,body=self.request('/v1/children/'+str(self.ids['child_a']),'a')
        self.assertEqual(status,200);self.assertEqual(body['id'],str(self.ids['child_a']))
        self.assertEqual(set(body),{'id','family_id','alias'})
        self.assertEqual(self.request('/v1/children/'+str(self.ids['sibling_a']),'a')[0],404)
        self.assertEqual(self.request('/v1/children/'+str(self.ids['child_a']),'b')[0],404)

    def test_04_child_list_pagination_and_family_separation(self):
        status,body=self.request('/v1/families/'+str(self.ids['family_a'])+'/children?limit=1','a')
        self.assertEqual(status,200);self.assertEqual(len(body['items']),1)
        self.assertEqual(body['items'][0]['id'],str(self.ids['child_a']))
        self.assertIn('next_cursor',body)
        self.assertEqual(self.request('/v1/families/'+str(self.ids['family_a'])+'/children','b')[0],404)
        self.assertEqual(self.request('/v1/families/'+str(self.ids['family_a'])+'/children?limit=101','a')[0],400)

    def test_05_consent_readback_schema(self):
        status,body=self.request('/v1/children/'+str(self.ids['child_a'])+'/consents','a')
        self.assertEqual(status,200);self.assertGreater(len(body['items']),0)
        for record in body['items']:
            self.assertTrue({'id','child_id','purpose','status','updated_at'}<=set(record))
            self.assertEqual(record['child_id'],str(self.ids['child_a']))
            self.assertIsInstance(record['updated_at'],str)

    def test_06_pooled_connections_do_not_leak_context(self):
        def fetch(index):
            actor='a' if index%2==0 else 'b'
            status,body=self.request('/v1/parents/me',actor)
            return status,body.get('adult_id'),str(self.ids[actor])
        with ThreadPoolExecutor(max_workers=2) as pool:
            for status,actual,expected in pool.map(fetch,range(12)):
                self.assertEqual(status,200);self.assertEqual(actual,expected)


if __name__=='__main__':unittest.main()
