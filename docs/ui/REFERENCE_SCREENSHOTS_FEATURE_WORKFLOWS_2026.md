# Madalasa–Alarka — User-Supplied Reference Screenshots: Functional Workflow Register

**Owner direction (2026-10-28):** Preserve the 15 screenshots supplied in conversation (two batches, with a repeated parental-controls view), and our discussion of their functional behavior. These are **third-party functional references, not templates, licensed graphics or evidence of Android/Play/legal feasibility**. Screenshot assets were supplied in chat; they are not repository assets and must not be copied into Figma without permission.

**Design identity:** Madalasa–Alarka takes its story from the **Mārkaṇḍeya Purāṇa** (pan-Indian narrative), not a Bengali regional folk tale. **English-only UI in the initial release**. Future localization must be architecturally supported with externalized strings, locale-aware formats and later professionally reviewed translations. Pan-Indian classical/Puranic illustration should remain distinguishable from competitor screenshots and should be original.

## A. Core workflows inferred from the screenshots

| Functional area | Screenshot-visible UI / inferred interaction | Madalasa screen IDs | Product decision / limits |
|---|---|---|---|
| Live map home | Map/satellite/automatic style picker; child marker/avatar, battery/connection, last-known-place chip, recenter; map-source choices; collapsed bottom action sheet | P-05, P-07, P-22 | Actual map provider/attribution; do not invent observations or infer child presence with certainty; map provider mix requires license/cost review |
| Expandable map controls | Collapsed map sheet expands into three important actions (audio/signal/usage), then family/call/places/chat/settings icons, then content and child-status summary | P-05, P-33 | Prototype collapsed/half/full states, preserve map/SOS/error controls; feature actions gated individually |
| Audio around child | Sound waveform, listen/stop control, remaining minute balance, additional-minutes and reward-like affordances | P-58 + media research | Distinguish app trial/paid quotas, verified delivered duration, explicit permission/child-visible behavior; do NOT copy incentivized reward or imply covert recording |
| Device alert signal | Bell/honk request | P-33, P-34 | Child device capability, DND and receipt/timeout, no guaranteed instant remote action |
| Places & notifications | Individual Home/School/relative's house/custom-place switches, visual place types | P-26, P-27, P-28, P-50 | Per-child/per-place enter/exit toggles, radius, hysteresis, stale/uncertain/late notifications |
| Daily activity feed | Chronological cards: social-app usage summaries/icons, nighttime use, low battery, places/step counts, distance, trip previews and date separators | P-15, P-19, P-23, P-31 | Data minimization and permissions; accuracy labeling; no inferred behavioral report unless legal gate approved |
| Journey map | Start/finish map, multicolor walk/ride legs, intermediate points | P-24, P-25 | Event-time route reconstruction, source confidence/gaps, actual observed vs inferred movement modes |
| Journey breakdown | Walk/ride segments, durations/distance, claimed speed, user route accuracy rating | P-24, P-25 | Avoid misleading inconsistent speed, allow optional correction feedback without storing excess child history |
| Usage analytics | Yesterday/Today/Week segmented control, usage histogram, categories/apps, exact-time viewing | P-31, P-32 | Android usage access plus legal child-data approval; unknown is not zero usage |
| Parental app restrictions | Per-app lock/unlimited indicators, 'Block apps', place-based/always/never blocked categories | P-35, P-36, P-37 | **Not a standard Android universal capability**; managed/DPC mode only when demonstrably supported; child transparency |
| Family enrollment | Add parent, add kid, app link, app-referral QR, pairing/onboarding | P-06, P-09, P-16, P-39, C-03 | Keep adult guardian invite, child pairing and app-referral links distinct; separate child-scoped grants, no automatic authority to extended family |
| Family members and device info | Guardian role, additional child, phones/watches, child battery and status | P-06, P-38, P-39 | Paid seat per child rather than guardian or device; distinct guardians/authority and provenance |
| Content recommendations | Articles and guidance cards | P-05 optional | Editorial content is optional, must not displace core safety/observations |
| Chat/super call | Shortcut icons on expanded dashboard | Future conditional feature | No assumption they exist in MVP or bypass Android controls |

## B. Pattern adoption vs deliberate differences

**Adopt as interaction patterns:** location-first home; collapsed/half/expanded action sheet; card-based history; per-place notification toggles; child enrollment and guardian invites; chronological trips; visible quota balance.

**Do not copy:** competitor branding, mascot, screenshots, icons, geographic photos, exact layouts, visual motifs or text. Do not imply all competitor features are technically feasible, lawful, included in the launch plan or already implemented.

**Our visual direction:** original pan-Indian **Markandeya Purana–inspired illustrated storybook** for optional five-page onboarding. Functional monitoring screens are modern, accessible and neutral with restrained lotus, ring and leafy/architectural motifs; do not make map tiles a fantasy map. No regional artistic label should define the source scripture. English-only now.

## C. Product gates that must remain visible

- Trial: 48h once per eligible verified family, compact dismissible countdown; no renewal charge.
- Free after expiry: live location at reduced adaptive Android-allowed sampling and last six hours visible history. Six hours visible != automatic perpetual storage.
- Paid Balanced media quota per child/month: 60 audio minutes, 20 video minutes, 30 photos, 10 screen minutes; 48h trial: 5/2 minutes audio/video, three photos, 2 screen minutes, all gated and shared among authorized guardians.
- Prepaid-only/manual renewal; public ₹99/₹999 and qualifying founding ₹50/₹500 per child for first 1,008 distinct paying families.
- All optional microphone/video/screen/managed app-control functions remain **subject to device, Play and child-law review** and should show unsupported/unavailable state honestly.
- Parent/child permission/revocation, OS capability and consent disclosure never hidden by story art or subscription banners.

## D. English-only now, internationalization-ready later

Source of truth for UI labels is English (`en` base strings). Design all text as editable Figma text and plan Android resource keys (`strings.xml`), no text burned into artwork, locale-safe dates/numbers/amounts, flexible card widths, dynamic type, LTR/RTL testing if future languages require. Do not show language toggles or translated UI in current screenshots. Later translations, cultural review and Play listing localization are separately approved deliverables.

**Screenshot analysis is inference, not verified competitor functionality.** Reference screen descriptions above derive from the screenshots and project discussions, not an inspection of a running third-party app.
