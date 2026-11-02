# Final Figma Screen-by-Screen API and DB Audit

**Date:** 2026-10-28. **Scope:** Figma design and existing OpenAPI/ERD, NOT implemented application QA.

187 registered screen/states were traced against 134 OpenAPI paths and 112 conceptual database entities. 106 linked frames were independently checked live in Figma: all exist and have text. 81 states are registry-only and require frame-level visual proof. A path match is not proof of backend implementation.

## Hard blockers

- India DPDP child data purpose, guardian consent, retention and backup deletion require signed owner/legal review. Six-hour free history visibility differs from full data retention.
- No verified third-party Google parent-child Family Link attestation integration. Sharing with a second parent remains blocked without trustworthy child-specific proof.
- Android/Play OS limitations for capture and Device Owner controls require real device evidence; no covert media or permission bypass.
- Current repository lacks demonstrated working Kotlin Gradle applications and Drogon backend handlers; existing OpenAPI is design.
- Play Personal account active status does not certify closed-test, identity/device verification, prepaid SKU or production approval.
- Historical OCI Chicago and India-first Mumbai preference conflict; hosting requires separate approval.
- Physical SQL is not the 112-table Figma conceptual design. Every new table needs migration, RLS, indexes and tests.

## Exact missing endpoint candidate register

[26 absent HTTP method/path candidates with conceptual database table references](SCREEN_MISSING_API_AND_DB_GAPS_2026-10-28.md). These are design proposals; verify user journeys before implementing.

## Screen-by-screen crosswalk

**Figma proof:** DIRECT=Figma frame verified; REGISTRY=screen specification with no verified frame ID. **API:** CANDIDATE=related path exists, not exact screen contract/handler proof; MANUAL=needs human mapping; STORY=local navigation.

