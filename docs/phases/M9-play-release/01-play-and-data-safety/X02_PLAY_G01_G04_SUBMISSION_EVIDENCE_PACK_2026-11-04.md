# X02 — Google Play G01 (Families/location) + G04 (background location) Submission Evidence Pack

> **Control:** M9 / Google Play · **Document state:** PUBLISHED DRAFT, REVIEW PENDING, NOT SUBMITTED · **Play status:** G01 **OPEN / NOT DECIDED**, G04 **NOT SUBMITTED / NOT APPROVED** · **Authority:** NONE — no Google Play, legal, regulatory or Android approval exists or is implied by this document.
>
> **This is an engineering and evidence-preparation document, not legal advice.** It does not create permission to collect any real child's location, to publish to Google Play, or to ship a location permission. Every external item below is marked `EXTERNAL / PENDING` with the owner action required.
>
> **Provenance:** composed read-only from `origin/main` @ `b4b4c898fe4edc5acfee6dc2d12a2e8772d87bbb` (canonical docs) and `origin/api` @ `1bb3afc7d03a26f8f61be4031dab8b159e009a2d` (Android source). Working branch `api` was not modified, checked out away, merged or committed to.
>
> **What this pack is not:** it is not a Play Console submission, not a declaration answer set, not a reviewer video, not a signed build record, and not evidence that any policy question has been answered.

---

## 0. Read this first — the pack's own fail-closed status

| Question | Answer today | Evidence |
|---|---|---|
| Does either app request location **today**? | **No.** Both release manifests declare `INTERNET` only. | §2 verified manifest inventory |
| Can G01 or G04 be submitted today? | **No.** No location permission, no disclosure screen containing the required wording, no signed AAB, no working build, and G01 has no human Play outcome. | §2, §5, §8 |
| Is there a Play policy determination? | **No.** An existing owner support case is open; a Play Console AI answer is advisory only, not a policy-team ruling. | [X02 §1, §2](X02_FAMILIES_LOCATION_AND_MONITORING_POLICY_REVIEW_2026-10-31.md) |
| Does the free-first 108-child release create any Play entitlement? | **No.** It is a product/deployment cap, not a permission, and not proof the app is eligible. | [FREE_FIRST §Decision, §Capacity decision](../../../roadmap/FREE_FIRST_108_CHILD_RELEASE_ROADMAP_2026-11-03.md) |
| Is any item here approved by legal counsel? | **No.** `DRAFT_LEGAL_REVIEW_REQUIRED`; approval not recorded. | [Publishing requirements header](GOOGLE_PLAY_PUBLISHING_REQUIREMENTS.md) |

**Governing rule (fail-closed):** if G01 is not affirmatively eligible for the actual Alarka package/audience/location combination, the Play build must **not** request location and must **not** claim child GPS. Removing or redesigning the feature is required — not relabelling the audience. ([X02 §3](X02_FAMILIES_LOCATION_AND_MONITORING_POLICY_REVIEW_2026-10-31.md))

---

## 1. Packages in scope

| Package | Role in the product | Who installs / opens / grants permissions | Product age scope | Play target audience |
|---|---|---|---|---|
| **Madalasa** (parent/guardian) | Receives and renders the child's authorized location, guardian/privacy controls | Adult guardian | N/A (adult) | `PENDING` — must be declared truthfully; parent app must not be labelled merely to avoid Families rules |
| **Alarka** (child companion) | Runs on the child's device, would collect and upload location when activated | Guardian configures; **the device user is a child and may also open, read and acknowledge screens** | India, 0–17 inclusive (owner-decided product scope) | `PENDING` — **G01 question**; the device user being a child does not by itself settle target audience, and the audience must not be engineered to evade Families |

- Product age scope (0–17) is an **owner business decision**, not a Play classification and not a legal clearance. ([BLOCKERS §A B-02](../../M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md); [DECISION_LEDGER §B B-02](../../../roadmap/DECISION_LEDGER.md))
- Alarka is a **separately installable free app** with no purchases/billing dependency; activation is a separate state from installation, and pairing is necessary but not sufficient for monitoring. ([FREE_FIRST §"Child app is fully free"](../../../roadmap/FREE_FIRST_108_CHILD_RELEASE_ROADMAP_2026-11-03.md))
- The parent companion's adult audience **cannot be silently imputed to Alarka**. ([X02 §1](X02_FAMILIES_LOCATION_AND_MONITORING_POLICY_REVIEW_2026-10-31.md))

**Build identity as found in the repo (not a release candidate):**

| Field | Madalasa | Alarka |
|---|---|---|
| `applicationId` | `in.berhampore.madalasa.synthetic` — explicitly commented *"Non-production placeholder ID until publication authorization"* | `in.berhampore.alarka.synthetic` — same comment |
| `versionCode` / `versionName` | `1` / `0.1.0-synthetic` | `1` / `0.1.0-synthetic` |
| `compileSdk` / `targetSdk` / `minSdk` | 36 / 36 / 29 | 36 / 36 / 29 |
| App label | `Madalasa — synthetic demo` | `Alarka` |

