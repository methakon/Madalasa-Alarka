# Logical-model reconciliation and enhancement review

Status: canonical specification consistency, migration compatibility, enhancement regressions and final metadata exports verified locally; see [final acceptance](../../../evidence/local/database/FINAL_LOCAL_SETUP_ACCEPTANCE_2026-10-29.md).

## Preserve the approved baseline and the proposed additions separately

The 120-entity [Figma V1 baseline](../MADALASA_ALARKA_FIGMA_LOGICAL_ERD_V1_2026.json) is restored from the pre-extension source, with two explicit dangling-reference corrections: `location_batch_items.batch_id` now targets `location_ingest_batches`, and `admin_role_permissions.permission_code` targets `admin_permissions`. No shadow entities are created.

All four added entities and existing-column proposals from commit `7123fd3d4c01043e460a94f3fc0645411c55654c` are preserved in the versioned [local V2 proposal](../MADALASA_ALARKA_LOGICAL_ERD_V2_LOCAL_PROPOSAL_2026-10-29.json):

- `admin_sessions`;
- `child_pickup_viewer_passes`;
- `compliance_export_bundles`;
- `credential_renewal_challenges`.

The proposal explicitly records that its live Figma source has not been reverified and that it is not an approved replacement baseline. Its `admin_sessions` reference is normalized to the existing logical `admin_principals`, rather than pointing at nonexistent logical `admin_accounts`. The latter remains a valid physical implementation name, not a new logical entity to invent.

The V1 count assertion is unchanged. The full OpenAPI/screen lint now passes with 171 design operations, 155 paths, 187 screen entries and 120 canonical concepts. Both model versions have zero dangling references under the independent relationship check. Two pure tests also verify count/duplicate/dangling-target negative controls. This repairs specification consistency without manufacturing Figma approval or deleting the proposal.

## Enhancement security review

New regression tests against installed migration 0016 reproduced two actual defects (two failures, exit 1):

1. Pickup-pass metadata remained visible after the creator's exact-child `VIEW_LOCATION` grant was revoked.
2. A compliance bundle could bind a case/family to another child without a composite foreign-key rejection.

Additive migration `0018_schema_enhancement_guards.sql` addresses these findings with live child scope/consent checks, case-child and family-child composite references, and bounded counters/digest validation. Both regressions now pass after coordinated replay, including in the stable 168-test run.

No pickup bearer issuance, non-account location access, compliance archive delivery, raw-child admin access or legal retention approval is enabled. A 45-minute label in the proposal or existing SQL is not independently verified product/legal approval.

## Historical migration compatibility

The original M1 credential/enrollment/idempotency migrations and the published V2 chain reuse versions 0002–0004 and contain incompatible renewal-table types. Explicit lineage manifests, checksum-bound history adoption, additive bridges and runtime quarantine now converge both paths while preserving their published bytes. Actual fresh/historical/populated-upgrade/restore acceptance and per-table retention/ownership metadata verification pass; policy approval remains a separate release requirement.

[Package index](README.md) · [Current setup status](STATUS.md) · [Last complete 140-test checkpoint](../../../evidence/local/database/REVERIFICATION_2026-10-29.md).
