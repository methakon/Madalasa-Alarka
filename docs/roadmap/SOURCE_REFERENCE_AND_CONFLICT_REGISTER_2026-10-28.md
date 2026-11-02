# Source/reference and conflict register — Madalasa–Alarka Local Agent Roadmap

**Reviewed repository tree:** 2026-10-28. **Review level:** All documentation paths and their Git blob metadata inventoried; major canonical requirements/security/algorithm/pricing/admin/release documents and actual source/test files inspected to build task dependencies. This register is **not** a claim that all 204 files received separate line-by-line legal or code reviews. Every coding task must re-read its exact referenced document before work.

**Documentation inventory from GitHub:** 210 `docs/` files, 74 substantive phase Markdown source documents (excluding short README indexes), 10 Figma handoff JSONs, 2 OpenAPI YAML files, plus root README and code. Older root `docs/*.md` short files often route to canonical `docs/phases/` copies; follow canonical path, not truncated pointer.

**Authoritative agent task listing:** [262-task DAG](LOCAL_TASK_GRAPH_2026-10-28.json) · [Readable local roadmap](LOCAL_AGENT_DEVELOPMENT_ROADMAP_2026-10-28.md). **The DAG is dependency-validated and all 262 tasks start NOT_STARTED.**

## Explicit unresolved contradictions / human decisions

| ID | Conflict or uncertainty | Conservative local handling | Decision / evidence required |
|---|---|---|---|
| C-01 | Early Oracle Chicago host-cost plans vs later India-first Mumbai-preferred release plan | Local Compose/SQLite never production; storage region configurable | Owner, Indian child-data counsel and actual OCI tenancy agreement; separate deployment plan |
| C-02 | Retention draft raw GPS 14d vs 30d, derived ~90d, vs later owner desire to retain until account closes | Free *visibility* of six hours only; retention remains disabled configurable policy for real data | Signed controller/legal retention decision including backups/WAL/DSAR |
| C-03 | Parent Google Family Link second parent support vs no verified public third-party parent-child attestation API | Google Sign-In proves account identity only; child-specific sharing OFF in production until supported verifier | Google official supported evidence + legal relationship process; no bypass by invite |
| C-04 | Historical auto-recurring plans/₹149/old prices vs latest prepaid manual-only ₹99/₹999 and founding ₹50/₹500 | Implement server catalog, fake Play and no-auto-renew; Play official price wins | Owner verified Play catalog for each child seat + founding eligibility; account payout/tax review |
| C-05 | 30-day, shorter-of-base extra viewer vs owner-confirmed ₹100 for 100 calendar days | Add-on validity independent of base lapse; dormant until renewal within 100d; 30 total combined AV minutes | Actual Play one-time product setup and load/cost tests |
| C-06 | “One screen” could refer to whole family vs paid child | Working interpretation per **paid child** across all approved parents | Owner confirmation before public customer copy; backend tests per child |
| C-07 | Media capture/remote background audio, camera and screen ideas vs Android/Play monitoring restrictions | Explicit DISABLED and honest OS failures; only visible lab research | Android API/OEM, Play declarations and counsel feature-specific approval |
| C-08 | Managed device owner claims vs ordinary child phone Android permissions | Separate STANDARD and actual provisioned DPC; no hidden Device Owner | Real resettable expendable phone test; enterprise/Play eligibility |
| C-09 | Figma 112 conceptual tables vs real M1 single SQL migration | Review logical model; implement only required physical tables and migrations | DBA/security tests proving RLS, keys, indexing and retention |
| C-10 | Whole `docs/openapi.yaml` 47 path draft vs narrow 11-operation `docs/openapi-m1.yaml` | Implement M1 contract first, then domain extensions + codegen | Handler/DTO/schema/negative tests per endpoint; versioned API ADR |
| C-11 | Admin owner “all admin access” vs child's right to privacy and existing restricted media audit | ROOT_OWNER can manage staff/content/billing/support, cannot query child-private raw data | Least privilege and case-scope audit tests, DPDP data minimization |
| C-12 | Active Personal Play account ≠ verified production access or closed-test status | Owner-reported active only, no account identifier in public docs | Owner checks creation date, device/identity verification, each app's Play access/closed tests |
| C-13 | 48-hour once trial fraud resistance vs right to account deletion and minimization | Synthetic risk model, purpose/retention review, no invasive device fingerprint | Privacy/owner-approved method to prevent repeat trial after deletion |
| C-14 | Older six versus five-hour free history notes | Adopt **six-hour parent visibility** from later explicit conversation; record as product decision | Align API/UX tests, ensure retention separately approved |
| C-15 | Root short Markdown doc pointers vs canonical phase documents with conflicting old appendices | Always use canonical path and most recent explicit owner addenda | Record supersession by date/feature; never silently alter independent legal gates |

