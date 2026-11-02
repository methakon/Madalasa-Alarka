# Repository Gap Assessment and Delivery Gate — Madalasa–Alarka

> **Document control:** M0 / 01-project-governance · Proposed owner: Project owner (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

**Audit date:** 2026-10-27 · **Source:** live GitHub directory listing, committed file reads, connected repository permissions, previous project decisions.  
**Scope:** User checklist across root governance, engineering, Android, operations and India/Google Play compliance.  
**Important:** `PRESENT` means the file is committed; it does **not** mean the policy is signed, test run, code built, or Play approval received.

## Summary

- The initial gap checklist describes an **earlier repository state**. The current repository has root LICENSE, SECURITY, CONTRIBUTING, CODE_OF_CONDUCT, .env.example, .gitignore, CHANGELOG, CODEOWNERS, issue/PR templates and a README developer quick-start. These files exist, but several are placeholders/drafts, not audited operating controls.
- Engineering/operations/legal documents named in the request exist under `docs/`, including DPIA, incident/breach, STRIDE, runbooks, SBOM register, consent, DPA, signing, test strategy and staged public legal pages.
- Kotlin files exist under `android/alarka/src/main/kotlin/.../domain` and `android/madalasa/src/main/kotlin/.../domain`. **No Gradle wrapper, AndroidManifest, applicationId or runnable APK** has been verified. C++ Drogon executable is also missing. The source folders are domain-model scaffolds, **not a running app**.
- GitHub connector confirms **push permission but no repository admin/maintain permission** for this session. GitHub **About description/topics and branch protection require a repository administrator**; committing a README cannot edit those settings.
- Substantive India child-data/legal/Play/operational gates remain **NO-GO**. No actual reviewer video, signed processor DPA, tested backup or appointed grievance officer is represented as complete.

## 1. Checklist-by-checklist audit

| Checklist request | Verified repository artifact | File state | Remaining actual gap |
|---|---|---|---|
| LICENSE | [root LICENSE](../../../../LICENSE), [IP decision](../03-legal-and-privacy/LICENSING_DECISION_AND_IP_REGISTER.md) | PRESENT, **interim all-rights-reserved** | Legal publisher, rights chain and selected operative licence unsigned; publicly visible != open source |
| .gitignore and .env.example | [root .gitignore](../../../../.gitignore), [example](../../../../.env.example) | PRESENT | Runtime app/env config not consumed; no real secrets in repo |
| CONTRIBUTING, CODE_OF_CONDUCT | [contributing](../../../../CONTRIBUTING.md), [conduct](../../../../CODE_OF_CONDUCT.md) | PRESENT | Verify actual enforcement/contact owners |
| SECURITY.md | [root reporting](../../../../SECURITY.md), [incident procedure](../../M8-operational-readiness/02-operations-and-support/INCIDENT_AND_BREACH_RESPONSE_PROCEDURE.md) | PRESENT, DRAFT | Turn on private vulnerability reporting and verified reachable security email/backup |
| CHANGELOG, CODEOWNERS | [changelog](../../../../CHANGELOG.md), [CODEOWNERS](../../../../.github/CODEOWNERS) | PRESENT | Branch protection/reviewer enforcement needs owner/admin |
| Issue and PR templates | [issue forms](../../../../.github/ISSUE_TEMPLATE), [PR template](../../../../.github/PULL_REQUEST_TEMPLATE.md) | PRESENT | Add a privacy/release-gate form for explicit owner decisions; no confidential vulnerability details in public issues |
| About description/topics | [values & instructions](REPOSITORY_ABOUT_AND_TOPICS.md) | **NOT APPLIED/NOT VERIFIED** | Repo admin must edit About UI; connected GitHub write token lacks repo admin |
| README build/run | [root README](../../../../README.md), [Build & Run](../../M1-secure-platform-foundation/02-development-process/BUILD_AND_RUN.md) | PRESENT, verified M1-only quick-start | No Android/C++ runnable build; do not claim future Gradle/CMake commands work |
| Developer standards | [Onboarding/Coding Standards](../../M1-secure-platform-foundation/02-development-process/DEVELOPER_ONBOARDING_AND_CODING_STANDARDS.md) | PRESENT, proposed | Kotlin/Gradle/C++ formatter/CI implementation pending |
| Branching/versioning | [Release Process](../../M1-secure-platform-foundation/02-development-process/BRANCHING_VERSIONING_AND_RELEASE_PROCESS.md) | PRESENT, proposed | Enforce rulesets, protected main, required status checks via admin |
| Dependency/SBOM | [Third-Party Register](../../M1-secure-platform-foundation/02-development-process/THIRD_PARTY_DEPENDENCY_AND_SBOM_REGISTER.md) | PRESENT, planning inventory | Real lockfile/dependency graph, SPDX/CycloneDX SBOM and licence scan not generated |
| STRIDE threat model | [Formal STRIDE](../../M1-secure-platform-foundation/03-security-and-permissions/THREAT_MODEL_STRIDE.md) | PRESENT, preliminary | Security assessor, controls implementation and independent threat review needed |
| Formal test strategy | [Test Strategy](../../M8-operational-readiness/03-quality-and-evidence/TEST_STRATEGY_UNIT_INTEGRATION_LOAD_SECURITY.md) | PRESENT | M1 structural lint + tenant SQL exist; broad Kotlin/C++/load/pen test suites NOT implemented |
| Signing/key policy | [Signing policy](../../M1-secure-platform-foundation/03-security-and-permissions/APP_SIGNING_AND_KEY_MANAGEMENT_POLICY.md) | PRESENT, draft | Keystore/KMS/Play signing enrollment and rotation drill unverified |
| Android app source | [android README](../../../../android/README.md), `android/alarka/`, `android/madalasa/` | **SOURCE SCAFFOLDS ONLY** | Gradle wrapper + manifest + SDK/AGP/Kotlin version + package IDs + runnable modules absent |
| Deploy/rollback/restore runbooks | [Operations Runbooks](../../M8-operational-readiness/02-operations-and-support/OPERATIONS_RUNBOOKS.md) | PRESENT, design | No OCI deployment or rollback/restore rehearsal evidence |
| Monitoring & SLA | [Monitoring/SLO](../../M8-operational-readiness/02-operations-and-support/MONITORING_ALERTING_SLO_SLA.md) | PRESENT, candidate | No live telemetry, alarms/on-call or contractual SLA |
| Incident/breach | [MA-IR-001](../../M8-operational-readiness/02-operations-and-support/INCIDENT_AND_BREACH_RESPONSE_PROCEDURE.md) | PRESENT, draft | Incident commander, CERT-In intake, India logs, 24×7 contacts/tabletop unverified |
| Restore evidence | [Restore Evidence Template](../../M8-operational-readiness/02-operations-and-support/BACKUP_RESTORE_TEST_EVIDENCE.md) | PRESENT **TEMPLATE ONLY** | No completed test or measured RPO/RTO |
| Support SOP | [Support/Escalation SOP](../../M8-operational-readiness/02-operations-and-support/SUPPORT_AND_ESCALATION_SOP.md) | PRESENT, draft | Staffing, grievance contact, secure case system and actual escalation tests pending |
| DPIA | [MA-DPIA-001](../03-legal-and-privacy/DPIA.md) | PRESENT, UNSIGNED | India counsel, controller, safeguards, real-child DPIA approval all OPEN |
| Retention | [MA-RET-001](../03-legal-and-privacy/DATA_RETENTION_SCHEDULE.md) | PRESENT, UNSIGNED | Raw GPS **14 vs 30 days** disagreement, inbox/WAL/backup TTL, deletion tests unresolved |
| Grievance process | [Grievance Officer](../03-legal-and-privacy/GRIEVANCE_OFFICER_AND_REDRESSAL_PROCESS.md) | PRESENT, DESIGN | No officer/contact appointed or published |
| Parental consent | [Authority & verification](../03-legal-and-privacy/VERIFIABLE_PARENTAL_CONSENT_AND_GUARDIAN_AUTHORITY.md) | PRESENT, DESIGN | No verifiable consent/authority provider, age-out/dispute flow or test evidence |
| Vendor DPAs | [Processor Register](../03-legal-and-privacy/VENDOR_DPA_AND_PROCESSOR_REGISTER.md) | PRESENT, DRAFT | OCI/Google/FCM/other actual agreements and processor/cross-border decision unsigned |
| Terms/refund/public pages | [Staged public/legal](../../../../public/legal/README.md) and three .html files | PRESENT, **DRAFT/NOINDEX, NOT HOSTED** | Lawyer-approved terms/privacy/refund/cancellation and public HTTPS URLs not delivered |
| Play declarations/demo/Families | [Reviewer Pack](../../M9-play-release/01-play-and-data-safety/PLAY_CONSOLE_DECLARATIONS_AND_REVIEWER_PACK.md) | PRESENT, **CHECKLIST ONLY** | Actual Play Console declarations/video, policy decision, signed APK/AAB, target audience validation absent |

## 2. Distinguish five completion levels

`DOCUMENTED` → `IMPLEMENTED` → `AUTOMATED TESTED` → `INDEPENDENTLY REVIEWED` → `OWNER/LEGAL/PLAY APPROVED`.

Documents and Figma designs are **DOCUMENTED** only. The repository cannot be called production-ready because basic Android runtime, backend runtime, signed builds, backup proofs and child-privacy/Play clearance are missing.

## 3. Priority-ordered work packages

| Work package | Owner action and exit evidence | Priority |
|---|---|---|
| M0-LEGAL-01 | Verify publisher/controller, India DPDP child-specific location/usage/media and Play monitoring/Families; produce signed feature-by-feature GO/NO-GO | **BLOCKING** |
| M0-GOV-02 | Choose copyright/licence and contributed-rights chain; appoint grievance/incident/security contacts; enable tested private security intake | **BLOCKING** |
| M0-PRIV-03 | Decide 14 vs 30-day raw GPS, backend inbox/WAL, local 48h capacity vs TTL, trip/usage/admin audit/backup periods; sign retention | **BLOCKING** |
| M1-ANDROID-04 | Select exact SDK/AGP/Kotlin/package IDs; build empty safe Alarka/Madalasa debug APK with visible identity, **no sensor permissions/telemetry**, then add tested pairing and OS permission flows | HIGH |
| M1-BACKEND-05 | Implement C++20 Drogon actual runtime, M1 scopes+SQL migrations/API with synthetic family isolation and CI, no child pilot | HIGH |
| M2-INGEST-06 | Postgres durable inbox Tx A 202 ACK; C++ bulk worker Tx B, dedup, 48h offline **capacity** and revocation/tombstones, synthetic crash/load tests | HIGH |
| OPS-07 | OCI tenancy/India region/DPAs, encrypted offsite backup, measured restore, on-call SLO monitoring, incident tabletop and CERT-In process | **BLOCKING before real use** |
| POLICY-08 | Signed/hosted Terms/Privacy/Refund pages, verified contact and customer deletion path; real Play reviewer video/declarations/approved feature behavior | **BLOCKING before distribution** |
| GITHUB-09 | **Repository administrator** sets About description/topics, enabled private vulnerability reporting and main branch protection/rulesets | OWNER ACTION |

## 4. Current repo metadata and owner-only settings

Connected GitHub repository reports `permissions: {push:true, pull:true, admin:false, maintain:false}`. The available connector supports file content writes but **not repository settings/description/topic updates**. The suggested About text/topics are recorded in [About Checklist](REPOSITORY_ABOUT_AND_TOPICS.md) for an owner to apply in GitHub. Do not claim to have changed those settings.

## 5. Exit audit / future revalidation

Before calling any row "fully complete," run M1 CI, physically compile target Android apps, compile Drogon/C++ tests, run Postgres/PostGIS migration and 48h reconnect/revoke/load tests with synthetic fixtures, record security+backup exercises, verify live independent security intake and public legal pages, obtain India counsel and Play policy decisions, and attach actual signed approvals in a secure evidence store—not public child records.

**No real child GPS, app-usage profiling, media recording or production testing was performed during this audit.**
