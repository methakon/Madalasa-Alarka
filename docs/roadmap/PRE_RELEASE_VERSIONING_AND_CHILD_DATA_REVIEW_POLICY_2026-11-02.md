# Pre-release versioning and child-data review workflow (2026-11-02)

**Status:** Owner direction recorded; documentation policy, not regulatory clearance or an implementation acceptance result.
**Scope:** Madalasa parent app, Alarka child app, C++ Drogon backend, admin UI, OpenAPI and operational documentation.
**Authority:** This addendum establishes version nomenclature and development sequencing; it does not override current Indian law, Android OS constraints, Google Play policies, or feature-specific security requirements.

## 1. Product versioning policy

- **Before the first public release:** use semantic-like `0.x.y` development versions. Existing source-control commits and historic ADR/document versions are preserved; no retroactive Git tag or APK version is asserted.
- **Internal testing:** `0.x.y-dev.N` or equivalent CI build metadata; never imply published availability.
- **First public release candidate:** `1.0.0-rc.N`; first actually published public product release: `1.0.0`.
- **After public release:** semantic versioning for compatible fixes/features and breaking changes, with independent Android `versionCode` monotonically increasing for each app; backend/API routes retain separately documented compatibility and schema migration versioning.
- Git is the source of truth: immutable tags for actual released commits, CHANGELOG entries, recorded release branch/build SHAs and signed artifacts where applicable. No release tags may be created from documentation decisions alone.
- Document revisions and ADR identifiers are **not** app version numbers. Updated canonical documents must point to superseded decisions explicitly; do not rewrite historical evidence.
- Reconcile `docs/openapi-m1.yaml`, `docs/openapi.yaml`, current migrations, SRS, admin stack decision and Android handoff using versioned contracts rather than resetting history.

## 2. Child-data legal and Play clarification: engineering may continue, release gate remains

Owner direction: use owner-controlled physical Android devices and consenting adult testers for genuine real-world integration tests instead of making synthetic data the mandatory or exclusive test method. Do not treat unresolved regulator/Play responses as blockers for unrelated local implementation. If official responses or applicable review evidence arrive before submission, incorporate them; a Play review response may inform later updates. **Do not adopt "wait for a rejection" as evidence of compliance or permission to process real child data.** The app must satisfy applicable requirements at submission, including disclosure, consent/guardian authority where required, documented retention/deletion, Data Safety answers, appropriate target audience and Android permission policy.

Allowed now: production-oriented architecture, explicit-consent/guardian authorization interfaces, configurable category-specific retention, erasure and audit reducers, deny-by-default handlers, UI, tests including revocation, negative auth and deletion/no-resurrection. For real-world functional verification, use owner-controlled physical Android devices with informed, consenting adult testers, authentic GPS and connectivity, real local Drogon/PostgreSQL services, and valid Android permission flows. Do not require artificial movement or fake location traces for this test lane. Keep an optional non-personal fixture/negative-test lane for repeatable CI, malicious inputs, and failure reproduction, since physical-device testing alone cannot cover every security failure deterministically. Payments remain in an authorized provider test/sandbox environment. Do not silently remove existing security/legality gates. Keep real-child GPS, behavioural usage reports, media capture and restricted background collection disabled until the applicable feature-specific legal/OS/Play gates are met.

The `docs/DOCUMENTATION_PHASE_GATE_CHECKLIST.md` release status remains NOT_READY; this document clarifies sequencing but grants no approval. Resolve uncertainties by recording `REVIEW_REQUIRED` / `BLOCKED_EXTERNAL` *for that live feature or release step*, not for unrelated synthetic implementation.

## 3. Comparable app privacy practices (research only; not legal precedent)

Checked public policies on 2026-11-02:
- **Google Family Link:** parent manages child-account/profile permissions, activity and account deletion; notice distinguishes Google's service from third-party applications. https://families.google.com/familylink/privacy/notice
- **Life360:** underage participation involves parent/guardian consent where applicable; supports parental review/deletion/withdrawal requests and differentiates location-history visibility by membership (2/7/30 days); retention may also depend on purpose. https://legal.corp.life360.com/hc/en-us/articles/16038777217175-Life360-Privacy-Policy ; https://support.life360.com/hc/en-us/articles/23053602225559-Location-Drive-History
- **Qustodio:** describes distinct retention for categories, including device-data access windows, longer annual-report data and backup deletion timelines; policy details vary by data type. https://www.qustodio.com/en/family/privacy/
- **Bark (bark.us):** describes parental access/revocation/deletion requests and necessary-duration child-data retention. https://www.bark.us/privacy/

