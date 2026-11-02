# Documentation Phase/Category Coverage and Approval Matrix

**Relocation snapshot:** 2026-10-27 · **Status reconciliation:** 2026-10-30 · **Nature:** File classification and scoped evidence crosswalk, not whole-product acceptance. **Canonical milestones:** M0–M9. Counts below preserve the original 72-document relocation set; later supporting records are separately registered. Phases with zero dedicated documents are gaps, not complete phases.

| Phase | Source documents | Categories | Phase purpose | Documentation decision still outstanding |
|---|---:|---:|---|---|
| [M0](phases/M0-foundation-and-approvals/README.md) | 25 | 3 | Project foundation, ownership, market feasibility, India privacy and legal decisions | Publishers, child-data legal basis, retention, signed ownership and cost decisions |
| [M1](phases/M1-secure-platform-foundation/README.md) | 16 | 3 | Secure Android/C++ foundation, M1 requirements, developer standards and permissions | Design baseline, signed M1 acceptance and no real-child deployment implied |
| [M2](phases/M2-location-collection/README.md) | 3 | 1 | Android location collection, encrypted offline queue and durable GPS ingestion | Android FGS/permission evidence, child location legality and Postgres crash tests |
| [M3](phases/M3-trips-and-places/README.md) | 1 | 1 | Trip, stop and named-place geometry from recorded locations | No fabricated roads; event-time backfill and appropriate guardian permission |
| [M4](phases/M4-usage-health-sos/README.md) | 2 | 1 | UsageStats, check-ins, health and SOS delivery semantics | Behavioural-monitoring legal assessment and truthful emergency-service limitations |
| [M5](phases/M5-managed-android-controls/README.md) | 0 | 0 | Eligible managed Android policies and Device Owner lifecycle | Dedicated M5 implementation/design specification is not yet a standalone document |
| [M6](phases/M6-guardian-erasure-security/README.md) | 1 | 1 | Per-child delegated access, account deletion, backups and recovery | Retention sign-off and no-resurrection after restore/old offline uploads |
| [M7](phases/M7-commercial-integrations/README.md) | 3 | 1 | Commercial integration, child-seat pricing and budgets | Merchant, tax, vendor, subscription and refund decisions before selling |
| [M8](phases/M8-operational-readiness/README.md) | 10 | 3 | Operational readiness, cloud, backup, incident response, support and QA | RPO/RTO and load evidence not yet executed, no deployment certification |
| [M9](phases/M9-play-release/README.md) | 7 | 3 | Google Play launch, reviewer declarations, Data Safety and public contracts | Signed legal pages, actual AAB/reviewer evidence and Play outcome pending |
| [P3](phases/P3-deferred-research/README.md) | 3 | 1 | Deferred media experiments, activity metadata and admin-panel research | Not included in initial launch; OS/India law/Play gates separate |
| [CROSS](phases/cross-milestone-references/README.md) | 1 | 1 | Cross-milestone diagrams and existing Figma architecture indexes | Editable design artifacts are not Android/C++ implementation |

**Total migrated source documents: 72.** Additionally, `docs/openapi-m1.yaml`, `docs/openapi.yaml`, `docs/ui/` and the root governance/public-legal documents are controlled but remain at established paths.

## Readiness interpretation

- M0: individual India publisher and India0–17/transparent-operation owner decisions are recorded; Payments identity, merchant setup, public contact and counsel/legal review remain pending. No company is claimed.
- M1: [PR9 review](phases/M1-secure-platform-foundation/02-development-process/M1_STACK_PR9_REVIEW_2026-10-30.md) verifies scoped C++/SQL/CI evidence, not real ParentOIDC, Android implementation or full product acceptance.
- M2–M4/M6–M9: specifications and operational plans are not proof of device test, deployment, signed Play submissions or real-child-data eligibility.
- **M5**: no standalone managed-device policy implementation/rollback document; owner should decide whether a dedicated M5 specification is required before baseline signoff.
- P3: defer media/admin features separately from staged launch; no real-child sensor collection authorization.

See [full per-document control register](MASTER_DOCUMENT_CONTROL_REGISTER.md), [unresolved blockers](phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md) and [formal control standard](DOCUMENT_CONTROL_POLICY.md).

## 2026-10-30 workstream crosswalk

| Phase | Current controlled evidence/preparation | Approval still required |
|---|---|---|
| M0 | Publisher facts reconciled; legal sources/commencement and purpose-by-purpose risks reviewed | Qualified Indian counsel; retention/authority/support/processor decisions; no legal approval claimed |
| M1 | PR9 fresh M1 PostgreSQL16 replay, restricted-role checks, hosted build/CTest and synthetic createFamily; supplemental fail-sensitive catalog SQL | Report findings and obtain owner approval before merge; implement real ParentOIDC separately |
| M1 / M2–M6 / P3 | Full existing feature inventory assessed in the [Android matrix](phases/M1-secure-platform-foundation/03-security-and-permissions/ANDROID_COMPATIBILITY_MATRIX.md) | Actual API/OEM/permission evidence, lawful purposes/Play classification, final per-feature release set; no Android coding now |
| M7 | Founding-family ₹50/₹500 rule preserved, prepaid/token/seats/expiry/refund lifecycle and negative cases prepared | Merchant/tax/Play sandbox acceptance, no real products or purchase actions |
| M8 | [T-PEND security acceptance queue](phases/M8-operational-readiness/03-quality-and-evidence/TEST_STRATEGY_UNIT_INTEGRATION_LOAD_SECURITY.md), threat/incident/recovery scopes distinguished | Rate limits, authentication, deletion/audit/device tests and independent recovery/security evidence |
| M9 | Separate Parent/Child reviewer and Data Safety preparation with owner/build dependencies | Signed builds, owner Console actions, notices/support, testing requirements and actual Play outcome |

Decision owner: project owner for explicitly supplied choices only. Other entries remain DOCUMENTED_REVIEW_PENDING, PROPOSED or evidence-scoped VERIFIED as detailed in the [progress report](phases/M0-foundation-and-approvals/01-project-governance/PENDING_IDENTITY_PROGRESS_2026-10-30.md); none is a release CLOSED state.