## Canonical document paths and source blob fingerprints

Each SHA below is the **Git blob ID at the inventory snapshot**, not a verified implementation/build result. Working agents should fetch the newest version and note deltas.


### M0-foundation-and-approvals (24)

| Canonical specification | Snapshot blob SHA | Size |
|---|---|---:|
| [AUDIT_REMEDIATION_STATUS.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/01-project-governance/AUDIT_REMEDIATION_STATUS.md) | `50ca49104367` | 18011 B |
| [BLOCKERS_AND_OWNER_DECISIONS.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md) | `0f84905887c2` | 29168 B |
| [DISCUSSION.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/01-project-governance/DISCUSSION.md) | `49a73f36f3cb` | 18500 B |
| [MASTER_MILESTONE_IMPLEMENTATION_AND_RELEASE_PLAN.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/01-project-governance/MASTER_MILESTONE_IMPLEMENTATION_AND_RELEASE_PLAN.md) | `7acc99a71b22` | 16251 B |
| [PROJECT_DOCUMENTS_INDEX_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/01-project-governance/PROJECT_DOCUMENTS_INDEX_2026.md) | `d8b032801f17` | 9445 B |
| [REPOSITORY_ABOUT_AND_TOPICS.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/01-project-governance/REPOSITORY_ABOUT_AND_TOPICS.md) | `fdd7b9179ff1` | 2667 B |
| [REPOSITORY_GAP_AND_DELIVERY_AUDIT_2026-10-27.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/01-project-governance/REPOSITORY_GAP_AND_DELIVERY_AUDIT_2026-10-27.md) | `69932e6ce228` | 11481 B |
| [REPOSITORY_RENAME_TO_MADALASA_ALARKA.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/01-project-governance/REPOSITORY_RENAME_TO_MADALASA_ALARKA.md) | `66190081e942` | 2106 B |
| [TECHNICAL_DOCUMENT_AUDIT_GAPS_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/01-project-governance/TECHNICAL_DOCUMENT_AUDIT_GAPS_2026.md) | `c28d169d5437` | 33675 B |
| [UPLOADED_GOVERNANCE_DOCUMENTS_REVIEW_2026-10-27.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/01-project-governance/UPLOADED_GOVERNANCE_DOCUMENTS_REVIEW_2026-10-27.md) | `547d8b5b6ac9` | 9128 B |
| [BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/02-market-and-feasibility/BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md) | `a593ea71e994` | 18284 B |
| [COMPETITOR_FEATURE_COMPARISON_AND_ADOPTION_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/02-market-and-feasibility/COMPETITOR_FEATURE_COMPARISON_AND_ADOPTION_2026.md) | `6779b5f45c12` | 30252 B |
| [FEASIBILITY_CONDITIONS_AND_EVIDENCE.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/02-market-and-feasibility/FEASIBILITY_CONDITIONS_AND_EVIDENCE.md) | `c0bed3398c6e` | 18093 B |
| [MARKET_FEEDBACK_GAPS_AND_DIFFERENTIATION_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/02-market-and-feasibility/MARKET_FEEDBACK_GAPS_AND_DIFFERENTIATION_2026.md) | `b3c7b7957c35` | 50318 B |
| [WHOLE_PROJECT_FEASIBILITY_GATE_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/02-market-and-feasibility/WHOLE_PROJECT_FEASIBILITY_GATE_2026.md) | `eb292bc3299f` | 14227 B |
| [DATA_RETENTION_SCHEDULE.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/DATA_RETENTION_SCHEDULE.md) | `48bb41c6c32e` | 17408 B |
| [DPIA.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/DPIA.md) | `63cfca0c629a` | 15146 B |
| [GRIEVANCE_OFFICER_AND_REDRESSAL_PROCESS.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/GRIEVANCE_OFFICER_AND_REDRESSAL_PROCESS.md) | `00652fdb8e00` | 3715 B |
| [INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md) | `b9d285ab4fe8` | 17418 B |
| [INDIA_GOVERNMENT_LEGAL_GOOGLE_PLAY_PROJECT_RISK_ASSESSMENT_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/INDIA_GOVERNMENT_LEGAL_GOOGLE_PLAY_PROJECT_RISK_ASSESSMENT_2026.md) | `887bcef8c1ed` | 28589 B |
| [INDIA_REGION_AND_M0_OWNER_DECISION_GATE.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/INDIA_REGION_AND_M0_OWNER_DECISION_GATE.md) | `2532a8535d34` | 5834 B |
| [LICENSING_DECISION_AND_IP_REGISTER.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/LICENSING_DECISION_AND_IP_REGISTER.md) | `00b139af73ac` | 3896 B |
| [VENDOR_DPA_AND_PROCESSOR_REGISTER.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/VENDOR_DPA_AND_PROCESSOR_REGISTER.md) | `a19224fa62c4` | 4079 B |
| [VERIFIABLE_PARENTAL_CONSENT_AND_GUARDIAN_AUTHORITY.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/VERIFIABLE_PARENTAL_CONSENT_AND_GUARDIAN_AUTHORITY.md) | `6f321dc0c54e` | 5903 B |

