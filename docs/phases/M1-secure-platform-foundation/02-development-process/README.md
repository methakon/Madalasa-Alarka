# M1 / development process

**MANDATORY UPDATED BRANCH POLICY (2026-10-31):** [Read current owner workflow](BRANCHING_VERSIONING_AND_RELEASE_PROCESS.md) before working. Code: four domain branches → dev → main. Documentation/planning: main only. Temporary branch only with owner instruction, then retire after verified merge. The earlier PR9 review paragraph below is archival, not today's integration state.

**Canonical category folder.** Full project documents are below; older `docs/<filename>` locations contain backward-compatible navigation pointers. **No signatures/implementation are implied.**

[M1 phase](../README.md) · [Docs home](../../../README.md) · [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md)

**2026-10-31 admin API:** [Partially implemented admin OIDC verifier, session self-status, applicant/owner read routes and outstanding issuer/MFA gates](ADMIN_WEB_UI_AND_API_INTEGRATION_STATUS_2026-10-31.md#admin-authenticationaccess-api-implementation--2026-10-31-synthetic). Positive end-to-end login is **not** yet available.

**2026-10-31 admin-web implementation:** [Figma BO-01–BO-09 responsive UI + typed API adapter and unfinished trusted backend integration](ADMIN_WEB_UI_AND_API_INTEGRATION_STATUS_2026-10-31.md). Synthetic-only on admin-web; not a production-ready administrator service.

**2026-10-31 Swagger integration:** [Local Swagger UI dev server for frozen M1 and design-only Figma API](SWAGGER_OPENAPI_DEV_WORKFLOW_2026-10-31.md); source on `api`, loopback-only, Try it out disabled by default and planned operations never executable. [Latest api Swagger CI](https://github.com/methakon/Madalasa-Alarka/actions/runs/41168787562) **PASSED**; production/UI browser rendering remains independently unverified.

**2026-10-31 API progress:** [Frozen M1 14-operation implementation and V2 security limitations](M1_API_HANDLER_IMPLEMENTATION_STATUS_2026-10-31.md). All 14 routes are registered on `api`, not integrated into `dev`/production. Current code undergoes CI; V2 session-positive, granular RLS/scope and replay integration are OPEN. No real child data is permitted.

**2026-10-30 supporting review:** [M1 stack PR9 review, findings and PostgreSQL16/CI evidence](M1_STACK_PR9_REVIEW_2026-10-30.md). Tests are scoped VERIFIED; findings and real ParentOIDC remain OPEN, and PR9 merge needs owner approval. [Branch register](BRANCHING_VERSIONING_AND_RELEASE_PROCESS.md) records the actual #3–#9 ancestry and existing V2 lineage boundary.

| Document | Registry state | Proposed owner role |
|---|---|---|
| [SWAGGER_OPENAPI_DEV_WORKFLOW_2026-10-31.md](SWAGGER_OPENAPI_DEV_WORKFLOW_2026-10-31.md) | SOURCE_COMMITTED / SYNTHETIC CI VERIFIED / NOT DEPLOYED | Backend/API |
| [M1_API_HANDLER_IMPLEMENTATION_STATUS_2026-10-31.md](M1_API_HANDLER_IMPLEMENTATION_STATUS_2026-10-31.md) | IMPLEMENTATION_IN_PROGRESS / V2_INTEGRATION_NOT_VERIFIED | Backend/security |
| [BUILD_AND_RUN.md](BUILD_AND_RUN.md) | DOCUMENTED_REVIEW_PENDING | Engineering lead (unassigned) |
| [DEVELOPER_ONBOARDING_AND_CODING_STANDARDS.md](DEVELOPER_ONBOARDING_AND_CODING_STANDARDS.md) | DOCUMENTED_REVIEW_PENDING | Engineering lead (unassigned) |
| [BRANCHING_VERSIONING_AND_RELEASE_PROCESS.md](BRANCHING_VERSIONING_AND_RELEASE_PROCESS.md) | DOCUMENTED_REVIEW_PENDING | Engineering lead (unassigned) |
| [THIRD_PARTY_DEPENDENCY_AND_SBOM_REGISTER.md](THIRD_PARTY_DEPENDENCY_AND_SBOM_REGISTER.md) | DOCUMENTED_REVIEW_PENDING | Engineering lead (unassigned) |
| [ANDROID_M1_SOURCE_BOOTSTRAP_AND_BUILD_GATE_2026-10-27.md](ANDROID_M1_SOURCE_BOOTSTRAP_AND_BUILD_GATE_2026-10-27.md) | DOCUMENTED_REVIEW_PENDING | Engineering lead (unassigned) |

**Review gate:** Design baseline, signed M1 acceptance and no real-child deployment implied. This grouping is a filing taxonomy, not a change to the approved/signed status of source material.

## Local database implementation

[Package index and reading order](../../../data-model/local-postgresql/README.md) · [Runbook](../../../data-model/local-postgresql/RUNBOOK.md) · [Current verification and integration status](../../../data-model/local-postgresql/STATUS.md). Status is LOCAL_BLOCKED, not implementation acceptance or production approval.
