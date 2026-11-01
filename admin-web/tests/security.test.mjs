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