### M1-secure-platform-foundation (16)

| Canonical specification | Snapshot blob SHA | Size |
|---|---|---:|
| [IMPLEMENTATION_TECHNICAL_SPECIFICATION.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/01-requirements-and-architecture/IMPLEMENTATION_TECHNICAL_SPECIFICATION.md) | `b713545198c3` | 27592 B |
| [M1_ANDROID_CPP_ARCHITECTURE_AND_IMPLEMENTATION.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/01-requirements-and-architecture/M1_ANDROID_CPP_ARCHITECTURE_AND_IMPLEMENTATION.md) | `0cb6a520889d` | 25522 B |
| [REQUIREMENTS_TRACEABILITY.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/01-requirements-and-architecture/REQUIREMENTS_TRACEABILITY.md) | `8de095234c96` | 19517 B |
| [SRS.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/01-requirements-and-architecture/SRS.md) | `eeb773329b87` | 63309 B |
| [TECHNICAL_SPECIFICATION.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/01-requirements-and-architecture/TECHNICAL_SPECIFICATION.md) | `fb438fad57c6` | 48269 B |
| [ANDROID_M1_SOURCE_BOOTSTRAP_AND_BUILD_GATE_2026-10-27.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/02-development-process/ANDROID_M1_SOURCE_BOOTSTRAP_AND_BUILD_GATE_2026-10-27.md) | `1e0d41cf1751` | 6645 B |
| [BRANCHING_VERSIONING_AND_RELEASE_PROCESS.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/02-development-process/BRANCHING_VERSIONING_AND_RELEASE_PROCESS.md) | `98f45bb92db9` | 3737 B |
| [BUILD_AND_RUN.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/02-development-process/BUILD_AND_RUN.md) | `65dd1ac717a7` | 8583 B |
| [DEVELOPER_ONBOARDING_AND_CODING_STANDARDS.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/02-development-process/DEVELOPER_ONBOARDING_AND_CODING_STANDARDS.md) | `092ecab10395` | 4623 B |
| [THIRD_PARTY_DEPENDENCY_AND_SBOM_REGISTER.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/02-development-process/THIRD_PARTY_DEPENDENCY_AND_SBOM_REGISTER.md) | `0081191ddd65` | 3928 B |
| [ANDROID_COMPATIBILITY_MATRIX.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/ANDROID_COMPATIBILITY_MATRIX.md) | `ec5b2966e619` | 10186 B |
| [APP_SIGNING_AND_KEY_MANAGEMENT_POLICY.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/APP_SIGNING_AND_KEY_MANAGEMENT_POLICY.md) | `f7840e72f189` | 3082 B |
| [CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md) | `f1349e0b8443` | 22249 B |
| [DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md) | `6f7cf26600b4` | 29994 B |
| [SECURITY.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/SECURITY.md) | `024e498d73f2` | 6645 B |
| [THREAT_MODEL_STRIDE.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/THREAT_MODEL_STRIDE.md) | `3b2548bbd0a1` | 5788 B |

