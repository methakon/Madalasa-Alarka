# Android Version and Device Compatibility Matrix

> **Document control:** M1 / 03-security-and-permissions · Proposed owner: Security + Android/backend (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

> **Current product naming:** **Madalasa** parent/guardian app, **Alarka** child companion; GitHub repository [Madalasa-Alarka](https://github.com/methakon/Madalasa-Alarka). [Brand and Markandeya Purana context](../../M0-foundation-and-approvals/02-market-and-feasibility/BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

## Current inventory and release interpretation — 2026-10-30

**Feasibility assessment and preparation only; no Android code, build, device test, credential creation or Console action.** `SUPPORTED` means an Android platform/API capability exists in the stated context, **not** a shipped, tested, legally approved or Play-approved feature. All release evidence below is **required / NOT EXECUTED by this assessment**. B01: India, Individual publisher **SWARNA SEKHAR DHAR**; B02: India children **0–17**; B03: transparent/discoverable background-operation model accepted. B04 accepts review of the **full candidate inventory**, not implementation approval of every feature. B05 approves financial-screen safeguards; actual DeviceOwner provisioning and classifier proof remain unresolved.

### Authority and coverage

Read together: [SRS including FR-050/051 and supersessions](../01-requirements-and-architecture/SRS.md), [traceability](../01-requirements-and-architecture/REQUIREMENTS_TRACEABILITY.md), [capability ADR](CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md), [media runtime ADR](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md), [media activity audit](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_ACTIVITY_AUDIT_LOGGING_AND_REPORTING_2026.md), [admin expansion](../../P3-deferred-research/01-media-and-administrator-research/ADMIN_OWNER_GOOGLE_ACCESS_FAQ_SUPPORT_BILLING_AND_USAGE_2026.md), [command/usage contract](../../M4-usage-health-sos/01-usage-health-and-sos/COMMAND_SOS_USAGE_QUEUE_CONTRACT.md), [trip/place/battery spec](../../M3-trips-and-places/01-trips-and-named-places/LIVE_TRIP_ROUTE_NAMED_PLACES_BATTERY_SPECIFICATION.md), [competitor candidate review](../../M0-foundation-and-approvals/02-market-and-feasibility/COMPETITOR_FEATURE_COMPARISON_AND_ADOPTION_2026.md), [reference workflows](../../../ui/REFERENCE_SCREENSHOTS_FEATURE_WORKFLOWS_2026.md) and [theme contract](../../../ui/MADALASA_ALARKA_THEME_C_STORY_AND_UI_CONTRACT_2026.md). Latest exact-child invitation/no-Family-Link decision overrides older Google-family attestation language. Original FR-040/041/042 IDs are reused in a later SRS commercial supplement: rows below preserve the original IDs and map commercial aliases separately; they do not renumber source requirements.

**Coverage:** 51 original SRS FR rows + 40 supplemental/split/candidate rows = **91 unique inventory rows**. Counts are assessment rows, not feature approvals, screen counts, tasks completed or tested capabilities. Underlying API minima are distinct from the **proposed app minSdk 29**; final minSdk/SDK-library requirements remain a build/product decision. `App 29` for server/UI features means client baseline, not an assertion that an Android sensitive API was introduced at 29. Android N/A applies to independent backend/web work. Versions/OEMs remain N/T.

### Non-negotiable runtime contract

1. Backend **before ACCEPT (and before sensitive dispatch)** checks requesting adult's exact-child/action scope, enrollment generation, app version and OS/target SDK, supported capability/report schema version, report freshness, feature-release/legal flag, entitlement and session budget, management role, declared permission scope and eligible execution context. Unknown, unsupported, stale or contradictory evidence fails closed for sensitive actions (`UNSUPPORTED`, `PERMISSION_REQUIRED`, `USER_ACTION_REQUIRED`, `OS_REJECTED`, or explicit pending verification), never an ACCEPT/success inferred from FCM. Child rechecks actual OS grant/context **immediately before execution**; ACK/report/stream/capture receipts remain distinct.
2. **Remote media default OFF**: camera live/snapshot/video, ambient audio, local recording and screen sharing remain P3. Setup grants do not provide future background-start authority. A qualifying FGS-start exemption and a qualifying while-in-use sensor exemption are separate checks; high-priority FCM alone does not supply the latter. Genuine device-owner exceptions are documented test candidates, not universal support or legality.[1][2]
3. **Never capture financial screens** (banking, wallets, UPI, payments, credentials), including transitions/overlays, previews and saved/exported frames. Unknown screen/application classification fails closed **before capture/transfer**, not by deleting after upload. Respect FLAG_SECURE and protected content; set FLAG_SECURE on own sensitive windows. Android offers no demonstrated universal reliable cross-app financial classifier here; package inventory/secure-window flags alone do not prove exclusion. Without trustworthy pre-frame classification/transition proof, screen sharing stays OFF. No Accessibility inspection/capture workaround, root, overlay trick, secure-content bypass or notification/launcher concealment.[3][24][25]
4. Closing the main Activity is not stealth. Keep recognizable launcher identity, required monitoring notice and system camera/mic indicators. Android 13+ may technically allow an FGS after notification denial, with Task Manager visibility only; that is **not** accepted evidence of this product's persistent monitoring disclosure. Stop/degrade affected monitoring until compliant visible behavior is established; never bypass the user's choice.[9][21]
5. India adult identity, purpose-specific lawful child authority/consent, retention/deletion, Families/audience and final Play decisions remain gates. Child location history, usage and live location need **separate** legal review; device permissions, payment and Individual identity are not legal clearance. No real child data for this assessment. No DeviceOwner provisioning, real-device wipe, release upload or merchant/account action authorized.

### Feature-by-feature feasibility and release evidence

In the table `DPM` = DevicePolicyManager; `DO` = genuine fully managed DeviceOwner (profile-owner/delegate authority is only within its permitted user/profile, not full personal-device control). INTERNET is a normal manifest permission for networked rows, not a runtime grant. All API references use the dated official source set below. Required tests cite existing planned catalogs; **none is marked PASS here**.

| Inventory ID | Feature / purpose | Android API / mechanism | API minimum / app baseline | Permission and runtime / Settings interaction | Background / FGS conditions | DO / management dependency | Play / privacy disposition | Required release evidence (not executed) |
|---|---|---|---|---|---|---|---|---|
| FR-001 | Pair parent/child securely | Keystore + QR/code + HTTPS | 29 baseline; Keystore 18 | Camera only if local QR scanning chosen; manual code alternative | User-visible pairing; bounded sync | No | Candidate; child authority separate from Google login | T-FR-001; stolen/replayed code, cross-child denial |
| FR-002 | Permission onboarding and monitoring identity | PackageManager, permission APIs[23] | 29 baseline | Progressive OS dialogs/Settings; optional decline | Recognizable launcher + required ongoing monitoring notice; no bypass | No | B03 transparent background direction only; no collection approval | T-CAP-01–24; denied notice stops incompatible monitoring |
| FR-003 | Latest observed location | LocationManager / fused provider[5][6] | Platform 1; app 29 | COARSE/FINE; BACKGROUND 29+ for justified all-time use; Settings 30+ | Location FGS when applicable; lawful eligible start; no timing guarantee | Not required; no blanket exemption | Conditional; live safety purpose + Families approval unresolved | T-FR-003; approximate, screen-off, no-GPS, revoke |
| FR-004 | History, mileage and trips | HTTPS + map rendering | App 29 | No extra child permission beyond lawful observations | Server query; map open does not wake GPS | No | Conditional historical-child-purpose/retention gate; six-hour free visibility is not retention | T-FR-004; gaps, estimates, expiry |
| FR-005 | App usage day/week/month/year | UsageStatsManager[20] | 21; app 29 | PACKAGE_USAGE_STATS declaration; user Usage Access Settings/AppOps | Bounded eligible work; not live current-app certainty | Not required | Conditional behavioral monitoring legal gate; missing ≠ zero | T-FR-005; revoke, overlap, DST, partial history |
| FR-006 | Authenticated remote commands | HTTPS + optional FCM | App 29 | Feature-specific grant at device execution | FCM receipt is not execution or sensor FGS exemption | Feature-dependent | Preflight before ACCEPT; replay/expiry/grant isolation | T-FR-006; no false COMPLETED |
| FR-007 | Scheduled app restrictions | DPM.setPackagesSuspended[4] | 24; app 29 | Actual provisioned role, not runtime permission | Durable local policy; schedule execution best effort and reported | Yes; eligible owner/delegate scope | Managed conditional; never universal standard blocking | T-FR-007; essential apps, offline TTL, restore |
| FR-008 | Authorized files/media list, preview, transfer | SAF / MediaStore[7] | SAF 19; app 29 | System URI selection; modern selected/all media scope only as needed | Bounded transfer work; eligible dataSync FGS only if justified | No; sandbox remains | P2 conditional; no arbitrary private directories or broad-storage shortcut | T-MEDIA-11; revoked URI, private-path denial |
| FR-009 | Remote photo/video requests | Camera2 / capture pipeline[1][2] | 21; app 29 | CAMERA; RECORD_AUDIO only for approved AV | Camera/mic FGS and while-in-use/start checks; remote push insufficient | Owner exception test candidate only | P3 OFF; no media permissions for unreleased paths | T-MEDIA-01–18; actual capture receipt |
| FR-010 | Remote one-way ambient audio | AudioRecord / MediaRecorder[1][2] | AudioRecord 3; app 29 | RECORD_AUDIO; privacy toggle/one-time grants | Microphone FGS; valid new start distinct from continuation | Owner exception test candidate only | P3 OFF; not voice-call interception; bystanders/privacy review | T-MEDIA-01–18; silence not proof of call |
| FR-011 | Optional Google Drive backup | OAuth + HTTPS scoped transfer | App 29 | Adult explicit narrow OAuth; Android file URI grants independently | Bounded upload; no perpetual service | No | P2 OFF until selected data flow/legal/security approval; separate copy deletion | T-FR-011; revoke, checksum, cancellation |
| FR-012 | Manual prepaid entitlements | Play Billing + server verification[16] | App 29; selected Billing SDK gate | Play purchase confirmation; no Android privilege purchased | Server verify/ack/notifications; not polling FGS | No | Commercial design; all prices/quotas preserved; merchant pending | T-FR-012; pending/refund/revoke/top-up/expiry |
| FR-013 | Privacy, export, deletion | HTTPS + local purge | App 29 | In-app authenticated deletion + public web request | Jobs erase queues/inbox/derived/backups under approved schedule | No | Required; retention/SLA/counsel unresolved | T-FR-013; late upload and restore tombstone |
| FR-014 | Status and notifications | NotificationManager + HTTPS[21] | Channels 26; POST_NOTIFICATIONS 33; app 29 | Runtime notice grant 33+; Settings/channel verification | Monitoring notice remains required even though OS may permit FGS without drawer permission | No | No notification-bypass workaround; denial degrades/stops affected monitoring | T-FR-014; delivery vs ack, last confirmed |
| FR-015 | Named places and map search/edit | Map UI + HTTPS | App 29 | No child GPS grant merely to place a marker; parent own-location optional only if used | Server read/write only | No | Place titles/coordinates sensitive; provider attribution/license | T-FR-015; child ownership, edit/delete |
| FR-016 | Observed route playback | Map polylines + HTTPS | App 29 | No extra grant | Server cached history; no extra GPS demand | No | Conditional history; never replace gaps with directions | T-FR-016; time selector, uncertainty |
| FR-017 | Trip legs, stops, walk/ride inference | C++ server + HTTPS | App 29 | Lawfully obtained observations only | Server analysis; not new Android permission | No | Conditional history; traffic stop ≠ visit | T-FR-017; labeled dwell/false-stop cases |
| FR-018 | Adaptive battery-aware location | Location + optional Activity Recognition[5][6] | App 29; activity runtime 29 | Location; ACTIVITY_RECOGNITION only if chosen for approved hints | Eligible location FGS; sampling ≠ upload cadence | No | Conditional; measured battery not promised savings | T-FR-018; stationary/walk/drive, saver |
| FR-019 | Optional road matching | Server provider adapter | App 29 | No additional Android grant | Server only | No | P2 conditional; provider licensing/quota; never fabricate route | T-FR-019; dense/sparse fallback |
| FR-020 | Phone/tablet/watch provenance | Per-device identity + location APIs | App 29 phone; Wear baseline TBD | Each source's permissions; Bluetooth pairing only if chosen | Wear independent lifecycle/power test; paired-only source marked | No | Optional watch unverified; source device ≠ physical child presence | T-FR-020; no-GNSS/paired-only/handoff |
| FR-021 | Place entry/exit/dwell alerts | GeofencingClient + server proximity[19] | App baseline 29; Play services eligibility | Location fine as needed + background if used; notice permissions | Geofence delays; limited subset, 100 per app/user; no immediate guarantee | No | Conditional location/Families; per-child opt-in toggles | T-FR-021; jitter, delayed/offline events |
| FR-022 | Exact-child guardian sharing | OIDC + server grants | App 29 | Adult login authenticates only; accepted child invitation + approved authority | Revoke caches/streams/sessions; no sensor FGS | No | No Family Link API dependency; no automatic siblings | T-FR-022; blended families, dispute hold |
| FR-023 | Durable batches and offline queue | Local encrypted storage + HTTPS | App 29 | Feature data grant; INTERNET normal | 48h queue capacity; eligible 1–2min upload target; WorkManager ≥15min periodic[22] | No | Conditional data purposes; 202 after durable inbox commit not map update | T-ING-01–24; crash/replay/full disk |
| FR-024 | Late event revisions | C++ event-time worker + HTTPS | App 29 | No extra grant | Server work only | No | Conditional history; late ≠ live; versioned revisions | T-FR-024; out-of-order/dedupe |
| FR-025 | API/worker isolation | Drogon/C++ workers + HTTPS | App 29 client; server N/A | No extra Android grant | No Android FGS for server scaling | No | Architecture requirement not Android certification | T-FR-025; bounded concurrency/backpressure |
| FR-026 | Map views do not trigger GPS | HTTPS/cache/SSE | App 29 | Authorized child read | Parent reads only; no extra child wakeups per viewer | No | Candidate; privacy and freshness display | T-FR-026; multiple viewers same sample count |
| FR-027 | Scoped revocation/retention | HTTPS + purge/tombstone jobs | App 29 | Guardian/device/integration revoke | Stop invalid local operations; offline parent reports remain last-confirmed | No | Required; lawful retention still pending | T-FR-027; queues, backup restore, cache purge |
| FR-028 | Quality-aware map | Map UI + observation metadata | App 29 | No extra grant | Server read only | No | Candidate rendering; uncertainty cannot be hidden | T-FR-028; gap, accuracy/source legends |
| FR-029 | Capacity and isolation verification | Synthetic HTTPS/DB tests | Android API N/A; app 29 | No real child data | Server tests, not Android FGS | No | No tested load/availability claim from language choice | T-FR-029; cross-family API/RLS/SSE |
| FR-030 | D01 route evidence | Server quality + UI | App 29 | No extra grant | Read only | No | Conditional history; no invented confidence percentages | T-FR-030; observed/approximate/gap labels |
| FR-031 | D02 reliability center | Capability + heartbeat timestamps | App 29 | Each underlying grant separate | No always-on status polling; stale/unknown explicit | No | Candidate; silence not proof of uninstall/revoke | T-FR-031; last fix/seen/ingested/processed |
| FR-032 | D03 offline recovery history | Versioned server revisions | App 29 | No extra grant | Read only | No | Conditional history; original events immutable | T-FR-032; late corrections and notice dedupe |
| FR-033 | D04 commute confidence | Schedules + server place analysis | App 29 | Lawful location + alert settings | Server bounded escalation | No | Conditional; no emergency or arrival certainty without data | T-FR-033; holidays, false alerts, dropout |
| FR-034 | D05 pickup viewer | Single-child expiring invitation | App 29 | Accepted limited grant, TTL | Terminate reads/SSE on expiry/revoke | No | Only approved current/recent scope; no usage/media by implication | T-FR-034; forwarded/expired links denied |
| FR-035 | D06 who-accessed ledger | Server audit + HTTPS | App 29 | Scoped child permissions | No sensor wakeup | No | Sensitive metadata; no raw coordinates in access logs | T-FR-035; audit/read privacy |
| FR-036 | D07 energy/coverage feedback | Battery/observation metrics | App 29 | No privileged battery-stat grant; app measurements only | Piggyback sync; physical baselines | No | Conditional; no fixed savings percentages | T-FR-036; disabled-app baseline/OEM |
| FR-037 | D08 preview and rollback | Pure policy + DPM[4] | Suspend 24; app 29 | Managed role for actual effect; preview grants separate | Best-effort transitions; actual per-package receipt | Yes for enforcement, no for preview | Managed conditional; preserve safe apps and fail-safe restore | T-FR-037; DST/reboot/TTL rollback |
| FR-038 | D09 source handoff explanation | Multi-device metadata | App 29; Wear TBD | Each source independently authorized | No new scan/collection just to render | No | Optional; conflicts/paired dependence shown | T-FR-038; source switch audit |
| FR-039 | D10 capability before purchase | Versioned capability GET + billing | App 29 | Grant, hardware, runtime, release, freshness separate | Read last confirmed state; refresh only OS-eligible | No | Required commercial honesty; granted ≠ released/active | T-CAP-20–24; stale downgrade |
| FR-040 | D11 redacted support packet (original ID) | HTTPS + explicit diagnostic export | App 29 | Adult opt-in; scoped support access | Bounded upload/TTL; no raw routes/media/tokens | No | P1/P2 optional; redaction/privacy review | T-FR-040; leak negatives |
| FR-041 | D12 child transparency (original ID) | Activity + notification link | App 29 | No new sensitive grant just to view own summary | Activity may close; launcher/notice remain discoverable | No | Required; age-appropriate English; no hidden consent | T-FR-041; TalkBack, declined permissions |
| FR-042 | D13 route corridor (original ID) | Server spatial analysis | App 29 | Lawful observations only | Server only | No | P3 OFF; alternate routes, sparse data, map license | T-FR-042; false-alarm evaluation |
| FR-043 | D14 scheduled sampling | Policy schedule + location | App 29 | Location/activity grants as selected | Eligible FGS; no exact alarm/timer guarantee | No | P2 conditional; downgrades exposed | T-FR-043; battery/lifecycle |
| FR-044 | Child-initiated SOS | Visible Activity/widget/notification + HTTPS | App 29 | No mic; last fix optional, fresh location only if granted | Durable priority event; no DND/notification bypass | No | Best effort; no emergency dispatch claim; independent delivery proof pending | T-FR-044; offline/provider/guardian ACK |
| FR-045 | Find-device bounded ring | AudioManager + command | App 29 | No RECORD_AUDIO; respect DND/audio policy | Only eligible bounded execution; no unlimited FGS or volume bypass | No | Conditional; sound actually played vs delivered | T-FR-045; mute/DND/offline/stop |
| FR-046 | Family check-in | Activity/widget + HTTPS | App 29 | No mic; optional location only if separately authorized | Queued vs received vs acknowledged | No | Candidate, child-visible; not chat by default | T-FR-046; offline/dedupe |
| FR-047 | Safe screen-time rules/tasks | UsageStats + DPM + time-credit ledger | Usage 21/suspend 24; app 29 | Usage Access; genuine managed role for blocking | Visible remaining-time/warnings; no Accessibility blocker | Yes for enforcement | Conditional; tasks P2 opt-in no surveillance rewards | T-FR-047; quotas, protected packages |
| FR-048 | Health heartbeat | BatteryManager + ConnectivityManager | App 29 | Normal network permissions as needed; no restricted identifiers | Piggyback eligible sync; no high-rate polling | No | Candidate; snapshots not live certainty | T-FR-048; battery/charge/offline/stale |
| FR-049 | Dedup/quiet hours | Server alerts + notification channels[21] | App 29; runtime notices 33 | Parent notice consent/channel settings | SOS distinct policy, never platform override | No | Candidate; privacy-safe lockscreen text | T-FR-049; duplicate events, denied notices |
| FR-050 | Parent media activity history | Metadata API, cursor/date filters | App 29 | Current child-specific guardian access | History reads never wake sensors | No | P3 OFF; no media payloads/thumbs/paths on VPS | T-AUD-01–22; nullable duration/size, view/save receipt |
| FR-051 | Restricted admin media audit | Separate web console + server | Android N/A | MFA, role, case/purpose/expiry; audit failure denies read | No Android sensors/FGS | No | P3 OFF; root owner no child-privacy override | T-ADM-01–14; autocomplete/export/read audit |
| AND-01 | First-launch hardware discovery | Build/PackageManager/CameraManager | App 29 | No sensitive grant for read-only public inventory | No sensor activation/background capture | No | Candidate design only; minimized fingerprint after pairing | T-CAP-01–05; no data before pair |
| AND-02 | Permission revision/ACK sync | Permission/AppOps recheck + HTTPS[23] | App 29; one-time 30 | OS owns grants; selected/temporary/revoked scopes | Recheck on next legitimate execution; no instant off-device detection promise | No | Candidate; monotonic generation/version, stale unknown | T-CAP-06–23; reorder/regrant/offline |
| AND-03 | Front/rear live camera | Camera2[1][2] | 21; app 29 | CAMERA; verified lens/toggle/resource | Typed camera FGS; eligible start then continuation | Documented owner exception test only | P3 OFF; visible sessions only | T-MEDIA-02/03/06/08; actual frames |
| AND-04 | Snapshot and flash OFF | Camera2 request controls[1][2] | 21; app 29 | CAMERA; active eligible session | Not a remote-start exemption | No universal exception | P3 OFF; mandatory shutter/indicator not suppressed | T-MEDIA-07; front/rear/flash/device tone |
| AND-05 | Video with/without audio | Camera2 + media pipeline[1][2] | 21; app 29 | CAMERA + RECORD_AUDIO only if AV selected | Camera + microphone service types/permissions as used | Owner candidate only | P3 OFF; verified start/stop/save or stream receipt | T-MEDIA-08/15; no false persisted success |
| AND-06 | Live one-way microphone | AudioRecord[1][2] | 3; app 29 | RECORD_AUDIO; runtime toggle, busy/silenced | Microphone FGS; FCM alone insufficient | Owner candidate only | P3 OFF; no call-audio interception or inference | T-MEDIA-01/05/06; actual input vs silence |
| AND-07 | Encrypted parent-local recording | Approved session + local storage | App 29 | Explicit recording intent; app-owned storage; export via chooser | No indefinite recording to evade start rules | No | P3 OFF; local backup/copies disclosed; no VPS media files | T-MEDIA-15; disk full, delete, key loss |
| AND-08 | Screen share / MediaProjection | MediaProjectionManager[3] | 21; app 29 | Fresh child-device system consent EACH session | mediaProjection FGS; FOREGROUND_SERVICE_MEDIA_PROJECTION 34+; token single-use | No replacement for consent | P3 OFF; no zero-interaction screen start | T-MEDIA-09/10; callback, stop/lock/token reuse |
| AND-09 | Financial/banking/wallet/UPI/password/payment screen exclusion | FLAG_SECURE for own windows; protected-window handling[24][25] | FLAG_SECURE 1; app 29 | No permission can authorize bypassing protected content | Never capture/transmit/save financial screens; block before frames escape | DO does not override exclusion | B05 approved safeguard, NOT working classifier; fail closed unknown classification | Leak-negative frame/transition tests; no reliable cross-app classifier proven |
| AND-10 | Own sensitive parent/child UI protection | Window FLAG_SECURE; obscure sensitive snapshots[24][25] | 1; app 29 | No runtime permission | Protect account recovery, payment/credentials/authority screens | No | Required security; NOT universal prevention on compromised/OEM devices | Screen/recents/casting/overlay negative tests |
| AND-11 | Scoped gallery/photos/videos/audio | Photo Picker/MediaStore/SAF[7] | App 29; media perms 33, selected photos 34 | Prefer chooser; READ_MEDIA_IMAGES/VIDEO/AUDIO only if justified; selected URI not all files | Bounded granted-scope transfers only | No sandbox override | P2 conditional; Play photo/video permission eligibility review | T-MEDIA-11; selected grants expire/revoke |
| AND-12 | Private files/passwords/other-app databases | Android sandbox[7] | App 29 | No ordinary grant | No background access path | DO not arbitrary root access | Unsupported/rejected; no root/exploit/Accessibility workaround | Negative traversal/URI/provider checks |
| AND-13 | Boot/package replacement recovery | BroadcastReceiver + eligible scheduled work[1][2] | App 29; typed restrictions target 34/35+ | RECEIVE_BOOT_COMPLETED only if used | Reconcile policy/queues; obey type-specific boot bans; no boot camera/mic/projection start promise | Not blanket authorization | Conditional; boot ≠ user sensor consent; force-stop not ordinary reboot | Boot/locked boot/unlock/restricted-battery tests |
| AND-14 | Doze/OEM/battery-optimization handling | WorkManager, power state[22] | App 29 | Settings guidance only; no coercion or blanket exemption request | Periodic min 15min, delays; no exact 1–2min job guarantee | No timing guarantee | Conditional; OEM-specific measured support | Screen-off/Doze/saver/process kill/48h reconnect |
| AND-15 | Uninstall/force-stop and stop guidance | OS app settings; app revocation | App 29 | User controls; no hidden launcher or permission suppression | Force-stop can prevent delivery/rechecks; unknown silence | Managed uninstall policy only separately approved | Standard cannot guarantee anti-uninstall; managed provisioning unresolved | Uninstall/reinstall/stop and parent stale-state tests |
| AND-16 | Managed provisioning/unprovisioning | DPM verified owner role[4][27] | Owner 21; app 29 | Separate informed reset/provision/exit plan; not legacy admin toggle | Role proof on physical device; not simulated setup | Required | Unresolved owner enrollment choice; no provision/reset executed | Physical resettable spare, role proof, exit/rollback evidence |
| AND-17 | Managed remote lock/wipe candidate | DPM.lockNow / wipe APIs[4] | lockNow/wipeData 8; wipeDevice 34; app 29 | Genuine role/explicit future scope; destructive confirmation | No general consumer remote wipe power | Role-dependent, unresolved | Not approved launch inventory; no real-device lock/wipe action | Separate owner/legal/security approval and destructive synthetic plan |
| AND-18 | Financial-app restriction policy | DPM eligible package policy[4] | Suspend 24; app 29 | Owner policy, protected critical/emergency exceptions | Do not block essential payment/recovery blindly; fail-safe restore | Yes if ever chosen | Separate from no-screen-capture protection; review only, not approved implementation | Per-package allow/deny, recovery/rollback tests |
| AND-19 | Paid child selection/two-parent sharing (SRS appended FR-040 alias) | Backend child seats + accepted grants | App 29 | Each adult Google-authenticated; no Family Link role API needed | Separate payment capacity from grants | No | Design; no automatic siblings; one paid child not two charges | Wrong-child/revoked invitation and entitlement tests |
| AND-20 | Premium viewer leases/add-on (SRS appended FR-041/042 aliases) | Atomic backend viewer lease + Play | App 29 | Child grant + verified paid expiry; payer-only checkout | Lease TTL/renew/revoke; no child wake just for viewer | No | Design; one premium viewer + optional ₹100/100d/+30 pooled AV; dormant base lapse | Race/takeover/refund/cross-child/replay tests |
| AND-21 | Trial/founding eligibility and quota meters | Server timer/receipts + billing[16] | App 29 | 48h once; minimal lawful anti-abuse ledger; no Aadhaar/IMEI | No failed OS attempts billed as delivered usage | No | Design; first 1,008 paying families; prepaid no auto-conversion | Reinstall/false-block appeal, shared child quota tests |
| AND-22 | Prepaid expiry/top-up/stop purchases | Play Billing + server[16] | App 29; library version gate | Explicit Play-confirmed purchases only | No automatic charge; expiry downgrades to free | No | Catalog/sandbox pending; prepaid stop means no further top-up; refunds separate | Top-up ack/deadline, pending, refund, expiry evidence |
| AND-23 | Adult Google identity/account recovery | OIDC verified issuer/sub/audience + backend | App 29 | Account chooser; no Gmail inbox access for login | Short-lived auth, recovery/revocation | No | Identity ≠ parent authority or admin role; merchant identity independently pending | Spoofed email/token, recovery and dispute tests |
| AND-24 | FAQ/content/story/theme/navigation | Android UI + HTTPS public content | App 29 | No sensor or monitoring consent inferred from story Skip | No monitoring service needed for editorial view | No | English-only now; optional original story; accessibility and IP review | TalkBack/text scale/reduced motion; no copied art |
| AND-25 | Parent support tickets/replies | HTTPS + transactional notifications | App 29 | Explicit minimal user content; attachment OFF unless approved | Safe push summaries; no raw child data by default | No | Candidate; support not unrestricted mailbox or child-data access | XSS/tenant scoping/redaction/delivery vs read |
| AND-26 | Admin owner/staff applications/roles | Separate web OIDC/MFA/case backend | Android N/A | Verified sub-bound owner bootstrap; profile/contact necessity review | No Android grant or sensors | No | Design; DOB/gender/address minimization pending; deny unapproved accounts | T-BO-01–09/15/17/18; fail-closed audit |
| AND-27 | Admin FAQ/support/subscriber/payment roster | Separate web + server restricted projections | Android N/A | Scoped approved roles; masked order/child aliases | No child location/media activation or arbitrary DB browse | No | Design; owner cannot override child privacy wall | T-BO-10–13/16; no raw payment tokens |
| AND-28 | Admin parent service usage/health/audit | Web metadata queries | Android N/A | Scoped staff authorization, paging/retention | Parent use duration/outcome, NOT child's behavioral usage | No | Design; sensitive named media audits remain separate case scope | T-BO-14–18; no payload/coordinates in logs |
| AND-29 | Driving/movement insights | Existing location derivations | App 29 | Lawful observations; no new vehicle sensor grant assumed | Server inference only | No | Candidate review, not implementation-approved; no crash/medical/emergency guarantee | Labeled walk/ride/speed accuracy and false positives |
| AND-30 | Step counts/activity feed | Step counter SensorManager if selected | Sensor 19; ACTIVITY_RECOGNITION 29; app 29 | Runtime activity grant if required; no body/health permission assumed | Bounded sampling; health FGS not a generic workaround | No | Candidate review only; separate child-purpose/sensor review | Sensor absent/denied, completeness and battery tests |
| AND-31 | Optional family text chat | New messaging API/UI | App 29 | No SMS/contact interception permissions | Normal message notifications only | No | P2 candidate not approved implementation; moderation/retention/abuse review | End-to-end scope, deletion/abuse tests pending |
| AND-32 | Optional call/super-call shortcut | ACTION_DIAL or separately scoped VoIP candidate | App 29 | Dialer handoff preferred, no CALL_PHONE required for ACTION_DIAL; VoIP needs new mic review | No phoneCall FGS entitlement merely from shortcut | No | Candidate review; no interception/auto-call/emergency guarantee | User confirmation and unavailable-capability tests |
| AND-33 | Website/content filter | VpnService candidate only | 14; app 29 | Explicit OS VPN approval if separately chosen | VPN lifecycle/notification; not Accessibility or TLS interception | Not automatically required | P2 research OFF; Play VPN use-case/child privacy approval; no current implementation scope | DNS/encrypted traffic limits, revoke, fail-open/closed design pending |
| AND-34 | Flight tracking | External data integration candidate | Android N/A; app 29 | No new Android privilege assumed | No Android FGS justification | No | Low-priority candidate; not implementation-approved | Provider licensing/cost/data-purpose review |
| AND-35 | Notification/social/call/SMS interception, keylogging | Restricted APIs / other apps' data | N/A | No sensitive permission requested for these paths | No Accessibility, notification-listener or default-role workaround | Not authorization | Rejected default; no third-party messages/calls/password extraction | Manifest absence + negative capability tests |
| AND-36 | Stealth, hidden launcher, suppressed indicators | No allowed implementation | N/A | Never suppress Android UI/permissions | No invisible persistent tracking or notification bypass | No exception | Prohibited; recognizable Alarka always discoverable | Listing/launcher/notification/indicator audit |
| AND-37 | Native libraries and SDK supply chain | AAB/native .so packaging[26] | App 29; 16KB release compatibility gate | No runtime data grant for build check | Build compliance only; not runtime monitoring proof | No | Required if native code ships; third-party SDK data audit | ELF/ZIP alignment, 16KB device, SBOM/release build proof |
| AND-38 | Child extra-time request / parent allowance | Visible Activity + allowance ledger + DPM[4] | App 29; suspend 24 | Child request is not self-approval; adult child-scoped authorization | Queued/approved/applied distinct; no Accessibility enforcement | Managed role for actual blocking changes | Candidate extension; school/night/holiday/override/unlimited rules remain conditional | Grant/deny/replay/expiry, warnings and safe-package tests |
| AND-39 | Predictive ETA / arrival ranges | Server route model / optional map provider | Android API N/A; app 29 | Only lawful observations and approved provider data | Server analysis; no extra GPS wake for map view | No | Research candidate; not precise ETA/emergency/arrival guarantee; license and false-alert review | Labeled route/uncertainty/calibration evidence, fallback UNKNOWN |
| AND-40 | Crash-detection / emergency-response comparator | No certified platform/provider integration selected | N/A; any future API/SDK minimum TBD | No sensor permission approved merely by competitor claim | No always-on sensor/health FGS workaround | No | Comparator/candidate review only; OFF/not implementation-approved; no crash/medical/rescue promise | Separate scope/provider/sensor/legal approval and field false-positive/negative evidence |

### Runtime permission and OS-version detail (applies to every relevant inventory row)

| Operation | Manifest / grant / API boundary | Mandatory behavior |
|---|---|---|
| FGS base/type | `FOREGROUND_SERVICE` normal permission API28+; `location` type API29; `camera`/`microphone` types API30; target34+ applicable `FOREGROUND_SERVICE_LOCATION`, `FOREGROUND_SERVICE_CAMERA`, `FOREGROUND_SERVICE_MICROPHONE`, `FOREGROUND_SERVICE_MEDIA_PROJECTION` plus actual service type | These normal permissions do not replace location/CAMERA/RECORD_AUDIO runtime grants or valid start context. Check foreground-start and while-in-use eligibility separately.[1][2] |
| Location grants | COARSE/FINE runtime API23+; BACKGROUND API29+; target30+ foreground request before separate background Settings flow; approximate location API31+ | No requesting everything at once; show precision/scope/time; Background location alone does not waive all FGS-start restrictions.[1][5] |
| Background/boot | Target31+ restricts background FGS starts; target34+ sensor while-in-use validation at service creation; target35+ additional type-specific BOOT_COMPLETED bans include mediaProjection/dataSync | Test actual OS+target combination. Boot recovery restores eligible queue/policy scheduling, not permanent camera/microphone/projection consent; do not use a perpetual service to evade restrictions.[1][2] |
| Notifications | POST_NOTIFICATIONS runtime33+; channels26+ | OS FGS allowance after denial is not product monitoring-policy approval. No bypass, hidden launcher or notification suppression.[9][21] |
| Usage/package visibility | UsageStats21+ / Settings special access; target30+ package queries filtered; narrow `<queries>` first | `QUERY_ALL_PACKAGES` needs actual eligible core justification/Play review; not a reliable universal financial-screen classifier.[8][20][31] |
| Storage/sensors | API33 media-granular permissions; API34 selected visual media; chooser/SAF first; CAMERA/RECORD_AUDIO while-in-use and one-time30+ | Do not request unrelated sensor/storage privileges for read-only discovery or receiving media; revocation stops invalid use.[7][23] |
| Scheduled work | WorkManager periodic minimum15min and flexible execution | Eligible1–2min upload target is not periodic WorkManager; no exact alarm/battery exemption introduced just to force tracking.[22] |

### Package and policy evidence crosswalk

Madalasa/Alarka need separate accurate audience, monitoring, Data Safety, deletion and review evidence. Play's solely-child-targeted location prohibition remains unresolved for Alarka; the monitoring designation is not an automatic exception.[9][10][18] Current phone target threshold is API36+; personal-account testing gates depend on the actual account.[11][15] Background-location core purpose/disclosure/video must match the real release.[12] SDK/off-device/ephemeral/shared definitions and app/web deletion require independent verification.[13][14] Listing artwork must reflect truthful audience; Individual identity/Payments/public contact details are separate checks, not proof of child lawful purpose.[17][29]

### Official sources and review date

Retrieved **2026-10-30** from developer.android.com / support.google.com; recheck at build and submission. Official pages are living documents, not app approval.

## Sources

[1] https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
[2] https://developer.android.com/develop/background-work/services/fgs/service-types
[3] https://developer.android.com/media/grow/media-projection
[4] https://developer.android.com/reference/android/app/admin/DevicePolicyManager
[5] https://developer.android.com/training/location/permissions
[6] https://developer.android.com/develop/sensors-and-location/location/background
[7] https://developer.android.com/training/data-storage/shared/media
[8] https://developer.android.com/training/package-visibility
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
[19] https://developer.android.com/develop/sensors-and-location/location/geofencing
[20] https://developer.android.com/reference/android/app/usage/UsageStatsManager
[21] https://developer.android.com/develop/ui/views/notifications/notification-permission
[22] https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work
[23] https://developer.android.com/training/permissions/requesting
[24] https://developer.android.com/security/fraud-prevention/activities
[25] https://developer.android.com/reference/android/view/WindowManager.LayoutParams
[26] https://developer.android.com/guide/practices/page-sizes
[27] https://developer.android.com/work/dpc/dedicated-devices
[31] https://support.google.com/googleplay/android-developer/answer/10158779
[29] https://support.google.com/googleplay/android-developer/answer/13628312


---

## Earlier device-test program (retained; no test status upgraded)

**Madalasa–Alarka | 2026-10-25 | No device tests executed**

## 1. Testing policy

Android API level alone is **not sufficient** to determine success. For every cell, record manufacturer, OS build/security patch, app version/targetSdk, permission state, device-owner status, FGS type, notification/indicator observation, result and log reference.

Legend: `N/T` = not tested; `P` = passed on named device; `C` = passed with conditions; `F` = failed; `N/A` = platform unsupported.

## 2. Device support candidates

| Android | API | Standard location | Usage Access | Managed app suspension | Authorized camera/audio mode | Status |
|---|---|---|---|---|---|---|
| Android 10 | 29 | Test needed | Test needed | Test only after owner provisioning | Test permitted visible workflow | N/T |
| Android 11 | 30 | Test needed | Test needed | Test only after owner provisioning | Test permitted visible workflow | N/T |
| Android 12 | 31 | Test needed | Test needed | Test only after owner provisioning | Test permitted visible workflow | N/T |
| Android 12L | 32 | Test needed | Test needed | Test only after owner provisioning | Test permitted visible workflow | N/T |
| Android 13 | 33 | Test needed | Test needed | Test only after owner provisioning | Test permitted visible workflow | N/T |
| Android 14 | 34 | Test needed; typed foreground services | Test needed | Test only after owner provisioning | Typed FGS and while-in-use restrictions require careful validation | N/T |
| Android 15 | 35 | Test needed; power restrictions | Test needed | Test only after owner provisioning | Test permitted visible workflow | N/T |
| Android 16 | 36 | Test needed; target new Play apps | Test needed | Test only after owner provisioning | Test permitted visible workflow, privacy indicator | N/T |

`minSdk=29` is a **proposed** engineering choice; no supported device range is finalized. New standard phone app submissions target API **36+** under current Play requirements. Android/OEM service behavior can vary by OS version and target SDK; rerun after every major change.

## 3. Per-feature prerequisites

| Feature | Standard app prerequisite | Managed-mode prerequisite | Must measure |
|---|---|---|---|
| Background location | Foreground/background grants where appropriate, location enabled, compliant service | Same; DPC does not replace permission/OS location rules | Fix timestamp, accuracy, stale state, battery |
| Usage collection | User grants Usage Access in Settings | Same or policy-supported equivalent if documented | Aggregation, access loss, coverage |
| App suspension | Not universally supported | Properly provisioned DPC with authorized policy APIs | Eligible app suspended/restored; excluded packages; restart/rollback |
| File browsing | Owned files, MediaStore/SAF authorized locations | Policy-specific access does not automatically defeat sandbox | Deny other apps' private files |
| Camera/mic recording | Explicit authorized visible workflow and permitted lifecycle | Validate documented owner exceptions as *test candidates*, without concealing recording | Permission denial, privacy indicators, service start, OS error, session result |
| Monitoring identity | Identifiable icon/disclosures/notifications | Same | Notification visibility and listing accuracy |

## 4. Test form

```yaml
case_id: AP-ANDROID-001
device_model: TBD
manufacturer: TBD
android_api: 36
build_fingerprint: TBD
target_sdk: 36
app_build: TBD
enrollment_mode: STANDARD
permissions: {}
network: WIFI
battery_saver: false
screen_state: OFF
test_action: background_location
expected: compliant timestamped fix or explicit unavailable
actual: NOT_TESTED
android_privacy_indicators: NOT_TESTED
app_notification: NOT_TESTED
logs_reference: null
result: NOT_TESTED
reviewer: null
```

## 5. Specific test scenarios

- Fresh install, normal disclosure, permission denied/granted and later revoked.
- Background vs foreground location, device restart, app force-stop, network loss, GPS unavailable.
- Motion transitions and timestamp freshness with power saver/OEM optimization.
- Usage report under time zone changes and midnight boundaries.
- DPC first enrollment vs standard install; suspend and restore permitted targets.
- Explicit supported media flow: visible indicator, interruption, OS rejection, correct command status.
- Managed mode must be tested on an actual appropriately provisioned physical device; do not treat a simulated role as device owner.
- Parent map freshness, route gaps, account unlink, storage deletion and remote command replay.

## 6. Promotion to supported status

Promote a configuration from `N/T` to `P`/ `C` only with a reproducible test, matching build hash, evidence and owner approval. Product feature flags must be computed from actual verified combination; don't infer that “Android 14 supports X” simply from an API's existence.

## 7. Conditional media and reason-UX test expansion (2026-10-26)

**RESEARCH / NOT TESTED:** Alarka main Activity stays closed after setup, but monitoring notification and Android camera/microphone indicators must remain discoverable. Run `T-MEDIA-01–18` from [MA-MEDIA-ADR-001](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md) independently on STANDARD and genuine MANAGED_DEVICE_OWNER physical devices across Android 10–16 candidates; normal Device Administrator cannot be treated as fully managed. Test start vs continuation of camera/microphone FGS, OS 14+ while-in-use checks, on-device notification interaction, denied/revoked permissions, camera/mic system toggle, locked/offline/killed phone, power saver, sensor busy, network switch and explicit session stop.

**Parent proof:** capture `Command.status`, actual `reason_code`, parent-facing copy and safe next step for every outcome; do not infer permission failures from offline/stale capability snapshots. Validate per-session Android MediaProjection consent, FLAG_SECURE exclusion, MediaStore/SAF allowed roots/revocation, snapshot flash-off on actual devices, no VPS stored media and guardian-revocation stop. Extend every device-test record with `requested_feature`, `fgs_type`, `actual_permission_at_execution`, `enrollment_mode`, `parent_status`, `parent_reason`, `indicator_visible`, `command_receipt`, `stream_stopped`, and `evidence_id`. Remain N/T until physical proof.

## 8. 2026-10-27 first-install capability scan and permission change matrix

**New physical-device test program:** See [MA-CAP-ADR-002](CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md). Record `T-CAP-01…24` in STANDARD and truly provisioned MANAGED_DEVICE_OWNER mode on Android API 29–36/OEMs with exact model/build/targetSdk, initial hardware scan, grant scope (denied, one-time, selected media, partial/approximate, foreground/background), sensor runtime context, release flag, `checked_at`, `report_version`, durable server ACK and Madalasa output. A device's camera hardware detection does **not** verify camera open/background FGS eligibility; `DevicePolicyManager` owner is distinct from legacy administrator. No child location/usage/media actually collected during read-only hardware discovery.

**Lifecycle verification:** permission flow triggers a system-owned dialog/Settings; Android 11+ foreground location must be granted **before** background location step. On dialog result, onResume, process restart/revocation, feature execution and legitimate WorkManager sync Alarka rechecks OS state. Simulate one-time grant expiration, Android permission auto-reset, app process termination on revoke, notifications disabled, locked/force-stopped device, Doze, network outage, Wi-Fi→mobile transitions, concurrent screen-share per-session prompts and SAF URI revocation. Madalasa shows verified GRANTED for permission only, not unverified active sensor, and STALE/UNKNOWN for offline/no ACK. Parent green operational requires matching supported OS, **fresh** access, permitted execution and enabled release flag. All T-CAP results remain NOT_TESTED.

## 2026-10-27 adaptive location recording, 48h offline buffering and upload eligibility tests

New accepted design [MA-INGEST-ADR-004](../../M2-location-collection/01-location-collection-and-ingestion/POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md): device read-only capability report distinguishes eligible location service and permission from actual observed fixes. Collect location via Fused/LocationManager as Android allows, write fixes to **encrypted local 48h capacity queue**, and attempt **1–2min JSON batch upload only while the OS permits**. Periodic WorkManager min interval is 15min and Doze/force-stop/offline can delay collection or upload. Alarka Activity normally stays closed, but required location foreground-service notification/monitoring disclosure is present when applicable. Standard versus genuinely managed-owner devices must be tested, with permission revoke, background location, screen off, battery saver, no GPS, smartwatch paired-only source, low disk and reboot. Never treat the offline capacity target as a promise of continuous capture.

T-ING-01–04, 15, 19–23 cover hardware/OEM Android 10–16 field battery+network behavior, file encryption, local queue restart, 48h reconnection, timestamps/accuracy, parent stale/backfill/gap rendering and correct no-live inference. C++ bulk worker and PostgreSQL inbox tests T-ING-05–14, 17, 18, 20, 24 remain synthetic backend tests. NO device tests executed and no Play/India policy clearance implied.


## 9. Owner decision: standard installation first; Device Owner deferred (2026-10-30)

**First-release scope:** ordinary Android installation only. Device Owner / fully managed provisioning is deferred and is not an Alarka first-release capability. Alarka may perform a read-only platform-state check and report whether Android currently identifies the app/device as managed or Device Owner. The app must not infer ownership from ordinary permissions or legacy Device Administrator status.

**No elevation or conversion:** Alarka must not attempt to grant itself Device Owner status, silently convert an already-configured personal phone, bypass setup/provisioning, or imply that a permission grant can replace Android's managed-device enrollment flow. A future managed-device edition requires a separate owner decision and supported Android provisioning, typically during eligible new-device or factory-reset setup, with clear guardian involvement and physical-device evidence.

**Required tests before first release:** (1) standard install and ordinary permission flows; (2) read-only managed-state detection returns accurate supported/unsupported/unknown states; (3) detection failure never grants extra capability; (4) no enrollment/elevation attempt occurs; (5) app identity, notifications and OS privacy indicators remain visible; (6) financial-app screens remain excluded and no financial-app protection is bypassed. These tests have NOT been executed. This decision does not establish Android/OEM support, legal authority or Google Play approval.
