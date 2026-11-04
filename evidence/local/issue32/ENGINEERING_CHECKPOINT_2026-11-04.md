# Issue #32 — synthetic engineering checkpoint

Date: 2026-11-04. Status: PARTIAL / REVIEW PENDING. No deployment, real-child processing, external approval or capacity certification.

## Source and review route

- E-01 focused PR: https://github.com/methakon/Madalasa-Alarka/pull/34 (`api` → `dev`), candidate `d9ece9ed0d4a2908fa0bb8368d12a8232989ffea`; five implementation/test files, no documentation changes.
- E-03 implementation `6d6004f`, production HTTP harness `aa1949e`; E-04 correction `456ca1e4d5ee1e440aed021d5a9a0593daf7a68e`.
- Later slices are recoverably published at remote tag `issue32-tested-packages-checkpoint-456ca1e`, not merged or separately PR-accepted. A verified complete-history bundle is retained privately under the project `.local-db/issue32-tested-packages.bundle`.
- Existing working branches are reused. To keep PR #34 focused, later slices remain queued at that tag until the preceding PR is reviewed. No temporary working branches or security-critical auto-merges are authorized by this checkpoint.

## Executed commands and outcomes

All Python commands used the project `.venv/bin/python`. SQL target: checkout-labelled synthetic PostgreSQL 16.9 / PostGIS 3.5.2 on loopback 15433; tmpfs, not a production or disk-durability test.

| Slice | Command / proof | Actual result |
|---|---|---|
| E-01-only PR candidate | `tools/database/manage.py reset`, `migrate`, `test` | Each exit 0; fresh chain through 0025; 309 tests OK (10 skipped), 120.949 s |
| E-01/E-03 targeted | `-m unittest backend.tests.database.test_device_transaction_context backend.tests.database.test_ingest_idempotency backend.tests.database.test_rls_posture backend.tests.database.test_migration_lineages` | Exit 0; 58 tests OK; fresh replay through 0027 |
| E-03 production HTTP | `backend/tests/integration_device_ingestion_v2.py build/backend/ma_backend --evidence .local-db/issue32-e03-production-http-parent.json` | Exit 0; 11/11 checks passed; production binary without synthetic-auth compilation, restricted runtime login; fixture cleaned and owned server stopped |
| E-04 RED | `PYTHONPATH=backend/tests/database .venv/bin/python -m unittest test_erasure_dependency_order.ErasureDependencyOrderTests.test_request_orders_dependents_and_is_idempotent -v` before 0028 | Exit 1: reproduced `compliance_export_bundles_case_id_fkey` violation while purging `admin_cases` |
| E-04 GREEN | Register/apply 0028; `PYTHONPATH=backend/tests/database .venv/bin/python -m unittest test_erasure_dependency_order -v` | Exit 0; eight tests OK, including restore replay, cross-family refusal, unresolved archive/hold refusal and private-function ACLs |
| Combined source through 0028 | `tools/database/manage.py test` | Exit 0; 345 tests OK (10 skipped), 144.568 s |

Ten skips: five historical-convergence tests require explicit isolated authorization and DSNs; five source guards reference a missing ignored historical fragment. Skips are not passes. No weakened guard or cleared independent erasure ledger is claimed.

## Requirement → implementation → negative proof

- **E-01:** 0025 / `test_rls_posture.py`: catalog forced-RLS coverage, explicit existing deny intent, membership/administrative-attribute detector, cross-family and revoked/expired scopes. False permissive policies document the prior no-policy denial, not stronger row enforcement. Does not close whole-system E-01.
- **E-03:** 0026 receipt wrapper, 0027 DeviceBearer digest context, `device_auth.h`, `device_activity.h`, `db_support.h`. Actual HTTP results: first delivery 202 (1 accepted/0 duplicate); exact and cross-batch replay 202 (0/1); repeated occurrences fresh (1/1), known (0/2); changed batch, event and reused sequence each 409; wrong device 403; absent/revoked bearer 401. Stored rows unchanged by denied requests. Every credential-context use revalidates against the established credential lookup. Digest context is bearer-equivalent and must never be logged.
- **E-04:** 0028 moves compliance bundles before cases, explicitly re-purges pairing logs and clears optional device description fields; relevant unresolved holds/archive scope abort without a false completion certificate. Tests preserve sibling/cross-family fixtures. No external archive, phone-local or lost-recovery-ledger deletion proof is claimed.

## Remaining gates

E-03 HTTP behavior is exercised, but the existing synchronous raw-write/outbox implementation is not acceptance of the design-only durable-inbox architecture or a benchmark-approved alternative. Health-table writes remain deliberately revoked under 0007; that separate HTTP path was not repaired by widening grants.

E-04 still needs comprehensive subject/hold coverage, recovery-source completeness/freshness, external-store receipts and physical/offline-device proof. An atomic hold refusal is not successful deletion or guaranteed durable revocation.

B-09/B-18 review must use approved exact-child authority/consent semantics; disputed guardian powers and TTLs are not invented. B-07 durations remain owner decisions. X-01 payment, X-02 Play and X-03 legal evidence remain separate; documentation does not certify them. 108-device capacity and Android battery acceptance remain NOT VALIDATED.
