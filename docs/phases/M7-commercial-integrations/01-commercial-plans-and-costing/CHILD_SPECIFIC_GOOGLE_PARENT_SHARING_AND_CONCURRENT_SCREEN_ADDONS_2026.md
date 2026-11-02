# Child-Scoped Google-Parent Sharing, Concurrent Viewer Screens and ₹100 Manual Add-on

**Owner requirement 2026-10-28. Status: product design direction; GOOGLE AUTHORITY VERIFICATION, Play pricing and Android capability are UNPROVEN. No billing/stream enforcement is implemented.** Supersedes earlier family-wide implicit sharing language; see [Two-parent prepaid baseline](TWO_PARENT_SHARED_CHILD_PREPAID_ENTITLEMENTS_2026.md). Launch UI English only; pan-Indian Markandeya Purana-inspired Theme C graphics.

## A. No automatic sharing across blended families

The payer may have multiple children attached to their profile from different parental relationships. **Never** automatically reveal all payer-linked children to a co-parent, other spouse, or another Google family group member. Sharing is **per verified child ID AND per permitted adult ID**. Default for new child is **no co-parent access**, including previously invited parents, unless approved for that specific child.

- Primary paying parent chooses one or several children to assign **paid seats** up to verified prepaid child-seat capacity, and **separately** selects which child can be shared with which verified co-parent. Payment is NOT a permission grant.
- Share flow lists only payer-authorized children. Each row includes **Paid seat selected?** and **Share with Parent B?** as separate settings. Parent B only sees allowed children, not total family roster or undisclosed siblings.
- Co-parent account must have a personal Google Account signed in (OAuth ID token verified server-side, audience/issuer/expiry checks). Google Sign-In **proves identity only**, not parental authority or a Family Link parent role.
- [Google Family Link supports an additional designated parent in a Google family group](https://support.google.com/accounts/answer/7295768), but **no independently verified supported public API for arbitrary third-party apps to query/attest the parent–child Family Link relationship has been found**. **HARD LAUNCH GATE:** product owner requested *only Google-supported parent accounts*. Until we have an approved evidence/verification method that establishes the **specific adult + specific child's** current parent status, the "Share access" action must remain **Unavailable — verification integration pending**. Do not pretend that Google Sign-In, email similarity, family surname, a screenshot alone, group membership or manually asserted relationship is proof. Evaluate permitted official integration or a lawful independent authority process with product-owner signoff before enabling. If Google does not expose that integration, inform owner that strict automated enforcement is impossible and request an explicit policy change; do not silently relax eligibility.
- Google families can generally belong to **one family group at a time**; verify practical Family Link support for blended families across groups and age/region restrictions. Never assume a biological or legal parent is automatically in the same Google group.
- On any verified parent-role removal, divorce/authority change, guardian grant revocation, child removal or account deletion: revoke only affected adult-child grants, sessions, signed URLs and cached snapshots; **other children and the payer's prepaid billing remain independent**.
- Child-side transparency: when child is capable of seeing it, show the specific authorized guardian names and effective data/capture privileges. Legal adult authority and child privacy constraints still require independent review.

## B. What "one screen at a time" means here

**Working implementation interpretation:** The included plan allows **one concurrent active premium remote-monitoring *viewer screen/session* per paid child** across all authorized guardians/devices. A "screen" is NOT a paid child seat, not a whole Android handset, and not a Google Family Link screen-time restriction. Switching between app tabs within the same signed-in device does NOT consume extra slots. Viewing static account settings, trial purchase details, parental safety notices, child-initiated SOS or other essential free/accessible features must NOT be blocked by this cap. Capturing/streaming the child's device screen is a SEPARATE Android MediaProjection-per-session feature and remains gated.

- On an active premium live-map or authorized live-media screen, acquire a server-issued **viewer lease** scoped to `child_id`; one lease per active viewer principal/device. Leases are not client-created entitlements.
- Capacity: `1 included + purchased_valid_additional_slots(child_id, now)`; **never** multiply the included slot just because a second parent logs in.
- For a second simultaneous viewer beyond capacity, display **“Another authorized viewer is active for this child.”** Actions: **Retry**, **Ask to take over** (send in-app request; do not silently eject the other parent), or **Add another screen** (payer only, if add-on eligible/available). A connected session may voluntarily release on page close/switch. Prefer clear `VIEWER_LIMIT_REACHED` API response, not fake network or media failure.
- Server's atomic lease algorithm must reject racing device requests. Candidate SQL transaction/Redis Lua: verify child-specific grant/feature flag/base plan active, count unique nonexpired leases by child, compare with eligible capacity, insert lease with 60–90s TTL and unique `child_id, adult_id, device_session_id`. Clients heartbeat every ~20s; disconnect/revoke/expiry releases or TTL expires. Lease renewal always rechecks payment, adult-child grant, child status and capture legality.
- No sharing authenticated tokens or devices to bypass slots; use per-device sessions, playback signed URLs with audience/session binding, WSS authentication, expiring child-scoped WebRTC tokens and relay admission control. Do not count idle/settings pages as live sessions, and do not hold a lease through background app inactivity. On app reconnection preserve same lease identity without double charging; close stale sockets.
- For locations/history, the **one-concurrent-screen limit is a premium viewer policy**, not permission to deny universally promised free live location or emergency access. Define exactly what is premium monitoring and what remains free before release. If the owner instead intends *one stream per whole family* vs per child, update the model and financial calculations before implementation.

## C. Optional ₹100 additional simultaneous viewer screen — working commercial assumption

**Owner-selected price and term: ₹100 for EACH +1 simultaneous premium monitoring viewer slot for 100 calendar days, manually purchased, NO recurring charge.** Store `addon_expires_at = purchase_activated_at + 100 calendar days`, computed on the server from a verified successful purchase, **independent of the child's base prepaid expiration**. The add-on must NOT be forfeited or have its 100-day expiry moved earlier just because the primary plan lapses. When base prepaid access is inactive, added premium viewing is **temporarily dormant** (free live tracking remains available); if the main plan is renewed within the original 100-day add-on window, unused extra viewer capacity and eligible extra AV quota resume automatically, without another add-on payment. The 100-day calendar timer continues during base lapses, so show both expiry clocks and explicitly disclose paused service before checkout. No rollover or auto-renew, no forced repurchase. ₹100 remains a customer price target pending actual Play Console checkout. Price is only final if the actual Play purchase offer shows ₹100 inclusive/exclusive of applicable taxes.

**Extra media allowance:** each extra paid concurrent screen purchase grants **30 additional combined audio+video minutes** (a single pooled balance, **NOT 30 audio + 30 video**). Shared by all authorized viewers of the **selected eligible child**; consumed after the ordinary per-child media quotas (existing paid Balanced: audio 60 min, video 20 min monthly). Additional balance and viewer slot expire together; refund/void revokes unused allowance. Screen-viewing time and photo snapshots are **not** increased by this add-on. Live audio/video/screen are still restricted features pending legal, Android and Google Play gates; the add-on must not be sold as an audio/video unlock unless those capabilities actually ship.

**No NEW purchases of a paid extra-screen add-on during the free 48h intro or while base prepaid access is expired**, unless a different explicit product is approved. A previously bought unexpired 100-day add-on is retained and resumes when base prepaid access returns. On base plan expiry, all active premium viewer sessions stop while **purchased add-on grants remain recorded through their full independent 100-day term**, dormant and resumable after manual base renewal within that window. Parents retain approved free tracking. Extra screens are not purchased per adult; capacity floats between **authorized** guardians for only that specific paid child.

**Google Play integration candidate:** A separate repeatable **one-time consumable** SKU `extra_viewer_100d_plus30_av_100_inr` using Play Billing; server verifies PURCHASED, amount/offer, purchaser account and unique purchase token, binds purchased unit to specified paid child with idempotent grant, consumes on backend after delivery, and processes RTDN, refunds, chargebacks and expiry. Google also supports time-bound one-time *rent* products; evaluate which method handles stacking multiple units and the independent 100-day add-on expiry. **Subscription add-ons are NOT suitable because Google currently limits them to auto-renew plans**. A non-consumable/permanent SKU is wrong. Multiple quantities or one-time repeatability need Play sandbox verification; do not rely on a purchase count solely from the Android client.

**Pricing economics gate:** ₹100 is a proposed total customer price, *not net proceeds*. Recalculate GST/Google fee, TURN/WebRTC fan-out (each extra viewer increases egress), concurrency, abuse and support. Establish maximum extra slots per child after load tests (candidate hard cap two add-ons, giving 3 total viewers), no unlimited sessions.

## D. Quota and lease examples

| Scenario | Concurrent premium viewers allowed for Child A | Audio/video extra pool | Effect |
|---|---:|---:|---|
| Parent A pays for Child A; one permitted guardian | 1 | 0 | Either parent may use the slot, not both simultaneously |
| Both parents open Child A at once, no add-on | 1 | 0 | Second gets viewer-limit explanation and takeover request |
| Payer buys one ₹100 slot add-on for Child A | 2 | +30 min shared combined | Both authorized parents can simultaneously view approved premium screens |
| Payer buys second eligible ₹100 slot add-on for Child A | 3 | +60 min shared combined | Only if approved max capacity/Play allows |
| Parent B is authorized for Child A but not Child B | Child B: 0 regardless of purchase | Child B: 0 | Child B never appears in Parent B's accessible roster |
| Base prepaid plan expires for Child A | 0 active premium (extra slot dormant) | Unused extra pool preserved to day 100 | Add-on is not cancelled; valid capacity resumes on base renewal before day 100, without an add-on repurchase |

## E. Suggested API and storage extension (implementation not performed)

```text
guardian_child_grant(child_id, adult_id, relationship_verification_status,
  verification_method, verification_expiry, scopes, revocation_epoch)
paid_child_entitlement(child_id, family_id, purchased_capacity, expiry)
concurrent_screen_addon(id, child_id, purchase_token_hash, payer_id,
  slots=1, extra_av_seconds=1800, activated_at, expires_at, state)
viewer_lease(id, child_id, adult_id, device_session_id, screen_type,
  acquired_at, renewed_at, lease_expires_at, entitlement_revision)
child_media_pool(child_id, period_key, base_audio_seconds, base_video_seconds,
  extra_flexible_av_seconds, consumed_flexible_av_seconds)
```

Server admission must check both **eligible viewer screen capacity** and **guardian-child permission**. Use one atomic metering ledger for both parents; split duration use with continuous verified server evidence, never deduct for rejected OS requests. Abort live capture at revocation/expiry/permission change; minimize data and do not increase storage retention due to extra viewer payment.

## F. Screen acceptance (Theme C English only)

- **SH-01 Child selection & co-parent sharing:** per-child separate toggles for paid seat and adult-specific sharing. Child B not automatically shared; disabled verified Google-parent-only gate.
- **SH-02 Verification pending:** Google Sign-In completed, parental relationship unverified; no premium data shared and no simulated Google-connected green check. Explain why.
- **SH-03 Viewer in use:** one included slot; parent A viewing; parent B requests takeover or payer reviews extra-screen option. No cross-child names/leaks to unapproved adult.
- **SH-04 Add extra screen:** exact Play checkout price (₹100 target), count +1 simultaneous viewer, 30 combined audio/video minutes, expiration, no auto-renew, explicit parent confirmation, child assignment.
- **SH-05 Family coverage summary:** permitted parents view only approved children and remaining shared quota; other children stay unshared/free.
- Preserve existing P-39/P-40/P-47/P-48/P-49/P-54 contract; do not replace existing Figma handoff or imply functional UI from mockups.

**Google policy references:** [Family Link parent privileges](https://support.google.com/accounts/answer/7295768), [Google family groups](https://families.google/intl/en_in/families/), [Google Play prepaid subscriptions and add-ons](https://developer.android.com/google/play/billing/subscription-with-addons), [one-time products](https://developer.android.com/google/play/billing/one-time-products), [one-time purchase lifecycle](https://developer.android.com/google/play/billing/lifecycle/one-time), [secure purchase verification](https://developer.android.com/google/play/billing/security).

## G. Concrete concurrency admission algorithm (proposed; not coded)

```text
acquire_premium_viewer(adult, child, device_session, screen_kind):
  assert personal_Google_identity_verified(adult)
  assert guardian_child_grant_is_approved(adult, child, screen_kind)
  assert parent_relationship_verification_is_approved(adult, child)
  assert paid_child_prepaid_entitlement_valid(child)         // server time
  assert screen_kind_is_permitted_and_device_capable(child)
  begin transaction (lock entitlement capacity row FOR UPDATE)
    cleanup_expired_leases(child)
    existing = active_lease(child, adult, device_session)
    if existing: heartbeat_and_return_same_lease(existing)
    slots = 1 + COUNT(valid_extra_viewer_units_for_this_child)
    if count_active_leases(child) >= slots:
       rollback; return VIEWER_LIMIT_REACHED + available user-approved takeover flow
    insert_new_lease(child, adult, device_session, expires=now+75s)
  commit; return opaque signed lease token (bind child/adult/device/scopes)
heartbeat: re-check verified grant, active base subscription and add-on validity; extend lease up to 75s, stop on loss.
release: revoke single lease on app background/exit, logout, expiry or guardian revocation; do not depend on clean client disconnect.
```

**Required tests:** 2 valid parents race for 1 slot -> exactly 1 succeeds; 2 authorized viewer sessions can succeed only after 1 verified active add-on; same device switching live-map tabs returns same lease; two sessions opened by same adult on different devices count twice; verified co-parent sees only selected child; Child B cannot be inferred through error payload; revoked grant immediately invalidates lease; pending Play purchase does not grant add-on; duplicate token grants exactly once; refund disables slot/pool; stale heartbeat releases lease; free location/check-in remains accessible; failed Android capture consumes zero AV pool; purchase expiry stops premium live viewer without automatic renewal. A locally cached screenshot/static screen cannot be technically prevented from being displayed; enforcement concerns **server-backed live premium feeds**, not a guarantee that nobody could photograph an on-screen view.

**Owner-confirmed term:** ₹100 for an independent 100-calendar-day extra-screen entitlement; never truncate it to the base monthly/yearly plan expiry. Still unresolved: whether the one included premium screen limit is *per paid child* (current working interpretation) or *per whole paying family*; actual Play offer and precise product cash-flow economics remain to validate.


## H. Owner correction — 2026-10-28 — Independent 100-day entitlement supersedes 30-day assumption

**Final commercial working direction:** ₹100 once buys **one extra premium concurrent viewer slot for 100 consecutive calendar days** from verified activation. The base plan expiry **does not modify or delete** the add-on's end timestamp. When the base prepaid child access lapses, premium sessions pause and cannot be initiated; only basic free services remain. The already-purchased extra-slot record and unused 30-minute combined A/V pool persist and are eligible again upon a manual base plan renewal during those 100 days. No pause of the 100-day calendar clock, no forced add-on repurchase, no automatic payment, no second-parent or second-child permission benefit. Example: buy day 1, monthly base expires day 29, renew base on day 70 → extra viewer slot becomes usable again on day 70 and expires at day 101 (100-day duration from activation). Exact dates must derive from timestamps rather than calendar-page numbering.

**Google Play fulfillment limitation:** published Play one-time *Rent* product periods are restricted to the product's supported periods (currently 48h, 72h, 30 days and 60 days), not a configurable 100-day rental. Use the repeatable Play one-time **Buy consumable purchase** with server-managed 100-day entitlement, backend verification and consumption/idempotency **only after** Play sandbox and Play policy checks; do not claim native 100-day Rent is supported. Official sources: https://support.google.com/googleplay/android-developer/answer/16430488 and https://developer.android.com/google/play/billing/one-time-products.

**Economics gate:** target gross ₹100 yields only approximately ₹72.03 available per sale under **illustrative assumptions** that ₹100 includes 18% GST and an eligible 15% Play fee applies to the ex-GST portion (`100 / 1.18 × 0.85`). This is about ₹21.61 per 30 calendar days of sold validity, before servers, support, bandwidth, refunds or tax adjustments; fee/GST treatment must be verified in actual settlement. 30min combined A/V quota covers only **one-time extra media minutes across the entire 100 days**, not per month or day. A 1 Mbps stream for 30 minutes transfers roughly **225 MB** to one receiver; running 1 Mbps continuously for 100 days would transfer **1,080 GB**, which is financially unsafe if not bounded. OCI publishes first **10 TB/month free outbound transfer per tenancy** (shared across all features); relay CPU, 10TB excess and HA remain unpriced. Must hard-cap all streamed media sessions, add-on AV balances, child media base quotas, bitrate and active viewer lease concurrency; measure TURN relay share and customer utilization before asserting ₹100 covers incremental load. https://www.oracle.com/in/cloud/price-list/ and https://support.google.com/googleplay/android-developer/answer/112622.

**Financial go/no-go:** prototype load testing with 100/1,000 sold add-ons, 10/50/100% quota use, one/two extra guardian receivers, selected video bitrates, realistic location-refresh traffic, relay fraction and refunds; require 100-day total marginal cost per sold add-on to stay below measured net proceeds with a reserve for ops. Free tracking is unaffected by this commercial screen-lease gate.


## OWNER SUPERSESSION — 2026-10-28: drop Google Family Link parental-role API dependency

**New decision overrides every older claim in this document that a co-parent may be invited ONLY if Google's Family Link parental role is programmatically verified, or that no sharing is possible until a public Family Link attestation API appears.** Google sign-in still verifies each adult independently (`iss/aud/sub/exp`). Madalasa's backend uses an exact-child single-use invitation, separately accepted and revocable scoped grants, device/child transparency, dispute hold, no sibling disclosure and security/authorization tests. **Legal verification of adult parental/lawful guardian authority and valid child-data consent is a distinct mandatory compliance gate, NOT waived**; synthetic local tests may use controlled fixtures, real child processing requires approved lawful method. A paid family seat is never a guardian permission and a second adult never inherits the entire family's children. See [V2 ADR](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/ADR_2026_10_28_BLEND_FAMILY_V2_AND_NO_FAMILY_LINK_DEPENDENCY.md) and [India legal brief](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/INDIA_CHILD_CONSENT_RETENTION_DELETION_ACTION_BRIEF_2026-10-28.md). Use new versioned DB migration, do not mutate M1 baseline. This is design only; no verified runtime has been built.