**Transferable architectural pattern, not permission to copy competitors:** separate (a) collection purpose/legal authority and guardian approval, (b) who may view how much history, (c) server retention by data category, (d) revocation/export/deletion/backup enforcement, and (e) child/device notices and permission states. Competitor practices are not proof that indefinite identifiable history or behaviour tracking is permissible in India.

## 4. Required future acceptance evidence (record; do not pre-approve)

1. Feature-by-feature India DPDP/operative-rule assessment with primary-source citations and current commencement/application analysis; exact parent/guardian authority and clear notices.
2. Per-category retention/deletion schedule with server enforcement, backup expiry, old offline-upload suppression, test evidence and documented exceptions as applicable. **Six-hour FREE visibility is not by itself a retention authorization.**
3. Review of real-app disclosure, background location eligibility, Families/monitoring classification and exact requested OS permissions; actual Google Play responses when received.
4. Data Safety, privacy policy and in-app statements consistent with implemented behavior; real-device/Play acceptance and verified release build.
5. Record the evidence and decision in the canonical blockers register; only then advance the relevant release gate.

**Engineering action:** proceed with real-world owner-device / consenting-adult testing plus repeatable automated negative tests. Device ownership is not blanket permission to monitor minors, other users, bystanders, or third-party sensitive information. Keep disclosure, consent, revocation, minimization, secure transport, deletion and Android/Play gates. Never upload personal GPS logs, credentials, media or test identities to a public repository. Do not ask the owner to resend completed publisher identity verification or request a mandatory paid signed legal opinion without a demonstrated rule requiring it.

## 5. Owner-device testing clarification (2026-11-02)

The owner explicitly rejected *synthetic-only* as the development testing strategy. Primary manual and end-to-end testing should use two or more owner-controlled physical Android devices, consent from any adult whose data is involved, the actual Android location and permission lifecycle, and real local/VPS APIs under access control. Tests should document device model/API level, network condition, consent/disclosure, redacted outcomes and deletion of collected test data. A dedicated test scope with short, bounded data retention must be defined before GPS ingestion; public GitHub issues/logs/screenshots must not expose trajectories or identifying information. Avoid use in financial apps or third-party private content. Continue deterministic fake-input/negative-test automation as a complementary technique rather than a substitute for device tests. This clarification does not authorize processing children's personal data before applicable requirements are met.

## 6. Private laboratory test mode — owner clarification (2026-11-02)

The project owner confirms that the primary test environment is a **private lab using devices owned and operated by the owner**. The owner does not need a separate written self-consent certificate to run their own test devices. For a different adult participant, obtain informed participation and disclose the monitoring scope; never imply that owning a device authorizes covert monitoring of another person. Android OS runtime permissions, applicable foreground-service notifications and privacy indicators, honest functionality disclosures, access control, and data security are retained in LAB_TEST_MODE. Test logs/data are private, scoped and deleted after the test as specified by the lab retention configuration. The legal and Google Play real-child/release gates remain separate; do not block legitimate owner-only lab integration testing merely because Play review is pending. Native Android tests may run with genuine GPS, physical movement, real connectivity and actual dev APIs/database. Automated non-personal negative-case tests remain useful but are not a condition that all real-device data be synthetic.

## 7. Privacy, guardian access and retention implementation specification (2026-11-02)

The authoritative engineering details are in [Privacy Controls v0 Technical and UI Specification](../phases/M1-secure-platform-foundation/01-requirements-and-architecture/PRIVACY_CONTROLS_V0_TECHNICAL_AND_UI_SPEC_2026-11-02.md). This document describes the specific data categories, child-scoped guardian grants and revocation, Free six-hour viewing window, deletion and no-resurrection, database schemas, draft API contracts, Android UI states, negative tests and source attribution. Its technical requirements replace earlier high-level decision-label tables; no competitor's privacy policy is copied as a universal legal rule. The six additional editable Figma Theme C privacy flow screens reside on the `PRIVACY • v0 Parent + Child Controls` page and do not renumber the original 81. Real-child use and release still require applicable law/Play eligibility, while owner-operated lab testing proceeds under Section 6.