Source: `android/madalasa/build.gradle.kts`, `android/alarka/build.gradle.kts`, `android/*/src/main/res/values/strings.xml` (branch `api`).

`EXTERNAL / PENDING` — **owner action:** confirm final release `applicationId`s and a monotonically increasing `versionCode` before any Console upload; the `.synthetic` IDs and `-synthetic` version names must never be the packages reviewed or published. Target API 36+ for new/updated phone apps must be re-verified at submission time ([Publishing requirements §1 item 1](GOOGLE_PLAY_PUBLISHING_REQUIREMENTS.md); [P04/C04](PLAY_CONSOLE_DECLARATIONS_AND_REVIEWER_PACK.md)).

---

## 2. Exact declared permission list (verified from the manifests)

**Method:** `git show origin/api:<path>` for all four `AndroidManifest.xml` files present under `android/`. No file was edited.

### 2.1 What the release manifests actually declare today

| File | Declared `uses-permission` | Other declarations |
|---|---|---|
| `android/madalasa/src/main/AndroidManifest.xml` | **`android.permission.INTERNET` only** | Comment: *"No location, audio, camera, usage or background monitoring grants in synthetic prototype."*; `allowBackup="false"`, `usesCleartextTraffic="false"`, one exported `MainActivity` (LAUNCHER) |
| `android/alarka/src/main/AndroidManifest.xml` | **`android.permission.INTERNET` only** | Comments: *"Zero covert capture…"*, *"Zero background monitoring or live location grants declared in synthetic prototype."*; `allowBackup="false"`, `usesCleartextTraffic="false"`, one exported `MainActivity` (LAUNCHER) |
| `android/madalasa/src/debug/AndroidManifest.xml` | none | Debug-only `.DesignPreviewActivity`, `exported="true"`, *"deliberately absent from release manifest"* |
| `android/alarka/src/debug/AndroidManifest.xml` | none | Debug-only `.DesignPreviewActivity`, `exported="true"`, same comment |

**Explicitly absent** from both release manifests and therefore from any release AAB built from them:

