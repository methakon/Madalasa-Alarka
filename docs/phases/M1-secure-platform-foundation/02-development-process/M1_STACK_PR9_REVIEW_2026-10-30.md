# M1 stack PR #9 — independent review and PostgreSQL16 evidence

**Date:** 2026-10-30. **Status:** REMEDIATION_IN_PROGRESS; Phase 1 and Phase 2 are locally exercised, published and hosted-CI verified (`d7f133a` implementation / `d3a4682` evidence; Phase2 `b1df65742faf3674486d7935cf02bd147957e103`). ParentOIDC implementation and final source/CI acceptance remain in progress, not yet verified. Owner merge approval NOT_GRANTED. **Scope:** synthetic local and separately pinned hosted evidence, not production/legal/Android acceptance. Sections 1–8 preserve the original `c693899` review; section 9 records remediation and supersedes those four findings' original execution states only within its stated local scope. Proposed review owners: backend/security; independent sign-off unassigned. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md) · [Current blockers](../../M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md).

[Machine-readable execution record](../../../../evidence/local/reviews/PR9_REVIEW_2026-10-30.json) preserves commands, exit codes, source SHA and local/hosted scope; no private logs or credentials are committed.

## 1. Baseline and verdict

- Repository: `methakon/Madalasa-Alarka`.
- [PR #9](https://github.com/methakon/Madalasa-Alarka/pull/9): OPEN, head `c693899e4b411cbadd1639f0bcb642844af50ea9`, base main `0a6be11ca811e842cc9839ab623ec118514020dd`. Rechecked unchanged during review. GitHub reports mergeable/CLEAN; **mergeability is not approval**.
- Reused documentation branch `audit/2026-10-29-final-screen-api-db-reconciliation` / existing [PR #2](https://github.com/methakon/Madalasa-Alarka/pull/2). Its newer owner decisions were locally merged without dropping the pre-existing index commit or signing work. No new branch or PR merge occurred.
- PR9's tree equals `feat/m1-purge-jobs`; 37 files changed against main, +3,041/−106. It carries the intended #3–#8 **content**, but not all historical merge nodes.
- **Verdict:** useful, tested M1 stack integration, not complete M1/product readiness. Report and fix/review the findings below before owner decides on merge. Do not imply that default-deny authentication is working ParentOIDC, that synthetic headers prove identity, or that this schema supports approved blended-family V2.

## 2. Stack ancestry and source preservation

All local/remote branch refs and open PRs were inspected after fetch. Local branch named `main` is stale; every comparison here uses fetched `origin/main`, not that local branch.

| PR | Content head is ancestor of PR9? | Recorded merge node in PR9 ancestry? | What actually happened |
|---|---|---|---|
| #3 credential/enrollment | `3f6cd01`: yes | `0a6be11`: no | Main includes #3; PR9 contains its content without main's merge node |
| #4 backend/idempotency | `ddbb25a`: yes | `2821a8a`: no | Merged into #3 branch after #3 had already merged |
| #5 physical catalog | `976805d`: yes | `ddbb25a`: yes | Included through #4's ancestry; not independently on main |
| #6 G-6 lint | `48318b2`: yes | `58ba650`: no | Merged into backend feature branch |
| #7 createFamily | `92d4803`: yes | `62a33a6`: no | Merged into G-6 feature branch |
| #8 purge jobs | `6106542`: yes | `c693899`: yes | Merged into createFamily; this is PR9 head |

`git merge-base origin/main <PR9 head>` is `3f6cd01`; migrations 0001–0003 are unchanged against main; 0004 and 0005 are additions. Thus PR9 solves the intended missing-content problem; a closed stacked PR did not by itself place that content on main. #1 six-gate handoff and #2 documentation audit remain separate open PRs, each with successful current documentation check.

## 3. Findings requiring attention

Line references below bind to PR9 head, not this documentation worktree. Static findings are explicitly not reported as locally reproduced HTTP failures.

| Severity / ID | Evidence | Consequence and proposed correction | Verification state |
|---|---|---|---|
| HIGH / PR9-01 | `backend/tests/integration_families.sh:17`: `kill ${PID:-0} ${PID2:-0}` | Before either child PID is assigned, or before PID2 starts, cleanup can signal process group 0, terminating the caller/siblings and interrupting DB cleanup. Kill/wait only validated positive PIDs actually started by this script. Run failure-path tests in a separate process group until repaired | STATIC_CONFIRMED; dangerous failure path deliberately not executed locally |
| MEDIUM / PR9-02 | `backend/src/families.h:52–53`; `main.cc:40–58` | `getDbClient("ma")` is called before testing existence. The pinned dependency asserts a missing named client in assertion-enabled builds; the null check and later try do not protect this path. Check `hasDbClient()` first and add authenticated-valid-request/no-DB regression | STATIC_REVIEW; no local binary reproduction. Existing second HTTP instance stops at 401, so does not exercise promised 503 |
| MEDIUM / PR9-03 | `.github/workflows/m1-contract-and-tenant.yml:137–139` | `strings binary \| grep -q synthetic_test` inside `if`, under Bash pipefail, can receive SIGPIPE upstream and skip its failure branch even when marker exists. Consume all output or inspect captured output; add a known-synthetic negative control | **REPRODUCED LOCALLY** using a large synthetic marker fixture: existing pattern exits 0 (miss); full-consumption grep alternative detects it (sentinel exit42). This demonstrates a gate defect, not that deployed auth is bypassed |
| MEDIUM / PR9-04 | `main.cc:49–54`, `families.h:59–60` | Client timeout is unset (`-1.0`); only DB lock_timeout is set after acquiring a transaction. No effective bounded acquisition/request/statement deadline for unavailable DB or pool exhaustion. Introduce finite deadlines and retryable dependency errors with unavailable-DB/slow-query/pool tests | STATIC_CONFIRMED configuration gap; no local outage/load run |
| MEDIUM / M1-INHERITED-01 | `0003_m1_enrollment_and_credential_hardening.sql:133–145`; `0002_m1_device_credentials.sql:23–37` | Distinct consumed challenges lock different rows. Parallel renewal can each insert a live credential without a common device lock or unique live-device constraint, violating documented one-live-credential invariant. Serialize on device and add two-session distinct-challenge test | SOURCE_REVIEW; existing sequential rotation tests pass, concurrent invariant NOT_PROVEN. Inherited from main, not newly introduced by PR9 |
| MEDIUM / M1-INHERITED-02 | `0002_m1_device_credentials.sql:97–110` | Count-before-insert five-open-challenge bound has no per-device serialization; concurrent callers may exceed it. Add device-scoped serialization plus burst regression; this does not replace rate limiting | SOURCE_REVIEW; inherited from main; no concurrent reproduction claimed |
| RETENTION GAP / M1-RET-01 | `0003_m1_enrollment_and_credential_hardening.sql:173–180`; `docs/M1_PURGE_JOBS_RUNBOOK.md:19` | Enrollment cleanup is limited to abandoned PENDING_PROOF devices. Completed enrollment challenges on active/revoked devices and pairing-code rows lack equivalent cleanup here. Do not call two purge jobs complete artifact/data retention; align lifecycle wording and approved per-category TTLs | SOURCE_CONFIRMED; current narrow purge tests pass |

The inherited use of transaction-frozen `now()` in credential/challenge windows also deserves the real-elapsed-time/row-lock regressions listed in T-PEND-04. Published SQL must not be silently edited to hide review findings; reconcile additive fixes with the existing namespaced migration policy.

## 4. Authentication, authorization and createFamily trace

`backend/src/auth.h` explicitly lacks JWT issuer/audience/signature/JWKS/expiry validation. Normal build selects reject-all, not a permissive production identity provider. `MA_SYNTHETIC_AUTH` defaults OFF; test-only header authentication additionally needs its runtime switch. The CI exclusion test's flaw above weakens assurance, but is **not evidence of a production JWT bypass**. Provider validation is engineering work that need not wait for Payments identity verification; real-provider acceptance needs separately authorized configuration.

The database trusts the verified backend: `resolve_parent_principal` accepts asserted issuer/subject; session GUCs and idempotency actor IDs are supplied by the DB caller. SQL helpers do not independently authenticate an adult, verify age, establish parenthood or legal guardian authority. Google Sign-In does not supply Family Link relationship proof.

Positive createFamily flow: body limit → strict syntax/idempotency UUID/JSON shape → authentication → label bounds → principal resolution → transaction-local principal → claim → family plus OWNER membership → recorded 201 response → awaited database commit. Values are bound parameters; raw key is hashed, mismatch response does not expose stored data, replay precedes cap and receives a fresh request ID. Family cap uses a transaction advisory lock. Error text is not leaked. These are source/CI-supported properties, not a claim of all 11 M1 HTTP operations implemented.

Only `/healthz` and `POST /v1/families` are registered in this PR. The whole-project 171-operation OpenAPI and 120 conceptual entities remain design scope, not implemented handler/table counts. No admin application or broad HMVC domain/worker implementation is established by a small header-based skeleton; maintain the approved C++20 Drogon modular/SOLID boundaries as work expands.

## 5. Fresh PostgreSQL16 execution — independent local evidence

Source was exported from the exact Git commit with `git archive`, without checking out or altering PR9. A newly created disposable database was used; the existing V2 development/test data was not contacted or reset.

Environment: PostgreSQL **16.15**, cached image ID `sha256:1a6ab3f5345eb6dbe04a1349529caabdb0ab09293a09590fad07b2246bfa4b54`; isolated container `madalasa-pr9-review-pg16`, network mode **none**, **no published ports**, local Unix socket, 1 CPU/512MiB RAM, 384MiB tmpfs database. Durability options were not disabled. SQL was invoked with `psql -X -v ON_ERROR_STOP=1` against `madalasa_pr9_review`. Test roles/password literals in upstream scripts are public synthetic fixtures, not generated production credentials.

Explicit replay order (not a directory-wide V2 glob):

1. `0001_m1_identity.sql`
2. `0002_m1_device_credentials.sql`
3. `0003_m1_enrollment_and_credential_hardening.sql`
4. `0004_m1_idempotency.sql`
5. `0005_m1_family_provisioning.sql`

| Command/check | Local result |
|---|---|
| `python3 backend/tests/lint_openapi_m1.py docs/openapi-m1.yaml` | Exit0 |
| `python3 backend/tests/check_physical_catalog.py` | Exit0 |
| `python3 backend/tests/lint_openapi_full.py` | Exit0: 171 draft operations,155 paths,187 screens,120 conceptual tables |
| `/usr/bin/python3 -m unittest backend.tests.test_physical_catalog backend.tests.test_lint_openapi_m1 backend.tests.test_deploy_units backend.tests.test_error_catalog_sync -v` | **61 tests PASS**, exit0 |
| Five explicit migration commands above | All exit0 |
| `m1_tenant_isolation.sql`, `m1_credential_lifecycle.sql`, `m1_enrollment.sql`, `m1_idempotency.sql`, `m1_family_provisioning.sql` | All five exit0 |
| `bash backend/tests/m1_idempotency_concurrency.sh` | Exit0: block→replay, rollback ownership handover, lock timeout |
| `bash backend/tests/purge_job.sh` | Exit0: expired/recent, repeat, exact grants, denied role, unreachable DB, bounded lock wait |
| New [m1_security_catalog_acceptance.sql](../../../../backend/tests/m1_security_catalog_acceptance.sql) | Exit0: catalog assertions and three deliberate drift controls detected/rolled back; wrong-database invocation exit3 before catalog mutation |

Initial local tooling attempts are not concealed: the default tool Python lacked PyYAML and one shell lacked psql on PATH. The first mixed unittest run had 58 tests/one import error; system Python with existing PyYAML and explicit rootless client paths produced the successful 61-test run above. No application test was weakened. Local native rebuild/outage tests were not attempted while system-wide I/O pressure was high; verified exact-head hosted evidence is reported separately below.

Observed live catalog: **18 ap_m1 base tables**, each ENABLE+FORCE RLS and owned by `ap_m1_owner`. `ap_m1_api`: NOLOGIN in migrations, NOSUPERUSER/NOBYPASSRLS/no role membership. `ap_m1_auth`: intentionally BYPASSRLS, but NOLOGIN/NOSUPERUSER, constrained function ownership/grants and fixed `pg_catalog, ap_m1` search path. PUBLIC has no application function EXECUTE or table grants. Do not claim every role is NOBYPASSRLS, or that superuser-run assertions alone prove tenant isolation: separate suites actually SET ROLE for denied behavior.

The new rollback-only controls remove FORCE RLS, grant PUBLIC create_family execution and grant runtime BYPASSRLS one at a time; each is detected and rolled back, then the clean catalog is rechecked. They validate the detector, not a product migration. The script refuses databases outside its dedicated review naming scope.

## 6. Hosted Actions evidence and older failures

[Run 41014540240](https://github.com/methakon/Madalasa-Alarka/actions/runs/41014540240), head `c693899e4b411cbadd1639f0bcb642844af50ea9`, pull_request event, 2026-10-30: **SUCCESS**. Job step metadata and logs were read, not inferred from a badge.

- `contracts-and-isolation`: five migrations, tenant/credential/enrollment/idempotency/family SQL, idempotency concurrency, purge, deploy-unit and error-catalog checks all successful.
- `backend-build`: pinned dependency build, backend compile, CTest **1/1**, HTTP smoke, deployable-marker gate, separate synthetic test build and end-to-end createFamily all successful. HTTP integration logs cover validation, replay/mismatch, principal separation, hashed keys, eight-way duplicate concurrency, cap and error envelopes. These synthetic results do not validate ParentOIDC. The marker gate's negative-control defect remains despite its successful check.
- [Documentation run 41014540218](https://github.com/methakon/Madalasa-Alarka/actions/runs/41014540218): SUCCESS.

Inspection of the latest **100 runs** found three older failures: run `40882818566` on DB branch revision `3d3e285` failed the full-contract conceptual DB table count; runs `40831057258` and `40831051347` on old catalog revision `31573ae` failed catalog checks. Logs from the DB failure and one duplicate catalog failure were inspected. These do not make the current PR9 head red; conversely PR9 green does not certify the separate latest V2 branch or erase historical failures. Its newer local evidence must remain separately scoped.

## 7. Canonical contract/schema conflicts and six gates

The six-gate handoff was read at existing PR1 head `59125d402b07c20aaf6ecb13d69542997223bedf`, where it lives; it is not silently claimed merged into the documentation branch. [Pinned handoff source](https://github.com/methakon/Madalasa-Alarka/blob/59125d402b07c20aaf6ecb13d69542997223bedf/docs/roadmap/SIX_GATE_OWNER_DECISIONS_AND_AGENT_HANDOFF_2026-10-29.md).

- M1 `child_guardian_grants` remains family-membership-bound, incompatible with the approved [exact-child blended-family V2 ADR](../03-security-and-permissions/ADR_2026_10_28_BLEND_FAMILY_V2_AND_NO_FAMILY_LINK_DEPENDENCY.md). It is a historical baseline, not safe external co-parent release behavior.
- Separate DB branch `b507e5f` contains the existing explicit namespaced manifest and additive V2 through0019. PR9's original M1 **0005 family provisioning** is newer than that manifest's historical M1 tail0004, and collides numerically with V2's 0005 location migration. Integrate semantically through the existing manifest/bridge model; never alphabetically combine files, renumber published SQL or assume the different backend/catalog implementations already agree.
- The catalog's 18 physical tables are not 120 conceptual tables to auto-generate. PR9's full-contract lint passing verifies draft joins/counts only.
- Auth, consent/authority, retention/deletion, prepaid seat/provider acceptance and Android evidence remain separate gaps. Hosting/egress choices are deployment gates, not prerequisites for portable synthetic engineering.
- G-7 parser-level oversized requests above1MiB still receive Drogon's bare413 before ordinary request advice; the comment/test documents this. A future deployed proxy/body-size normalization contract needs actual acceptance, not an assumption that all errors already share one envelope.

## 8. Required follow-up and prohibited inference

1. Fix guarded positive-PID cleanup and prove failure cleanup cannot signal the caller.
2. Fix fail-open marker pipeline and prove the actual synthetic binary is rejected.
3. Guard absent DB client and bound acquisition/statement/request time; add outage/pool tests.
4. Add serialized credential renewal/challenge-limit regressions and clarify artifact purge coverage using additive migration discipline.
5. Review real ParentOIDC/JWKS implementation and separate legal guardian authority; no Family Link API dependency.
6. Owner reviews these findings before any PR9 merge. Reconcile M1 0005, V2 grants/manifests and backend/contracts without duplicating published histories.

No infrastructure deployment, Android implementation, new production credentials, real-child processing, Console declaration/payment change, Android app build, purchase or PR merge was performed. Product/production/legal/Play readiness remains **NOT_READY**; the tested local/CI slices are **VERIFIED only within their stated scope**.

## 9. Remediation checkpoint — Phase 1 local execution

The existing `feat/m1-create-family` branch is reused. Tests below exercised source subsequently committed as `d7f133ad1d04938b46e536fd417eb1274b5e1585` against pinned Drogon **1.9.14**, JsonCpp **1.9.5**, and a fresh isolated PostgreSQL **16.15** container named `madalasa-pr9-remediation-pg16` (network none, no published ports). [Phase 1 command/source record](../../../../evidence/local/reviews/PR9_PHASE1_REMEDIATION_2026-10-30.json). CI publication is pending; these are not final task PASS records. Original migrations 0001–0005 were replayed explicitly and byte-compared against `c693899e4b411cbadd1639f0bcb642844af50ea9`. The separate V2 worktree was not modified.

| Finding | Code correction | Regression and actual execution | Remaining status |
|---|---|---|---|
| PR9-01 — cleanup can signal PID 0 | `integration_families.sh` records positive spawned PIDs, TERM/bounded wait/KILL/reap, preserves original exit, and cleans project-TMPDIR artifacts | `test_integration_cleanup.py`: early failure, failure before second server, uncooperative child; isolated caller and unrelated sibling survival checked before emergency harness cleanup. Combined shell/gate suite: 9 tests, exit 0 | Local correction exercised; final immutable source/hosted acceptance pending |
| PR9-02 — absent-client lookup precedes availability check | `families.h` calls `hasDbClient()` before acquisition; authenticated missing configuration returns catalog-compliant retryable 503 | `integration_db_failures.py --case all`: authenticated missing DB returns 503; unauthenticated remains 401; no process termination, exit 0 | Assertion-enabled dependency failure remains source-confirmed, not locally reproduced: baseline with Release-built dependency already returned 503 |
| PR9-03 — fail-open marker pipeline | `check_production_auth.sh` consumes inspection output, distinguishes absence from tool errors; CI uses a real synthetic-build control | Nine combined unit tests, exit 0; actual production binary with synthetic auth OFF passes, actual synthetic binary presented as production is rejected with exit 1, combined real-binary control exits 0 | Marker exclusion only; not ParentOIDC acceptance |
| PR9-04 — unbounded acquisition/statements | `db_config.h`, `main.cc`, `families.h`, `db_support.h`: bounded validated limits, finite acquisition/execution/commit waits, server statement/lock deadlines, controlled retryable dependency errors | Immutable baseline fails both `--case unreachable` and `--case slow` with client timeouts (exit 1 each). Corrected `--case all` exits 0: invalid configuration, authenticated missing DB, unreachable DB, slow nonlocking statement, exhausted pool, lock timeout | Local deadline behavior exercised; final immutable source/hosted acceptance pending |

Executed commands (all exit 0 unless explicitly noted):

- `/usr/bin/python3 -m unittest discover -s backend/tests -p 'test_*.py' -v`: **70 tests**.
- `python3 backend/tests/integration_db_failures.py .dev-environment/pr9-baseline-build/ma_backend --case unreachable` and `--case slow`: **exit 1 each**, expected baseline regression failures.
- `python3 backend/tests/integration_db_failures.py "$PWD/.dev-environment/pr9-fixed-build/ma_backend" --case all`: six reported cases.
- `bash .dev-environment/build-pr9-backend.sh "$PWD" "$PWD/.dev-environment/pr9-fixed-build" ON` and the analogous `pr9-production-build OFF`: both builds and CTest exit 0.
- `bash backend/scripts/check_production_auth.sh .dev-environment/pr9-production-build/ma_backend .dev-environment/pr9-fixed-build/ma_backend`: exit 0.
- `bash backend/scripts/check_production_auth.sh .dev-environment/pr9-baseline-build/ma_backend`: **exit 1**, required rejection.
- `bash backend/tests/integration_families.sh "$PWD/.dev-environment/pr9-fixed-build/ma_backend"`: exit 0.
- `psql -X -v ON_ERROR_STOP=1 -f backend/tests/<suite>.sql` for `m1_tenant_isolation`, `m1_credential_lifecycle`, `m1_enrollment`, `m1_idempotency`, `m1_family_provisioning`: five exit-0 runs.
- `bash backend/tests/m1_idempotency_concurrency.sh`; `bash backend/tests/purge_job.sh`: exit 0 each.
- Both OpenAPI lints, `check_physical_catalog.py`, `check_document_structure.py`, and `git diff --check`: exit 0 each. Documentation structure check validates the existing 72-document canonical relocation inventory, 12 phase indexes and 19 categories; it is not validation of the separate audit branch's later policy inventory.

Raw local command logs remain ignored under `.dev-environment/phase1-*`; they contain synthetic fixtures only and are not a substitute for the final committed, redacted command/source/CI record. Full Phase 2 concurrency/hold/retention tests and real ParentOIDC implementation/verification remain pending. No merge or deployment is authorized by this checkpoint.

## 10. Phase 2 combined local execution — supersedes inherited finding states

Historical M1 receives additive `0006_m1_concurrency_and_retention_holds.sql`; 0001–0005 remain byte-identical to `c693899`. Separate V2 migrations/manifests are untouched. This migration preserves 18 physical tables and existing lifecycle/purge signatures, defaults, owners, ACLs, fixed search paths and the four-field credential-purge result. The new pairing purge requires explicit grace; it is optionally wired into the undeployed runner, never silently enabled by a new legal TTL.

| Original finding | Correction | Regression and actual execution | Scope/status |
|---|---|---|---|
| M1-INHERITED-01: distinct renewal challenges can create two live credentials | Shared device-first lifecycle serialization; recheck state and wall-clock validity after waits, including credential locks | `m1_credential_concurrency.py`: historical baseline actually leaves two unrevoked credentials; combined0006 passes 17 barrier-driven renewal/enrollment/expiry/rollback/revocation/ACL cases | Local database behavior verified; final publication/CI acceptance pending |
| M1-INHERITED-02: concurrent issuance exceeds five open challenges | Challenge count and insert under the same device lock | Same suite reproduces six baseline challenges and passes deterministic cap and burst tests after0006 | Local concurrency verified; not an HTTP rate-limit implementation |
| M1-RET-01: incomplete enrollment/pairing retention | Completed enrollment cleanup, explicit-grace pairing cleanup, artifact/device holds, all direct device FK guards; no audit/key/revocation deletion | Fresh empty `ma_pr9_retention_*` replay: original five migrations fail completed-ACTIVE cleanup, exit3; combined0006 plus `m1_retention_holds.sql -v retention_check_hold_acl=1` passes twice, exit0 | Synthetic engineering retention only, no legal-policy approval |
| Hold/purge and lifecycle lock-order integration | Device-first purge, target-row hold rechecks; optional safely quoted pairing runner; exactly three function grants and no purge-role table privileges | `m1_purge_concurrency.py`: 20 tests pass, exit0; `purge_job.sh` executed separately and passes optional/default jobs, counts, idempotence, denied roles/hold mutation, invalid/injection-shaped grace and bounded lock waits | Local runtime integration verified; no scheduling/deployment |

Exact principal commands (project-local rootless psql PATH/LD_LIBRARY_PATH and the isolated PGHOST from section9):

- `.dev-environment/concurrency-venv/bin/python backend/tests/m1_credential_concurrency.py`: exit1 on original five migrations (baseline RED); add `--migration backend/persistence/migrations/0006_m1_concurrency_and_retention_holds.sql`: exit0, 17 tests.
- `psql -X -v ON_ERROR_STOP=1 -v retention_check_hold_acl=1 -f backend/tests/m1_retention_holds.sql`: exit0 twice on a fresh empty six-migration replay. The test refuses other database names or populated fixture databases before cleanup.
- `.dev-environment/concurrency-venv/bin/python backend/tests/m1_purge_concurrency.py`: exit0, 20 tests; `bash backend/tests/purge_job.sh`: exit0, run serially because its synthetic fixture roles are cluster-wide.
- Original five SQL suites, full Python discovery, HTTP database-failure/family integration, both OpenAPI lints, physical catalog and documentation structure checks were rerun successfully after the combined migration. Final all-checks source freeze remains pending ParentOIDC.

One integration attempt ran the retention matrix on the already-used review database and failed its global fixture count. No assertion was weakened: a new empty isolated replay passed, and an explicit empty/dedicated-database preflight now rejects this misuse. SQL fixture failures during test development remain in ignored execution histories; they are not hidden as product failures or passing tests.

Phase2 source is published as `b1df65742faf3674486d7935cf02bd147957e103`: [backend/contracts CI41050956770](https://github.com/methakon/Madalasa-Alarka/actions/runs/41050956770) and [documentation CI41050956590](https://github.com/methakon/Madalasa-Alarka/actions/runs/41050956590) are successful. [Phase2 command/source/migration-hash record](../../../../evidence/local/reviews/PR9_PHASE2_REMEDIATION_2026-10-30.json). Phase 1 publication at `d3a4682dd3790672f40fabc09b134097338cac9b` is verified remotely: [backend/contracts CI41049572540](https://github.com/methakon/Madalasa-Alarka/actions/runs/41049572540) and [documentation CI41049572707](https://github.com/methakon/Madalasa-Alarka/actions/runs/41049572707) are successful. Those runs do not certify this later Phase2 source. ParentOIDC remains pending. PR9 stays open; merge requires owner review.