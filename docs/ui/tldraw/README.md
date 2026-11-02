# Madalasa–Alarka — Native tldraw Android UI Design System

> **Current product:** **Madalasa** (parent app) + **Alarka** (child app); the GitHub repository is now **[Madalasa-Alarka](https://github.com/methakon/Madalasa-Alarka)**. [English mythological inspiration](../../phases/M0-foundation-and-approvals/02-market-and-feasibility/BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

**Design status:** Editable UI wireframes implemented as native tldraw vector shapes, **not yet executable Android code**.  
**Date:** 2026-10-26 · **Design board:** https://www.tldraw.com/f/-IuhoGjlF7uXC5imxkaL3  
**Native source backup:** [amar-pola-ui-master-snapshot.json](amar-pola-ui-master-snapshot.json) (tldraw editor snapshot with `document.store`, `document.schema`, `session`).  
**Source of requirements:** [SRS](../../phases/M1-secure-platform-foundation/01-requirements-and-architecture/SRS.md), [master M0–M9 milestones](../../phases/M0-foundation-and-approvals/01-project-governance/MASTER_MILESTONE_IMPLEMENTATION_AND_RELEASE_PLAN.md), [M1 Android design](../../phases/M1-secure-platform-foundation/01-requirements-and-architecture/M1_ANDROID_CPP_ARCHITECTURE_AND_IMPLEMENTATION.md), [child privacy legal gate](../../phases/M0-foundation-and-approvals/03-legal-and-privacy/INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md).

## Deliverable inventory

| Actor / page | Screens | Themes | Editable variants |
|---|---:|---:|---:|
| Parent — core navigation and setup | 18 | Light, Dark, Battery Saver | 54 |
| Parent — requirement-based extended flows | 36 | Light, Dark, Battery Saver | 108 |
| Child — transparent setup, permissions and app states | 21 | Light, Dark, Battery Saver | 63 |
| **Total** | **75** | **3** | **225** |

The board has **9 populated tldraw pages**, plus one unused empty starter page. Each phone frame, caption, text label, status strip and control-shaped object is an individual editable tldraw shape; unlike a generated image, they can be selected, moved, resized and restyled. **Buttons are visual prototypes only**, and are not wired to live Android actions.

### Parent core 18 screens

1. Welcome
2. Sign In
3. Sign Up
4. Google Account Login / account chooser
5. Dashboard with observation freshness
6. My Children
7. Child Detail
8. Child App Installation Instructions
9. Pair Child with time-limited code
10. Child Data and Consent Review
11. Permission Guide
12. Detailed Location Permission Coach
13. Battery Settings Coach
14. Device Health and Setup Status
15. Route History
16. Guardian Access
17. Alerts and Check-ins
18. Proposed Billing Plans and App Settings

### Parent extended 36 requirement screens

1. Alert Inbox
2. Alert Detail
3. Reliability Center
4. Map Evidence Legend
5. Travel Day
6. Trip Detail
7. Revised Trip History
8. Named Places List
9. Add Named Place
10. Place Alerts
11. Commute Planner
12. Commute Status
13. App Usage Overview (disabled pending law)
14. App Usage Detail (synthetic only)
15. Remote Commands
16. Find Device
17. Managed Screen Time
18. Managed Rule Preview and Revert
19. Managed Mode Eligibility
20. Device Source Provenance
21. Guardian Invitation
22. Individual Guardian Grant
23. Access Ledger
24. Data Retention
25. Scoped Data Export
26. Account and Child Deletion
27. Support Diagnostic Export
28. Pre-Purchase Capability Check
29. Family Subscription Seats
30. Purchase Review
31. Billing Status
32. Notification and Quiet Hours
33. Battery and Coverage Profiles
34. Cloud Outage and Recovery State
35. Device Permission Changed
36. Subscription Cancellation

### Child 21 screens

1. Visible Child App Welcome
2. Child-Accessible Monitoring Disclosure
3. Pairing Code Entry
4. Android Keystore Challenge
5. Guardian Authority Confirmation
6. Child Permission Overview
7. Android Location Settings Instructions
8. Android Notification Settings Instructions
9. Battery and Background Settings Help
10. Usage Access (legally gated)
11. Fully Managed Device / DPC Provisioning (lab gated)
12. Monitoring Transparency Center
13. Device Health
14. Offline Queue Status
15. Child Quick Check-in
16. SOS Delivery State and Manual Contact
17. Access Revoked
18. Child Theme and Privacy Settings
19. Managed-App Rule Status
20. Optional Media Requests (disabled/not implemented)
21. Secure Device Re-Enrollment

## Edit using tldraw

1. Open [the live editable board](https://www.tldraw.com/f/-IuhoGjlF7uXC5imxkaL3).
2. Switch among pages: Light, Dark, Battery Saver, Parent Extended Light/Dark/Eco, Child Light/Dark/Eco.
3. Select/tweak individual shapes, text, buttons, headings and card backgrounds. Keep a consistent theme per page.
4. For version control, use the backup's `snapshot.document` and `snapshot.session` with a compatible tldraw Editor snapshot import API. This JSON is an **SDK editor snapshot**, not an Android layout XML or ready-made tldraw import button format. Keep the live board as the interactive editing source.
5. When significantly revised, export an updated snapshot and commit it; **GitHub backup is a point-in-time copy and does not sync automatically to tldraw**.

## Implementation contract: Kotlin Jetpack Compose

Use a shared design system with explicit tokens:

| Token | Light | Dark | Battery Saver |
|---|---|---|---|
| Background/surface | White/off-white | Black/charcoal | Warm muted off-white/graphite option |
| Primary action | Accessible blue/teal | High-contrast violet/cyan | Small amber accent |
| Default type | Dark on light | Light on dark | High-contrast static type |
| Motion | Standard low-distraction transitions | Same low-distraction transitions | Reduce or remove ornamental transitions |
| Map | Full map when available | Dark map theme | Static last-observed map preview / on-demand full map |
| Data update | Standard adaptive policy | Standard adaptive policy | Lower **requested** frequency, batching; no guarantee OS will execute on schedule |
| Safety | Always show stale/unknown | Always show stale/unknown | Always show stale/unknown; no hidden or false SOS confirmation |

Suggested packages/components:
- `ui/theme/ThemeMode.kt` and `ColorTokens.kt`: `LIGHT`, `DARK`, `BATTERY_SAVER`, accessibility contrast and Android user override.
- `ui/components/ChildStatusCard.kt`, `ObservationMapCard.kt`, `QualityChip.kt`, `GrantChip.kt`, `PermissionStepCard.kt`, `SetupProgressCard.kt`, `DeviceHealthCard.kt`, `FamilySeatCard.kt`, `AlertAcknowledgement.kt`.
- `ui/flows/ParentOnboardingGraph.kt`, `ChildOnboardingGraph.kt`, `PermissionCoach.kt`, `GuardianGrantFlow.kt`, `MapHistoryGraph.kt`, `BillingGraph.kt`, and `PrivacyDeletionGraph.kt`.
- Typed unidirectional state/ViewModel: `UNKNOWN`, `PERMISSION_REQUIRED`, `DENIED`, `OS_REJECTED`, `UNSUPPORTED`, `QUEUED_OFFLINE`, `SERVER_ACCEPTED`, `PROVIDER_ACCEPTED`, `GUARDIAN_ACK` must not be conflated.
- Parent app may **instruct** child users about permissions, and child app can launch supported Android system settings; **parent app cannot remotely grant Android permissions**. Verify settings on return and reflect actual OS state.
- Distinguish login via Google Credential Manager from verified parent/legal guardian authority; never imply an ID token proves custody.

## Important gates and exclusions

- India under-18 purpose-by-purpose DPDP legal review and parent verification remain unresolved; app usage/history/behavioral monitoring disabled pending signoff. No real child data on test boards.
- OCI Mumbai is proposed, no region-specific infrastructure or RPO/RTO is deployed.
- Emergency SOS cannot promise dispatch or delivery; FCM acceptance is not guardian acknowledgement, SMS/independent backup is unpriced.
- Remote microphone/camera stealth capture is not included; optional visible authorized workflows are research-only.
- ₹50/month and ₹500/year/child remain proposed prices subject to tax and Google Play setup.
- All screens are **visual design artifacts**, not production pixel-perfect layouts, navigation-wired interactions, real App Bundle builds, or Play-compliant screens already tested.

**Next implementation step:** build Compose Navigation graphs and Material 3 components from these individually editable visual specifications. Link each screen to M0–M9 and FR-001–FR-049 traceability while implementing.


## Renamed application family

**Madalasa** is the parent app; **Alarka** is the child app. tldraw's older snapshot remains an editable exploration archive with some former display-name text. The developer handoff and naming policy supersede those old captions. Repository rename to [Madalasa-Alarka](https://github.com/methakon/Madalasa-Alarka) is complete.
