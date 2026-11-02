# Local PostgreSQL implementation package

Status: LOCAL_READY for the synthetic local database foundation. Admin/product/real-child/production release remains NOT_READY; this is not a legal-approval record.

## Reading order

1. [Current setup status and integration prerequisites](STATUS.md).
2. [Development, migrations, build, tests and recovery runbook](RUNBOOK.md).
3. [2026-10-30 main reconciliation and executed acceptance](../../../evidence/local/database/PR11_RECONCILIATION_ACCEPTANCE_2026-10-30.md); [reconciliation acceptance: four reproduced defects, 0019 fix and 205-test run](../../../evidence/local/database/RECONCILIATION_ACCEPTANCE_2026-10-29.md); [earlier setup acceptance](../../../evidence/local/database/FINAL_LOCAL_SETUP_ACCEPTANCE_2026-10-29.md); [lineage/restore checkpoint](../../../evidence/local/database/LINEAGE_CONVERGENCE_2026-10-29.md).
4. [Owner decisions and acceptance boundaries](../../roadmap/SIX_GATE_OWNER_DECISIONS_AND_AGENT_HANDOFF_2026-10-29.md).
5. [Logical model reconciliation and enhancement security review](MODEL_RECONCILIATION_2026-10-29.md).
6. [Separate historical 18-table M1 catalog](../historical-m1/PHYSICAL_TABLE_CATALOG.md).

## Package ownership and layout

- `docs/data-model/local-postgresql/`: database-specific runbook, status, and catalog/traceability exports when generated and verified.
- `backend/persistence/migrations/`: versioned executable SQL, not duplicated in documentation.
- `backend/tests/database/`: synthetic database and HTTP integration acceptance.
- `tools/database/`: local lifecycle and catalog-export tooling.
- `evidence/local/database/`: redacted execution checkpoints, separate from specifications.
- `.local-db/`: ignored credentials, raw logs, database storage, build caches and backup archives. Never commit these files.

The [catalog](physical-schema.json), [physical ERD](PHYSICAL_ERD.md), [logical mapping](logical-to-physical.json), [operation/dependency matrix](api-to-table.json), [migration manifest](migration-manifest.json), [retention/ownership manifest](retention-ownership-manifest.json) and [typed constraint registry](typed-constraint-registry.json) are regenerated and verified against the actual final test catalog. They are schema/dependency evidence, not proof of every HTTP handler or approved retention policy.

## Navigation

[Documentation home](../../README.md) · [Canonical project document index](../../phases/M0-foundation-and-approvals/01-project-governance/PROJECT_DOCUMENTS_INDEX_2026.md) · [M1 development-process index](../../phases/M1-secure-platform-foundation/02-development-process/README.md)
