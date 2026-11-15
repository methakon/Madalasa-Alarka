// Static, local-only deployment rule checks (no network/VPS required).
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';
const read = path => readFileSync(new URL(path,import.meta.url),'utf8');

test('admin web is HTTPS with only scoped admin API',()=>{
 const admin=read('../nginx/madalasa-admin.conf.template');
 assert.match(admin,/listen 443 ssl/);
 assert.match(admin,/location \^~ \/v1\/admin\//);
 assert.match(admin,/location \^~ \/v1\/ \{ return 404; \}/);
 assert.match(admin,/proxy_pass http:\/\/127\.0\.0\.1:8080/);
 assert.match(admin,/frame-ancestors 'none'/);
 assert.match(admin,/Strict-Transport-Security "max-age=31536000; includeSubDomains" always;/);
 assert.match(admin,/location \^~ \/v1\/admin\/[\s\S]*?Content-Security-Policy/);
 assert.match(admin,/location \^~ \/v1\/admin\/[\s\S]*?Strict-Transport-Security/);
 assert.doesNotMatch(admin,/listen 80/);
});

test('public API does not expose administrator routes',()=>{
 const api=read('../nginx/madalasa-api.conf.template');
 assert.match(api,/location \^~ \/v1\/admin\/ \{ return 404; \}/);
 assert.match(api,/listen 443 ssl/);
 assert.match(api,/return 301 https:\/\/api\.madalasa\.berhampore\.in\$request_uri;/);
 assert.doesNotMatch(api,/proxy_pass http:\/\/161\.33\.146\.238/);
});

test('publishing keeps immutable release directory and rollback',()=>{
 assert.match(read('./publish.sh'),/test ! -e "\$dest"/);
 assert.match(read('./publish.sh'),/mv -Tf "\$new" "\$base\/current"/);
 assert.match(read('./rollback.sh'),/test -s "\$dest\/index.html"/);
});

// Abuse limits. nginx itself is not available to CI here, so this checks the template text: every zone
// that a limit_req/limit_conn names is declared once, 429 is the refusal status, pre-auth routes get the
// strict zone and safety-critical routes never do.
const zonesDeclared=text=>[...text.matchAll(/^limit_(?:req|conn)_zone \$binary_remote_addr zone=(\w+):\d+m/gm)].map(m=>m[1]);
const zonesUsed=text=>[...text.matchAll(/limit_(?:req zone|conn)[= ](\w+)/g)].map(m=>m[1]);

for (const [name,file] of [['api','madalasa-api.conf.template'],['admin','madalasa-admin.conf.template']]) {
 test(`${name} nginx rate limits are declared and refuse with 429`,()=>{
  const text=read(`../nginx/${file}`);
  const declared=zonesDeclared(text);
  assert.ok(declared.length>=3,'general, auth and connection zones');
  assert.equal(new Set(declared).size,declared.length,'no zone declared twice');
  for (const used of zonesUsed(text)) assert.ok(declared.includes(used),`zone ${used} is declared`);
  assert.match(text,/^limit_req_status 429;/m);
  assert.match(text,/^limit_conn_status 429;/m);
  assert.match(text,/^limit_req_zone \$binary_remote_addr/m,'keyed on the real client address, never on a header value');
  assert.doesNotMatch(text,/limit_req_zone \$http_/);
  // A location that sets limit_req replaces the inherited one: it must name the general zone again.
  for (const m of text.matchAll(/location [^{]*\{([^}]*)\}/g)) {
   if (/limit_req zone=\w+_auth/.test(m[1])) assert.match(m[1],/limit_req zone=\w+_general/,'strict location repeats the general zone');
  }
 });
}

test('API strict zone covers pre-auth routes and never safety-critical ones',()=>{
 const api=read('../nginx/madalasa-api.conf.template');
 const m=api.match(/location ~ (\S+) \{\s*limit_req zone=ma_api_auth/);
 assert.ok(m,'strict pre-auth location exists');
 const re=new RegExp(m[1]);
 const strict=['/v1/auth/parent/google','/v1/auth/session','/v1/enrollment','/v1/enrollment/00000000-0000-4000-8000-000000000000/proof',
  '/v1/devices/00000000-0000-4000-8000-000000000000/credential/challenge','/v1/devices/00000000-0000-4000-8000-000000000000/credential/renew'];
 const never=['/v1/devices/00000000-0000-4000-8000-000000000000/signals','/v1/devices/00000000-0000-4000-8000-000000000000/locations:batch',
  '/v1/children/00000000-0000-4000-8000-000000000000/signals','/v1/children/00000000-0000-4000-8000-000000000000/signals/00000000-0000-4000-8000-000000000000/ack',
  '/v1/families','/v1/release/capabilities'];
 for (const p of strict) assert.match(p,re,`${p} is strictly limited`);
 for (const p of never) assert.doesNotMatch(p,re,`${p} stays on the general zone`);
 assert.match(api,/limit_req zone=ma_api_general burst=60 nodelay;/);
});

test('admin login steps use the strict zone',()=>{
 const admin=read('../nginx/madalasa-admin.conf.template');
 assert.match(admin,/location \^~ \/v1\/admin\/auth\/ \{\s*limit_req zone=ma_admin_auth/);
 assert.match(admin,/limit_conn ma_admin_conn \d+;/);
});