### M2-location-collection (3)

| Canonical specification | Snapshot blob SHA | Size |
|---|---|---:|
| [ADAPTIVE_MOVEMENT_CPP_SERVER_ARCHITECTURE.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M2-location-collection/01-location-collection-and-ingestion/ADAPTIVE_MOVEMENT_CPP_SERVER_ARCHITECTURE.md) | `131e6e1910d5` | 68803 B |
| [POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M2-location-collection/01-location-collection-and-ingestion/POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md) | `ee702f3e2061` | 22733 B |
| [TRACKING_RUNTIME_AND_ALGORITHM_CONTRACT.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M2-location-collection/01-location-collection-and-ingestion/TRACKING_RUNTIME_AND_ALGORITHM_CONTRACT.md) | `20499923c2e8` | 17882 B |

### M3-trips-and-places (1)

| Canonical specification | Snapshot blob SHA | Size |
|---|---|---:|
| [LIVE_TRIP_ROUTE_NAMED_PLACES_BATTERY_SPECIFICATION.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M3-trips-and-places/01-trips-and-named-places/LIVE_TRIP_ROUTE_NAMED_PLACES_BATTERY_SPECIFICATION.md) | `323668af142c` | 36716 B |

### M4-usage-health-sos (2)

| Canonical specification | Snapshot blob SHA | Size |
|---|---|---:|
| [COMMAND_SOS_USAGE_QUEUE_CONTRACT.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M4-usage-health-sos/01-usage-health-and-sos/COMMAND_SOS_USAGE_QUEUE_CONTRACT.md) | `a7d92970081c` | 19378 B |
| [SOS_ESCALATION_AND_INDEPENDENT_DELIVERY_DESIGN.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M4-usage-health-sos/01-usage-health-and-sos/SOS_ESCALATION_AND_INDEPENDENT_DELIVERY_DESIGN.md) | `f1392efbc0e3` | 12084 B |

### M6-guardian-erasure-security (1)

| Canonical specification | Snapshot blob SHA | Size |
|---|---|---:|
| [ACCOUNT_DELETION_DESIGN.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M6-guardian-erasure-security/01-data-erasure-and-access/ACCOUNT_DELETION_DESIGN.md) | `bbc1e02955ab` | 15334 B |

### M7-commercial-integrations (5)

| Canonical specification | Snapshot blob SHA | Size |
|---|---|---:|
| [CHILD_SPECIFIC_GOOGLE_PARENT_SHARING_AND_CONCURRENT_SCREEN_ADDONS_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/CHILD_SPECIFIC_GOOGLE_PARENT_SHARING_AND_CONCURRENT_SCREEN_ADDONS_2026.md) | `e17d45fdf077` | 19996 B |
| [PRICE_BREAK_EVEN_STAFFING_AND_DELIVERY_CAPACITY.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/PRICE_BREAK_EVEN_STAFFING_AND_DELIVERY_CAPACITY.md) | `f4e2c9400967` | 23565 B |
| [SUBSCRIPTION_PLANS_PRICING_AND_RULES_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/SUBSCRIPTION_PLANS_PRICING_AND_RULES_2026.md) | `ace27e30619d` | 47260 B |
| [THIRD_PARTY_SERVICES_COST_ANALYSIS_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/THIRD_PARTY_SERVICES_COST_ANALYSIS_2026.md) | `2cc247a90338` | 41003 B |
| [TWO_PARENT_SHARED_CHILD_PREPAID_ENTITLEMENTS_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/TWO_PARENT_SHARED_CHILD_PREPAID_ENTITLEMENTS_2026.md) | `ea46cfdcb77e` | 12756 B |

### M8-operational-readiness (10)

