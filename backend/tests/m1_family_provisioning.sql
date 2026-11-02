-- Madalasa-Alarka M1 PostgreSQL 15+ regression: family provisioning (migration 0005).
-- Run on a FRESH isolated CI database after migrations 0001..0005. Own fixtures. SYNTHETIC DATA ONLY.
\set ON_ERROR_STOP on

CREATE FUNCTION public.ap_m1_test_expect(cond boolean, msg text) RETURNS void
 LANGUAGE plpgsql AS $f$
BEGIN
 IF cond IS NOT TRUE THEN RAISE EXCEPTION 'M1_PROVISIONING_TEST_FAILURE: %', msg; END IF;
END $f$;

-- FP_01 boundaries: definer, pinned search_path, owned by ap_m1_auth, API-executable, not PUBLIC-executable
DO $t$
DECLARE n integer;
BEGIN
 SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace s ON s.oid=p.pronamespace JOIN pg_roles o ON o.oid=p.proowner
  WHERE s.nspname='ap_m1' AND p.proname IN ('resolve_parent_principal','create_family') AND p.prosecdef
    AND o.rolname='ap_m1_auth' AND EXISTS (SELECT 1 FROM unnest(p.proconfig) c WHERE c LIKE 'search_path=%');
 PERFORM public.ap_m1_test_expect(n=2,'FP_01 both functions SECURITY DEFINER, owned by ap_m1_auth, pinned search_path');
 SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace s ON s.oid=p.pronamespace
  WHERE s.nspname='ap_m1' AND (p.proacl IS NULL OR EXISTS (SELECT 1 FROM aclexplode(p.proacl) a WHERE a.grantee=0));
 PERFORM public.ap_m1_test_expect(n=0,'FP_01 no ap_m1 function may be PUBLIC-executable, found '||n);
 PERFORM public.ap_m1_test_expect(has_function_privilege('ap_m1_api','ap_m1.create_family(text)','EXECUTE')
   AND has_function_privilege('ap_m1_api','ap_m1.resolve_parent_principal(text,text)','EXECUTE'),'FP_01 app role must execute both');
 PERFORM public.ap_m1_test_expect(NOT has_table_privilege('ap_m1_api','ap_m1.parent_principals','INSERT'),
  'FP_01 the app role must not insert principals directly');
END $t$;

SET ROLE ap_m1_api;

-- FP_02 principal resolution is idempotent and distinguishes identities
SELECT ap_m1.resolve_parent_principal('https://idp.example.invalid','prov-a') AS pa \gset
SELECT ap_m1.resolve_parent_principal('https://idp.example.invalid','prov-a') AS pa2 \gset
SELECT ap_m1.resolve_parent_principal('https://idp.example.invalid','prov-b') AS pb \gset
SELECT ap_m1.resolve_parent_principal('https://other.example.invalid','prov-a') AS pc \gset
SELECT public.ap_m1_test_expect(:'pa' = :'pa2','FP_02 same identity gives the same principal');
SELECT public.ap_m1_test_expect(:'pa' <> :'pb' AND :'pa' <> :'pc' AND :'pb' <> :'pc','FP_02 different subject or issuer gives a different principal');
DO $t$
DECLARE refused boolean := false;
BEGIN
 BEGIN PERFORM ap_m1.resolve_parent_principal('https://idp.example.invalid',''); EXCEPTION WHEN check_violation THEN refused := true; END;
 PERFORM public.ap_m1_test_expect(refused,'FP_02 an empty subject must be refused');
END $t$;

-- FP_03 creating a family needs a principal in the transaction
DO $t$
DECLARE refused boolean := false;
BEGIN
 BEGIN PERFORM ap_m1.create_family('Synthetic family'); EXCEPTION WHEN invalid_authorization_specification THEN refused := true; END;
 PERFORM public.ap_m1_test_expect(refused,'FP_03 create_family without ap.principal_id must be refused (28000)');
END $t$;

-- FP_04 create: family row, OWNER membership, visible to its owner through RLS
BEGIN;
SELECT set_config('ap.principal_id', :'pa', true);
SELECT id AS fam_a FROM ap_m1.create_family('Synthetic family A') \gset
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.create_family('Second A'))=1,'FP_04 second family allowed');
COMMIT;
SELECT set_config('ap.principal_id', :'pa', false), set_config('ap.family_id', :'fam_a', false);
SELECT public.ap_m1_test_expect((SELECT label||state FROM ap_m1.families WHERE id=:'fam_a')='Synthetic family AACTIVE',
 'FP_04 the owner reads the new family through RLS');
