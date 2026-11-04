# Google Play Publishing and Compliance Specification

> **Document control:** M9 / 01-play-and-data-safety · Proposed owner: Play release owner + counsel (not assigned) · Registry: DRAFT_LEGAL_REVIEW_REQUIRED; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

> **Product names:** **Madalasa** (parent app), **Alarka** (child app). Desired repository name **Madalasa-Alarka** is **completed GitHub repository rename**. Use the verified new repository URL for all current documentation and integrations. [Naming rationale](../../M0-foundation-and-approvals/02-market-and-feasibility/BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

## X-01 BillDesk onboarding update — 2026-11-03

The owner supplied a BillDesk Connect confirmation that the **application was successfully submitted**, with a numeric Application ID assigned for correspondence. BillDesk directs application-status enquiries to **onboarding@billdesk.com**, with that ID in the **subject line**. Keep the number and official receipt **private**, never in public docs, Figma, source or logs. A `BD`-prefixed Partner ID is an alternative identifier, not required in addition to the application ID.

**Current gates:** Play publisher identity = owner-confirmed complete; BillDesk submission = owner-confirmed complete, **provider review response pending**; Video KYC completion = **unverified**; Google Payments merchant/payout/tax and Play billing product eligibility = **unverified**. Continue engineering without payment onboarding as a development blocker. Actual paid purchases and public release require relevant separate approvals. Request BillDesk clarification for the currently unpublished Play Store listing URL rather than assuming the portal submission resolves it.

See [BillDesk application submission and verification tracker](../03-release-gates/BILLDESK_APPLICATION_SUBMISSION_TRACKER_2026-11-03.md). Historical 2026-10-31 status text below remains historical; this update is authoritative for X-01B.

## 2026-10-31 X-02 reviewer readiness — current primary Play policy

[Canonical X-02 Families/location/monitoring decision path](X02_FAMILIES_LOCATION_AND_MONITORING_POLICY_REVIEW_2026-10-31.md) documents Google Families *solely-child-targeting precise-location exclusion*, monitoring disclosure and `isMonitoringTool` **without a Families waiver**, plus **separately required** background-location review (one declared core feature, actual device build, consent, privacy HTML URL, video and reviewer access). **G01 remains OPEN awaiting product-specific human Play review in the existing owner support case; G04 remains NOT SUBMITTED/NOT APPROVED.** Development/research with synthetic users is not blocked by awaiting a response. Do not introduce unapproved child GPS/media permissions into released Alarka.

## 2026-10-31 clarification: legal compliance vs paid legal opinion

Indian-law compliance is a real launch obligation for applicable child-data features. **A signed/printed advocate opinion, generic MeitY permission or legal certificate is not a universal Play Console or DPDP pre-submission requirement established by the cited rules.** Internal X-03/G02 evidence is an owner-accountable, cited feature-by-feature legal assessment; counsel's written **email** is acceptable supporting evidence, while independent specialist advice is strongly recommended when the lawfulness of sensitive child tracking, behavioural analytics or audio/video/screen recording is uncertain. No document format alone conveys permission to process children's data. Keep affected features OFF until lawful basis, safeguards and independent Play/Android gates are resolved. See [current blocker register](../../M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md).

## X-01 publisher/payment status correction — 2026-10-31

**Google Play developer identity verification: COMPLETED (owner-confirmed; prior owner-provided status screenshot, not copied to public Git).** This publisher-identity requirement is **no longer an active blocker**. **BillDesk/payment verification: SUBMITTED; provider response PENDING.** Payment/merchant activation is **NOT CONFIRMED**, and a BillDesk submission does not automatically establish that a separate Google Payments merchant account/profile is approved or activated. Verify any distinct Google Payments profile, tax, payout, SKU and Play monetization requirements when applicable. Do not repeat completed identity verification or request sensitive ID/payment documents. This status update does not authorize app upload, purchases or child data collection.

## Historical release preparation checkpoint — 2026-10-30 (identity/payment statuses superseded above)

**NO-GO / preparation only. No credentials created, Android build run, Console read/write, upload, identity/merchant change or release submission performed by this assessment.** Publisher is the owner-selected **Individual SWARNA SEKHAR DHAR, India**; not a company. Planned child scope is **India 0–17**. These owner choices are decided; their legal/Play consequences are not. Public support/privacy/grievance contacts, publishable address and effective dates remain pending confirmation; never invent them or expose private verification documents.

### Publisher, Payments and merchant identity are distinct gates

Google uses a linked Payments profile to verify a developer's legal name/address; monetization additionally requires a merchant account/payment setup, which may use the same or a different Payments profile. An owner declaration of the Individual publisher name is **not evidence that either verification has completed**. At the 2026-10-30 checkpoint, Payments identity was **PENDING**, merchant setup **PENDING**, legal/tax review **PENDING**. **Current state:** Google Play publisher identity COMPLETE per owner, BillDesk submitted and awaiting response, merchant activation not yet verified, legal/tax review still pending. Do not create a fictitious organization, infer GST status, copy a personal address into drafts or request identity/bank documents in chat. Owner records only redacted status/outcome and approved public particulars in the handoff.[29][30]

| Dependency | PREP now (no account action) | BUILD / evidence later | CONSOLE OWNER / counsel only |
|---|---|---|---|
| Publisher identity | **Identity COMPLETE (owner-confirmed)**; continue using exact Individual name/country, keep public contact/address pending | Notices and URLs match approved identity | No repeat identity submission; confirm required public contact/display and preserve sensitive proof privately |
| Merchant/Payments | **BillDesk submission complete; response pending.** Distinct Google Payments merchant/profile activation not confirmed; tax/currency/support still pending | Real sandbox verified purchase lifecycle/ledger | Await actual provider outcome; verify provider-specific merchant/payout eligibility, tax/country and catalog separately |
| Separate apps | Distinct Madalasa/Alarka purpose, age/privacy/permission/declaration worksheets | Read applicationId/manifests/versionCode/target/native SDKs from signed candidates | Confirm listings, track access, signing and upload authorization; existing local key material is not release evidence |
| Audience/Families | Parent adult purpose vs child-companion 0–17 truthful assessment; English story art does not decide audience | Actual content/flows/SDK/permission audit | Resolve Families-location incompatibility; no age misdeclaration or inferred monitoring exemption[10][17] |
| Monitoring | Declare all tracking functions; recognizable Alarka launcher, disclosure and persistent monitoring notice | Inspect actual monitoring metadata/type/notice on every active track; denial behavior | Complete monitoring designation and review actual policy outcome[9][18] |
| Location | Separate live safety/history/usage purposes; child prominent background disclosure/video storyboard | Foreground then separate background grant; location FGS; OEM/force-stop/Doze/revoke and late queue proof | Location form/video and policy clarification; India legal purpose/consent before real child processing[12] |
| FGS/sensors | Only enabled feature types/permissions; camera/mic/projection OFF | Match service type, trigger, stop, prerequisites/boot restrictions, verified visible behavior to each form | Complete actual FGS forms/use-case videos; approve any future media scope separately[1][2] |
| Privacy/Data Safety | Separate worksheets, real recipients/retention pending, deletion/contact drafts | Manifest/SDK/traffic, encryption, web+in-app deletion and restore-safe erasure tests | Approve public policy/terms/contact/retention and final per-package responses[13][14] |
| Commerce | Preserve prepaid prices/quotas/seat/add-on rules; stop/top-up/refund explanations | Server purchase verification, timely acknowledgment, pending/refund/revoke/expiry; capability preflight | Verify prepaid SKUs/seat/offer/add-on architecture in actual sandbox, not assume Play native prepaid add-ons support[16] |
| Testing/review | Synthetic reviewer scenarios/accounts/video scripts, no secrets | Real signed build/synthetic backend/device/video evidence, cross-family negative tests | Determine account testing applicability; personal accounts after 2023-11-13: 12 opted-in testers continuously 14 days, then production-access application, not automatic approval[15] |
| Release/native | Manifest/library/SBOM/evidence acceptance list | Target API36+ phone candidate; native 16KB proof if native libraries ship; final binary checked | Owner upload/track/review/staged rollout only after legal/security gates; policy recheck at submission[11][26] |

### Explicit release boundaries

- **Remote media OFF**, including paid/trial quota UI. Review of full planned/candidate inventory is not permission to implement or publish all features. No alternate noncompliant APK, hidden launcher, notification suppression, sensor indicator bypass, Accessibility spy/block/capture workaround, root or exploit.[9]
- Backend preflights exact app/version/OS/capability-report freshness and schema, enrolled role, exact-child action scope, release flags/authority and verified entitlement/budget **before ACCEPT**, not only at purchase or after command delivery. Alarka rechecks OS eligibility at execution. FCM/delivery is not actual capture, saved file, viewing or emergency receipt.
- Financial/banking/wallet/UPI/payment/credential screens **must never be captured**, including transitions/overlays/previews. Unknown classification fails closed before capture/transmission; respect secure surfaces, protect own sensitive windows. A universal safe classifier is not demonstrated: MediaProjection remains OFF until leak-negative proof, per-session consent and independent legal/Play approval. DeviceOwner status is no privacy bypass.
- STANDARD cannot promise app suspension, anti-uninstall or universal background sensor startup. Optional genuine managed DPC enrollment/reset/exit is separately unresolved; no provisioning/lock/wipe is authorized here.
- Live/history/usage/media need independent India child-purpose review; Google Sign-In authenticates an adult, not parenthood. Exact-child accepted invitation/grant is the design, **no Family Link API dependency**. Final processor/hosting region and transfer/economics are deployment decisions, not prerequisites for synthetic documentation work.

### Commercial wording that must survive all forms

Prepaid/manual renewal **only**. Public **₹99/month / ₹999/year** per paid child; founding **₹50/month / ₹500/year** for first **1,008** distinct successfully paying families. One **48h** family trial, no auto-conversion. Free reduced adaptive location and last **six hours visible history**, not unlimited retention. One included premium viewer per active paid child, optional **₹100 once / 100 days / +30 combined audio-video minutes**; dormant on base lapse, original day-100 expiry unchanged. Payment never grants guardian scope or Android permissions. Store's technical term “prepaid subscription” must not be rewritten as auto-renew; choose/confirm actual eligible products in sandbox. Existing trial/paid media allocations remain conditional/OFF, not a promise of media availability.[16]

### Submission acceptance (still open)

Use the complete **P01–P20** and **C01–C20** independent [reviewer checklists](PLAY_CONSOLE_DECLARATIONS_AND_REVIEWER_PACK.md), [Data Safety rows DS01–DS18](DATA_SAFETY_WORKSHEET.md) and [91-row feature assessment](../../M1-secure-platform-foundation/03-security-and-permissions/ANDROID_COMPATIBILITY_MATRIX.md). Required record per package: exact candidate SHA/version/manifest/SDKs, enabled inventory rows, actual device results, public URLs, redacted reviewer video/access steps, declaration answers/IDs, account testing outcome, India legal/privacy/security signoffs, owner submission authorization and actual Play result. **No release-ready count or PASS is asserted.**

### Official sources (retrieved 2026-10-30)

## Sources

[1] https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
[2] https://developer.android.com/develop/background-work/services/fgs/service-types
[9] https://support.google.com/googleplay/android-developer/answer/9888380
[10] https://support.google.com/googleplay/android-developer/answer/9893335
[11] https://support.google.com/googleplay/android-developer/answer/11926878
[12] https://support.google.com/googleplay/android-developer/answer/9799150
[13] https://support.google.com/googleplay/android-developer/answer/10787469
[14] https://support.google.com/googleplay/android-developer/answer/13327111
[15] https://support.google.com/googleplay/android-developer/answer/14151465
[16] https://developer.android.com/google/play/billing/subscriptions
[17] https://support.google.com/googleplay/android-developer/answer/13393723
[18] https://support.google.com/googleplay/android-developer/answer/12955211
[26] https://developer.android.com/guide/practices/page-sizes
[29] https://support.google.com/googleplay/android-developer/answer/13628312
[30] https://support.google.com/googleplay/android-developer/answer/16260648?hl=en

---

## Retained detailed preparation guidance (current direction above takes precedence)

**Madalasa–Alarka | 2026-10-25 | Draft only — not a publication approval**

Applies separately to a parent client and a child agent if distributed as separate packages. Final answers must be based on the **actual shipped manifests, SDKs, backend behavior and every active Play track**.

## 1. Critical go/no-go conditions

1. **New standard Android apps/updates target Android 16, API 36+, from August 31, 2026** (specialized form-factor exceptions and extension arrangements are separate). Verify again at submission.
2. **Monitoring apps must be exclusively positioned for parental child monitoring or permitted enterprise management.** Display recognizable icon, clear tracking disclosures and a persistent notification while the app runs; do not cloak monitoring. Declare `isMonitoringTool` with `child_monitoring` value in each child-monitoring build on every Play track. Check exact manifest placement against current Android manifest documentation at build time.
3. Camera, audio and other sensitive capabilities may be technically conditionally possible, but **will not be shipped until the supported user-visible behavior and actual Play policy review have been satisfied**. Do not offer alternate noncompliant APK links from the listing or application.
4. Background location is a sensitive core feature; Play requires prominent in-app disclosure, a background location declaration and demonstration video when required, and a matching privacy policy.
5. If a parent account can be created, provide account deletion from within the app **and through a working web deletion-request URL**.
6. Complete accurate Data safety declarations, target audience, ads, access/reviewer instructions and permissions/foreground-service forms applicable to the final app.
7. Because the app contains native C++, validate 16 KB memory page size support on 64-bit devices and packaged native libraries.
8. Use Play Billing for paid digital capabilities sold in a Play-distributed Android app where the policy requires it; validate purchases server-side.

## 2. Application/package separation

| Package | Purpose | Suggested distribution |
|---|---|---|
| Parent app | Maps, reporting, controls and subscription | Standard Play listing |
| Child agent | Parentally configured monitoring and permitted device controls | Separate explicitly declared monitoring application; distribution path must pass Play review |
| Managed DPC variant | Fully managed device policies via explicit provisioning | Investigate appropriate device-management/enterprise distribution and Play eligibility separately; do not assume a consumer install can acquire device-owner authority |

Each application needs its own final package name, signing configuration, store listing, permissions, Data safety answers and policies where Play treats them separately.

## 3. Manifest and permission declaration worksheet

**Do not copy all permissions into an app. Include only permissions used by a released feature.**

| Capability | Android declaration / access to investigate | Play review / condition |
|---|---|---|
| Foreground / background location | `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`, `ACCESS_BACKGROUND_LOCATION` as justified | Permission timing and prominent disclosure; background location form and video |
| Location foreground service | `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, service type `location` where appropriate | Foreground-service type declaration and actual use-case demonstration as required |
| Notifications | `POST_NOTIFICATIONS` runtime permission on relevant versions; notification channel | Persistent monitoring notification must not be hidden; handle denial coherently |
| Usage access | `PACKAGE_USAGE_STATS` special access via Settings | Explain use clearly and map app activity to Data safety |
| Installed app visibility | Narrow `<queries>` where possible, possibly `QUERY_ALL_PACKAGES` only with a documented eligible core use | Broad package visibility is restricted and requires declaration/review when applicable |
| App suspension | DevicePolicyManager with valid device owner/profile owner/delegate state | Correctly provisioned DPC; ordinary permission onboarding is not sufficient |
| Photo/video | `CAMERA`, possible camera foreground-service type and related FGS permission only for a supported release workflow | Lifecycle/while-in-use restrictions, clear indication, permission disclosure; feature stays deferred without approval |
| Audio recording | `RECORD_AUDIO`, possible microphone foreground-service type and permission only for a supported release workflow | As above; no hidden, unannounced capture |
| Local media/files | MediaStore/SAF access and modern photo picker as appropriate | No arbitrary private app storage |
| Network | `INTERNET`, network state only if actually required | Encrypt transport; list third-party SDKs and data recipients |

**Monitoring flag candidate (verify exact position during manifest integration):**
```xml
<meta-data android:name="isMonitoringTool"
           android:value="child_monitoring" />
```
This alone does **not** certify compliance. Every version code on every active testing/release track must reflect the actual monitoring design.

## 4. Background location permission declaration package

**Core-feature rationale draft:**
“Madalasa–Alarka is a parent-configured child location history and safety application. Background location is needed to record journeys and update a parent's last-known location while the child-side setup screen is closed. Without background access, route history would have substantial gaps and location updates would be limited to the setup screen.”

**Draft prominent in-app disclosure** (validate exact shipped language):
“Madalasa–Alarka collects location data to provide your parent or guardian with your last reported position, travel history and movement alerts, including when this app is closed or not in use. Location reports are securely sent to the paired parent account. You can review monitoring information in Madalasa–Alarka and Android settings.”

Review the wording with legal/policy advisers for child audience and the actual feature list. Show this disclosure in the child app **before** requesting location permission, not solely in Terms or the privacy policy.

**Reviewer video storyboard** (record real device later):
1. Show named Madalasa–Alarka child app and prominent disclosure in normal onboarding.
2. Show Android permission and background-location setup.
3. Show monitoring notification.
4. Close the child setup Activity; move between test coordinates on test device.
5. Show the parent app's latest location/history and timestamps.
6. Provide a public/test-viewable unlisted video URL and exact test credentials or demo instructions; no fabricated evidence.

## 5. Play Console app content submission inventory

For **each** Play-distributed package, complete as applicable:
- App name, category, short/full description, high-resolution icon, feature graphic, appropriate screenshots and localization.
- Contact email, developer legal identity, published privacy policy URL, account deletion web URL.
- Ads declaration; in-app purchases/subscription settings; countries/pricing; content rating questionnaire.
- Target audience and applicable Families policies; parent-versus-child audience must be accurately described.
- Data safety questionnaire (collected/shared categories, encryption in transit, optional/required, deletion).
- App access / reviewer test credentials, pairing workflow and any hardware requirements.
- Background location declaration and short demonstration video.
- Foreground service declarations, high-risk permissions, package visibility declarations or other forms that the Console displays.
- Monitoring `isMonitoringTool=child_monitoring` where appropriate, non-cloaked UI/notification and transparent listing.
- Release signing, AAB upload, Play App Signing, software supply chain/SBOM review.
- Internal testing, closed testing and a production review, staged rollout and policy appeal/response process.

For personal developer accounts created **after November 13, 2023**, the currently documented production-access gate includes a closed test with **at least 12 opted-in testers for 14 continuous days**. Verify whether your actual developer account is subject to this requirement; do not assume exemption or completion.

## 6. Data safety prerequisites

Data safety must be generated from **the final binary and every SDK, service and backend**, not from a marketing aspiration. Relevant categories may include:
- Precise/approximate location and location history.
- App activity / installed apps / interaction events.
- Device identifiers, diagnostics, crash data.
- Parent identity and email/authentication IDs.
- Photos, videos and audio **only if the final released feature collects/transfers them**.
- Purchase/subscription metadata (not card numbers if processed exclusively by Play).
- Sharing with providers/processors and the parent recipient; classify “sharing” according to Play's exact definitions, not assumptions.

Use the [Data safety worksheet](DATA_SAFETY_WORKSHEET.md) for line-item review.

## 7. Native and build compliance

- `compileSdk`, `targetSdk >= 36` for current new/updated phone apps, tested Gradle/AGP and NDK revisions.
- `minSdk` selected from support matrix (proposed 29, not finalized).
- Rebuild native `.so` libraries with 16 KB page compatibility; verify ELF load alignment, zip packaging and tests in a 16 KB emulator/device.
- Reproducible builds, deterministic version codes, signed AAB, Play App Signing; protect upload key.
- Review imported SDKs for Play SDK Index warnings, dependency vulnerability reports and unintended data collection.

## 8. Privacy policy, deletion and user support

Public URLs must exist and be accessible without logging in:
- Privacy policy: specific entity/company, app name, feature/data collection, recipients, retention, security, contact and rights.
- Account deletion: clear request path, authentication/verification where justified, associated-data deletion and disclosed legally necessary exceptions.
- Support: real email/contact and dispute/refund instructions.

Drafts are in [Privacy policy](../02-public-legal-drafts/PRIVACY_POLICY_DRAFT.md) and [Data safety worksheet](DATA_SAFETY_WORKSHEET.md). **They are not ready for publication** until operator identity, actual retention, hosting, SDKs and release behavior are confirmed.

## 9. Store-listing draft guardrails

Use accurate descriptions like “Parentally configured family location history and app usage reports.” Explicitly describe monitoring and limitations. Do not claim “invisible,” “undetectable,” “remote listening without any indication,” or “works on every Android phone.” Avoid claims of universal blocking.

Create screenshots only from a real release candidate. List supported device requirements and managed enrollment restrictions. Provide reviewers a working sandbox/demo account and paired test device flow.

## 10. Release go/no-go checklist

- [ ] Parent and child binaries actually exist and build as AABs.
- [ ] Every manifest permission has justification and tested corresponding feature.
- [ ] No forbidden covert capture or cloaking.
- [ ] Monitoring identification, notification and disclosure verified on child device.
- [ ] Target API 36+ and native 16 KB page-size compatibility confirmed.
- [ ] Data safety matches the app, SDKs, backend and released feature flags.
- [ ] Privacy and account deletion URLs are public and operative.
- [ ] Play Billing **manual prepaid** purchase/top-up/expiry/refund integrated and server-validated; no automatic renewal.
- [ ] Background-location demo video and declarations ready.
- [ ] Reviewer onboarding and app access instructions tested.
- [ ] Functional and device matrix tests passed.
- [ ] Security/privacy/retention review signed off.
- [ ] Required testing-track/production-access prerequisites fulfilled.
- [ ] Play Console review approved, with no unresolved policy notices.

## Official sources

- Target SDK: https://support.google.com/googleplay/android-developer/answer/11926878
- Monitoring apps: https://support.google.com/googleplay/android-developer/answer/9888380
- Monitoring flag: https://support.google.com/googleplay/android-developer/answer/12955211
- Background location: https://support.google.com/googleplay/android-developer/answer/9799150
- App review: https://support.google.com/googleplay/android-developer/answer/9859455
- Account deletion: https://support.google.com/googleplay/android-developer/answer/13327111
- 16 KB page sizes: https://developer.android.com/guide/practices/page-sizes
- Closed testing: https://support.google.com/googleplay/android-developer/answer/14151465


## Separate named Play packages

**Madalasa** is the parent/guardian app and **Alarka** is the identifiable child companion. Prepare separate package IDs, launcher strings, listings, review scripts and Data Safety declarations; verify package IDs only after publisher/domain selection. Subscription or Google authentication does not prove lawful custody.

## 2026-10-26 Critical new Play Families location restriction and child app gate

**Read [MA-COMPLIANCE-001](../../M0-foundation-and-approvals/03-legal-and-privacy/INDIA_GOVERNMENT_LEGAL_GOOGLE_PLAY_PROJECT_RISK_ASSESSMENT_2026.md) before submitting either package.** Official [Google Play Families Policy](https://support.google.com/googleplay/android-developer/answer/9893335?hl=en) states **apps solely targeted to children cannot request location permission or collect/use/transmit precise location**. Alarka is a child-installed monitoring companion; the [Play monitoring-app exception](https://support.google.com/googleplay/android-developer/answer/9888380?hl=en) and [isMonitoringTool flag](https://support.google.com/googleplay/android-developer/answer/12955211?hl=en) **do not, by themselves, provide a verified exemption** from that Families restriction. Product owner must obtain an actual Play policy clarification on truthful target audience and permissible Alarka functionality **before committing the child GPS Play business model**. Do not misdeclare ages, conceal monitoring or sideload a noncompliant alternate APK. Even favorable Play treatment does not solve Indian DPDP child legal purpose; and Android permission grants do not bypass background restrictions. No real-minor pilot or child GPS submission until these gates pass.

## 2026-10-26 conditional media research is not Play approval

The owner wants to study conditionally executable microphone listening/recording, camera view/photos/video, flash-off captures, scoped files, and MediaProjection with per-session consent. The Alarka main Activity should remain closed after setup during routine valid operation; Alarka must still have a recognizable icon, persistent monitoring notification and Android camera/microphone indicators. Ordinary initial permissions do not universally permit new background sensor startup; genuine device-owner FGS exception remains to be tested. Never disguise capture, suppress indicators, or publish a bypass APK.

Parent Madalasa must explain an unavailable action with a **verified runtime reason**, not hide refusal or pretend success. Child/guardian authorization and notice, target audience/Families review, DATA SAFETY truthfulness, media-specific manifest/FGS declarations, effective Indian child-data permission and final Google Play clearance remain prerequisites. Do not ship CAMERA/RECORD_AUDIO runtime paths, list a media feature as available, or advertise "always available listening" until the separate gated review passes. Encrypted P2P/no VPS recordings does not eliminate personal-data processing. Research [MA-MEDIA-ADR-001](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md); T-MEDIA-01–18.

## 2026-10-27 progressive permission onboarding and compatibility UI

The owner requests a **read-only device compatibility scan** at first Alarka launch and a separate explained step for each legitimate Android grant. Google Play permission/target-audience restrictions still apply: no automatic capture, no coercive request for all permissions, no sensitive permission requested without corresponding actually approved core function, no hidden app identity, no pre-granted MediaProjection, no permission-bypass APK. Permission rationale is in-app, **OS dialog/Settings/Photo Picker/SAF owns the actual approval**, and Alarka verifies it after returning. Android 11+ foreground and background location grants are separate steps; one-time mic/camera/location grants can expire. Parent UI may show granted only after device-verified report and server ACK; granted does not mean remotely accessible without compliant sensor lifecycle.

Before launching any relevant feature or even reporting real child feature data, complete the exact India age/purpose/guardian legitimacy and Google Play Families/background location/monitoring/notification/permission declarations/reviewer evidence. A compatibility checklist cannot replace explicit personal data disclosure. Keep FR-009/010 media behind disabled release flags even if Alarka detects camera/mic hardware. [MA-CAP-ADR-002](../../M1-secure-platform-foundation/03-security-and-permissions/CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md) and [46 Figma screens](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=23-2) are prototypes only.

## 2026-10-27 design of logged media activity and parent/admin transparency (no release approval)

If eligible child-monitoring media operations are eventually approved, capture requires Android system safeguards, recognizable Alarka app identity, required monitoring disclosure, indicator/notification and properly permitted session. The separate metadata logger records attempted/actual actions and verified outcomes **without storing content on VPS**. Parents will receive an own-family event history with date/child/media filters; backend logs its authorized processing. **Administrator panel is not a stealth media retrieval portal**: MFA/case-bound child scopes, restricted autocomplete and separate admin access audit; ordinary support cannot browse named child activity.

For Play and India review provide actual disclosure showing data categories, purposes, retention, parent recordings and child rights; no 'zero stored user data' marketing claim. Neither Figma screens nor a granted microphone/camera permission prove that any media feature is eligible for Play distribution. FR-009/010 and new FR-050/051 stay P3 research/flag OFF until counsel, Play, OS hardware tests and security authorization. [Media Activity Audit ADR](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_ACTIVITY_AUDIT_LOGGING_AND_REPORTING_2026.md).

## 2026-10-27 adaptive GPS offline queue and server inbox release policy

New engineering design [MA-INGEST-ADR-004](../../M2-location-collection/01-location-collection-and-ingestion/POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md) uses adaptive child-device GPS callbacks, **encrypted local up-to-48h offline capacity**, best-effort 1–2-minute uploads within a legitimately allowed Android service context, and sensitive GPS batches in a *temporary* PostgreSQL durable inbox. This does not give a standard background Android app an exemption from background-location/FGS restrictions or WorkManager 15-min periodic minimum. Parent Live Tracking and detailed historical location require an explicit approved purpose and truthful foreground service/monitoring disclosures; Android privacy notifications are never concealed. GPS history and app-usage monitoring each require **independent** Google Play/India DPDP child-data permissions and review. Server buffering/data ingestion technology does not grant permission to collect child behavioral data. No real Indian-minor location/usage pilot or Play-approved tracking claimed. Detailed burst/offline, disclosure and child-deletion tests T-ING-01…24 NOT_RUN.
