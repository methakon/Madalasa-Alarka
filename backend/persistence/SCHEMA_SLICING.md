# Physical Schema Slicing — concept-to-table justification (L02-001)

> **Scope:** LOCAL synthetic schema reconciliation. Confirms that the implemented physical PostgreSQL schema contains **no concept-only table created by accident**: every physical `ap_m1` base table is justified either by a Figma conceptual entity mapping or by a deliberate operational/security/audit/test role referenced in the migrations. Not an API, Android, legal, or release completion claim.

**Task:** `L02-001` — Review the conceptual logical tables and the implemented MVP subset.
**Established:** 2026-11-01 · **Verified against:** v2 migration lineage `0001`…`0022` on a disposable local PostgreSQL 16 (`madalasa_alarka_test`).

## Inputs

- Conceptual model: `docs/data-model/MADALASA_ALARKA_FIGMA_LOGICAL_ERD_V1_2026.json` — **11 domains, 120 conceptual tables**.
- Concept→physical map: `docs/data-model/local-postgresql/logical-to-physical.json` — `concept_count = 120`, 120 mappings each with `representation` (DIRECT / NORMALIZED / …) and `physical_objects`.
- Authorization/retention/erasure contracts: `DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md`, `DATA_RETENTION_SCHEDULE.md`, `ACCOUNT_DELETION_DESIGN.md`.
- Baseline migration: `backend/persistence/migrations/0001_m1_identity.sql`.

## Observed physical schema

- **141 physical base tables** exist in schema `ap_m1` after applying the v2 lineage.
- **110** of them are directly referenced by at least one of the 120 concept mappings (`physical_objects`).
- **31** physical tables are **not** 1:1 with a Figma concept. Each is a deliberate implementation table (sessions, challenges, audit, consent, erasure/restore, retention, security bootstrap, a normalized child table, or the test-harness table), and each is referenced by migrations (functions, policies, or foreign keys). **None is a speculative concept-only table.**

The physical count exceeding the 120 conceptual count is expected and correct: a sound physical schema normalizes some concepts into multiple tables, and adds infrastructure tables (durable inbox/outbox, idempotency, audit, worker fences, revocation epochs) that are implementation mechanisms rather than user-facing entities. **120 conceptual entities is not a target of 120 physical tables.**

## The 31 non-concept physical tables and why each is justified

| Category | Tables | Justification |
|---|---|---|
| Admin/session/auth | `admin_sessions`, `admin_login_challenges`, `credential_renewal_challenges`, `owner_identity_allowlist`, `trusted_principal_verifications`, `device_credentials`, `device_reenrollment_events` | Authentication/session/credential machinery behind the identity concepts; referenced by auth functions and RLS, not separate Figma entities. |
| Audit/security | `audit_events`, `consent_decision_audit`, `entitlement_audit`, `security_audit_events` (if present) | Immutable audit trails for sensitive actions; required by the authorization/consent contracts. |
| Consent | `consent_documents`, `consent_policy_versions` | Versioned consent artifacts supporting the consent-records concept (DPDP lawful-authority path). |
| Erasure/restore/retention | `adult_erasure_jobs`, `adult_erasure_requests`, `erasure_evidence`, `erasure_store_inventory`, `restore_ledger_imports`, `restore_runs`, `restore_suppression_receipts`, `backup_inventory`, `retention_holds`, `compliance_export_bundles` | Account-deletion / retention / backup-fence mechanisms from `ACCOUNT_DELETION_DESIGN.md` and `DATA_RETENTION_SCHEDULE.md`; prevent deleted data from being silently restored. |
| Delivery/receipts | `alert_delivery_attempts`, `command_receipts` | Delivery-attempt and receipt detail rows normalized out of the alert/command concepts. |
| Billing/trial detail | `trial_child_entitlements`, `child_pickup_viewer_passes` | Normalized per-child trial/pickup detail behind the billing concepts. |
| Location detail | `trip_routepoints`, `location_collection_policies` | Route geometry points and collection-policy rows normalized under the trip/location concepts. |
| M1 compatibility | `child_guardian_grants`, `m1_renewal_hold_preservation` | Historical M1 predecessors retained for lineage compatibility (superseded by `child_access_grants_v2`); preserved, not duplicated. |
| Test harness | `local_test_settings` | Synthetic-only local test opt-in; never carries product data. |

Reference-integrity check: 25 of the 31 carry declarative foreign keys and/or RLS policies; the remaining 6 (`admin_login_challenges`, `erasure_store_inventory`, `local_test_settings`, `m1_renewal_hold_preservation`, `owner_identity_allowlist`, `retention_holds`) carry no FK/RLS but are each referenced 7–20 times across the migrations by functions and policies — i.e. purposeful standalone tables, not accidents.

## MVP subset position

The v2 lineage already implements the full M1 + V2 subset needed for the current synthetic development (identity, child-scoped grants, consent/authority, billing/entitlements, location ingestion/history, alerts/usage, commands/capabilities, admin RBAC/support/FAQ, media sessions/quota, erasure/audit, operations/integrity). No additional "ship all 120" expansion is implied; new tables must be sliced per justified feature with migration, RLS, indexes, and tests.

## Verification

Reproducible check (disposable local PostgreSQL, v2 lineage):

```
tools/database/manage.py start-memory-test
tools/database/manage.py migrate --database test --lineage v2
python3 backend/tests/check_schema_slicing.py
```

`check_schema_slicing.py` asserts that every physical `ap_m1` base table is justified (present in the concept map OR in the curated operational allowlist above), and fails if any unexplained table appears — catching an accidental concept-only table in future changes. See `evidence/local/tasks/L02-001.md`.

## Related

- `docs/data-model/local-postgresql/logical-to-physical.json` · `physical-schema.json` · `MODEL_RECONCILIATION_2026-10-29.md`
- `docs/data-model/PHYSICAL_SCHEMA_DEEP_AUDIT_AND_REMEDIATION_2026-10-29.md`