| Canonical specification | Snapshot blob SHA | Size |
|---|---|---:|
| [OCI_CHICAGO_DEPLOYMENT_AND_FINANCIAL_PLAN.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M8-operational-readiness/01-cloud-infrastructure/OCI_CHICAGO_DEPLOYMENT_AND_FINANCIAL_PLAN.md) | `c037f9cb2b2e` | 64317 B |
| [OCI_CHICAGO_RECOVERY_AND_PILOT_READINESS.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M8-operational-readiness/01-cloud-infrastructure/OCI_CHICAGO_RECOVERY_AND_PILOT_READINESS.md) | `da88f4cc4f7c` | 9167 B |
| [BACKUP_RESTORE_TEST_EVIDENCE.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M8-operational-readiness/02-operations-and-support/BACKUP_RESTORE_TEST_EVIDENCE.md) | `ef3698c9cc90` | 3090 B |
| [INCIDENT_AND_BREACH_RESPONSE_PROCEDURE.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M8-operational-readiness/02-operations-and-support/INCIDENT_AND_BREACH_RESPONSE_PROCEDURE.md) | `fed989be6ac0` | 19027 B |
| [MONITORING_ALERTING_SLO_SLA.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M8-operational-readiness/02-operations-and-support/MONITORING_ALERTING_SLO_SLA.md) | `38ec82dfecde` | 3716 B |
| [OPERATIONS_RUNBOOKS.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M8-operational-readiness/02-operations-and-support/OPERATIONS_RUNBOOKS.md) | `c77419e5bc26` | 5714 B |
| [SECURITY_AND_OPERATIONS.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M8-operational-readiness/02-operations-and-support/SECURITY_AND_OPERATIONS.md) | `5ab12a4f9e11` | 15739 B |
| [SUPPORT_AND_ESCALATION_SOP.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M8-operational-readiness/02-operations-and-support/SUPPORT_AND_ESCALATION_SOP.md) | `effd1a8a6515` | 3524 B |
| [TEST_STRATEGY_UNIT_INTEGRATION_LOAD_SECURITY.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M8-operational-readiness/03-quality-and-evidence/TEST_STRATEGY_UNIT_INTEGRATION_LOAD_SECURITY.md) | `ad173e38f664` | 3902 B |
| [VALIDATION_AND_RELEASE_PLAN.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M8-operational-readiness/03-quality-and-evidence/VALIDATION_AND_RELEASE_PLAN.md) | `ef627dfcf85d` | 19240 B |

### M9-play-release (7)

| Canonical specification | Snapshot blob SHA | Size |
|---|---|---:|
| [DATA_SAFETY_WORKSHEET.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M9-play-release/01-play-and-data-safety/DATA_SAFETY_WORKSHEET.md) | `4e6e37ec152d` | 14515 B |
| [GOOGLE_PLAY_PUBLISHING_REQUIREMENTS.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M9-play-release/01-play-and-data-safety/GOOGLE_PLAY_PUBLISHING_REQUIREMENTS.md) | `154bb562cf1e` | 20813 B |
| [PLAY_CONSOLE_DECLARATIONS_AND_REVIEWER_PACK.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M9-play-release/01-play-and-data-safety/PLAY_CONSOLE_DECLARATIONS_AND_REVIEWER_PACK.md) | `1a8e6ce6b64f` | 4278 B |
| [PLAY_STORE_LISTING_AND_REVIEWER_GUIDE.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M9-play-release/01-play-and-data-safety/PLAY_STORE_LISTING_AND_REVIEWER_GUIDE.md) | `aa6c6876cc3f` | 17220 B |
| [PRIVACY_POLICY_DRAFT.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M9-play-release/02-public-legal-drafts/PRIVACY_POLICY_DRAFT.md) | `8dc5cd2ae986` | 13766 B |
| [TERMS_AND_SUBSCRIPTIONS_DRAFT.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M9-play-release/02-public-legal-drafts/TERMS_AND_SUBSCRIPTIONS_DRAFT.md) | `9dbd078d1fa9` | 13382 B |
| [DEPLOYMENT_RELEASE_READINESS_CHECKLIST.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M9-play-release/03-release-gates/DEPLOYMENT_RELEASE_READINESS_CHECKLIST.md) | `e5f4da64d36b` | 4989 B |

