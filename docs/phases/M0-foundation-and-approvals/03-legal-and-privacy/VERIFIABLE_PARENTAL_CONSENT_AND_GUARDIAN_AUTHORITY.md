# Verifiable Parental Consent, Guardian Authority and Revocation — Proposed Contract

> **Document control:** M0 / 03-legal-and-privacy · Proposed owner: Privacy counsel + owner (not assigned) · Registry: DRAFT_LEGAL_REVIEW_REQUIRED; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

**Status:** Design only; India counsel and Play approval required, no live identities or consent processor. Current M1 identity SQL and auth contracts are synthetic only.

## Decision principles
Under-18 child-personal-data processing and monitoring is **feature/purpose specific**. A parent tapping "I consent" or installing Alarka and granting Android permissions does not necessarily satisfy verifiable parental consent, genuine custodial/guardian authority, or legal exceptions from restrictions on behavioural monitoring. Actual DPDP Act section 9 and Rules 2025 Rule 10/12 commencement/exemption details must be confirmed by India counsel at pilot/release time; 2025 notification phases substantive children provisions eighteen months from Gazette 13 November 2025. **No assumption that limited real-time safety location exemption authorizes persistent historical trails, UsageStats or microphone/video monitoring.**

Source: https://www.meity.gov.in/static/uploads/2025/11/53450e6e5dc0bfa85ebd78686cadad39.pdf (2025 Rules); https://www.meity.gov.in/static/uploads/2024/02/Digital-Personal-Data-Protection-Act-2023.pdf (Act).

## Proposed technical flow
1. Adult registers a guardian account; obtain purpose-specific disclosures in understandable language, child identity/age, nominated device association and authority evidence through a counsel-approved verification method (not just self-assertion).
2. Trusted enrollment creates one-time pairing code; Alarka user/device visibly accepts, binds enrolled device public key to Keystore, and server links `guardian_id + child_id + device_id + enrollment_generation`.
3. Separate lawful consent/purpose decisions for **safety location**, **history/trips**, **app usage**, **managed app controls**, **SOS**, **media research**, **optional Drive backup** and **media-event metadata**. Default sensitive features OFF pending legal/Play decisions.
4. For each released feature, Alarka displays purpose/recipients/retention, then requests the **Android-controlled** permission/Settings grant; checks the actual OS scope. Permission result and legal consent are recorded independently.
5. Generate tamper-evident consent record: guardian ID/verified authority method & assurance level, child/device scope, precise purpose ID/version, notice/policy hash, locale, grant UTC, expiry/reverification, issuing actor, verification provider, consent status, revocation time and trace/reference. Store encrypted and retention-limited. **No scan of IDs, passports or guardian documents unless an approved vendor/legal basis and minimization workflow exist.**
6. Pairing, permission and legal-purpose grants can each be revoked independently; deny new server commands and intake before cleanup. Current partner roles do not automatically permit every linked child. Device may be offline for 48h; server enrollment tombstone/revocation blocks late queue replay.
7. When minor reaches applicable age of majority or guardianship changes, reassess rights and discontinue child monitoring absent new legal basis; preserve only lawful, minimized records.
8. In custody/abuse reports, prioritize safety and constrained access; never give every adult claiming parenthood unrestricted tracking. Create confidential dispute review and access freeze policy.

## Proposed consent schemas (not migrations)
`consent_decisions(id,child_id,guardian_id,purpose_code,purpose_version,notice_hash,source,effective_at,expires_at,revoked_at,status,authority_verification_ref,assurance_level)`; `guardian_authority_checks(...)`; `device_enrollment_generations(...)`. Authorized reads only, append-only decision events and bounded audit logs. Parent app sees approved, pending/reverify, revoked, not eligible and Android permission *separately*, with last observed timestamps.

## Test gates
Verified guardian vs unauthorised adult, two-parent dispute, stepchild/grant mismatch, re-enrollment stolen phone, Android location grant without lawful-purpose grant, precise vs approximate/temporary scope, India-privacy effective dates, stale offline revoke, one child vs sibling, underage-to-adult transition, history-retention after withdraw, attempted admin bypass and double notification. Do not mark tests passed until server/Android/verification provider exist.

**Status: NOT IMPLEMENTED; DO NOT COLLECT REAL MINOR DATA.**

## Current owner and blended-family authority gate — 2026-10-30

**Supersedes the 2026-10-28 Google-supported-parent/Family Link wording.** The declared responsible publisher is **Individual SWARNA SEKHAR DHAR, India**, intended to be the same legal/Play publisher. Payments identity, merchant setup, public support confirmation and legal review remain pending; the declaration is not a verified identity or consent-provider appointment.

Google Sign-In authenticates an account used in the adult workflow only; it does **not** prove age, parenthood, custody or lawful guardianship. There is **no Google Family Link dependency**. Sharing requires an invitation accepted for **one exact child**, an authorized inviter, and approved authority/consent where legally required; it never grants siblings or billing-family membership. Leave real-child sharing OFF until that flow and the legal gate pass.

Rule 10 addresses verifiable parental consent and due diligence on an identifiable adult using reliable identity/age details or voluntarily supplied details/authorized tokens. It does not prescribe a universal upload of custody papers or make Google login a verification method. Rule 11 concerns a **person with disability who has a lawful guardian**, not the general child-consent rule. The product's separate anti-abuse/custody-authority checks require a proportionate, counsel-approved method; do not present that additional safety design as an exact statutory document checklist. See [official Rules and commencement review](INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md#current-source-grounded-review--2026-10-30).

New marriage, biological relationship, co-parent designation, a shared surname and paid coverage do not establish authority to track a child. No routine identity-document scans or Family Link screenshots; use minimized verified references only after a reviewed method exists. Do not disclose sibling names, child/device status or location through invite/search errors. Reverify material authority changes; provide confidential dispute handling, access freeze and revocation without assuming one adult is always sole authority. No real-time-location exception is presumed to cover history, usage or media. **Real child-data release OFF; no live identity verification or external upload is authorized.**