- `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`
- `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, any typed FGS permission
- `POST_NOTIFICATIONS`
- `PACKAGE_USAGE_STATS`, `<queries>`, `QUERY_ALL_PACKAGES`
- `CAMERA`, `RECORD_AUDIO`, `FOREGROUND_SERVICE_CAMERA`, `FOREGROUND_SERVICE_MICROPHONE`
- `<meta-data android:name="isMonitoringTool" …>` — **not present in either manifest**

**Consequence:** a release AAB built from the current tree is a **non-monitoring, internet-only** app. It cannot be submitted for G01/G04 as a location app, and it also cannot yet carry the monitoring designation that Play's monitoring policy expects of the actual product. This is a build-state finding, not a compliance finding.

### 2.2 Target permission set — required **only if** the location feature is ever approved

The following is the working declaration set the repo already specifies. Each permission is conditional; none is authorized today.

| # | Permission | Madalasa (parent) | Alarka (child) | Why it would exist | Play form / gate | Status |
|---|---|---|---|---|---|---|
| 1 | `android.permission.INTERNET` | **required** (declared) | **required** (declared) | Authenticated HTTPS to the backend | Normal permission; Data safety network answers | `DECLARED` |
| 2 | `ACCESS_COARSE_LOCATION` | **not required** to render a child map | required for approximate fixes | Approximate child position | Location permissions declaration + G01 | `NOT DECLARED / GATED` |
| 3 | `ACCESS_FINE_LOCATION` | **not required**; only if a separate own-location recenter is ever enabled | required for precise child position | Precise child safety location | G01 eligibility first, then G04 | `NOT DECLARED / GATED` |
| 4 | `ACCESS_BACKGROUND_LOCATION` | **do not copy from child manifest** | required only if background collection is approved | Location while Alarka is closed / not in use | G04 separate declaration + review | `NOT DECLARED / GATED` |
| 5 | `FOREGROUND_SERVICE` | only if a parent-side FGS type is actually used | required with a typed location FGS | Keep a visible location service running | FGS type declaration | `NOT DECLARED / GATED` |
| 6 | `FOREGROUND_SERVICE_LOCATION` | no | required with `android:foregroundServiceType="location"` | Typed location FGS | FGS use-case form + demo | `NOT DECLARED / GATED` |
| 7 | `POST_NOTIFICATIONS` | if parent notifications ship | **required** — the persistent monitoring notice is the non-stealth guarantee | Visible, ongoing monitoring disclosure | Notification permission/channel behaviour | `NOT DECLARED / GATED` |
| 8 | `PACKAGE_USAGE_STATS` (special access, not a runtime permission) | no | only if app-usage reporting ships | Behavioural monitoring — separately gated | Usage-access justification; India purpose review | `OFF / HIGH-RISK` |
| 9 | `<queries>` narrow; `QUERY_ALL_PACKAGES` only with a documented eligible core use | no | only if usage reporting ships | Installed-app visibility | Package-visibility declaration where applicable | `OFF` |
| 10 | `CAMERA`, `RECORD_AUDIO`, camera/mic FGS types | no | **must remain absent** | SOS media is `CONDITIONAL / OFF` | Dedicated sensor + FGS review | `OFF` |

Sources for the target set: [Publishing requirements §3 manifest worksheet](GOOGLE_PLAY_PUBLISHING_REQUIREMENTS.md); [P07/P08](PLAY_CONSOLE_DECLARATIONS_AND_REVIEWER_PACK.md) (parent needs no own location grant merely to render a child's map); [C06/C07/C08/C09/C10/C11](PLAY_CONSOLE_DECLARATIONS_AND_REVIEWER_PACK.md); [free-first feature boundaries](X02_FAMILIES_LOCATION_AND_MONITORING_POLICY_REVIEW_2026-10-31.md) §4.

**Rule:** include only permissions used by a released feature; deny non-essential permissions; scan **all active tracks and dependencies** for flags/permissions, not just the main manifest ([Publishing requirements §3 intro](GOOGLE_PLAY_PUBLISHING_REQUIREMENTS.md); T-X02-03).

`EXTERNAL / PENDING` — **owner action:** none at this step. **Engineering action (blocked on G01):** do not add location permissions to a release manifest before a favourable human G01 outcome; the `synthetic` flavours are the only sanctioned place for this work.

---

## 3. Audience declaration worksheet

| Field | Required answer posture | Current state | Source |
|---|---|---|---|
| Alarka target audience | Truthful description of who installs, opens after setup, grants permissions, sees notices | **Not drafted for Console**; G01 question is precisely this | [X02 §3.1](X02_FAMILIES_LOCATION_AND_MONITORING_POLICY_REVIEW_2026-10-31.md), [C01](PLAY_CONSOLE_DECLARATIONS_AND_REVIEWER_PACK.md) |
| Madalasa target audience | Adult guardian; must still be a genuine audit of content/flows/SDKs, not a policy dodge | Not drafted | [P01](PLAY_CONSOLE_DECLARATIONS_AND_REVIEWER_PACK.md) |
| Console age buckets vs product age scope | Console buckets ≠ the product's India 0–17 legal scope; do not add older buckets to escape Families | Not resolved | [C01](PLAY_CONSOLE_DECLARATIONS_AND_REVIEWER_PACK.md) |
| Mixed-audience claim | Only if the app **genuinely** serves that mixed audience; never manipulated to bypass policy | **Prohibited as a tactic** | [BLOCKERS §2026-10-30 G01/G04 AI guidance](../../M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md) |
| Is Alarka "solely targeting children"? | Unresolved — this is the G01 determination, not a drafting choice | **OPEN** | [X02 §1](X02_FAMILIES_LOCATION_AND_MONITORING_POLICY_REVIEW_2026-10-31.md) |
| Monitoring designation (`isMonitoringTool=child_monitoring`) | Where required, correct metadata on **every** active track; does **not** waive the Families location restriction | **Absent from manifest**; "DESIGN DOCUMENTED / not build-verified" | [X02 §2](X02_FAMILIES_LOCATION_AND_MONITORING_POLICY_REVIEW_2026-10-31.md), [C03/C20](PLAY_CONSOLE_DECLARATIONS_AND_REVIEWER_PACK.md) |

**Prohibited audience tactics** (all are explicit project prohibitions, not merely bad practice): misdeclaring age; adding age groups to bypass Families; labelling the app adult-only to avoid child rules; using the parent app's audience to imply Alarka's; pointing the Store listing at an alternative non-compliant APK. ([X02 §3](X02_FAMILIES_LOCATION_AND_MONITORING_POLICY_REVIEW_2026-10-31.md); [Publishing requirements §9](GOOGLE_PLAY_PUBLISHING_REQUIREMENTS.md))

`EXTERNAL / PENDING` — **owner action:** obtain a **human** Play policy outcome for the actual Alarka package, audience and proposed child location, then record it in the private capture template (§9). Do not create duplicate support messages; the existing case text reportedly cannot be edited.

---

## 4. Disclosure text → in-app screen mapping

### 4.1 What exists in the app today (verbatim from source, branch `api`)

| Screen (route) | File | Actual user-visible text | Usable as the G04 prominent disclosure? |
|---|---|---|---|
| **Transparency disclosure** — `disclosure` | `android/alarka/src/main/kotlin/org/madalasa/alarka/ui/screens/TransparencyDisclosureScreen.kt` | Top bar "Alarka Child Companion" / "Transparency & Mutual Awareness Disclosure"; card **"Child Privacy & Rights Charter"** with: (1) *"Exact-Child Pairing: This app connects exclusively to verified guardians approved for this exact child. No public or shared family directory exists."* (2) *"No Hidden Surveillance: Covert camera capture, ambient microphone recording, screen scraping, and keylogging are strictly prohibited by architecture and code."* (3) *"Visible Protection: Whenever child companion services are operational, a prominent, persistent Android system notification is visible on this device."* (4) *"Local Device Checks: Hardware and app-permission status may be inspected on this device. **This screen does not collect or transmit GPS, audio, camera or private files**; backend pairing and monitoring remain development-gated."*; acknowledgement button "I Understand & Agree" → "Disclosure acknowledged. Device setup may proceed." → "Continue to Device Pairing" | **NO.** Bullet (4) affirmatively states no GPS is collected. Using it as a background-location disclosure would be a false statement. |
| **Permissions & status** — `permissions` | `…/ui/screens/PermissionsScreen.kt` | "Read-only Android hardware and app-grant snapshot"; rows show `Fine grant present · feature OFF pending approval`, `Approximate grant present · feature OFF pending approval`, `Not granted · feature OFF`; "Persistent Notification" row reads "No active background monitoring service" | **NO.** It is a status read-out, not a consent disclosure, and it says the feature is off. |
| **Monitoring information & privacy** — `privacy/transparency` | `…/ui/screens/PrivacyControlsScreen.kt`, route table in `…/ui/navigation/ChildNavRoutes.kt` | Privacy controls surface (route exists; content not part of this evidence claim) | **NO** — not verified as containing background-location wording |
| **Location unavailable** — `privacy/location_unavailable` | `ChildNavRoutes.kt` | Dedicated honest-unavailable state | Not a disclosure; useful as demo negative state |
| **Persistent monitoring notification (policy, not yet wired to a real service)** | `…/service/MonitoringDisclosure.kt` | channel `alarka_monitoring_status`; title **"Alarka is active"**; body **"This device is being monitored with guardian consent. Tap for details and controls."**; `ongoing=true`, `visibleWhileMonitoring=true`; `isValidDisclosure()` requires ongoing + visible + app-name-bearing title + non-blank body, and `monitoringPermitted()` refuses monitoring without a valid disclosure | **NO, but it is the correct persistent-notice artefact** and a strong anti-stealth invariant. It says nothing about background/closed-app collection. |
| **App status strings** | `android/alarka/src/main/res/values/strings.xml` | `app_description` "Alarka Child Companion"; `app_status` *"Child companion prototype — no monitoring enabled. Synthetic data only. No tracking or recording is active."* | **NO** — prototype wording must not appear in any reviewed build |

### 4.2 Required disclosure content that does **not** exist yet

G04 requires prominent on-device disclosure **before** the Android runtime permission, stating location and **"when the app is closed or not in use"**, naming **every actual background-location use**, and naming disclosure/recipient categories. ([X02 §4](X02_FAMILIES_LOCATION_AND_MONITORING_POLICY_REVIEW_2026-10-31.md); [Publishing requirements §4](GOOGLE_PLAY_PUBLISHING_REQUIREMENTS.md); [C06](PLAY_CONSOLE_DECLARATIONS_AND_REVIEWER_PACK.md))

The repo carries a **draft** wording that must be revised before use:

> Draft (repo, not approved): *"Madalasa–Alarka collects location data to provide your parent or guardian with your last reported position, travel history and movement alerts, including when this app is closed or not in use. Location reports are securely sent to the paired parent account. You can review monitoring information in Madalasa–Alarka and Android settings."* — [Publishing requirements §4](GOOGLE_PLAY_PUBLISHING_REQUIREMENTS.md)

**Revision blockers on that draft:**

1. It uses a combined product name; the reviewed app is **Alarka** alone and must name itself consistently with the listing. ([X02 §4 item 3](X02_FAMILIES_LOCATION_AND_MONITORING_POLICY_REVIEW_2026-10-31.md))
2. It promises **travel history and movement alerts**. Under the free-first release, the product entitlement is live last-known location plus at most the **most recent six hours of visible history**; SOS and app-usage are separately gated, and premium/history-for-pay is disabled. Promising more than the shipped build is a listing/disclosure inconsistency and a policy risk. ([FREE_FIRST §Decision](../../../roadmap/FREE_FIRST_108_CHILD_RELEASE_ROADMAP_2026-11-03.md))
3. Six hours is a **visibility window, not a retention schedule**; the disclosure must not imply a storage lifetime that has not been approved. ([DECISION_LEDGER §A C-02](../../../roadmap/DECISION_LEDGER.md); [DATA_RETENTION_SCHEDULE](../../M0-foundation-and-approvals/03-legal-and-privacy/DATA_RETENTION_SCHEDULE.md))
4. It must enumerate **every** background use that actually ships — not just the single core feature chosen for the Console form.

### 4.3 Required screens for the review — target mapping

| Step | Screen / artefact | Requirement | Current state |
|---|---|---|---|
| 1 | Alarka disclosure screen (first run, before any permission) | Prominent, non-dismissible-before-acknowledgement, names Alarka, states closed/not-in-use collection, lists all background uses and recipients | `NOT BUILT` — existing screen contradicts it |
| 2 | Android foreground location grant | OS-owned dialog; app explains "why" first | `NOT BUILT` (no location permission) |
| 3 | Android **separate** background-location grant | Settings flow at 30+; no forced grant; deny path honest | `NOT BUILT` |
| 4 | Persistent monitoring notification | Ongoing, cannot be swiped away, names Alarka | Policy exists in `MonitoringDisclosure.kt`; **not bound to a real service** |
| 5 | Child stop / revoke + OS settings navigation | User-visible stop path | Route `privacy/transparency` exists; behaviour unverified |
| 6 | Parent view (Madalasa) | Latest location + last-updated timestamp + honest stale/offline | Parent privacy controls specified in [PRIVACY_CONTROLS_V0 §4](../../M1-secure-platform-foundation/01-requirements-and-architecture/PRIVACY_CONTROLS_V0_TECHNICAL_AND_UI_SPEC_2026-11-02.md); device evidence absent |

`EXTERNAL / PENDING` — **owner action:** none yet. **Gate:** the disclosure wording must be reviewed for child audience and the actual feature list **before** it is shown in any recorded demo ([Publishing requirements §4](GOOGLE_PLAY_PUBLISHING_REQUIREMENTS.md)). Approval of disclosure text is not legal or Play approval.

---

## 5. Background-location justification under the free-first, 108-child release

**Single selected primary feature for the Console form** (draft, **not** a Play-accepted statement):

> *"Child-safety location availability to a verified guardian while the child companion is not being actively used."*

Source: [X02 §4](X02_FAMILIES_LOCATION_AND_MONITORING_POLICY_REVIEW_2026-10-31.md).

### 5.1 Necessity argument (engineering draft, for owner/legal review)

| Element | Draft position | Constraint |
|---|---|---|
| Core function served | A guardian's ability to see a child's last-known position during an unaccompanied journey | Must be the **actual** shipped behaviour, not an aspiration |
| Why foreground-only is inadequate | The child does not hold the app open while walking/commuting; a foreground-only design yields gaps precisely during movement | Must be demonstrated on a real build, not asserted |
| What remains foreground-only | Pairing, disclosure, permission grants, permission/status review, stop/revoke | Any of these run in background would contradict the claim |
| Physical-safety benefit | Real-time last-known position for a guardian during a safety-relevant interval | "Safety" is a **potential** qualifying benefit, **not** an automatic permission grant |
| Free-tier scope | Live last-known location, moving collection target **10–15 minutes** (a target, not an Android timing promise); most recent **six hours** of visible history | Free tier does **not** enlarge the Play justification; entitlement is not permission |
| Collection cadence in code | `TrackingCadencePolicy`: FREE moving 60 s / stationary 5 min, stepped down under battery saver, and relaxed to 20 min moving / 60 min stationary after 168 h guardian inactivity; **requested intervals only, never guaranteed** | Never state "continuous" or "guaranteed" |
| Explicitly excluded background uses | Stored route reconstruction, geofences, app-usage inference, paid analytics, media | Must still be disclosed accurately if ever shipped; they do not belong in the single-feature answer |

Sources: [X02 §4](X02_FAMILIES_LOCATION_AND_MONITORING_POLICY_REVIEW_2026-10-31.md); [FREE_FIRST §Decision](../../../roadmap/FREE_FIRST_108_CHILD_RELEASE_ROADMAP_2026-11-03.md); `android/alarka/src/main/kotlin/org/madalasa/alarka/service/TrackingCadencePolicy.kt`.

### 5.2 Honest limits the justification must state

- Background collection is **not** permitted merely because the parent granted a runtime permission, the app carries `isMonitoringTool`, the device is parent-owned, transport is P2P/encrypted, or India DPDP has a real-time-safety purpose exception. ([X02 §1, §3](X02_FAMILIES_LOCATION_AND_MONITORING_POLICY_REVIEW_2026-10-31.md))
- Foreground-service start can be **rejected by the OS**; the code already fails closed with an explicit reason and never retries covertly (`ForegroundServiceStartPolicy.kt`).
- The 108-child cap is a **deployment safety cap**, not proof the service is eligible or capacity-safe. ([FREE_FIRST §Capacity decision](../../../roadmap/FREE_FIRST_108_CHILD_RELEASE_ROADMAP_2026-11-03.md))
- Android location compatibility is **NOT DEVICE TESTED**: distinct foreground/background grants, allowed FGS state, Doze/OEM/force-stop, revocation. ([X02 §2](X02_FAMILIES_LOCATION_AND_MONITORING_POLICY_REVIEW_2026-10-31.md))

`EXTERNAL / PENDING` — **owner action:** approve this justification text (or replace it) only after a favourable G01 outcome; it is submitted by the owner in the Console location-permissions declaration, never by engineering on the owner's behalf.

---

## 6. Capture checklist — screenshots and demonstration video

All captures must come from a **real signed build on a real Android device**. Simulated UI, Figma frames or edited footage must never be presented as proof. ([X02 §4 item 4](X02_FAMILIES_LOCATION_AND_MONITORING_POLICY_REVIEW_2026-10-31.md); [C19](PLAY_CONSOLE_DECLARATIONS_AND_REVIEWER_PACK.md))

### 6.1 Preconditions (all must be true before recording)

- [ ] G01 human outcome recorded as affirmatively eligible **for this build** (private evidence).
- [ ] Final `applicationId`, `versionCode`, signing, and target API ≥ 36 verified on the signed candidate.
- [ ] Release manifest permission list re-read from the **signed AAB**, not from source.
- [ ] All non-shipping features verified OFF in the binary (media, usage, geofence, paid history).
- [ ] Disclosure wording final and reviewed; no "prototype/synthetic" string in the build.
- [ ] Reviewer accounts prepared for **two synthetic families**, one unauthorized/revoked adult, and free/expired states — real usable QA accounts, never fabricated logins.
- [ ] Test data is non-personal or owner-authorized-labelled; no third-party/bystander data; no financial screens on camera.

### 6.2 Video storyboard (ordered, one continuous take per segment)

| # | Segment | Must visibly show | Capture note |
|---|---|---|---|
| 1 | Identity | Recognizable **Alarka** launcher/icon and app name; build/version and device/API level | Record build SHA, package, device model, API level, UTC date in the private evidence register only |
| 2 | Prominent disclosure **before** any grant | Full disclosure text on screen; explicit "when the app is closed or not in use"; every background use; recipient categories; acknowledgement | Must precede the OS dialog in the recording, no cut |
| 3 | Foreground location grant | Android-owned dialog; app's "why" screen preceding it | OS-owned UI must not be faked |
| 4 | Separate background grant | Settings → Location → "Allow all the time" (or equivalent on the tested OEM) | Show the OS-owned separate step; no coercion |
| 5 | Activation | Pairing/consent re-check at activation; state that pairing alone is not monitoring | Show waitlisted/queued child failing closed if in scope |
| 6 | Persistent notice | Ongoing notification naming Alarka, not swipeable | Show notification shade |
| 7 | Closed-app operation | Alarka Activity closed; movement between **real** test coordinates; map/notification still correct | Note collection is requested, not guaranteed |
| 8 | Parent view | Madalasa shows latest position, **last-updated timestamp**, six-hour history bound | No fabricated coordinates, no `0,0` |
| 9 | Negative states | Permission denied, revoked mid-session, location off, device offline/force-stopped: honest STALE/UNAVAILABLE, never fake success | Each state separately visible |
| 10 | Stop / revoke | Child-side stop and guardian revoke actually stop monitoring and the notice | Under 60 s per state |
| 11 | Non-shipping features | Remote media, usage, paid gates visibly absent/disabled | Do not enable media to "demonstrate" it |

### 6.3 Screenshots (from the same signed build)

- [ ] Listing screenshots: real UI only, no mockups, no invisible/undetectable/universal-control claims.
- [ ] In-app disclosure screen, permission screens (pre-grant and post-grant), permission-denied state.
- [ ] Persistent monitoring notification.
- [ ] Parent latest-location and history view with timestamps.
- [ ] Privacy/delete-request entry point reachable in-app.

### 6.4 Handling rules

- Unredacted video, credentials, case references and test coordinates go **only** to owner-controlled private channels, never to Git, chat, or video captions. ([X02 §6](X02_FAMILIES_LOCATION_AND_MONITORING_POLICY_REVIEW_2026-10-31.md))
- Reviewer access must not be blocked by geography/MFA traps that are not explained.
- A recording is evidence of a build's behaviour; it is **not** a policy approval.

`EXTERNAL / PENDING` — **owner action:** record and upload through owner-controlled Console fields after the build exists.

---

## 7. Owner-only submission steps (nothing here is performed by engineering)

Each step is `EXTERNAL / PENDING`. Order matters: **G01 before G04**.

| # | Step | Where | Owner action | Prerequisite | Cannot be claimed |
|---|---|---|---|---|---|
| 1 | Read the existing support case outcome | Owner's Play Console / support case | Do not duplicate the message; preserve the full response privately | Existing case already created | That a case existing means a favourable decision |
| 2 | Record the G01 determination in the private capture template (§9) | Private evidence only | Fill `case_reference`, `package_under_review`, `declared_actual_audience`, decision date, `families_applies`, `precise_location_allowed`, `limitations` | — | A published or guessed case ID |
| 3 | If G01 is **ineligible** | Product decision | Remove location permissions/precise collection and dependent claims from the Play build, or redesign and seek a new assessment | G01 result | That the monitoring flag, parent consent or a foreground service substitutes |
| 4 | If G01 is **eligible**, prepare the location-permissions declaration | Play Console → **Policy → App content → Sensitive app permissions → Location permissions** | Enter **one** strongest core feature (see §5), privacy URL, working build | Signed AAB, final disclosure, real video, live privacy HTML page | Automatic approval; a submitted form is not a grant |
| 5 | Target audience / content rating / ads | Console → App content | Truthful audience declaration per §3; do not manipulate age buckets | Final feature list | Families acceptance |
| 6 | Monitoring designation | Build + Console | `isMonitoringTool=child_monitoring` where required, on **every** active track; identifiable icon; transparent listing | Manifest integration reviewed at build time | That the flag waives Families location rules |
| 7 | Data safety questionnaire | Console → App content → Data safety | Answer per package from the actual binary/SDKs/backend, per the DS01–DS18 worksheet | Verified network/SDK evidence | That "no VPS media archive" means "no collection" |
| 8 | FGS type declarations and use-case video | Console | Only for service types actually used; unused types marked NOT REQUESTED | Device-verified lifecycle | Background push implies unrestricted FGS start |
| 9 | Public privacy policy + account-deletion URLs | Public web | Live, login-free, naming the correct developer/app, honest retention and contacts | Approved retention/deletion policy (B-07 open) | That a draft policy is a lawful notice |
| 10 | App access / reviewer credentials | Console → App access | Reviewer instructions, pairing steps, two synthetic families, hardware requirements | Workable build + QA accounts | Credentials in Git or captions |
| 11 | Testing-track gate | Console | Confirm whether this account (personal, created after 2023-11-13) needs **12 opted-in testers for 14 continuous days**, then apply for production access | Account-specific verification | Exemption or automatic production access |
| 12 | Upload and staged rollout | Console | Signed AAB, Play App Signing, staged rollout, policy recheck at submission | All gates above | That a merge/CI pass grants release permission |

Sources: [X02 §2, §4](X02_FAMILIES_LOCATION_AND_MONITORING_POLICY_REVIEW_2026-10-31.md); [Publishing requirements §5, §10](GOOGLE_PLAY_PUBLISHING_REQUIREMENTS.md); [BLOCKERS §C X-02](../../M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md); [PLAY_CONSOLE_DECLARATIONS_AND_REVIEWER_PACK §"Reviewer pack contents"](PLAY_CONSOLE_DECLARATIONS_AND_REVIEWER_PACK.md).

**Free-first sequencing note:** the free-only public build precedes any paid release, but a free listing is **not** permit to ship an ineligible location feature, and a public listing does **not** establish merchant approval. ([FREE_FIRST §Decision](../../../roadmap/FREE_FIRST_108_CHILD_RELEASE_ROADMAP_2026-11-03.md); FF-08/FF-09 status `EXTERNAL GATES OPEN` / `NOT SUBMITTED`.)

---

## 8. Gate register — current fail-closed state

| Gate | State (draft) | Closing evidence | Owner |
|---|---|---|---|
| G01 audience + precise location eligibility | **OPEN / EXTERNAL** | Case-linked **human** Play outcome for the actual packages and behaviour | Owner / Google Play |
| G04 background location declaration | **NOT SUBMITTED / EXTERNAL** | Console location-permissions form + one core feature + signed build + disclosure + privacy URL + video + reviewer access + approved outcome | Owner / Google Play |
| Monitoring designation | **DESIGN ONLY** | Manifest metadata on all tracks, real icon/notice/listing, track audit | Engineering + Owner |
| Disclosure before runtime permission | **NOT BUILT** | Final wording + real-device recording | Engineering (blocked) |
| Android location lifecycle | **NOT DEVICE TESTED** | Foreground/background/deny/revoke/Doze/OEM/force-stop evidence | Engineering |
| Signed AAB / package identity | **NOT PRESENTED** | Real signed package ID, version, target SDK, manifest review | Engineering + Owner |
| India legal basis for real child location | **OPEN (X-03)** | Feature-specific documented lawful assessment (see X03 register) | Owner |
| Public privacy / deletion URLs | **OPEN (X-04)** | Live pages matching real data operations | Product/backend + Owner |
| Data safety answers | **NOT SIGNED** | Per-package answers reconciled to the binary | Owner + Engineering |

No test in the X02 set (T-X02-01 … T-X02-10) is executed; all are **PLANNED / NOT EXECUTED**. ([X02 §5](X02_FAMILIES_LOCATION_AND_MONITORING_POLICY_REVIEW_2026-10-31.md))

---

## 9. Private decision-capture template (copy into private evidence; never into Git)

`case_reference` · `package_under_review` · `declared_actual_audience` · `play_policy_reply_date` · `decision_maker_and_channel` · `verbatim_scope` · `families_applies` · `precise_location_allowed` · `background_location_declaration_required` · `separate_approval_received` · `feature_eligibility` · `limitations` · `reviewed_build_version` · `link_to_private_evidence`

Source: [X02 §6](X02_FAMILIES_LOCATION_AND_MONITORING_POLICY_REVIEW_2026-10-31.md). Do not publish case IDs, screenshots, real children's data, Google credentials or counsel consultation details.

---

## 10. Source map (every claim above traces to one of these)

| Key | Repo path (origin/main) | Sections used |
|---|---|---|
| S1 | `docs/phases/M9-play-release/01-play-and-data-safety/X02_FAMILIES_LOCATION_AND_MONITORING_POLICY_REVIEW_2026-10-31.md` | §1 key outcome, §2 status table, §3 decision path, §4 disclosure/declaration/video, §5 tests, §6 capture template, §7 precedence |
| S2 | `docs/phases/M9-play-release/01-play-and-data-safety/GOOGLE_PLAY_PUBLISHING_REQUIREMENTS.md` | X-01 update, 2026-10-31 reviewer readiness, dependency table, §1, §3 worksheet, §4 background-location package, §5 inventory, §6 data safety, §9 listing guardrails, §10 go/no-go |
| S3 | `docs/phases/M9-play-release/01-play-and-data-safety/PLAY_CONSOLE_DECLARATIONS_AND_REVIEWER_PACK.md` | P01–P09, C01–C20, "Reviewer pack contents and handling", commercial invariants |
| S4 | `docs/phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md` | §A B-02/B-03/B-05, §C X-01/X-02, §"X-02 Google Play G01/G04 review progress", §"2026-10-30 G01/G04 AI guidance" |
| S5 | `docs/roadmap/FREE_FIRST_108_CHILD_RELEASE_ROADMAP_2026-11-03.md` | Decision, "Child app is fully free", "Capacity decision", "New prioritized delivery checkpoints", "Merge and test policy" |
| S6 | `docs/roadmap/DECISION_LEDGER.md` | §A C-02/C-03/C-14, §B B-02/B-03/B-16, §C X-02/X-03, §E stale passages |
| S7 | `docs/phases/M1-secure-platform-foundation/01-requirements-and-architecture/PRIVACY_CONTROLS_V0_TECHNICAL_AND_UI_SPEC_2026-11-02.md` | §1 purpose/category registry, §4 Android UI specification |
| S8 | `docs/phases/M9-play-release/01-play-and-data-safety/DATA_SAFETY_WORKSHEET.md` | DS01–DS18, mandatory answer worksheet |
| C1 | `android/madalasa/src/main/AndroidManifest.xml`, `android/alarka/src/main/AndroidManifest.xml`, `android/*/src/debug/AndroidManifest.xml` (branch `api`) | Declared permissions, exported activities, absent metadata |
| C2 | `android/madalasa/build.gradle.kts`, `android/alarka/build.gradle.kts` | applicationId, versionCode/Name, compileSdk/targetSdk/minSdk |
| C3 | `android/alarka/src/main/kotlin/org/madalasa/alarka/ui/screens/TransparencyDisclosureScreen.kt`, `PermissionsScreen.kt`, `service/MonitoringDisclosure.kt`, `service/ForegroundServiceStartPolicy.kt`, `service/TrackingCadencePolicy.kt`, `ui/navigation/ChildNavRoutes.kt` | Actual disclosure text, notification spec, FGS fail-closed policy, cadence, routes |
| C4 | `android/alarka/src/main/res/values/strings.xml`, `android/madalasa/src/main/res/values/strings.xml` | app_name, app_description, app_status |

Policy citations named inside S1/S2 (Google Families, Monitoring Applications, background location, `isMonitoringTool`) are reproduced **from those repo passages only**; they were not independently retrieved for this draft, and no such retrieval is claimed.

---

## 11. Bottom line for a reviewer

1. The apps as they exist in Git declare **only `INTERNET`**; there is nothing to submit for G01/G04 and no child location is collected.
2. The only in-app disclosure text available **explicitly denies GPS collection** — it must be replaced, not reused.
3. G01 has **no human Play outcome**, and G04 cannot start before it.
4. The free-first 108-child release changes product scope, not platform eligibility.
5. Nothing in this pack is legal advice, and nothing in it constitutes Google Play, Android, legal or regulatory approval. All external items remain `EXTERNAL / PENDING` with the owner action listed.