### P3-deferred-research (4)

| Canonical specification | Snapshot blob SHA | Size |
|---|---|---:|
| [ADMIN_OWNER_GOOGLE_ACCESS_FAQ_SUPPORT_BILLING_AND_USAGE_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/P3-deferred-research/01-media-and-administrator-research/ADMIN_OWNER_GOOGLE_ACCESS_FAQ_SUPPORT_BILLING_AND_USAGE_2026.md) | `3b1211833462` | 18706 B |
| [ADMIN_PANEL_SPECIFICATION_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/P3-deferred-research/01-media-and-administrator-research/ADMIN_PANEL_SPECIFICATION_2026.md) | `0e126ea38bae` | 16061 B |
| [MEDIA_ACTIVITY_AUDIT_LOGGING_AND_REPORTING_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/P3-deferred-research/01-media-and-administrator-research/MEDIA_ACTIVITY_AUDIT_LOGGING_AND_REPORTING_2026.md) | `39a90d2ed62a` | 18232 B |
| [MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/P3-deferred-research/01-media-and-administrator-research/MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md) | `0a450e3a1000` | 16938 B |

### cross-milestone-references (1)

| Canonical specification | Snapshot blob SHA | Size |
|---|---|---:|
| [ERASER_HLD_LLD_DIAGRAM_INDEX.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/cross-milestone-references/01-architecture-and-visual-indexes/ERASER_HLD_LLD_DIAGRAM_INDEX.md) | `81f3cf4aa87e` | 10013 B |

## API, database, Figma and source code anchors

