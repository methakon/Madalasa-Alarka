import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const read=p=>readFileSync(new URL('../'+p,import.meta.url),'utf8');
test('synthetic preview never enables in production',()=>{
 const ui=read('src/main.tsx');
 assert.match(ui,/VITE_ADMIN_SYNTHETIC_PREVIEW==='true'&&import\.meta\.env\.DEV/);
 assert.match(ui,/if\(PREVIEW\)\{setActionMessage/);
});
test('admin API never stores credentials or trusts client role',()=>{
 const api=read('src/api.ts');
 assert.match(api,/credentials:'same-origin'/);
 assert.match(api,/method!=='GET'&&!csrf\(\)/);
 assert.ok(!api.includes('localStorage'));
 assert.match(api,/onlyServerRoles/);
});
test('no child private-data admin API paths',()=>{
 const api=read('src/api.ts');
 for(const path of ['/admin/media-activity','/admin/child-location','/admin/media-exports'])assert.ok(!api.includes(path));
});
test('Figma admin inventory includes ten variants',()=>{
 const registry=JSON.parse(read('../docs/ui/figma-functional-handoff/10-admin-back-office.json'));
 assert.equal(registry.screens.length,10);
});

test('admin login sends only backend-issued nonce and token and uses a server session',()=>{
 const ui=read('src/main.tsx'),api=read('src/api.ts');
 assert.match(ui,/request<\{nonce:string;expires_at:string\}>\('\/admin\/auth\/challenge'/);
 assert.match(ui,/body:\{id_token:idToken,nonce\}/);
 assert.doesNotMatch(ui,/csrf_state:csrfState/);
 assert.match(ui,/setCsrfToken\(result\.csrf_token\)/);
 assert.match(api,/\/admin\/auth\/csfr|\/admin\/auth\/csrf/);
 assert.match(api,/credentials:'same-origin'/);
 assert.doesNotMatch(api,/localStorage|sessionStorage/);
});
test('admin protected status is restored from server roles after reload',()=>{
 const ui=read('src/main.tsx'),api=read('src/api.ts');
 assert.match(ui,/state\.status==='APPROVED'\?onlyServerRoles\(state\.role_codes\)/);
 assert.match(ui,/request<\{csrf_token:string\}>\('\/admin\/auth\/csrf'/);
 assert.match(ui,/request\('\/admin\/auth\/session',\{method:'DELETE'\}\)/);
 assert.match(api,/clearCsrfToken/);
});
test('owner approvals use the server revision, not a hardcoded zero',()=>{
 const ui=read('src/main.tsx');
 assert.match(ui,/expected_revision:entry\.revision/);
 assert.doesNotMatch(ui,/expected_revision:0/);
 assert.doesNotMatch(ui,/postal_address:address/);
});