| ID | Screen | Source | Figma proof | API coverage | Candidate paths | Data/access concern |
|---|---|---|---|---|---|---|
| P-01 | Welcome | 01-parent-foundation Registry | REGISTRY | CANDIDATE | `/auth/parent/google`, `/parents/me` | Child scope / retention as applicable |
| P-02 | Sign in | 01-parent-foundation Registry | REGISTRY | CANDIDATE | `/auth/parent/google`, `/parents/me` | Child scope / retention as applicable |
| P-03 | Create account | 01-parent-foundation Registry | REGISTRY | CANDIDATE | `/families`, `/families/{familyId}/children` | Child scope / retention as applicable |
| P-04 | Google account handoff | 01-parent-foundation Registry | REGISTRY | CANDIDATE | `/auth/parent/google`, `/parents/me` | Child scope / retention as applicable |
| P-05 | Home dashboard | 01-parent-foundation Registry | REGISTRY | CANDIDATE | `/auth/parent/google`, `/parents/me` | Child scope / retention as applicable |
| P-06 | My children | 01-parent-foundation Registry | REGISTRY | CANDIDATE | `/families`, `/families/{familyId}/children` | Child scope / retention as applicable |
| P-07 | Child details | 01-parent-foundation Registry | REGISTRY | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| P-08 | Install child app | 01-parent-foundation Registry | REGISTRY | CANDIDATE | `/pairing-codes`, `/enrollment` | Child scope / retention as applicable |
| P-09 | Pair child device | 01-parent-foundation Registry | REGISTRY | CANDIDATE | `/pairing-codes`, `/enrollment` | Child scope / retention as applicable |
| P-10 | Data-purpose review | 01-parent-foundation Registry | REGISTRY | CANDIDATE | `/families`, `/families/{familyId}/children` | Child scope / retention as applicable |
| P-11 | Parent permission coach | 01-parent-foundation Registry | REGISTRY | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| P-12 | Location permission walkthrough | 01-parent-foundation Registry | REGISTRY | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| P-13 | Battery settings walkthrough | 01-parent-foundation Registry | REGISTRY | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| P-14 | Setup/device verification | 01-parent-foundation Registry | REGISTRY | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| P-15 | Travel history overview | 01-parent-foundation Registry | REGISTRY | CANDIDATE | `/children/{childId}/position`, `/children/{childId}/locations` | Child scope / retention as applicable |
| P-16 | Guardian management | 01-parent-foundation Registry | REGISTRY | CANDIDATE | `/families`, `/families/{familyId}/children` | Child scope / retention as applicable |
| P-17 | Alerts and check-ins | 01-parent-foundation Registry | REGISTRY | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| P-18 | Plans and app settings | 01-parent-foundation Registry | REGISTRY | CANDIDATE | `/billing/catalog`, `/billing/entitlement` | Child scope / retention as applicable |
| P-19 | Alert inbox | 02-parent-operations Registry | REGISTRY | MANUAL | Local/needs mapping | Child scope / retention as applicable |
| P-20 | Alert detail | 02-parent-operations Registry | REGISTRY | CANDIDATE | `/auth/parent/google`, `/parents/me` | Child scope / retention as applicable |
| P-21 | Reliability Center | 02-parent-operations Registry | REGISTRY | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| P-22 | Map evidence legend | 02-parent-operations Registry | REGISTRY | CANDIDATE | `/children/{childId}/position`, `/children/{childId}/locations` | Child scope / retention as applicable |
| P-23 | Travel day selector | 02-parent-operations Registry | REGISTRY | CANDIDATE | `/children/{childId}/position`, `/children/{childId}/locations` | Child scope / retention as applicable |
| P-24 | Trip detail | 02-parent-operations Registry | REGISTRY | CANDIDATE | `/children/{childId}/position`, `/children/{childId}/locations` | Child scope / retention as applicable |
| P-25 | Trip revision history | 02-parent-operations Registry | REGISTRY | CANDIDATE | `/children/{childId}/position`, `/children/{childId}/locations` | Child scope / retention as applicable |
| P-26 | Named places list | 02-parent-operations Registry | REGISTRY | CANDIDATE | `/auth/parent/google`, `/parents/me` | Child scope / retention as applicable |
| P-27 | Add named place | 02-parent-operations Registry | REGISTRY | CANDIDATE | `/children/{childId}/places`, `/children/{childId}/places/{placeId}` | Child scope / retention as applicable |
| P-28 | Place-alert configuration | 02-parent-operations Registry | REGISTRY | CANDIDATE | `/children/{childId}/places`, `/children/{childId}/places/{placeId}` | Child scope / retention as applicable |
| P-29 | Commute planner | 02-parent-operations Registry | REGISTRY | CANDIDATE | `/billing/catalog`, `/billing/entitlement` | Child scope / retention as applicable |
| P-30 | Commute confidence | 02-parent-operations Registry | REGISTRY | MANUAL | Local/needs mapping | Child scope / retention as applicable |
| P-31 | Usage overview (gated) | 02-parent-operations Registry | REGISTRY | CANDIDATE | `/children/{childId}/usage`, `/children/{childId}/usage/apps` | Child scope / retention as applicable |
| P-32 | App usage detail (gated) | 02-parent-operations Registry | REGISTRY | CANDIDATE | `/children/{childId}/usage`, `/children/{childId}/usage/apps` | Child scope / retention as applicable |
| P-33 | Remote commands | 02-parent-operations Registry | REGISTRY | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| P-34 | Find device request | 02-parent-operations Registry | REGISTRY | MANUAL | Local/needs mapping | Child scope / retention as applicable |
| P-35 | Managed screen-time rules | 02-parent-operations Registry | REGISTRY | MANUAL | Local/needs mapping | OS + legal feature gate |
| P-36 | Rule preview and rollback | 02-parent-operations Registry | REGISTRY | CANDIDATE | `/billing/catalog`, `/billing/entitlement` | Child scope / retention as applicable |
| P-37 | Managed eligibility | 03-parent-governance-billing Registry | REGISTRY | MANUAL | Local/needs mapping | Child scope / retention as applicable |
| P-38 | Device provenance and handoff | 03-parent-governance-billing Registry | REGISTRY | MANUAL | Local/needs mapping | Child scope / retention as applicable |
| P-39 | Guardian invitation | 03-parent-governance-billing Registry | REGISTRY | CANDIDATE | `/families`, `/families/{familyId}/children` | Child scope / retention as applicable |
| P-40 | Guardian grant detail | 03-parent-governance-billing Registry | REGISTRY | CANDIDATE | `/families`, `/families/{familyId}/children` | Child scope / retention as applicable |
| P-41 | Access ledger | 03-parent-governance-billing Registry | REGISTRY | CANDIDATE | `/account/deletion-request`, `/account/export-requests` | Child scope / retention as applicable |
| P-42 | Retention settings | 03-parent-governance-billing Registry | REGISTRY | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| P-43 | Data access/export | 03-parent-governance-billing Registry | REGISTRY | CANDIDATE | `/account/deletion-request`, `/account/export-requests` | Child scope / retention as applicable |
| P-44 | Account and child deletion | 03-parent-governance-billing Registry | REGISTRY | CANDIDATE | `/account/deletion-request`, `/account/export-requests` | Child scope / retention as applicable |
| P-45 | Support diagnostics | 03-parent-governance-billing Registry | REGISTRY | CANDIDATE | `/faqs`, `/support/tickets` | Child scope / retention as applicable |
| P-46 | Capability before purchase | 03-parent-governance-billing Registry | REGISTRY | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| P-47 | Family seats | 03-parent-governance-billing Registry | REGISTRY | CANDIDATE | `/families`, `/families/{familyId}/children` | Child scope / retention as applicable |
| P-48 | Checkout review | 03-parent-governance-billing Registry | REGISTRY | CANDIDATE | `/billing/catalog`, `/billing/entitlement` | Child scope / retention as applicable |
| P-49 | Subscription status | 03-parent-governance-billing Registry | REGISTRY | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| P-50 | Notification and quiet hours | 03-parent-governance-billing Registry | REGISTRY | CANDIDATE | `/families`, `/families/{familyId}/children` | Child scope / retention as applicable |
| P-51 | Battery/coverage profiles | 03-parent-governance-billing Registry | REGISTRY | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| P-52 | Server outage/recovery | 03-parent-governance-billing Registry | REGISTRY | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| P-53 | Permission-change notice | 03-parent-governance-billing Registry | REGISTRY | CANDIDATE | `/pairing-codes`, `/enrollment` | Child scope / retention as applicable |
| P-54 | Cancel/manage subscription | 03-parent-governance-billing Registry | REGISTRY | CANDIDATE | `/billing/catalog`, `/billing/entitlement` | Child scope / retention as applicable |
| P-55 | Optional Google Drive backup | 04-parent-conditional Registry | REGISTRY | CANDIDATE | `/auth/parent/google`, `/parents/me` | Child scope / retention as applicable |
| P-56 | Authorized file access | 04-parent-conditional Registry | REGISTRY | CANDIDATE | `/auth/parent/google`, `/parents/me` | Child scope / retention as applicable |
| P-57 | Photo/video capability request | 04-parent-conditional Registry | REGISTRY | CANDIDATE | `/auth/parent/google`, `/parents/me` | Child scope / retention as applicable |
| P-58 | Microphone capability request | 04-parent-conditional Registry | REGISTRY | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| P-59 | Phone and watch source handoff | 04-parent-conditional Registry | REGISTRY | MANUAL | Local/needs mapping | Child scope / retention as applicable |
| P-60 | Schedule-aware sampling | 04-parent-conditional Registry | REGISTRY | MANUAL | Local/needs mapping | Child scope / retention as applicable |
| C-01 | Child welcome | 05-child-app Registry | REGISTRY | CANDIDATE | `/auth/parent/google`, `/parents/me` | Child scope / retention as applicable |
| C-02 | Child transparency disclosure | 05-child-app Registry | REGISTRY | CANDIDATE | `/auth/parent/google`, `/parents/me` | Child scope / retention as applicable |
| C-03 | Enter pairing code | 05-child-app Registry | REGISTRY | CANDIDATE | `/pairing-codes`, `/enrollment` | Child scope / retention as applicable |
| C-04 | Keystore proof in progress | 05-child-app Registry | REGISTRY | CANDIDATE | `/pairing-codes`, `/enrollment` | Child scope / retention as applicable |
| C-05 | Guardian authority review | 05-child-app Registry | REGISTRY | CANDIDATE | `/auth/parent/google`, `/parents/me` | Child scope / retention as applicable |
| C-06 | Child permission overview | 05-child-app Registry | REGISTRY | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| C-07 | Location Settings guide | 05-child-app Registry | REGISTRY | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| C-08 | Notification Settings guide | 05-child-app Registry | REGISTRY | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| C-09 | Battery & background guide | 05-child-app Registry | REGISTRY | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| C-10 | Usage Access (disabled) | 05-child-app Registry | REGISTRY | CANDIDATE | `/children/{childId}/usage`, `/children/{childId}/usage/apps` | Child scope / retention as applicable |
| C-11 | Managed DPC setup | 05-child-app Registry | REGISTRY | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| C-12 | Monitoring center | 05-child-app Registry | REGISTRY | CANDIDATE | `/account/deletion-request`, `/account/export-requests` | Child scope / retention as applicable |
| C-13 | Child device health | 05-child-app Registry | REGISTRY | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| C-14 | Encrypted offline queue | 05-child-app Registry | REGISTRY | MANUAL | Local/needs mapping | Child scope / retention as applicable |
| C-15 | Child quick check-in | 05-child-app Registry | REGISTRY | CANDIDATE | `/devices/{deviceId}/sos`, `/children/{childId}/sos-events` | Child scope / retention as applicable |
| C-16 | SOS status and manual call | 05-child-app Registry | REGISTRY | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| C-17 | Access withdrawn | 05-child-app Registry | REGISTRY | CANDIDATE | `/account/deletion-request`, `/account/export-requests` | Child scope / retention as applicable |
| C-18 | Child settings & appearance | 05-child-app Registry | REGISTRY | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| C-19 | Managed rule status | 05-child-app Registry | REGISTRY | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| C-20 | Optional media capture request | 05-child-app Registry | REGISTRY | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | OS + legal feature gate |
| C-21 | Secure re-enrollment | 05-child-app Registry | REGISTRY | CANDIDATE | `/pairing-codes`, `/enrollment` | Child scope / retention as applicable |
| A-01 | Welcome to Alarka | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=23-3) | DIRECT | CANDIDATE | `/auth/parent/google`, `/parents/me` | Child scope / retention as applicable |
| A-02 | Checking this device | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=23-27) | DIRECT | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| A-03 | Compatibility result | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=23-51) | DIRECT | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| A-04 | Feature details | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=23-78) | DIRECT | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| A-05 | Secure device pairing | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=23-105) | DIRECT | CANDIDATE | `/auth/parent/google`, `/parents/me` | Child scope / retention as applicable |
| A-06 | Before permissions | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=23-129) | DIRECT | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| A-07 | Location while using | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=23-153) | DIRECT | CANDIDATE | `/children/{childId}/position`, `/children/{childId}/locations` | Child scope / retention as applicable |
| A-08 | Background location | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=23-177) | DIRECT | CANDIDATE | `/children/{childId}/position`, `/children/{childId}/locations` | Child scope / retention as applicable |
| A-09 | Monitoring notifications | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=23-201) | DIRECT | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| A-10 | Usage access | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=23-225) | DIRECT | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| A-11 | Choose media access | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=23-249) | DIRECT | CANDIDATE | `/children/{childId}/media/requests`, `/parents/me/media-activity` | OS + legal feature gate |
| A-12 | Microphone permission | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=23-276) | DIRECT | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| A-13 | Camera access · Research | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=24-2) | DIRECT | CANDIDATE | `/children/{childId}/media/requests`, `/parents/me/media-activity` | OS + legal feature gate |
| A-14 | Managed-device mode | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=24-29) | DIRECT | CANDIDATE | `/pairing-codes`, `/enrollment` | Child scope / retention as applicable |
| A-15 | Screen-sharing consent | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=24-53) | DIRECT | CANDIDATE | `/auth/parent/google`, `/parents/me` | OS + legal feature gate |
| A-16 | Android decision received | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=24-80) | DIRECT | MANUAL | Local/needs mapping | Child scope / retention as applicable |
| A-17 | Permission declined | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=24-104) | DIRECT | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| A-18 | Selected photos only | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=24-128) | DIRECT | CANDIDATE | `/children/{childId}/media/requests`, `/parents/me/media-activity` | Child scope / retention as applicable |
| A-19 | Permission confirmed | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=24-155) | DIRECT | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| A-20 | Setup complete | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=24-179) | DIRECT | MANUAL | Local/needs mapping | Child scope / retention as applicable |
| A-21 | Access changed in Settings | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=24-206) | DIRECT | CANDIDATE | `/children/{childId}/media/requests`, `/parents/me/media-activity` | Child scope / retention as applicable |
| A-22 | Re-enable a permission | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=24-233) | DIRECT | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| A-23 | Offline changes queued | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=24-257) | DIRECT | MANUAL | Local/needs mapping | Child scope / retention as applicable |
| A-24 | Your monitoring controls | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=24-284) | DIRECT | CANDIDATE | `/account/deletion-request`, `/account/export-requests` | Child scope / retention as applicable |
| P-01 | Child device connecting | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=25-2) | DIRECT | CANDIDATE | `/pairing-codes`, `/enrollment` | Child scope / retention as applicable |
| P-02 | Device overview | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=25-26) | DIRECT | CANDIDATE | `/faqs`, `/support/tickets` | Child scope / retention as applicable |
| P-03 | Feature compatibility | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=25-53) | DIRECT | MANUAL | Local/needs mapping | Child scope / retention as applicable |
| P-04 | Setup progress | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=25-80) | DIRECT | MANUAL | Local/needs mapping | Child scope / retention as applicable |
| P-05 | Access granted | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=25-107) | DIRECT | MANUAL | Local/needs mapping | Child scope / retention as applicable |
| P-06 | Permission disabled | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=25-131) | DIRECT | CANDIDATE | `/auth/parent/google`, `/parents/me` | Child scope / retention as applicable |
| P-07 | Denied or unsupported? | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=25-158) | DIRECT | CANDIDATE | `/faqs`, `/support/tickets` | Child scope / retention as applicable |
| P-08 | Temporary access | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=25-182) | DIRECT | CANDIDATE | `/children/{childId}/position`, `/children/{childId}/locations` | Child scope / retention as applicable |
| P-09 | Partial media access | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=25-206) | DIRECT | CANDIDATE | `/children/{childId}/media/requests`, `/parents/me/media-activity` | OS + legal feature gate |
| P-10 | Remote camera conditions | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=25-233) | DIRECT | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | OS + legal feature gate |
| P-11 | Screen request approval | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=25-260) | DIRECT | CANDIDATE | `/children/{childId}/media/requests`, `/parents/me/media-activity` | OS + legal feature gate |
| P-12 | Managed-mode requirement | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=25-284) | DIRECT | CANDIDATE | `/auth/parent/google`, `/parents/me` | Child scope / retention as applicable |
| P-13 | Alarka is offline | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=26-2) | DIRECT | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| P-14 | Status needs recheck | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=26-29) | DIRECT | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| P-15 | Status restored | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=26-53) | DIRECT | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| P-16 | Permission change history | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=26-80) | DIRECT | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| P-17 | How to enable location | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=26-107) | DIRECT | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| P-18 | Guardian access check | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=26-134) | DIRECT | CANDIDATE | `/auth/parent/google`, `/parents/me` | Child scope / retention as applicable |
| P-19 | Report version conflict | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=26-158) | DIRECT | CANDIDATE | `/admin/auth/google`, `/admin/access/requests` | Child scope / retention as applicable |
| P-20 | Privacy switch disabled | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=26-185) | DIRECT | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | Child scope / retention as applicable |
| P-21 | Approval reversed | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=26-212) | DIRECT | CANDIDATE | `/auth/parent/google`, `/parents/me` | Child scope / retention as applicable |
| P-22 | Full compatibility details | 06-capability-onboarding [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=26-239) | DIRECT | CANDIDATE | `/faqs`, `/support/tickets` | Child scope / retention as applicable |
| PA-01 | Media activity | 07-media-activity-audit [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=32-3) | DIRECT | CANDIDATE | `/auth/parent/google`, `/parents/me` | OS + legal feature gate |
| PA-02 | Choose a child | 07-media-activity-audit [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=32-29) | DIRECT | CANDIDATE | `/families`, `/families/{familyId}/children` | OS + legal feature gate |
| PA-03 | Date range | 07-media-activity-audit [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=32-59) | DIRECT | CANDIDATE | `/account/deletion-request`, `/account/export-requests` | OS + legal feature gate |
| PA-04 | Filter results | 07-media-activity-audit [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=32-89) | DIRECT | MANUAL | Local/needs mapping | OS + legal feature gate |
| PA-05 | Session details | 07-media-activity-audit [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=32-119) | DIRECT | CANDIDATE | `/auth/parent/google`, `/parents/me` | OS + legal feature gate |
| PA-06 | Saved recording details | 07-media-activity-audit [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=32-153) | DIRECT | CANDIDATE | `/account/deletion-request`, `/account/export-requests` | OS + legal feature gate |
| PA-07 | Why did it fail? | 07-media-activity-audit [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=32-187) | DIRECT | MANUAL | Local/needs mapping | OS + legal feature gate |
| PA-08 | No matching activity | 07-media-activity-audit [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=32-221) | DIRECT | CANDIDATE | `/auth/parent/google`, `/parents/me` | OS + legal feature gate |
| PA-09 | Historical activity offline | 07-media-activity-audit [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=32-247) | DIRECT | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | OS + legal feature gate |
| PA-10 | Browse more activity | 07-media-activity-audit [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=32-277) | DIRECT | MANUAL | Local/needs mapping | OS + legal feature gate |
| PA-11 | Access not available | 07-media-activity-audit [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=32-303) | DIRECT | CANDIDATE | `/families`, `/families/{familyId}/children` | OS + legal feature gate |
| ADM-01 | Administrator sign-in | 07-media-activity-audit [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=33-2) | DIRECT | CANDIDATE | `/auth/parent/google`, `/parents/me` | OS + legal feature gate |
| ADM-02 | Operations overview | 07-media-activity-audit [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=33-48) | DIRECT | CANDIDATE | `/faqs`, `/support/tickets` | OS + legal feature gate |
| ADM-03 | Request case-based access | 07-media-activity-audit [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=33-98) | DIRECT | MANUAL | Local/needs mapping | OS + legal feature gate |
| ADM-04 | Media activity explorer | 07-media-activity-audit [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=33-148) | DIRECT | CANDIDATE | `/children/{childId}/media/requests`, `/parents/me/media-activity` | OS + legal feature gate |
| ADM-05 | Search parent accounts | 07-media-activity-audit [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=33-198) | DIRECT | MANUAL | Local/needs mapping | OS + legal feature gate |
| ADM-06 | Search children | 07-media-activity-audit [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=33-244) | DIRECT | MANUAL | Local/needs mapping | OS + legal feature gate |
| ADM-07 | Media record details | 07-media-activity-audit [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=33-290) | DIRECT | CANDIDATE | `/children/{childId}/media/requests`, `/parents/me/media-activity` | OS + legal feature gate |
| ADM-08 | Failure reason & evidence | 07-media-activity-audit [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=33-344) | DIRECT | MANUAL | Local/needs mapping | OS + legal feature gate |
| ADM-09 | No results or no access | 07-media-activity-audit [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=33-394) | DIRECT | MANUAL | Local/needs mapping | OS + legal feature gate |
| ADM-10 | Pagination and retry | 07-media-activity-audit [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=34-2) | DIRECT | CANDIDATE | `/children/{childId}/position`, `/children/{childId}/locations` | OS + legal feature gate |
| ADM-11 | Administrator access audit | 07-media-activity-audit [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=34-52) | DIRECT | CANDIDATE | `/account/deletion-request`, `/account/export-requests` | OS + legal feature gate |
| ADM-12 | Privacy and retention gates | 07-media-activity-audit [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=34-102) | DIRECT | CANDIDATE | `/account/deletion-request`, `/account/export-requests` | OS + legal feature gate |
| ADM-13 | Session expired | 07-media-activity-audit [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=34-152) | DIRECT | CANDIDATE | `/auth/parent/google`, `/parents/me` | OS + legal feature gate |
| ADM-14 | Access denied | 07-media-activity-audit [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=34-198) | DIRECT | CANDIDATE | `/admin/auth/google`, `/admin/access/requests` | OS + legal feature gate |
| ADM-15 | Controlled export request | 07-media-activity-audit [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=34-248) | DIRECT | CANDIDATE | `/account/deletion-request`, `/account/export-requests` | OS + legal feature gate |
| ADM-16 | Role and case assignment | 07-media-activity-audit [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=34-298) | DIRECT | MANUAL | Local/needs mapping | OS + legal feature gate |
| ADM-17 | Audit service unavailable | 07-media-activity-audit [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=34-352) | DIRECT | CANDIDATE | `/admin/auth/google`, `/admin/access/requests` | OS + legal feature gate |
| ST-01 | A Mother's Wisdom | 09-theme-c-story-and-screens [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=46-164) | DIRECT | STORY | Local/needs mapping | OS + legal feature gate |
| ST-02 | Alarka's Responsibility | 09-theme-c-story-and-screens [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=46-177) | DIRECT | STORY | Local/needs mapping | OS + legal feature gate |
| ST-03 | The Ring of Counsel | 09-theme-c-story-and-screens [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=46-190) | DIRECT | STORY | Local/needs mapping | OS + legal feature gate |
| ST-04 | Remembering Her Words | 09-theme-c-story-and-screens [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=46-203) | DIRECT | STORY | Local/needs mapping | OS + legal feature gate |
| ST-05 | The Path to Wisdom | 09-theme-c-story-and-screens [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=46-216) | DIRECT | STORY | Local/needs mapping | OS + legal feature gate |
| P-05 |  | 09-theme-c-story-and-screens [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=52-164) | DIRECT | MANUAL | Local/needs mapping | OS + legal feature gate |
| P-15 |  | 09-theme-c-story-and-screens [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=52-192) | DIRECT | MANUAL | Local/needs mapping | OS + legal feature gate |
| P-24 |  | 09-theme-c-story-and-screens [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=52-212) | DIRECT | MANUAL | Local/needs mapping | OS + legal feature gate |
| P-28 |  | 09-theme-c-story-and-screens [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=52-237) | DIRECT | MANUAL | Local/needs mapping | OS + legal feature gate |
| P-39 |  | 09-theme-c-story-and-screens [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=52-263) | DIRECT | MANUAL | Local/needs mapping | OS + legal feature gate |
| P-48 |  | 09-theme-c-story-and-screens [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=52-281) | DIRECT | MANUAL | Local/needs mapping | OS + legal feature gate |
| P-58 |  | 09-theme-c-story-and-screens [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=52-303) | DIRECT | MANUAL | Local/needs mapping | OS + legal feature gate |
| C-02 |  | 09-theme-c-story-and-screens [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=52-337) | DIRECT | MANUAL | Local/needs mapping | OS + legal feature gate |
| P-31 |  | 09-theme-c-story-and-screens [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=52-317) | DIRECT | MANUAL | Local/needs mapping | OS + legal feature gate |
| P-47 |  | 09-theme-c-story-and-screens [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=81-179) | DIRECT | MANUAL | Local/needs mapping | OS + legal feature gate |
| P-49 |  | 09-theme-c-story-and-screens [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=81-201) | DIRECT | MANUAL | Local/needs mapping | OS + legal feature gate |
| SH-01 |  | 09-theme-c-story-and-screens [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=84-179) | DIRECT | MANUAL | Local/needs mapping | OS + legal feature gate |
| SH-02 |  | 09-theme-c-story-and-screens [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=84-201) | DIRECT | MANUAL | Local/needs mapping | OS + legal feature gate |
| SH-03 |  | 09-theme-c-story-and-screens [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=84-221) | DIRECT | MANUAL | Local/needs mapping | OS + legal feature gate |
| SH-04 |  | 09-theme-c-story-and-screens [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=84-242) | DIRECT | MANUAL | Local/needs mapping | OS + legal feature gate |
| SH-05 |  | 09-theme-c-story-and-screens [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=84-263) | DIRECT | MANUAL | Local/needs mapping | OS + legal feature gate |
| SH-06 |  | 09-theme-c-story-and-screens [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=89-180) | DIRECT | MANUAL | Local/needs mapping | OS + legal feature gate |
| BO-01 | BO-01 / Sign in · access required | 10-admin-back-office [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=106-2) | DIRECT | CANDIDATE | `/auth/parent/google`, `/parents/me` | RBAC / child privacy |
| BO-02 | BO-02 / Complete profile · verify email | 10-admin-back-office [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=106-35) | DIRECT | CANDIDATE | `/admin/auth/google`, `/admin/access/requests` | RBAC / child privacy |
| BO-02V | BO-02V / Verified profile · submit request | 10-admin-back-office [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=106-71) | DIRECT | MANUAL | Local/needs mapping | RBAC / child privacy |
| BO-03 | BO-03 / Request submitted · awaiting approval | 10-admin-back-office [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=106-106) | DIRECT | CANDIDATE | `/devices/{deviceId}/capabilities`, `/devices/{deviceId}/permission-snapshots` | RBAC / child privacy |
| BO-04 | BO-04 / Owner · review access requests | 10-admin-back-office [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=107-2) | DIRECT | CANDIDATE | `/admin/auth/google`, `/admin/access/requests` | RBAC / child privacy |
| BO-05 | BO-05 / FAQ pages · content management | 10-admin-back-office [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=107-44) | DIRECT | CANDIDATE | `/faqs`, `/support/tickets` | RBAC / child privacy |
| BO-06 | BO-06 / Support requests · conversation | 10-admin-back-office [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=107-85) | DIRECT | CANDIDATE | `/faqs`, `/support/tickets` | RBAC / child privacy |
| BO-07 | BO-07 / Subscribers · plans and payments | 10-admin-back-office [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=107-123) | DIRECT | CANDIDATE | `/billing/catalog`, `/billing/entitlement` | RBAC / child privacy |
| BO-08 | BO-08 / Subscribers · child roster & parent service usage | 10-admin-back-office [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=107-161) | DIRECT | CANDIDATE | `/billing/catalog`, `/billing/entitlement` | RBAC / child privacy |
| BO-09 | BO-09 / Super Admin · overview and access security | 10-admin-back-office [Open](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=107-202) | DIRECT | CANDIDATE | `/admin/auth/google`, `/admin/access/requests` | RBAC / child privacy |

