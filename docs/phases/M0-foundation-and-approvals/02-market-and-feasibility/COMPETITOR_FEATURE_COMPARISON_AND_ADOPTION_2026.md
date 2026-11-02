# Competitive Feature Gap & Adoption Report — Madalasa–Alarka

> **Document control:** M0 / 02-market-and-feasibility · Proposed owner: Product + finance (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

> **Current product naming:** **Madalasa** parent/guardian app, **Alarka** child companion; GitHub repository [Madalasa-Alarka](https://github.com/methakon/Madalasa-Alarka). [Brand and Markandeya Purana context](BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

**Revision:** 1.0  
**Research date:** 2026-10-25  
**Status:** Product research and proposed backlog; **not** a confirmation that advertised competitors' features work on all phones  
**Scope:** Five Google Play listings supplied by the project owner; cross-checked against official feature/product guides where available.  
**Madalasa–Alarka baseline:** [SRS](../../M1-secure-platform-foundation/01-requirements-and-architecture/SRS.md), [Technical Architecture](../../M1-secure-platform-foundation/01-requirements-and-architecture/IMPLEMENTATION_TECHNICAL_SPECIFICATION.md), [Adaptive Movement & C++ Server Architecture](../../M2-location-collection/01-location-collection-and-ingestion/ADAPTIVE_MOVEMENT_CPP_SERVER_ARCHITECTURE.md), [Road Tracking & Named Places](../../M3-trips-and-places/01-trips-and-named-places/LIVE_TRIP_ROUTE_NAMED_PLACES_BATTERY_SPECIFICATION.md), [Play Requirements](../../M9-play-release/01-play-and-data-safety/GOOGLE_PLAY_PUBLISHING_REQUIREMENTS.md).

## Executive verdict

**Build a trustworthy, efficient location-and-screen-time platform first.** Borrow the strongest *product patterns*—SOS, find-phone signal, place alerts, family invitation, child-visible limits, quick check-ins, and optional motivational task rewards—without copying any competitor's code, assets or UI.

For Madalasa–Alarka, a credible differentiator is **quality-aware multi-stop trip reconstruction** (accurate stops/gaps/provenance), **energy-adaptive tracking** on phones/tablets/watches, **family/guardian-level access controls**, optional parent-authorized Google Drive storage, and **honest Android capability/status reporting**. These are **proposed advantages**, not independently verified deficiencies in competitor products.

**Most important qualification:** A Play listing is *marketing evidence*, not reverse engineering, device benchmarking, security audit, or proof that a claimed feature works on the latest Android. Features vary by child companion app, Android version, OEM, plan, geography and permissions. “Not listed” means **not confirmed from reviewed materials**, not “doesn't exist.”

## 1. The five products as currently listed

| Supplied package | Currently displayed Play product | Positioning | Best feature ideas to study |
|---|---|---|---|
| org.findmykids.app | **Findmykids: Parental Control / Location tracker** (LETEM LTD; listing wording can vary by region/time) | Child safety and location-centric | Live routes, safe zones, SOS, sound alert when child device is muted, supported watches, app-use reports |
| com.sygic.familywhere.android | **Find my Phone – Family Locator** (GEO TRACK LABS LTD at review), **not branded “Sygic FamilyWhere”** in its current Play listing | Consensual family-circle location sharing | Invite/accept family circle, private family map, check-ins, SOS, chat, flight-related alerts |
| com.pinaidea.pinaguardian.parent | **Pinardin: Parental Control** (Pinardin) | Broad monitoring, activity and restrictions | Parental controls, web filtering, notifications, location/geofencing; marketed remote camera/audio/screen view need cautious separate evaluation |
| com.wondershare.famisafe | **FamiSafe** (Wondershare) | Comprehensive screen-time, location, content and device supervision | Screen-time rules, app/website controls, browser history, geofences, driving report, SOS, co-parenting; also markets screenshots/audio |
| app.kids360.parent | **Kids360: Parental Control** (MINDCARE LAB LTD) | Screen-time management and child engagement; **Alli360** companion | Daily and per-app limits, school/sleep schedules, essential-app exclusions, usage stats, screen-time rewards, child-visible limits |

### Notes worth preserving

1. The historical **Sygic package ID** is unchanged, but the live listing names **GEO TRACK LABS LTD** and *Find my Phone – Family Locator*. Do not attribute its current feature set to the current Sygic navigation product.
2. **Findmykids** has a location-centric feature set and explicitly markets a paired child app/watch approach. Its official site also markets app blocking/screen time in a higher tier, so don't classify it as “location only.”
3. **Pinardin** officially advertises remote camera, one-way audio, screen view, notifications and website/history features. Its feature site also describes a one-tap access request with **child notification** for camera and notification with microphone activation. This does not establish support for hidden background capture or demonstrate how the Android implementation works.
4. **FamiSafe** describes feature/platform differences in its user guide, including driving reports, geofencing, advanced screen time and content checks. Its marketing of one-way audio/screen viewer is not proof a background app may bypass OS restrictions.
5. **Kids360** describes an explicitly visible child agent (**Alli360**) with screen-time warnings, approved safe apps, earned time, and activity-based tasks. Its Play listing describes overlay, Usage Access and device-admin privileges for its child-side behavior; those do **not** imply ordinary apps gain unrestricted DevicePolicyManager package-suspension authority.

## 2. Competitor feature matrix

**Legend:** **Y** = explicitly advertised in reviewed official sources; **?** = not clearly established from reviewed sources; **AP** = already proposed in Madalasa–Alarka documents; **ADD** = candidate addition; **DEFER** = conditional/high-risk research. This is a marketed-feature comparison, not a tested feature verification.

| Feature | Findmykids | Family Locator | Pinardin | FamiSafe | Kids360 | Madalasa–Alarka assessment |
|---|:---:|:---:|:---:|:---:|:---:|---|
| Live/latest GPS on map | Y | Y | Y | Y | Y | AP |
| Routes and history | Y | Y | Y | Y | Y | AP; differentiate with truthful gaps/stops |
| Saved places / arrival-departure alerts | Y | Y | Y | Y | Y | AP; complete alerts |
| SOS from child's device | Y | Y | ? | Y | ? | **ADD P0** |
| Ring/find phone even when silent | Y | ? | ? | ? | Y | **ADD P0/P1**, respect DND |
| Battery level, offline and last-seen | ? | ? | ? | ? | Y | **ADD P0** |
| Family circle / multiple guardians | Y | Y | ? | Y | Y | AP; improve invitations, roles |
| One-tap “I'm safe” check-in | ? | Y | ? | ? | ? | **ADD P1** |
| In-app family chat | ? | Y | ? | ? | ? | **ADD P2**, optional |
| App use duration reports | Y | ? | Y | Y | Y | AP |
| Per-app daily limit / schedules | Y | ? | Y | Y | Y | AP conditionally managed; improve UX |
| Essential apps excluded from restrictions | ? | ? | ? | Y | Y | **ADD P1 safety policy** |
| Child-visible time remaining and warnings | ? | ? | ? | ? | Y | **ADD P1** |
| Earn screen time for completed tasks | ? | ? | ? | ? | Y | **ADD P2** |
| Web category filtering / site blocking | ? | ? | Y | Y | Y | **RESEARCH P2** |
| Driving behavior/speed reports | ? | ? | ? | Y | ? | AP speed; **ADD P1** optional safety report |
| Camera / one-way audio / remote screen | Audio marketed | ? | Y | Y | ? | **DEFER**: authorized/visible only |
| Calls/social/chat/keyword surveillance | Call filter marketed | ? | Y | Y | ? | **DO NOT ADOPT AS DEFAULT** |
| Watch tracking integration | Y | ? | ? | ? | ? | AP; optimize Wear capability testing |
| Flight tracking | ? | Y | ? | ? | ? | **DEFER** (low relevance) |
| Parent Google Drive media backup | ? | ? | ? | ? | ? | AP; potential positioning, absence not proven |

A Y means the feature is described in the reviewed sources for at least one supported configuration; platform and subscription requirements may vary. Child-app companion functionality is part of the vendor product, not necessarily the parent APK alone.

## 3. Feature-by-feature adoption decisions

### A. Immediate/high-value: SOS emergency button (P0)

**Why:** Findmykids, Family Locator and FamiSafe market SOS. SOS can provide a child-initiated safety action without persistent high-rate location polling.

**Implementation:**
- Child-visible prominent SOS control with a confirmation or long-press design to reduce accidental activation; accessible emergency contact guidance.
- Capture last known position, observation time/accuracy, battery/connectivity and child/device IDs, with permission-compliant optional fresh-fix attempt.
- Queue durable **high-priority** \`SOS_RAISED\` event on device; backend authenticates and fans out notifications to **authorized guardians only** (FCM or equivalent).
- Parent acknowledge/dismiss/mark resolved; retries, audit, dedupe and escalation rules configurable.
- Never imply 24/7 human monitoring, precise availability or emergency-services dispatch. If offline, show queued/unknown delivery rather than “parent notified.”

**Backend:** separate priority queue from trip reconstruction; \`sos_events\`, \`notification_deliveries\`, \`guardian_acknowledgments\`.
**Tests:** offline SOS, false tap, no GPS, revoked guardian, clock skew, repeated presses, duplicate push.

### B. High-value: find-device / loud signal (P0/P1)

**Why:** Findmykids and Kids360 advertise a way to find a muted device.

**Implementation:** guardian-authenticated, rate-limited \`FIND_DEVICE_RING\` with command TTL (e.g. 60 seconds), app-visible explanation and optional clear child notification. Play a bounded sound only using permitted audio behavior and device capabilities. **Do not guarantee bypass of Android DND/silent restrictions** or manipulate system sound settings without explicit special access and Play review.

**Backend:** per-device command queue already proposed; response \`COMPLETED\`, \`OS_RESTRICTED\`, \`OFFLINE\`, etc.
**Tests:** muted/DND, headphones, interrupted audio, offline, expired command and spam abuse.

### C. High-value: device health & reliability (P0)

**Why:** Kids360's public product information describes battery level. Unexplained GPS gaps undermine parent trust.

**Implementation:** occasional low-cost \`device_status\` heartbeat piggybacked on existing location/usage upload: battery percent (when available), charging, API level/permission capability, last_seen, queue age and source device type. Parent should see:
- “last GPS fix 12 min ago ±80 m”
- “device battery 18%; last status 3 min ago”
- “offline / GPS disabled / Usage Access missing” only if substantiated.

Avoid frequent standalone battery polling and avoid assuming the child is personally present just because the device is.

### D. Essential: saved zones and trustworthy trip/stops (P0/P1)

**Why:** all five market at least location and place features; visual and analytical quality matters more than collecting GPS every few seconds.

**Madalasa–Alarka status:** Already thoroughly specified:
- Parent titles map coordinates; proximity matching on C++ server.
- Event-time route reconstruction with raw tracks, gap segments, detected stops and real timestamp confidence.
- Optional server/Android geofencing subset for arrival/departure; delayed and uncertain status exposed.
- No additional GPS collection simply because several parents open the map.
- High-detail road matching only with adequate samples and Maps/Roads commercial licensing.

**Add from competitors' UX:** one-tap “Set Home/School,” alerts per named place, weekly recurring location-rule schedule and shareable child safety timeline (authorized guardians only).

### E. Essential: co-parent/family circle without over-sharing (P0/P1)

**Why:** Family Locator's consent-based invite model and FamiSafe co-parenting are strong patterns.

**Implementation:** \`family\` + \`child\` + \`guardian_membership\` + \`guardian_child_grant\` with OWNER/GUARDIAN/VIEWER roles. Short-lived invite QR/link, verified acceptance, audit and immediate revoke. Scope \`view_current_location\`, \`view_history\`, \`manage_places\`, \`manage_controls\`, \`receive_sos\` separately. Avoid unlimited history access just because a person joined a “circle.” Accounts and guardians remain bound to actual child authorization and Play parental-monitoring policy.

### F. High-value: screen time with clear rules, safe apps and warnings (P1)

**Why:** Kids360 demonstrates that visible time remaining, bedtime/school profiles and positive reinforcement can be more usable than unexpected hard blocks.

**Implementation:**
- Existing UsageStats aggregates: daily/weekly/monthly/yearly by app and category, with historical completeness warnings.
- Rule engine: daily quota, per-package limit, school-day/night schedule, holidays, override until date, parent “add 15 minutes” allowance.
- **Protect essential functions**: dialer, emergency services, device setup/permission controller and required system components; allowlist must be enforced even in managed mode.
- Eligible managed devices use supported \`DevicePolicyManager\` package suspension. **Ordinary installation does not have universal app-stop authority.**
- Child-visible remaining-time screen and warnings (when rules are enabled); audit policy transitions and user explanation. Do not promise no warning/notification.
- Overlay/accessibility alternatives require separate policy and usability scrutiny; do not use AccessibilityService to spy or bypass limitations.

**Tests:** DST/time-zone shifts, reboot/offline policy, unsuspendable packages, restore, quota rollover, disabled Usage Access, emergency app safety.

### G. Candidate: one-tap check-in and optional family messaging (P1/P2)

**Why:** Family Locator advertises quick check-ins and private chat.

**Phase 1:** “I'm safe,” “Need pickup,” “Please call” preset messages with acknowledgement; small encrypted messages, no background microphone access.
**Phase 2:** optional text chat between child and authorized guardians with short retention, abuse prevention, delivery/notification status and opt-out. Do not confuse this with monitoring the child's unrelated messages.

### H. Candidate: driving/movement safety insights (P1/P2)

**Why:** FamiSafe promotes driving reports; Madalasa–Alarka already captures speed, routes and trip stop data.

**Implementation:** only if location accuracy/speed confidence is high enough: trip duration, speed range, optionally unusual rapid movement events **with confidence indicators**. Do not infer traffic offences, collisions or driver identity from sparse GPS. Vehicle motion could be bus/train/passenger. Avoid frequent sensor sampling solely for a flashy score.

### I. Candidate: child-earned screen time tasks (P2)

**Why:** Kids360 differentiates on incentives and active child participation.

**Implementation:** optional parent-created chore/learning task, parent approval, small bonus-time credit, expiration and anti-replay event ledger. Only grant bonus to a permitted app/time quota; don't incentivize disclosure of personal data, constant exercise/video capture, or excessive phone use. Start with manual parent-approved tasks, not camera-based exercise recognition.

### J. Candidate: web/content filtering (P2 research)

**Why:** Pinardin and FamiSafe market site filters; Kids360 also markets safer browsing.

**Implementation choices must be explicit:** a supervised in-app browser can filter its own traffic; a user-consented \`VpnService\`-based DNS/domain filter can cover more traffic but creates very substantial privacy, bypass, battery, compatibility and policy obligations. Encrypted DNS/VPN, app-specific proxies and browser sandboxing complicate effectiveness. Do not promise access to browser incognito history or arbitrary encrypted messages across all apps.

**Recommendation:** defer until GPS, SOS and usage controls are mature; offer a narrow, transparent, opt-in domain/category filter only with independent review.

### K. Do not simply copy marketed screen/audio surveillance features

Pinardin and FamiSafe market camera, one-way audio and screenshots. This does not establish their technical approach, the OS/version matrix, child notification model or independent Play approval for an Madalasa–Alarka equivalent.

**Decision:** No covert capture, hidden microphone activation, interception of other apps' private messages or continuous screen collection. If future requirements include capture, evaluate only supported, clearly authorized and visible workflows on real Android devices, respecting privacy indicators and Play monitoring rules, then publish a separate decision record. These features are **not** a core product differentiator to pursue before trustworthy location and control features.

## 4. Product fit and differentiators

| Positioning dimension | Competitor inspiration | Madalasa–Alarka opportunity |
|---|---|---|
| Trusted location | Findmykids / Family Locator | Mark gaps, accuracy and last-seen reliably; label known stops vs proximity |
| Family coordination | Family Locator | Granular guardian grants, check-in, acknowledgement and alert settings |
| Responsible screen-time management | Kids360 | Visible schedules and optional rewards; safe-app exclusion; managed-mode precision |
| Broad suite | FamiSafe / Pinardin | Avoid high-risk surveillance feature bloat, prioritize privacy, compatibility and battery |
| Watch/phone interoperability | Findmykids | Separate source provenance, energy-aware Wear OS tracking and continuity status |
| Storage and control | Existing Madalasa–Alarka proposal | Parent-approved Drive backup, retention choices, secure data deletion and transparent access logs |
| Performance | Project architecture | C++ event-time trip reconstruction, durable batching and multi-tenant API security |

**Avoid unsubstantiated competitive claims** such as “competitors have poor battery life” or “none offer secure history.” We did not test their binaries, telemetry efficiency or security.

## 5. Proposed prioritized backlog (not automatically approved SRS)

Effort estimate is **relative only**: S=small, M=medium, L=large, XL=very large. These are not delivery time promises.

| Proposal ID | Feature | Value | Complexity | Android / security risk | Recommendation |
|---|---|---|---|---|---|
| COMP-001 | SOS with guardian acknowledgement | Very high | M | M: offline/alerts | **P0 adopt** |
| COMP-002 | Battery, last seen and permission health | Very high | S–M | Low–M | **P0 adopt** |
| COMP-003 | Loud find-device signal | High | M | M: DND/audio behavior | **P0/P1 adopt with honest status** |
| COMP-004 | One-tap named safe zones and entry alerts | Very high | M | M: false geofence alerts | **P0/P1 enhance planned** |
| COMP-005 | Guardian invite/consent and scoped sharing | Very high | M–L | **High: child-data authorization** | **P0 security-critical** |
| COMP-006 | Child-safe scheduled app rules + whitelist | High | L | High: provisioning/eligibility | **P1 conditional managed** |
| COMP-007 | Remaining-time warnings / visible rules | High | M | M: child UX | **P1 adopt** |
| COMP-008 | Simple “I'm safe / Call me” check-in | High | S–M | Low–M | **P1 adopt** |
| COMP-009 | Driving report / movement insights | Medium | M–L | M: inference accuracy | **P1/P2 cautiously** |
| COMP-010 | Chore/learning reward time | Medium | M–L | M: gamification/control consistency | **P2** |
| COMP-011 | Optional family text chat | Medium | L | High: retention/access/moderation | **P2 only if demanded** |
| COMP-012 | Transparent website category filter | Medium | XL | High: VPN/privacy/Play | **P2 research** |
| COMP-013 | Flight tracking | Low | L | External APIs/cost | **Do not prioritize** |
| COMP-014 | Notification/social/call interception | High sensitivity, uncertain product fit | XL | Very high privacy/platform/legal | **Reject as default** |
| COMP-015 | Unannounced camera/audio/screen monitoring | Not acceptable | — | Prohibited stealth/policy risk | **Do not adopt** |

## 6. Suggested first-release feature packages

**Free/entry tier (proposal):** secure pairing, latest location with timestamp/accuracy, recent limited route, SOS, device battery/online status, a small number of named places, basic usage summary and account deletion. Do not put basic SOS and safety disclosures behind an unexpected paywall.

**Family tier (proposal):** extended trip history, multiple named places/geofence rules, detailed daily-to-yearly usage reports, multiple guardian accounts, stop timeline, parental alert settings.

**Advanced/managed tier (only where supported):** eligible app-block schedules, per-app quota, bedtime/school rules, device-owner enrollment and per-policy verification. A paid upgrade cannot grant missing OS privileges.

**Optional add-ons:** authorized Drive backup, Wear OS support after tests, reward tasks, curated web filtering where compliant. Avoid pricing or device-count claims until entitlement model and Play billing policies are decided.

## 7. Architectural changes to implement adopted features

Reuse existing C++ Drogon multi-family model; no unrelated tracking network or parallel auth system.

**Tables/objects to add or formalize:**
- \`emergency_events(event_id,child_id,device_id,raised_at,location_event_id,accuracy_m,status)\`
- \`emergency_deliveries(event_id,guardian_id,notified_at,acknowledged_at,delivery_state)\`
- \`device_health(device_id,observed_at,battery_pct,charging,permission_state,queue_depth,app_version)\`
- \`saved_places\` and \`geofence_events\` (already planned)
- \`guardian_invitations(token_hash,inviter,invited,expires_at,accepted_at)\`
- \`guardian_child_grants\` (already planned)
- \`checkins(id,child_id,actor_device_id,kind,created_at,ack_at)\`
- \`screen_time_policy\` and \`policy_effects\` (already planned)
- \`screen_time_allowance_ledger\` (for optional tasks and manual extra time)

**API proposal:**
- \`POST /v1/devices/{deviceId}/sos\`
- \`POST /v1/children/{childId}/sos/{eventId}/ack\`
- \`GET /v1/children/{childId}/health\`
- \`POST /v1/devices/{deviceId}/commands\` with capability \`FIND_DEVICE_RING\` (parent-authorized route in existing API)
- \`POST /v1/families/{familyId}/guardian-invitations\`; \`POST /v1/guardian-invitations:accept\`
- \`POST /v1/devices/{deviceId}/checkins\`; \`POST /v1/children/{childId}/checkins/{id}/ack\`
- \`POST /v1/children/{childId}/screen-time/allowances\` (supported managed enforcement only)

Each request requires strict principal/device/family ownership, nonce/idempotency, bounded retries and audit. SOS routing should have stronger priority than route-history reconstruction. Device health piggybacks on routine batched sync to minimize battery/radio work.

## 8. Verification / test plan

**Functional:** SOS offline and repeated tap; acknowledgement and denied guardian; loud signal DND/silent and expired TTL; geofence false positives; parental contact scopes; rules not suspending dialer/emergency functions; learning rewards not exceeding configured cap; check-in delivery statuses.

**Battery:** idle, walking, school commute, poor cellular network, watch-to-phone handoff; compare incremental energy with and without new features. Named places, parent viewing and passive check-ins should not inadvertently force high-rate GPS.

**Security:** cross-family event reads; push token interception; guardian invitation replay; unauthorized SOS acknowledgement; notification content on lockscreen; permission revocation; deletion and audit retention.

**Play/compliance:** active monitoring icon/notification, \`isMonitoringTool=child_monitoring\` for relevant child package, prominent location disclosures, Data safety and account deletion. Validate FGS start/background location rules, and do not infer API permission merely from a competitor's marketing copy.

**Acceptance model:** mark each candidate \`DOCUMENTED\`, \`IMPLEMENTED\`, \`DEVICE_TESTED\`, \`POLICY_REVIEWED\`, \`SHIPPED\`; today all new features above are **DOCUMENTED PROPOSALS ONLY**.

## 9. Risks and unresolved questions

1. Which age group and jurisdictions will Madalasa–Alarka support? Impacts consent, communication, child privacy and store audience.
2. Can/should multiple parent accounts share one child without granting full history? Requires fine-grained rights and a clear guardian-authorization protocol.
3. Is a watch a first-class tracking source or only a companion? Impacts cost/battery/UX.
4. What supported managed-device provisioning path will commercial customers tolerate? Device owner enrollment is not a normal permission wizard.
5. How many saved-place alerts and emergency notification retries should be allowed? Must prevent alert fatigue.
6. What should remain free vs paid, including safety-critical SOS and account deletion?
7. Can a child message parent while the child phone is offline? Queue/last-delivery semantics required.
8. For web filters, can the product accept the privacy/battery/support cost? Default **no** for first release.
9. Do not infer how competitors implement background camera/audio/screen access; no reverse engineering performed.
10. Competitor developer listings and features can change; recheck before launching marketing comparisons.

## 10. Primary product sources

- [Findmykids — Google Play](https://play.google.com/store/apps/details?id=org.findmykids.app) and [official features](https://findmykids.org/), [parental control summary](https://findmykids.org/parental-control-app).
- [Find my Phone – Family Locator — Google Play](https://play.google.com/store/apps/details?id=com.sygic.familywhere.android) (current app developer GEO TRACK LABS LTD).
- [Pinardin — Google Play](https://play.google.com/store/apps/details?id=com.pinaidea.pinaguardian.parent) and [official features](https://pinardin.com/feature/).
- [FamiSafe — Google Play](https://play.google.com/store/apps/details?id=com.wondershare.famisafe), [official user guide](https://famisafe.wondershare.com/user-guide/) and [official feature overview](https://famisafe.wondershare.com/).
- [Kids360 — Google Play](https://play.google.com/store/apps/details?id=app.kids360.parent), [official features](https://kids360.app/help/features/?child=android&parent=android), [tasks guide](https://kids360.app/help/how-tasks-work-on-android-from-android/) and [child-app transparency explanation](https://kids360.app/basic-information-about-kids360/).

## 11. Platform-policy sources

- [Google Play monitoring-app policy](https://support.google.com/googleplay/android-developer/answer/9888380)
- [Monitoring manifest flag](https://support.google.com/googleplay/android-developer/answer/12955211)
- [Android DevicePolicyManager package suspension](https://developer.android.com/reference/android/app/admin/DevicePolicyManager)
- [Android FGS/background start restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start)
- [Android geofencing limits](https://developer.android.com/develop/sensors-and-location/location/geofencing)

**Research integrity:** The sources establish developer-advertised capabilities; no APK was installed or reverse-engineered, no paid subscription was activated, and no comparative battery/performance/privacy benchmark was run. The above is an adoption report and proposal, not a competitor certification, validated device feasibility test, or a release approval.

## 12. Explicit conflict with the existing minimal-child-UI requirement

Earlier Madalasa–Alarka discussions require that the child agent's **main Activity normally remains closed after setup**. This does **not** prohibit an identifiable app, required monitoring notification, or an explicitly chosen child interaction.

The following optional interaction modes let the parent preserve the original low-interruption design:

| Proposed new function | Minimal-UI option | Trade-off |
|---|---|---|
| SOS | Persistent monitoring notification action, child home-screen widget or wearable complication where supported | Child must initiate; lockscreen/widget accessibility depends on device/OS. A large optional SOS screen is more discoverable. |
| “I'm safe” check-in | Notification action, widget or optional mini Activity | Avoid continual UI or microphone use |
| Screen-time remaining | Child taps existing monitoring notification to open status, or parent enables visible countdown | Silent hard blocking can be confusing; visible warnings improve fairness and usability |
| Earn-time tasks | **Optional child-facing Activity** | Incompatible with literally never showing the child app, so postpone until product owner approves child UX |
| Loud ring | Parent command triggering permitted sound plus on-device indication | Do not guarantee bypass of DND/silent settings |

**Decision required:** Does “child app never in foreground” mean **no mandatory ongoing screen** (compatible with optional SOS/widget/UI), or **no child interaction at all** (then skip SOS/check-in/rewards, retaining automatic safety alerts and guardian controls)? Neither choice removes Android's required monitoring notices.

## 13. October 2026 parent-feedback and differentiated-experience follow-up

See [Market Feedback, Competitive Gaps & Feasible Differentiation](MARKET_FEEDBACK_GAPS_AND_DIFFERENTIATION_2026.md). This additional research incorporates sampled Google Play reviews, Reddit parent concerns, Life360/Qustodio/Bark/Family Link features and official Android/Play feasibility. It corrects any temptation to call SOS, arrival alerts, extra-time requests, screen-time rewards or driving reports inherently unique. The strongest proposed differentiation is an **evidence-first and privacy-accountable experience**: transparent route gaps, diagnostics, late-trip recovery, time-limited guardian grants and clear feature/billing support states. Every candidate remains pending product/security approval and device testing.