SELECT public.ap_m1_test_expect((SELECT membership_role FROM ap_m1.guardian_memberships WHERE family_id=:'fam_a' AND principal_id=:'pa')='OWNER',
 'FP_04 the creator is OWNER');
SELECT public.ap_m1_test_expect(ap_m1.family_owner(:'fam_a'),'FP_04 family_owner() agrees');

-- FP_05 another principal cannot see it, even with the right family in context
SELECT set_config('ap.principal_id', :'pb', false);
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.families WHERE id=:'fam_a')=0,'FP_05 a different principal sees no family');
SELECT public.ap_m1_test_expect(NOT ap_m1.family_owner(:'fam_a'),'FP_05 a different principal is not the owner');
SELECT set_config('ap.family_id', '', false);

-- FP_06 label bounds (table CHECK)
SELECT set_config('ap.principal_id', :'pb', false);
DO $t$
DECLARE refused boolean := false;
BEGIN
 BEGIN PERFORM ap_m1.create_family(''); EXCEPTION WHEN check_violation THEN refused := true; END;
 PERFORM public.ap_m1_test_expect(refused,'FP_06 empty label refused');
 refused := false;
 BEGIN PERFORM ap_m1.create_family(repeat('x',101)); EXCEPTION WHEN check_violation THEN refused := true; END;
 PERFORM public.ap_m1_test_expect(refused,'FP_06 101-character label refused');
 PERFORM public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.create_family(repeat('x',100)))=1,'FP_06 100-character label accepted');
END $t$;

-- FP_07 rollback leaves nothing behind
SELECT set_config('ap.principal_id', :'pc', false);
BEGIN;
SELECT id AS fam_rb FROM ap_m1.create_family('Rolled back') \gset
ROLLBACK;
RESET ROLE;
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.families WHERE label='Rolled back')=0,'FP_07 a rolled-back create leaves no family');
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.guardian_memberships WHERE principal_id=:'pc')=0,'FP_07 nor a membership');
SET ROLE ap_m1_api;

-- FP_08 per-principal cap of 10 owned families
SELECT set_config('ap.principal_id', :'pc', false);
DO $t$
DECLARE i integer; refused boolean := false;
BEGIN
 FOR i IN 1..10 LOOP PERFORM ap_m1.create_family('Cap '||i); END LOOP;
 BEGIN PERFORM ap_m1.create_family('Cap 11'); EXCEPTION WHEN configuration_limit_exceeded THEN refused := true; END;
 PERFORM public.ap_m1_test_expect(refused,'FP_08 the 11th owned family must be refused (53400)');
END $t$;
-- a revoked ownership no longer counts toward the cap, and the cap applies again afterwards
RESET ROLE;
UPDATE ap_m1.guardian_memberships SET revoked_at = now()
 WHERE principal_id = :'pc' AND family_id = (SELECT family_id FROM ap_m1.guardian_memberships WHERE principal_id = :'pc' ORDER BY created_at, family_id LIMIT 1);
SET ROLE ap_m1_api;
SELECT set_config('ap.principal_id', :'pc', false);
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.create_family('After revoke'))=1,'FP_08 a revoked ownership frees a slot');
DO $t$
DECLARE refused boolean := false;
BEGIN
 BEGIN PERFORM ap_m1.create_family('Cap again'); EXCEPTION WHEN configuration_limit_exceeded THEN refused := true; END;
 PERFORM public.ap_m1_test_expect(refused,'FP_08 the cap applies again at 10 live families');
END $t$;
-- the cap is per principal
SELECT set_config('ap.principal_id', :'pa', false);
SELECT public.ap_m1_test_expect((SELECT count(*) FROM ap_m1.create_family('A still can'))=1,'FP_08 another principal is not affected');

RESET ROLE;
DROP FUNCTION public.ap_m1_test_expect(boolean,text);
\echo 'M1 family provisioning PASS: definer boundaries, idempotent principals, ctx-bound create, owner membership, RLS visibility, label bounds, rollback, cap'
