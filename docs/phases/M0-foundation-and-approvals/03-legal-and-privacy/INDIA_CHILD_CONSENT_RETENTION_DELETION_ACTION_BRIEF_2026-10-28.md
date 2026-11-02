# India child-data privacy: consent, retention, deletion — implementation and signoff brief

**Date:** 2026-10-28; reconciled **2026-10-30 IST**. **Status:** compliance preparation, NOT legal advice or legal approval. Local coding may use synthetic test scaffolding only while sensitive real-child features remain OFF until independent review.

**Current owner facts:** **Individual SWARNA SEKHAR DHAR, India**, same intended legal/Play publisher; declaration, not verified account/legal evidence. Payments identity, merchant setup, public support confirmation and legal review remain pending. India-only launch and ages 0–17 are owner-decided; no company/GST/address/email is inferred. No Family Link dependency; exact-child invitation acceptance and approved authority/consent where required remain separate from Google account authentication. The [current legal-source review](INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md#current-source-grounded-review--2026-10-30) takes precedence on commencement/corrigendum, existing IT/SPDI/CERT-In applicability, future Rule 8(3) personal-data retention and unresolved questions. **Real child-data release OFF.**

## Current statute and commencement

The Digital Personal Data Protection Act, 2023, Section 9 addresses processing of children's data and verifiable parental/lawful guardian consent, and restricts detrimental processing and tracking/behavioural monitoring, with narrow statutory and prescribed exceptions. DPDP Rules 2025 were notified on 14 November 2025. The statutory 13 November 2025 commencement notification schedules key provisions, including Section 9, for **18 months after Gazette publication**; the earlier unqualified **13 May 2027** calculation is superseded by the current legal gate's publication-date assessment and counsel confirmation. This phased commencement does not remove current Google Play requirements, other applicable Indian legal duties or privacy/security commitments.

Authoritative sources:
- https://www.meity.gov.in/documents/act-and-policies/digital-personal-data-protection-rules-2025-gDOxUjMtQWa
- https://www.meity.gov.in/static/uploads/2025/11/c56ceae6c383460ca69577428d36828b.pdf (commencement)
- https://www.meity.gov.in/static/uploads/2025/11/53450e6e5dc0bfa85ebd78686cadad39.pdf (rules)
- https://www.meity.gov.in/static/uploads/2024/02/Digital-Personal-Data-Protection-Act-2023.pdf (Act Section 9)

**Critical:** Dropping the *Google Family Link relationship API* is not dropping verifiable parent/guardian consent or lawful access. Verified Google login authenticates an account used in the adult workflow, not verified adult age or parent/guardian authority. Any mechanism satisfying the legal parental-authority and consent obligation must be separately designed/approved. Primary parent's invitation by itself may be insufficient, especially in contested custody. Counsel must assess applicable exemptions for real-time safety by fiduciary type, purpose and conditions; a consumer monitoring app cannot presume blanket coverage for live GPS, history, behavioural usage, media and app blocking.

## Required design controls by category

| Category | Local engineering contract | Owner/legal decision before real processing |
|---|---|---|
| Adult authority | Authenticated adult, child-specific grant, exact scopes, consent record; enforce guardian revocation, dispute freeze and child transparency | Age and parent/lawful guardian verification method; who can authorize each type of monitoring |
| Live GPS | Real device OS location permission, visible monitoring, encrypted transport, minimal precision and last-seen quality | Does specific narrowly limited child-safety purpose meet an exception? |
| Location history | Separate FREE last-six-hours *visibility* filter from physically retained raw data; data partition TTL and backup tombstones | Raw GPS, derived trips, backup/WAL and audit retention periods. Owner's wish to retain until closure is not itself compliant retention authorization |
| Child usage reports | Feature gate and consent scope; app activity telemetry independent from parent service logs | Determine applicability of Section 9 monitoring restriction; no automatic exemption |
| Remote media/screen | OS-allowed visible workflows and meaningful user action/permission where required; no covert capture | Separate Play/Android/legal approval per feature, especially background recording |
| Parent account/billing/admin | Minimal identifiers and store purchase metadata; admin sees only masked child names/seat counts and parent service usage | Contract, taxation, retention and grievance provisions; avoid compulsory admin DOB/gender/address without necessity |
| Erasure/rights | Delete-request ledger, identity verification, child ingest tombstones and revocation, primary object/derived/cache/inbox/outbox erase; backups/WAL restore suppression, encrypted export | Specific statutory retention exceptions and timeframes, data rights/grievance contact, process assurance |
| Security/breach | RLS, access logs, short-lived sessions, encryption, privilege segregation and response runbook | Legal reporting thresholds and responsibilities, vendors and notices |

## Definition of completion for local code

Implement policy-as-data: `consent_record(id, child_id, authorized_adult_id, purpose, notice_version, authority_status, issued_at, withdrawn_at)`, `retention_policy(data_category, period, approval_status, backup_scope)`, `child_erasure_tombstones(child_id, epoch)`, `erasure_jobs(store, state, proof)`. Default unknown legal settings to **DENIED/NOT_APPROVED** for real use. Run tests for cross-child access, revocation, offline queued replay after erase, backup restore, free history >6h cursor denial, and data export leakage. Local fake consent and synthetic guardians are not government-approved evidence.

## Owner and qualified counsel decisions required

1. Verify declared Individual SWARNA SEKHAR DHAR as legal/Play publisher and record India-only ages 0–17; complete pending Payments/merchant/public-support evidence. Counsel must approve lawful purposes, adult identity/age and exact-child parent/guardian authority method.
2. Approve purposes per data class and assess DPDP tracking/monitoring exceptions with citation to applicable rule/schedule, not a blanket label “parental safety”.
3. Decide separate retention durations for location, route, media metadata, support, billing, backups/WAL, deletion audit and trial replay resistance; audit necessity and data-minimization.
4. Approve clear child/parent privacy notices, consent/withdraw and rights handling, dispute resolution, child transparency, exports, grievance response, breach response and deletion commitments.
5. Review subprocessors, India transfers and cross-border restrictions at deployment; **hosting region itself is a deployment decision, not a local coding prerequisite**.

No automated coding agent, policy checker or Figma diagram can substitute for signoff by a legally responsible controller and qualified Indian privacy counsel.
