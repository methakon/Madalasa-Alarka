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
