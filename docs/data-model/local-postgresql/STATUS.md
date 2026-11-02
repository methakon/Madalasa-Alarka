# Local PostgreSQL setup status

Status: LOCAL_READY for the synthetic local database foundation and admin API development. **Current reconciled checkpoint (2026-10-30):** the branch has been merged with `main`, convergence extends to `v2:0020`, and V2-backed *production* parent authentication is an explicit blocker (see below). Product/admin UI/provider/real-child/production release remains NOT_READY. This is not blanket completion of roadmap tasks.

## 2026-10-30 main reconciliation

Ledger numbers below describe the earlier 0019 checkpoint and are kept as history. The reconciled branch adds `compat/m1_pre_v2_0017` (pre-0017 retention-hold preservation) and `v2:0020` (hold restoration, definer/ACL normalization, M1 0006 lock ordering and a catalog-driven dependent-device check), covers `m1:0005`/`m1:0006` in the manifest, and keeps every published migration byte-identical. Executed on an isolated PostgreSQL 16.9/PostGIS 3.5.2 instance: fresh V2 replay plus a 232-test suite (six real HTTP→Drogon→PostgreSQL probe tests included), historical M1 suites, retention matrix, security catalog, purge/concurrency gates, populated 0006→V2 and 0004→V2 upgrades with holds preserved, hold-aware purge and a backup/restore/quarantine drill. Full commands, exit codes and limits: [PR11 reconciliation acceptance](../../../evidence/local/database/PR11_RECONCILIATION_ACCEPTANCE_2026-10-30.md).

**Blockers retained:** V2 production session issuance for a verified Google OIDC identity is unimplemented (`mint_session` stays synthetic-gated), `ap_db_executor` RLS-bypass posture is assumed rather than separately certified, and the `0017`→`0020` range is only safe inside one transaction. Production `ma_backend` therefore remains on the historical M1 authorization path.

## Verified at the recorded checkpoint

- Both original historical M1 and clean V2 through 0019 replay successfully; populated upgrade and exact history adoption are verified without rewriting published SQL.
- Actual C++20/Drogon build and native CTest passed.
- Final unfiltered discovery passed 205 tests, including the reconciliation regressions, metadata tests, six actual HTTP integration tests and both real backup/restore tests.
- Historical `0001_m1_identity.sql` remained checksum-identical.

Commands, exit codes, actual catalog, implementation revision and admin decision: [final setup acceptance](../../../evidence/local/database/FINAL_LOCAL_SETUP_ACCEPTANCE_2026-10-29.md); the 0019 defect reproductions and full-catalog equivalence run are in [reconciliation acceptance](../../../evidence/local/database/RECONCILIATION_ACCEPTANCE_2026-10-29.md). Persistent development was backed up, additively migrated from 0015 to 0018 and verified successfully. Test remains separately RAM-backed with fsync enabled; no reboot/power-loss durability certification is claimed.

## Closed setup gates and remaining release boundaries

1. Migration collisions are resolved with explicit checksummed lineages and additive bridges. The original 18-table M1 checkpoint/checker remains distinct from the converged 139-table application catalog.
2. Persistent development backup/migration/verification now succeed within bounded commands; the earlier I/O timeout is historical rather than the current blocker.
3. The [logical model reconciliation](MODEL_RECONCILIATION_2026-10-29.md) preserves the 120-entity canonical baseline and all 124 proposed entities separately; full contract lint and regenerated mappings pass without loosening the baseline.
4. Retention/ownership metadata and typed constraints now cover all 143 base tables, including bookkeeping. Unknown classifications and unapproved retention periods remain explicit; real-child release stays OFF.
5. Verified source is `99f0914fb55eaf15b12436f8db9ed420880fb8b1` (0019 reconciliation), on top of the lineage/restore commits and `37704be` (full-catalog equivalence). Final unfiltered regression passes. Normal review/CI and product/provider/release acceptance remain separate.
6. The two 0016 metadata authorization/child-consistency regressions pass with additive 0018; four further defects in retention purge, multi-child account erasure, credential clock sampling and media child binding are reproduced and fixed additively in 0019. Historical inspection restores remain quarantined; full V2 restore verifies suppression before reopening runtime.
7. Fresh-V2 versus upgraded-M1 equivalence now compares complete policy, view, function-body, owner and role/column-ACL state, with rollback-only negative controls proving the comparison can fail.

## Admin API development assessment

Yes: synthetic, metadata-only admin API development can proceed on this verified database foundation. Hosting, live Play verification and real-child legal approval are not prerequisites for local coding. There are 48 draft admin operations and zero implemented admin adapters; database readiness is not a completed admin backend.

Admin implementation must retain identity/approval/RBAC, immutable decisions, role revocation, redaction and denied-access tests. Existing SQL is not a running admin HTTP API. Real Google OIDC exchange and production authentication remain separate acceptance work. Owner authority must never imply unrestricted access to child location or media.

## Document control

[Package index](README.md) · [Runbook](RUNBOOK.md). This status is a workstream checkpoint, not a change to the approval state of historical specifications. The canonical document library remains organized by phase/category; implementation-specific database material is grouped here and linked from its indexes.
