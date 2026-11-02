# Historical 2026-10-30 progress while Google Payments identity verification was pending

> **2026-10-31 supersession notice:** This document is a historical snapshot. The owner subsequently confirmed **Google Play developer identity verification COMPLETED** and **BillDesk/payment verification SUBMITTED, with no provider response yet**. The current X-01 split (identity CLOSED; BillDesk pending; separate merchant setup unverified) is in [the blocker register](BLOCKERS_AND_OWNER_DECISIONS.md). Do not reuse this document's earlier "identity pending" wording as today's status. No private screenshot/identity/bank evidence is stored in Git.

**Date:** 2026-10-30. **Status:** DOCUMENTED_REVIEW_PENDING; scoped local/CI evidence VERIFIED as stated, product/release NOT_READY. **Decision owner:** project owner for supplied publisher/product choices; qualified India legal/security/Play sign-off remains pending. **Source:** owner instruction, fetched Git/PR state, pinned PR9 and official sources cited by canonical topic documents. [Docs home](../../../README.md) · [Master control register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md) · [Coverage matrix](../../../PHASE_DOCUMENTATION_COVERAGE_MATRIX.md).

## 1. Completed tasks, in requested workstream order

1. Inspected fetched main/all branch refs, all three open PRs (#1/#2/#9), current checks and latest100 Actions runs; read canonical docs home/control/coverage/blocker and the existing six-gate handoff at its PR1 source. Reused existing documentation PR2 branch; preserved existing local index/signing work. No new branch, canonical deletion/rename or PR merge.
2. Reviewed PR9 at `c693899e4b411cbadd1639f0bcb642844af50ea9` against main `0a6be11ca811e842cc9839ab623ec118514020dd`, verified #3–#8 content ancestry and fresh M1 migrations0001–0005, and reported defects and scope limits in the [detailed review](../../M1-secure-platform-foundation/02-development-process/M1_STACK_PR9_REVIEW_2026-10-30.md). Real ParentOIDC is absent; default rejection is not production authentication.
3. Reconciled nine canonical M0 legal documents and owner facts: **SWARNA SEKHAR DHAR, Individual, India**, same legal/Play publisher. **Payments identity PENDING, merchant setup PENDING, legal review PENDING, public support PENDING CONFIRMATION.** No company, GST registration, legal address or support email invented; no sensitive identity evidence collected.
4. Reviewed India DPDP Act, official commencement/rules/corrigendum, CERT-In directions/FAQ and current consolidated IT Rules. Separated notified law/phases from guidance, interpretation and counsel decisions. The Gazette publication-date question and full-text SPDI retrieval limitation remain explicit. No legal approval or real-child processing authority is claimed.
5. Advanced M9 reviewer and Data Safety preparation: separate **20-item Madalasa and 20-item Alarka checklists**, **18 Data Safety categories**, prepare-now/build/device/owner dependencies and individually named draft publisher. No declarations submitted and no reviewer credentials created.
6. Assessed complete recorded candidate inventory: **91 unique Android feasibility rows**, all **51 SRS FR IDs** plus **40 supplemental/split/candidate rows**, covering purpose, APIs/minima, grant/Settings, background/FGS/DeviceOwner, policy/privacy disposition and required evidence. Remote media OFF, financial screens prohibited, no stealth/OS bypass; backend version/capability gate must precede ACCEPT. Assessment is not Android implementation or release eligibility approval.
7. Preserved first **1,008 distinct successfully paying families**, counting each once, founding **₹50/month or ₹500/year** for eligible paid children including later additions; existing regular **₹99/₹999** and prepaid/no-auto-renew unchanged. Prepared **13 billing lifecycle/negative sandbox cases, all NOT RUN**. Public guidance does not prove founding prepaid catalog, repeated child seats or viewer-product feasibility.
8. Updated threat, incident, backup/recovery limits and **T-PEND-01–12** security evidence queue. Added executed fail-sensitive SQL catalog checks and eight automated documentation-inventory tests; wired inventory tests into the existing documentation workflow. Updated master controls and relevant indexes.

## 2. Code/test changes and real results

No application/business handlers or Android code changed. Test/control changes:

[Machine-readable review results](../../../../evidence/local/reviews/PR9_REVIEW_2026-10-30.json) preserve the pinned source, actual exit codes (including initial tooling errors) and local-versus-hosted scope without private logs or credentials.

- [M1 security catalog SQL](../../../../backend/tests/m1_security_catalog_acceptance.sql): executed successfully on disposable PostgreSQL16.15; 18 forced-RLS tables, API/definer/PUBLIC invariants, three rollback-only negative controls. Wrong-database refusal executed with exit3 before catalog mutation.
- [Documentation coverage tests](../../../../backend/tests/test_pending_identity_documentation.py): **8 tests PASS** locally. They reject missing/duplicated/unexpected rows and prose-only substitutes; verify 51+40 inventory rows, nine required fields, separate20+20 checklists,18 Data Safety IDs and13 billing cases. They do not prove documented features/legal conclusions/provider behavior.
- [Documentation workflow](../../../../.github/workflows/documentation-structure.yml): runs these tests and triggers on verifier changes. Its hosted result for the publication commit must be read separately; PR9's older green run does not validate this new workflow revision.
- Existing PR9 local reproduction: **61 Python tests PASS**, three structural lints PASS, five explicit migrations PASS, five SQL regression suites PASS, idempotency concurrency PASS and restricted purge-job test PASS.
- Existing exact-head hosted [run41014540240](https://github.com/methakon/Madalasa-Alarka/actions/runs/41014540240): backend build/CTest1/1, smoke, synthetic HTTP family flow and SQL/purge jobs SUCCESS. [Run41014540218](https://github.com/methakon/Madalasa-Alarka/actions/runs/41014540218): documentation SUCCESS. No local C++ rebuild during elevated host I/O pressure; hosted evidence is not relabelled local.
- Local known-forbidden-marker reproduction proved PR9's `strings | grep -q`/pipefail gate can miss a marker; full-consumption alternative detected it. This is a CI-test defect, not demonstrated deployable authentication bypass.
- Disposable PG container had network NONE/no ports,1CPU/512MiB/384MiB tmpfs, no durability-disable flags; stopped and removed after testing. No existing V2 DB was started/reset. No new real credentials were generated; upstream fixed synthetic fixture credentials remained confined to the disposable tests.

## 3. PR review findings and CI status

PR9 remains OPEN and unmerged. Findings: HIGH process-group-zero cleanup; MEDIUM absent-client assertion path, fail-open marker gate and unbounded DB acquisition/execution; inherited MEDIUM parallel renewal/live-credential and five-open-challenge races; incomplete artifact purge coverage. ParentOIDC, V2 external co-parent grants, rate limiting, full endpoints, restore/device/production evidence remain gaps. See exact files/lines, observed positives and reproduction limits in the detailed review.

Current PR9 checks are successful but do not negate those findings. Three failures in the latest100 historical runs belong to older DB/catalog commits; inspected logs distinguish those from current PR9. PR2 is the reviewable destination for this substantial documentation/test checkpoint; no duplicate PR or automatic merge.

## 4. Updated blocker register and owner decisions required

The [canonical blocker register](BLOCKERS_AND_OWNER_DECISIONS.md) is current. Do not re-ask publisher type, India0–17, transparent operation, full-inventory assessment permission or founding prices; these choices are recorded. Decisions/evidence still needed:

- Review PR9 findings and decide whether fixes are required before giving merge approval; no approval inferred from green CI.
- Appoint qualified Indian counsel for feature-specific purposes/section9 exceptions, authority/consent/custody, commencement, current SPDI/intermediary applicability, Rule6/8 retention/erasure and transfer duties.
- Approve category retention/deletion/backup/legal-hold schedules; define invite/revoke/history scopes and custody dispute process.
- Confirm public support/privacy/grievance contact and actual public notice/deletion URLs without placing private IDs/address/bank/verification screenshots in GitHub.
- Decide genuine managed DeviceOwner edition provisioning/reset/exit authority, optional child SOS/check-in interaction, actual test-device matrix and final surviving release feature set.
- Resolve founding refund/fraud disqualification, slot recycling and checkout reservation/order; approve tax/refund text with counsel/accountant, not by changing prices.
- Arrange independent off-device upload-key backup/recovery custody and confirm app-signing versus upload role. Prior local signing work is documented separately; current task created no signing credentials.

## 5. What really waits on Google versus what does not

Direct external/account dependencies: owner-held Payments identity outcome, merchant/payment setup, package/account eligibility and any Console-specific gating before authorized billing/release work. An identity result alone does not verify merchant capability, tax treatment, provider catalog or policy acceptance. Account-specific requirements have not been inspected.

**Not blocked by identity verification:** code review and fixes, synthetic ParentOIDC/JWKS unit tests, child-scope/RLS and retention/deletion/restore tests, legal analysis, reviewer scripts/worksheet preparation, billing state-machine/contract tests, threat/incident and documentation reconciliation. Android implementation remains excluded by this instruction, not because Google is pending. Signed builds, device tests, Console declarations and purchases need their own later authorized work; no blanket claim that every sandbox action is technically forbidden by pending identity.

## 6. Superseded/conflicting material identified

- Older statements that no C++ backend or expanded CI exists are superseded by narrow PR9 source/CI evidence, not by complete backend acceptance.
- Branch register's old #3→#4→#6 merge advice and numeric-renumber recommendation are corrected. Main includes #3; PR9 carries #4–#8 content. The separate V2 branch already has an immutable namespaced manifest; new original M1 0005 needs careful additive integration, not alphabetical replay.
- Historical B03 “not approved/next answer” wording is marked superseded; financial-screen B05 approval is separate from unresolved DeviceOwner provisioning.
- Historical universal ₹50/₹500, auto-renew and example hosting/profit assumptions are explicitly quarantined by current founding/regular prepaid policy. A top-up buys time, not another child seat; prepaid offers/legacy cohorts must not be assumed to guarantee founding pricing.
- Family Link relationship lookup and fixed Chicago deployment dependencies are superseded; Google login is not guardian proof, hosting is a separate deployment decision.
- DPDP assent/PIB “operationalisation” are not full commencement, broad one-year retention is not merely security logs, current IT Rules deadlines depend on actual intermediary classification. Older dated legal summaries yield to the2026-10-30 review.
- Some untouched historical documents/public HTML drafts retain obsolete context. They remain non-operative; this scoped reconciliation is not a claim that every historical paragraph or unpublished HTML draft was rewritten. Canonical legal drafts and current indexes take precedence; public publication still requires a separate approved reconciliation.

## 7. Prioritized next work

1. Fix PR9 cleanup and fail-open CI gate, add actual negative controls; guard absent DB and finite acquisition/statement deadlines. Retest failure paths without signaling the caller.
2. Add per-device renewal/challenge serialization and wall-clock/lock regressions additively; clarify credential/pairing/enrollment purge coverage.
3. Implement/test real ParentOIDC behind the existing narrow interface with synthetic JWKS/issuer/audience/expiry/key-rotation/outage cases; keep legal guardian authority independent.
4. Reconcile PR9 historical M10005 and canonical backend/contracts into the existing V2 lineage without rewriting published histories or duplicated stack commits, only after owner integration decision.
5. Obtain feature-purpose/retention/authority legal decisions and resolve Families/location eligibility; keep media/financial screens and all unapproved processing OFF. Prepare policy/runtime negative tests without Android application development.
6. Prove prepaid founding catalog, repeated-child capacity, token/RTDN/ack/refund lifecycle in a separately authorized owner-held sandbox; keep all13 cases NOT_RUN until actual evidence.
7. After separate authorization, implement/build Android, execute physical API/OEM/revocation/boot/visibility tests and generate real reviewer videos. Offsite recovery, security review and actual Console decisions precede release.

## 8. Changed documentation inventory

The list below covers this checkpoint's canonical/control/index edits and the preserved prior signing setup record. Links identify files, not approvals. Test/workflow/Git exclusions are listed separately above; no private keystore, password or recovery secret is included.

- [android/README.md](../../../../android/README.md).
- [docs/MASTER_DOCUMENT_CONTROL_REGISTER.md](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).
- [docs/PHASE_DOCUMENTATION_COVERAGE_MATRIX.md](../../../PHASE_DOCUMENTATION_COVERAGE_MATRIX.md).
- [docs/README.md](../../../README.md).
- [docs/phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md](BLOCKERS_AND_OWNER_DECISIONS.md).
- [docs/phases/M0-foundation-and-approvals/01-project-governance/PENDING_IDENTITY_PROGRESS_2026-10-30.md](PENDING_IDENTITY_PROGRESS_2026-10-30.md).
- [docs/phases/M0-foundation-and-approvals/01-project-governance/PROJECT_DOCUMENTS_INDEX_2026.md](PROJECT_DOCUMENTS_INDEX_2026.md).
- [docs/phases/M0-foundation-and-approvals/01-project-governance/README.md](README.md).
- [docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/DATA_RETENTION_SCHEDULE.md](../03-legal-and-privacy/DATA_RETENTION_SCHEDULE.md).
- [docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/DPIA.md](../03-legal-and-privacy/DPIA.md).
- [docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/GRIEVANCE_OFFICER_AND_REDRESSAL_PROCESS.md](../03-legal-and-privacy/GRIEVANCE_OFFICER_AND_REDRESSAL_PROCESS.md).
- [docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/INDIA_CHILD_CONSENT_RETENTION_DELETION_ACTION_BRIEF_2026-10-28.md](../03-legal-and-privacy/INDIA_CHILD_CONSENT_RETENTION_DELETION_ACTION_BRIEF_2026-10-28.md).
- [docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md](../03-legal-and-privacy/INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md).
- [docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/INDIA_GOVERNMENT_LEGAL_GOOGLE_PLAY_PROJECT_RISK_ASSESSMENT_2026.md](../03-legal-and-privacy/INDIA_GOVERNMENT_LEGAL_GOOGLE_PLAY_PROJECT_RISK_ASSESSMENT_2026.md).
- [docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/INDIA_REGION_AND_M0_OWNER_DECISION_GATE.md](../03-legal-and-privacy/INDIA_REGION_AND_M0_OWNER_DECISION_GATE.md).
- [docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/README.md](../03-legal-and-privacy/README.md).
- [docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/VENDOR_DPA_AND_PROCESSOR_REGISTER.md](../03-legal-and-privacy/VENDOR_DPA_AND_PROCESSOR_REGISTER.md).
- [docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/VERIFIABLE_PARENTAL_CONSENT_AND_GUARDIAN_AUTHORITY.md](../03-legal-and-privacy/VERIFIABLE_PARENTAL_CONSENT_AND_GUARDIAN_AUTHORITY.md).
- [docs/phases/M1-secure-platform-foundation/02-development-process/BRANCHING_VERSIONING_AND_RELEASE_PROCESS.md](../../M1-secure-platform-foundation/02-development-process/BRANCHING_VERSIONING_AND_RELEASE_PROCESS.md).
- [docs/phases/M1-secure-platform-foundation/02-development-process/M1_STACK_PR9_REVIEW_2026-10-30.md](../../M1-secure-platform-foundation/02-development-process/M1_STACK_PR9_REVIEW_2026-10-30.md).
- [docs/phases/M1-secure-platform-foundation/02-development-process/README.md](../../M1-secure-platform-foundation/02-development-process/README.md).
- [docs/phases/M1-secure-platform-foundation/03-security-and-permissions/ANDROID_COMPATIBILITY_MATRIX.md](../../M1-secure-platform-foundation/03-security-and-permissions/ANDROID_COMPATIBILITY_MATRIX.md).
- [docs/phases/M1-secure-platform-foundation/03-security-and-permissions/MADALASA_UPLOAD_KEY_SETUP_2026-10-30.md](../../M1-secure-platform-foundation/03-security-and-permissions/MADALASA_UPLOAD_KEY_SETUP_2026-10-30.md).
- [docs/phases/M1-secure-platform-foundation/03-security-and-permissions/README.md](../../M1-secure-platform-foundation/03-security-and-permissions/README.md).
- [docs/phases/M1-secure-platform-foundation/03-security-and-permissions/THREAT_MODEL_STRIDE.md](../../M1-secure-platform-foundation/03-security-and-permissions/THREAT_MODEL_STRIDE.md).
- [docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/PRICE_BREAK_EVEN_STAFFING_AND_DELIVERY_CAPACITY.md](../../M7-commercial-integrations/01-commercial-plans-and-costing/PRICE_BREAK_EVEN_STAFFING_AND_DELIVERY_CAPACITY.md).
- [docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/README.md](../../M7-commercial-integrations/01-commercial-plans-and-costing/README.md).
- [docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/SUBSCRIPTION_PLANS_PRICING_AND_RULES_2026.md](../../M7-commercial-integrations/01-commercial-plans-and-costing/SUBSCRIPTION_PLANS_PRICING_AND_RULES_2026.md).
- [docs/phases/M8-operational-readiness/02-operations-and-support/BACKUP_RESTORE_TEST_EVIDENCE.md](../../M8-operational-readiness/02-operations-and-support/BACKUP_RESTORE_TEST_EVIDENCE.md).
- [docs/phases/M8-operational-readiness/02-operations-and-support/INCIDENT_AND_BREACH_RESPONSE_PROCEDURE.md](../../M8-operational-readiness/02-operations-and-support/INCIDENT_AND_BREACH_RESPONSE_PROCEDURE.md).
- [docs/phases/M8-operational-readiness/03-quality-and-evidence/README.md](../../M8-operational-readiness/03-quality-and-evidence/README.md).
- [docs/phases/M8-operational-readiness/03-quality-and-evidence/TEST_STRATEGY_UNIT_INTEGRATION_LOAD_SECURITY.md](../../M8-operational-readiness/03-quality-and-evidence/TEST_STRATEGY_UNIT_INTEGRATION_LOAD_SECURITY.md).
- [docs/phases/M9-play-release/01-play-and-data-safety/DATA_SAFETY_WORKSHEET.md](../../M9-play-release/01-play-and-data-safety/DATA_SAFETY_WORKSHEET.md).
- [docs/phases/M9-play-release/01-play-and-data-safety/GOOGLE_PLAY_PUBLISHING_REQUIREMENTS.md](../../M9-play-release/01-play-and-data-safety/GOOGLE_PLAY_PUBLISHING_REQUIREMENTS.md).
- [docs/phases/M9-play-release/01-play-and-data-safety/PLAY_CONSOLE_DECLARATIONS_AND_REVIEWER_PACK.md](../../M9-play-release/01-play-and-data-safety/PLAY_CONSOLE_DECLARATIONS_AND_REVIEWER_PACK.md).
- [docs/phases/M9-play-release/01-play-and-data-safety/README.md](../../M9-play-release/01-play-and-data-safety/README.md).
- [docs/phases/M9-play-release/02-public-legal-drafts/PRIVACY_POLICY_DRAFT.md](../../M9-play-release/02-public-legal-drafts/PRIVACY_POLICY_DRAFT.md).
- [docs/phases/M9-play-release/02-public-legal-drafts/README.md](../../M9-play-release/02-public-legal-drafts/README.md).
- [docs/phases/M9-play-release/02-public-legal-drafts/TERMS_AND_SUBSCRIPTIONS_DRAFT.md](../../M9-play-release/02-public-legal-drafts/TERMS_AND_SUBSCRIPTIONS_DRAFT.md).
- [docs/phases/M9-play-release/03-release-gates/DEPLOYMENT_RELEASE_READINESS_CHECKLIST.md](../../M9-play-release/03-release-gates/DEPLOYMENT_RELEASE_READINESS_CHECKLIST.md).
- [docs/roadmap/PLAY_BILLING_SANDBOX_ACCESS_CHECKLIST_NO_SECRETS_2026-10-29.md](../../../roadmap/PLAY_BILLING_SANDBOX_ACCESS_CHECKLIST_NO_SECRETS_2026-10-29.md).
