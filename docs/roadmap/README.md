# Madalasa–Alarka Local Coding Roadmap

Planning baseline: 20 phases and 262 atomic acceptance tasks; implementation checkpoints are separately evidenced. Local development uses synthetic test data.

> **Implementation status reconciliation (2026-11-01):** The original 262 task acceptance statuses have **not** been reverified and remain NOT_STARTED in the evidence ledger. This does not mean no code exists: both Android Gradle application modules and the shared UI module are present; 60 parent and 21 child initial screen composables exist on the `parent`/`child` branches; their builds, runtime navigation and Figma visual fidelity are not yet verified. The ParentOIDC bridge PR #16 is merged. The new 168-hour inactivity sampling design is documented but not coded. See [Android UI and inactivity execution addendum](ANDROID_UI_AND_INACTIVITY_EXECUTION_ADDENDUM_2026-11-01.md) and [execution status ledger](LOCAL_TASK_EXECUTION_STATUS.json).\n\n- [Local development roadmap](LOCAL_AGENT_DEVELOPMENT_ROADMAP_2026-10-28.md)
- [Machine-readable task dependency graph](LOCAL_TASK_GRAPH_2026-10-28.json)
- [Task execution status ledger](LOCAL_TASK_EXECUTION_STATUS.json)
- [Agent testing and evidence protocol](AGENT_EXECUTION_AND_TEST_EVIDENCE.md)
- [Source references and conflict register](SOURCE_REFERENCE_AND_CONFLICT_REGISTER_2026-10-28.md)
- [Separate deployment and Play release plan](DEPLOYMENT_AND_PLAY_RELEASE_PLAN_SEPARATE_2026-10-28.md)
- [Agent entrypoint](../../AGENTS.md)

Dependency checks passed: 262 task IDs, dependencies present and acyclic, all statuses initialized NOT_STARTED. This is not evidence of code, physical-device validation, regulatory approval or production readiness.

## Figma 187-screen and API/database audit amendment

[Full screen-by-screen audit](../audits/FINAL_FIGMA_SCREEN_BY_SCREEN_API_DB_REPORT_2026-10-28.md) · [machine-readable exact screen mapping](../audits/FIGMA_SCREEN_API_DB_AUDIT_2026-10-28.json) · [96 new draft API operations](../audits/FIGMA_API_GAP_OPERATIONS_2026-10-28.json) · [28 additional local remediation tasks](FIGMA_SCREEN_API_DB_REMEDIATION_TASKS_2026-10-28.json) · [11-domain 120-table Figma database](../data-model/MADALASA_ALARKA_FIGMA_LOGICAL_ERD_V1_2026.json) · [proposed physical schema / external-parent RLS correction](../data-model/FIGMA_SCREEN_GAP_PHYSICAL_SCHEMA_REVIEW_2026-10-28.md). Original 262 tasks + 28 new audit tasks = **290 planned tasks**, all requiring actual implementation/testing; none of the new audit tasks is marked PASS.

## Final screen/API/database documentation audit

- [187-state screen-by-screen Figma/OpenAPI/DB crosswalk](FINAL_FIGMA_SCREEN_BY_SCREEN_API_DB_AUDIT_2026-10-28.md)
- [Figma frame existence and text verification (106 direct nodes)](FIGMA_LIVE_FRAME_VERIFICATION_2026-10-28.json)
- [Existing path vs screen inventory](SCREEN_API_DB_AUDIT_INVENTORY_2026-10-28.json)
- [26 proposed exact API method/path gaps and needed DB structures](SCREEN_MISSING_API_AND_DB_GAPS_2026-10-28.md)

This is a design/traceability audit. No new backend implementation, real-device Android test, PostgreSQL migration or legal/Play approval is claimed.


## Post-development-plan Figma/API audit supplement

[Final 187-screen post-remediation report](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/audits/POST_REMEDIATION_SCREEN_API_DB_REPORT_2026-10-28.md) · [187-screen machine coverage](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/audits/POST_REMEDIATION_SCREEN_API_DB_COVERAGE_2026-10-28.json) · [54-task gap implementation addendum](FIGMA_SCREEN_API_DB_REMEDIATION_TASKS_2026-10-28.json). The combined *planned* backlog is 262 base + 54 gap tasks = **316**, all remain unverified. Current OpenAPI master: 171 proposed methods, 155 paths, 130 schemas. `GAP-054` is the final local traceability reconciliation, NOT a Play release signoff.

## Owner clarification — 28 October 2026

[Blended-family V2 authorization and Google Family Link dependency removal](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/ADR_2026_10_28_BLEND_FAMILY_V2_AND_NO_FAMILY_LINK_DEPENDENCY.md) · [Implementation proof and secure Google Play sandbox setup](IMPLEMENTATION_PROOF_AND_PLAY_SANDBOX_HANDOFF_2026-10-28.md) · [India child-data privacy action brief](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/INDIA_CHILD_CONSENT_RETENTION_DELETION_ACTION_BRIEF_2026-10-28.md). Hosting region and final cloud costs are deferred to separate deployment planning, not local coding blockers.