## Agent completion protocol

For each screen, register actual HTTP method + operationId, exact request/response fields, security audience, DB table/view, fallback/error state, UI automated test, and linked Figma frame. LOCAL_ONLY narrative screens should have no fake API. Do not mark a screen implemented without compiled app/admin-web, C++ handler, SQL migration with RLS, negative authorization and evidence.

All rows are design audit status only; no Play/legal approval or test completion inferred.

## 2026-10-28 — Supplemental API contract and database audit after initial 187-screen pass

The *historical* 146-operation and 95-schema figures in the report above describe the earlier contract snapshot, not the current master. A further remediation pass strengthened 11 sensitive mutation request bodies, then added 25 additional tightly scoped draft operations: **current `docs/openapi.yaml` has 171 design-only operations, 155 paths and 130 named schemas**. Of the 26 supplemental endpoint suggestions, the unsafe/redundant `POST /admin/owner/access-requests/{requestId}/revoke` was intentionally rejected; the correct authorization object to revoke is an approved role grant/session, leaving the immutable application decision recorded. Full [post-remediation report](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/audits/POST_REMEDIATION_SCREEN_API_DB_REPORT_2026-10-28.md), [187-row updated machine coverage](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/audits/POST_REMEDIATION_SCREEN_API_DB_COVERAGE_2026-10-28.json), and [54 follow-up agent task addendum](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/roadmap/FIGMA_SCREEN_API_DB_REMEDIATION_TASKS_2026-10-28.json). All new API contracts remain UNIMPLEMENTED and all 120 tables remain conceptual except previously existing M1 SQL components; no policy or Play approval is implied.