- [docs/openapi-m1.yaml](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/openapi-m1.yaml) — blob `7e9c2fc82dae`, 54405 B
- [docs/openapi.yaml](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/openapi.yaml) — blob `b84eac226785`, 208305 B
- [docs/data-model/MADALASA_ALARKA_FIGMA_LOGICAL_ERD_V1_2026.json](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/data-model/MADALASA_ALARKA_FIGMA_LOGICAL_ERD_V1_2026.json) — blob `c5c28bb75cda`, 47171 B
- [docs/data-model/MADALASA_ALARKA_FIGMA_LOGICAL_ERD_V1_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/data-model/MADALASA_ALARKA_FIGMA_LOGICAL_ERD_V1_2026.md) — blob `e7df32e181fc`, 35707 B
- [docs/ui/FIGMA_ANDROID_UI_INDEX.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/ui/FIGMA_ANDROID_UI_INDEX.md) — blob `50eae41167a4`, 31494 B
- [docs/ui/MADALASA_ALARKA_THEME_C_STORY_AND_UI_CONTRACT_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/ui/MADALASA_ALARKA_THEME_C_STORY_AND_UI_CONTRACT_2026.md) — blob `106d41bca8e0`, 15025 B
- [docs/ui/REFERENCE_SCREENSHOTS_FEATURE_WORKFLOWS_2026.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/ui/REFERENCE_SCREENSHOTS_FEATURE_WORKFLOWS_2026.md) — blob `47fb9a5a4ee2`, 7209 B
- [docs/ui/figma-functional-handoff/README.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/ui/figma-functional-handoff/README.md) — blob `cf860cef2a32`, 35090 B
- [backend/persistence/migrations/0001_m1_identity.sql](https://github.com/methakon/Madalasa-Alarka/blob/main/backend/persistence/migrations/0001_m1_identity.sql) — blob `be501b33351d`, 15859 B
- [backend/tests/m1_tenant_isolation.sql](https://github.com/methakon/Madalasa-Alarka/blob/main/backend/tests/m1_tenant_isolation.sql) — blob `4b7aa8c3b72f`, 6735 B
- [backend/tests/lint_openapi_m1.py](https://github.com/methakon/Madalasa-Alarka/blob/main/backend/tests/lint_openapi_m1.py) — blob `b46926617ac0`, 5739 B
- [.github/workflows/m1-contract-and-tenant.yml](https://github.com/methakon/Madalasa-Alarka/blob/main/.github/workflows/m1-contract-and-tenant.yml) — blob `0a9bc761a7ac`, 1562 B
- [android/alarka/src/main/kotlin/org/madalasa/alarka/domain/LocationObservation.kt](https://github.com/methakon/Madalasa-Alarka/blob/main/android/alarka/src/main/kotlin/org/madalasa/alarka/domain/LocationObservation.kt) — blob `b4da6fe4a7d0`, 1151 B
- [android/madalasa/src/main/kotlin/org/madalasa/madalasa/domain/VerifiedLocationState.kt](https://github.com/methakon/Madalasa-Alarka/blob/main/android/madalasa/src/main/kotlin/org/madalasa/madalasa/domain/VerifiedLocationState.kt) — blob `a663c55fbd4b`, 651 B
- [docs/MASTER_DOCUMENT_CONTROL_REGISTER.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/MASTER_DOCUMENT_CONTROL_REGISTER.md) — blob `ae81fe9cbd2c`, 20492 B
- [docs/DOCUMENT_CONTROL_POLICY.md](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/DOCUMENT_CONTROL_POLICY.md) — blob `fbc4d64ec162`, 4808 B

### Figma source pages and feature handoff

- [Figma Madalasa–Alarka master](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli).
- [Parent/child functional screen register](https://github.com/methakon/Madalasa-Alarka/tree/main/docs/ui/figma-functional-handoff) — 10 JSON screen handoff files, some visual design artifacts and conditional prototypes not a running app.
- [Theme C visual and story contract](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/ui/MADALASA_ALARKA_THEME_C_STORY_AND_UI_CONTRACT_2026.md) — pan-Indian Markandeya Purana inspiration, English initially, future translations.
- [Child-specific payment/guardian sharing SH-01](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=84-179) · [verification pending SH-02](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=84-201).
- [One-viewer SH-03](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=84-221) · [₹100/100d checkout SH-04](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=84-242) · [addon persists on base lapse SH-06](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=89-180).
- [Family P-47 paid child seat assignment](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=81-179) · [P-49 covered co-parent](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=81-201).
- [10-domain DB logical ERD (112 proposed tables)](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=92-2).
- [10-page/state separate administrator back office](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=105-2) · [16 admin logical tables](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=108-2).
- [Eraser architecture HLD/LLD index](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/cross-milestone-references/01-architecture-and-visual-indexes/ERASER_HLD_LLD_DIAGRAM_INDEX.md).

## External official sources (refresh at each release)

[Play Personal account closed testing](https://support.google.com/googleplay/android-developer/answer/14151465) · [Device verification](https://support.google.com/googleplay/android-developer/answer/14316361) · [Target API 36 from Aug 2026](https://developer.android.com/google/play/requirements/target-sdk) · [Monitoring app policy](https://support.google.com/googleplay/android-developer/answer/9888380) · [Android FGS background restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start) · [DPDP Act](https://www.meity.gov.in/static/uploads/2024/02/Digital-Personal-Data-Protection-Act-2023.pdf) · [DPDP phased notification](https://www.meity.gov.in/static/uploads/2025/11/53450e6e5dc0bfa85ebd78686cadad39.pdf).

## Audit usage

This register identifies the source of each feature, not a legal certification. A coding agent must read the latest linked document when executing its task, report discrepancies as ADRs and never treat proposed data retention, parent verification, Play account testing, government exception or local build as approved/completed. Deployment has its own separate plan.

## 2026-10-28 owner decisions superseding C-01 and C-03

- C-01 (**hosting region and actual egress cost**) is **DEFERRED_TO_DEPLOYMENT**, not a local code blocker. Local benchmark tests must still measure synthetic resource use. Don't use an OCI region selection as dependency for C++/Android/Admin build.
- C-03 (**Google Family Link parent-role API**) is **REMOVED as an app dependency**. Use Google account authentication and child-specific invite/acceptance + revocable permission grants independent of billing-family membership. Separate statutory parent/guardian consent and legal authority gates remain mandatory, see [V2 ADR](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/ADR_2026_10_28_BLEND_FAMILY_V2_AND_NO_FAMILY_LINK_DEPENDENCY.md). Older 'Google role verification required' notes retained for historical traceability are now superseded.
