# X-02 / G01 + G04 — Google Play Families, Child Monitoring and Background Location

> **Control:** M9 / Google Play and data safety · **Date:** 2026-10-31 · **Status:** ENGINEERING/POLICY PREPARATION COMPLETE; **EXTERNAL PLAY ELIGIBILITY OPEN** · Authoritative approval: **NONE** · Audience: **not finalized or Play-accepted** · Signed Android app/reviewer video: **NOT YET AVAILABLE**.
>
> **Scope:** Madalasa guardian Android app and Alarka installed on a child's Android device. India-first, intended children ages 0–17. Publisher's Google Play identity is owner-confirmed COMPLETE; BillDesk verification remains submitted and awaiting a response. Merchant setup and app release are separate from this policy.

## 1. Key outcome — no invented policy waiver

**G01 must be decided before G04.** The [Google Play Families policy](https://support.google.com/googleplay/android-developer/answer/9893335) explicitly says: **apps solely targeting children may not request location permission or collect, use or transmit precise location**. Its further restrictions on sensitive child data include device identifiers and camera/microphone sensor data.

The [Monitoring Applications policy](https://support.google.com/googleplay/android-developer/answer/9888380) permits *exclusively designed and marketed* parental monitoring (or qualifying enterprise management) with prominent disclosure, identifiable icon, persistent notification while running, no stealth, and appropriate \`isMonitoringTool\` designation across all tracks. That policy **does not say it overrides the Families location restriction**. Parent-granted Android runtime permissions, an \`isMonitoringTool=child_monitoring\` flag, a genuine parent account, a managed device, P2P encryption, or an India DPDP real-time child-safety-purpose exception **do not independently settle Play's audience/location classification**.

**Product-specific uncertainty:** Whether the separately packaged Alarka app, truthfully described with its child-device role and actual audience, can qualify for a Play-permitted classification that allows the proposed precise child GPS. The fact that the **device user is a child** does not itself conclusively determine the app's Play *target audience*; nor may its target-audience answers be engineered to evade Families restrictions. The parent companion's adult audience cannot silently be imputed to Alarka. Require the actual human Play response or an eligible reviewed Play outcome for the precise package/behavior.

**G04 remains separately required even if G01 is favourable.** [Play background-location policy](https://support.google.com/googleplay/android-developer/answer/9799150) restricts access to significant user benefit and core functionality; requires distinct permission declaration/review when applicable; and says apps designed for children must also follow Families policy. “Safety” is a potential relevant benefit, **not an automatic permission grant**.

## 2. Current external status and what is NOT being requested again

| Gate | 2026-10-31 status | Evidence accepted to close |
|---|---|---|
| **X-02/G01: child-app target-audience + precise GPS** | **OPEN / human policy determination pending**; owner previously consulted a Google Play Console AI assistant, which is NOT a policy-team ruling. Existing support case is already created; the owner reported that its submitted text cannot be edited. **Do not create duplicate messages or imply a response has arrived.** | Case-linked explicit human Play policy outcome for actual separate Madalasa/Alarka packages, intended users, Families applicability and proposed child location; or documented outcome from review of the actual eligible build. Screenshots/case IDs stored in private evidence only |
| **X-02/G04: background location** | **OPEN / not submitted or approved**; further to G01. | App Console \`App content → Sensitive app permissions → Location permissions\` form, **one** strongest background-location core feature, suitable working app build, in-app disclosure, privacy URL, real short video, valid review access, approved permission outcome |
| **Monitoring designation** | **DESIGN DOCUMENTED / not build-verified** | Actual child app icon/notification/listing, package manifest metadata \`isMonitoringTool\` (per actual policy), compiled versionCode/track audit, stop/revoke, disclosures and review |
| **Android location compatibility** | **NOT DEVICE TESTED** | Distinct foreground/background grants, allowed FGS service state, user Settings flow, denial, accurate last fix, Doze/OEM/force-stop and real devices |
| **Indian child-data legality G02/X-03** | **Primary-law desk review documented, feature-specific assessment still OPEN** | Documented lawful purpose, consent/guardian authority where applicable, proportionate data categories/retention and launch controls; no universal paid lawyer's opinion required |
| **AAB/actual Play artifact** | **NOT PRESENTED/NOT REVIEWED** | Real signed package ID, target SDK, manifest review, permissions, listing, live app/video/reviewer credentials through approved channels |

No Play Console submission, government email, support-ticket alteration, developer-login, paid step or release is undertaken by creating this document. Existing MeitY/Tele-Law/LegalMeet requests are unrelated to Google Play's decision.

## 3. Decision path for Alarka

1. **Truthfully inventory audience** of each distinct Android package: who installs it, opens it after setup, grants permissions, interacts with alerts/consent and sees monitoring notices. Parent typically configures, but child/device user may also interact; do not invent adult-only usage.
2. **Obtain G01 policy result for Alarka**: if Play confirms proposed package/audience/location is **ineligible**, **do not ship that combination via Google Play**, even with parental permission or a foreground service. Remove location permissions, exact-precision collection and dependent product claims from the Play build, or redesign and seek a new genuine policy assessment. Do **not** use misleading audience labels, a Play-store link to an alternate non-compliant APK, or covert capture.
3. If G01 is **affirmatively eligible**, proceed to **G04** background-location necessity test: could a genuinely foreground interaction meet the child-safety feature? Background location only if necessary to the prominent core safety value, with precise purpose/retention constraints; disclose all background uses.
4. Independently satisfy Android compatible location start lifecycle, guardian-child permission/grant, real India data-purpose compliance, full Data Safety, public policy, deletion and consent. Approval of one gate cannot waive another.
5. If G01/G04 result remains **ambiguous**, status stays POLICY_UNRESOLVED; use only synthetic or authorized adult-owned engineering fixtures. Do not promise child GPS or launch a paid product based on unconfirmed location eligibility.

**Important:** The contemplated P2P WebRTC DataChannel, background foreground service, push/FCM, device-owner DPC, encryption and app-to-app architecture do not change Families policy's restrictions on *requesting permissions and processing precise location*. Do not refactor transport as a purported compliance workaround.

## 4. Prepare once — disclosure, declaration and review artifacts

### Child app audience/monitoring evidence worksheet

- App's actual installer/user/parent/child interactions and purpose on each screen. Never mark adult-only solely to avoid Families rules.
- Exact Manifest \`uses-permission\` list for every active App Bundle and testing track; presence of \`ACCESS_FINE_LOCATION\`/\`ACCESS_COARSE_LOCATION\`/\`ACCESS_BACKGROUND_LOCATION\`, typed location FGS, and third-party SDK access; deny nonessential permissions.
- Recognizable Alarka name/icon/launcher, clear monitoring purpose in app/store; persistent notification while monitoring app runs per Play monitoring policy, OS-level permission revocation and child-device Stop/unpair where legitimately supported.
- Scope parent device separately: Madalasa only *receives/renders* the child's data; this does not by itself require the parent's own \`ACCESS_FINE_LOCATION\`.
- Exact child-safe onboarding, guardian authority and consent statements, no sale of location and no behavioral-use expansion by default.
- Existing Google Play human support case reference as private evidence, not in public Markdown. Preserve complete response; avoid re-asking an already submitted question unless policy team invites clarification.

### Proposed G04 background-location core-feature declaration — *DRAFT ONLY, NOT READY FOR CONSOLE*

**Single selected primary feature for evaluation:** "Child-safety location availability to a verified guardian while the child companion is not being actively used." This is a product description, **not** a representation that Play has accepted it. Other background uses (history, route reconstruction, geofence, paid analytics) must still be disclosed accurately in the app and policy; they do not all belong in the form's *single feature* answer. **Do not submit until exact G01 eligibility and a working matching build have been evidenced.**

Required real evidence under Google's instructions:
1. Why **this core feature** cannot be provided adequately by foreground-only access and what physical-safety benefit it delivers; identify any operation that can instead be foreground.
2. Prominent **on-device disclosure before Android runtime permission**, stating location and "when the app is closed or not in use", naming *every actual background-location use* and disclosure/recipient categories. Clear affirmative consent and Android's actual separate background grant where required.
3. Public valid privacy-policy **HTML page** in the app and store listing, naming the developer/app correctly and documenting collection, data sharing/processor, retention, deletions and contact.
4. Short **real Android video** showing the final actual signed app, prominent disclosure, OS grant workflow, functionality while Alarka is minimized, persistent notification, parent visible location and an honest offline/revoked status. No simulated UI/Figma footage passed as real proof. Record build SHA, package, device, API, date and unredacted reviewer view only in approved private channels.
5. Reviewer credentials/access through owner-controlled Console fields; at least two synthetic families to test exact-child isolation, no actual child data or fake successful login.
6. Approved final location-permission declaration under **Policy → App content → Sensitive app permissions → Location permissions**. Google can reject the declaration; do not claim automatic review success from a submitted form.

Source for checklist/form: [Google official background-location guidance](https://support.google.com/googleplay/android-developer/answer/9799150).

### Actual release feature boundaries, unless separately permitted

| Feature | Play research state | First Play AAB default |
|---|---|---|
| Parent app maps showing *synthetic* test fixtures | Parent app itself may avoid child-device location permission; actual data retrieval requires scope | No real-child data |
| Alarka precise location / location in background | **G01 + G04 UNSOLVED** | **No real-child collection, no permission in a release that is not Play-eligible** |
| General child history, geofence/usage inference | Families and Indian-law purposes separately unresolved | OFF |
| Microphone/camera and screen projection | Media capability research only; dedicated sensitive sensor and screen permission review not satisfied | OFF; exclude unreleased runtime permissions/types |
| Basic account setup, non-sensitive compliance pages and synthetic tests | Independently developable | Engineering work can proceed |

## 5. Measurable evidence / no-false-PASS cases

- **T-X02-01**: enumerate real \`Alarka\` app audience and distinguish it from \`Madalasa\` parent audience; no misleading target-age answers.
- **T-X02-02**: preserve official Play Families + Monitoring + background location policy citations and human response status; no AI support text as approval.
- **T-X02-03**: deny release build requesting unapproved precise GPS / background permissions; scan *all active tracks* and dependencies for flags/permissions.
- **T-X02-04**: actual prominent disclosure before runtime permission, all actual background uses stated, privacy URL valid, listing consistent.
- **T-X02-05**: real Android demonstration of OS background grant, persistent notice and verified guardian-view location, with offline/revoked/force-stop negative cases.
- **T-X02-06**: signal/FCM and role-based pairing do not bypass Google Play access decisions or Android runtime eligibility.
- **T-X02-07**: correct \`isMonitoringTool\` metadata and no hidden functionality/off-Play noncompliant APK links.
- **T-X02-08**: per-package human Play review status G01 then G04, immutable linked build, case/decision date and accountable release owner.
- **T-X02-09**: no production real-child precise GPS / paid location marketing if policy classification or permission review remains unresolved.
- **T-X02-10**: review remains blocked by missing actual signed AAB, tested disclosure/video, owner-supplied Console result, Indian scope/retention and physical test evidence.

All tests **PLANNED / NOT EXECUTED**. Source-policy review **DOCUMENTED** does not equal Google policy eligibility verification.

## 6. Human response decision capture template (PRIVATE evidence)

\`case_reference\` (private), \`package_under_review\`, \`declared_actual_audience\`, \`play_policy_reply_date\`, \`decision_maker_and_channel\`, \`verbatim_scope\` (private), \`families_applies\`, \`precise_location_allowed\`, \`background_location_declaration_required\`, \`separate_approval_received\`, \`feature_eligibility\`, \`limitations\`, \`reviewed_build_version\`, \`link_to_private_evidence\`. **Do not guess or publish case IDs, screenshots, real children's data, Google credentials or lawyer consultation details.**

## 7. Source precedence and related project records

Official Google sources are primary for Play requirements: [Families policy](https://support.google.com/googleplay/android-developer/answer/9893335), [Monitoring Applications](https://support.google.com/googleplay/android-developer/answer/9888380), [\`isMonitoringTool\` flag](https://support.google.com/googleplay/android-developer/answer/12955211), [Background location declaration](https://support.google.com/googleplay/android-developer/answer/9799150). A Google Play Console **AI-generated** answer is advisory, not eligibility approval, and a support case existing is not a favourable decision.

Internal: [M9 reviewer pack](PLAY_CONSOLE_DECLARATIONS_AND_REVIEWER_PACK.md), [Play publishing requirements](GOOGLE_PLAY_PUBLISHING_REQUIREMENTS.md), [Indian child law assessment](../../M0-foundation-and-approvals/03-legal-and-privacy/INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md), [Android compatibility matrix](../../M1-secure-platform-foundation/03-security-and-permissions/ANDROID_COMPATIBILITY_MATRIX.md), [Blocker register](../../M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md).
