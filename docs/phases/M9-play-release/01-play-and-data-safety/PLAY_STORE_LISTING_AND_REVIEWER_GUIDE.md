# Play Store Listing, Reviewer Access and Submission Checklist

> **Document control:** M9 / 01-play-and-data-safety · Proposed owner: Play release owner + counsel (not assigned) · Registry: DRAFT_LEGAL_REVIEW_REQUIRED; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

> **Product names:** **Madalasa** (parent app), **Alarka** (child app). Desired repository name **Madalasa-Alarka** is **completed GitHub repository rename**. Use the verified new repository URL for all current documentation and integrations. [Naming rationale](../../M0-foundation-and-approvals/02-market-and-feasibility/BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

**Madalasa–Alarka | 2026-10-25 | Draft; must reflect actual shipped functionality**

## 1. Store listing copy — parent app (candidate, unapproved)

**Title candidate:** Madalasa — Family Safety

**Short description candidate:** Child location history and app-use insights for parents.

**Long description candidate:**

“Madalasa–Alarka helps parents and guardians review location history and device-usage information on a child's Android phone after it has been set up with the necessary permissions.

Available supported features may include:
- Last reported device location on a map, with accuracy and freshness.
- Trip history, route views and optional reported travel speed.
- Daily, weekly, monthly and yearly app usage summaries after Android Usage Access is granted.
- Supported device policies on appropriately managed phones.
- Device pairing, monitoring status and parent-controlled retention settings.

Setup requires access to the child's device. Madalasa–Alarka is an identifiable monitoring tool; the child-side app provides required disclosures and persistent monitoring notification while operating. Feature availability differs by Android version, permissions, phone manufacturer and whether the phone is managed. The app does not guarantee continuous GPS tracking, arbitrary app blocking or unannounced camera/microphone access.

A paid subscription may be required for certain features. Availability, price and terms are shown in the app.”

**Do not publish this paragraph until every included feature is actually released and verified.**

For a separately listed child agent, write a clear child-device setup listing that explicitly identifies data collection, parental monitoring purpose, permissions and the persistent notification.

## 2. Required graphic and content deliverables

- Real app icon, consistent developer brand and identifiable child app icon.
- Store feature graphic, appropriate aspect ratio and quality per latest Play specifications.
- Minimum required screenshot set per device category; each image must depict the **actual app**, not concepts.
- Localized description and privacy/disclosure text in supported languages.
- Support contact; public privacy-policy and account-deletion URLs.
- Screenshots for parent map/history, app usage, pairing, authorized policy controls, and monitoring disclosure (only when implemented).
- Subscription terms/price/free trial disclosure wherever shown.

Do not invent reviews, benchmark claims or screenshots of features not included in the uploaded release.

## 3. Reviewer instructions — to complete using real release candidates

```text
Package name(s):
Parent demo account username:
Parent demo access credentials or test login instructions:
Child pairing test code flow:
Test device(s) available to reviewer or test simulation workflow:
Exact steps to reach each declared monitoring feature:
Steps to view disclosure and persistent notification:
Background location demonstration video:
App restrictions test: standard mode vs managed mode:
Subscription demo/test entitlement steps:
Instructions for optional Google Drive consent:
Country/account access restrictions:
Support contact for review:
Features intentionally disabled in this build:
```

**Never put production passwords, permanent device enrollment keys, or private customer data in repo documentation.** Supply testing credentials through the secured Play Console reviewer-access entry.

## 4. Public communication boundaries

Allowed marketing themes: “family location history”, “parental device supervision”, “supported screen-time insights”, “managed-device restrictions”. Avoid “secret,” “invisible,” “spy,” “without the child knowing,” “guaranteed camera access,” “record without notification,” and unmeasured battery claims.

## 5. Publication workflow

1. Verify publisher identity/account prerequisites and app ownership.
2. Register unique package name(s) and app signing.
3. Upload release AAB to internal test.
4. Resolve pre-launch report crashes, permission and 16 KB page-size warnings.
5. Complete App content forms (ads, target audience, rating, privacy, Data safety, reviewer access and sensitive permission declarations).
6. Upload relevant real demonstration videos for background location and other selected declarations.
7. Verify in-app account deletion and public web deletion URL.
8. Run required closed testing, if account subject to production-access gate.
9. Validate billing products, pricing, taxes and subscriptions.
10. Submit for review, process findings, then staged rollout.
11. Reconcile Play listing, SDKs, permission/declaration forms and privacy policy on **every** update.

## Sources

- https://support.google.com/googleplay/android-developer/answer/9859455
- https://support.google.com/googleplay/android-developer/answer/9799150
- https://support.google.com/googleplay/android-developer/answer/9888380
- https://support.google.com/googleplay/android-developer/answer/14151465


## New two-app public names (owner-approved)

**Parent app:** **Madalasa — Family Safety** (candidate listing title). **Child companion:** **Alarka — Family Safety Companion** (candidate listing title). Each needs independent Play publisher and data disclosures. Alarka must display visible child-monitoring notifications and ask permissions on the child's phone. No guaranteed emergency dispatch or covert capture claims; app IDs and titles still require store verification.

## Conditional media features: no premature reviewer or listing claims (2026-10-26)

Owner accepts media and scoped-file **R&D** with exact parent-facing failure explanations. Do not advertise/bill these features as released, pretend media works on all Android devices, claim hidden listening or suppress system camera/mic indicators. Alarka main Activity normally stays closed after initial setup but monitoring notification, app icon, sensor indicators and required child-visible prompts remain. Android MediaProjection screen viewing requires fresh system consent for each session. If the feature is ever submitted, verify every relevant Android/OEM/standard/managed-device scenario, accurate monitoring disclosure, guardian verification, manifest/FGS permissions, children/Families eligibility, privacy and recording retention. [MA-MEDIA-ADR-001](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md). Commercial feature flag stays OFF until release gates pass.

## 2026-10-27 permission onboarding UX and reviewer evidence requirements

The proposed Alarka-first-launch compatibility scan must be **read-only** and explained: detect public hardware/API availability without turning on camera/microphone, collecting location or reading file contents. After verified family pairing, OS permission requests are staged with clear in-app purpose and user-controlled standard Android dialogs / Settings / Photo Picker / SAF selectors, followed by **actual Android recheck** and child-device report sync. Do not claim the parent can grant permissions remotely, force all optional permissions, hide Alarka after setup or offer screen sharing without new per-session Android consent.

If publicly released after policy clearance, reviewer video must show (a) Alarka's identifiable icon/notifications and disclosure, (b) appropriate foreground then separately requested background location for API30+, (c) denial/skipping and limited modes, (d) server acknowledgement and Madalasa accurate granted/conditional/offline indicator, and (e) later revocation/reapproval without false instant notification. A Figma screen is not compliance proof; submit real signed build/screens/permission declarations. Protected India child location/usage/media features remain blocked until official/purpose review. [MA-CAP-ADR-002](../../M1-secure-platform-foundation/03-security-and-permissions/CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md); [Figma](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=23-2).


## 2026-10-28 — New approved-for-review icon and logo assets (not Play approved)

**Figma editable vector components:** [Madalasa parent icon](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=68-164), [Alarka child icon](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=68-173), [family/website icon](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=68-179). [Editable website wordmark](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=70-164), [Madalasa Play feature graphic](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=70-200) and [Alarka Play feature graphic](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=70-213). All branding is original geometric illustration inspired by the pan-Indian Markandeya Purana narrative, **not Bengali folk art**, and English-only. No claim of supernatural monitoring, Google approval or operational app release.

**GitHub deliverables:** [master brand source and instructions](https://github.com/methakon/Madalasa-Alarka/tree/main/branding), [individual Play-ready candidate icons and graphics](https://github.com/methakon/Madalasa-Alarka/tree/main/branding/play-store), [Madalasa Android resources](https://github.com/methakon/Madalasa-Alarka/tree/main/android/madalasa/src/main/res), [Alarka Android resources](https://github.com/methakon/Madalasa-Alarka/tree/main/android/alarka/src/main/res), [website wordmarks and favicon assets](https://github.com/methakon/Madalasa-Alarka/tree/main/public/brand). Two 512×512 PNG candidates, two 1024×500 opaque JPEG Play graphics, adaptive 108dp vector layers + monochrome icons, five density variants per app, website 32/180/192/512 PNGs, SVGs, social preview and manifest were committed. [Detailed dimensions, placement and manual release gates](https://github.com/methakon/Madalasa-Alarka/blob/main/branding/README.md). Google Play and Android/OEM validation, publisher/trademark checks and actual AndroidManifest integration remain required.


## 2026-10-28 — Two parents, one child payment; select paid children (supersedes conflicting assumptions)

**Owner working decision:** one verified prepaid **paid child entitlement** may be used by *both separately signed-in, explicitly authorized parent accounts* within the same Madalasa family. Second parent does **not** buy a second plan for the same child. Primary billing adult selects which child IDs are covered by N paid seats; nonselected siblings stay on free features. Permissions remain scoped per adult-child grant, shared quotas meter per child across both parents, and co-parent access is revoked independently of purchase. One family is counted once for first-1,008 founding-family eligibility. Prepaid/manual renewal only, no auto debit; when expired both parents revert to the child's free tracking/reduced frequency/six-hour visible history. Other rules unchanged.

**Google verification:** [Family Link supports a second adult parent](https://support.google.com/families/answer/7295768) but does NOT automatically authorize Madalasa or expose a verified public parent-relationship API to this app. [India does not support new Play Family Library/family payment signups](https://support.google.com/googleplay/answer/16719923), and [family payment methods exclude subscriptions](https://support.google.com/googleplay/answer/15775614). Google Play purchases stay with the paying Play account; backend verifies and binds unique purchase tokens to family capacities/child entitlements, NOT guardian devices. [Play prepaid add-ons are unavailable](https://developer.android.com/google/play/billing/subscription-with-addons) because add-ons are currently auto-renew-only. Play Console sandbox must prove suitable N-seat prepaid SKUs, explicit seat reassignment, upgrades, top-ups and founding offers before any launch pricing promise.

**Canonical implementation design:** [Two-parent Shared Child Entitlements and Seat Selection](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/TWO_PARENT_SHARED_CHILD_PREPAID_ENTITLEMENTS_2026.md) (use an appropriate relative path from each document). Figma added [P-47 family child seats](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=81-179) and [P-49 covered by family](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=81-201), editable mockups only. Media and other restrictive Android features remain gated.


## 2026-10-28 — New ACTIVE illustrated face icons (supersedes abstract-logo guidance above)

The active Play Store / launcher artwork now contains **original generated face portraits** of Madalasa (adult queen) and Alarka (young boy-prince), with a two-face family mark on the website. **These are NOT verified ancient portraits**; the 1904 Markandeya Purana translation gives narrative context but not authentic character photographs or artwork. Figma portrait components are still at [Madalasa](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=68-164), [Alarka](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=68-173) and [website dual portrait](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=68-179). Full details in [Portrait Logo Revision](https://github.com/methakon/Madalasa-Alarka/blob/main/branding/CHARACTER_PORTRAIT_LOGOS_2026.md). Previous geometric PNG artwork is archived at `branding/archive/abstract-v1/` and legacy geometric `branding/source/*.svg` are **not** source masters for the new portraits. Android launcher now uses adaptive transparent `@drawable/ic_launcher_face` foreground PNG; themed monochrome icon remains geometric. The website portrait look is currently delivered through PNG wordmarks and favicons; SVG alternatives remain older geometric vector marks. Validate small icon readability, copyright/trademark/AI-art usage, exact Play size and adaptive masks on real devices before publication.

## 2026-10-28 selected-child Google-parent-only sharing + screen limits

**Owner direction:** a payer can select among multiple children, but cannot automatically share any child with another spouse or co-parent. Each parent-child pairing requires an explicit separate selection, suitable verification of that **specific Google-supported parental relationship** (currently NOT accessible through a verified public integration), and a separate scoped grant. **The entire co-parent sharing action remains blocked** until the trusted verification method is approved; Google Sign-In alone is not proof. Child B identity is not shown to a co-parent authorized only for Child A. Strict sharing never depends on family name or shared billing.

**One simultaneous PREMIUM live viewer per covered paid child is included**, shared among parents; backend viewer lease/heartbeat and atomic admission prevent simultaneous second screens. Free basic tracking, account screens and SOS remain usable. Working optional checkout proposal: **₹100 per +1 simultaneous premium viewer screen for up to 30 days (duration still NOT owner-confirmed)**, with **30 extra combined audio/video minutes** shared per selected child/period, no auto-renew, and stop no later than parent prepaid expiry. Media itself remains conditional and NOT yet available; no Play product configured. Distinguish paid child seats from extra concurrent viewer screens, and one pool from 30+30 separate quotas. See [canonical specification](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/CHILD_SPECIFIC_GOOGLE_PARENT_SHARING_AND_CONCURRENT_SCREEN_ADDONS_2026.md).

**Figma editable visual states:** [SH-01 child selection](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=84-179), [SH-02 Google role unavailable](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=84-201), [SH-03 viewer limit](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=84-221), [SH-04 ₹100 checkout preview](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=84-242), [SH-05 private co-parent child list](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=84-263). Earlier [P-47](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=81-179)/[P-49](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=81-201) also received explicit pending-verification/privacy wording. Figma frames are static, not Android screens or functioning controls.
