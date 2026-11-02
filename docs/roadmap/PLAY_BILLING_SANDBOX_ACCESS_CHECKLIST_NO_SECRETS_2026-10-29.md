# Google Play Billing sandbox setup — safe owner handoff (no secrets)

**Created 2026-10-29; official-guidance review 2026-10-30. Status: setup/acceptance checklist only; no API connection, Console inspection, license test, product or purchase verified.** Owner reports active Personal Play developer account: individual **SWARNA SEKHAR DHAR, India**, same Play publisher legal entity for Payments/merchant setup. **Payments identity pending; merchant pending; tax/accountant not approved.** This does not mean a verified merchant or approved tax position. Never put account ID, private keys, OAuth refresh tokens or payment details in GitHub or chat.

## BillDesk application tracker update — 2026-11-03

The owner supplied a BillDesk portal confirmation reading **"Your application is successfully submitted"**. It issued a numeric Application ID (held outside this public repository) and instructs follow-up by email to **onboarding@billdesk.com**, with that ID in the subject. Application submission is **owner-confirmed**; BillDesk approval/Video KYC completion, Google Payments merchant activation, Play Console billing products and actual payment acceptance are **not verified**. A `BD` Partner ID is an alternative, not needed if the application ID is provided. The public Play Store listing requirement for an unpublished app remains an open BillDesk clarification.

This provider step does **not** block local billing API/ledger/negative/sandbox-fixture development, and does not authorize real purchase flows or a public app release. See [current tracker](../phases/M9-play-release/03-release-gates/BILLDESK_APPLICATION_SUBMISSION_TRACKER_2026-11-03.md). Earlier 2026-10-29/30 pending-payment wording is historical and must not be interpreted as absence of the subsequently confirmed application submission.

**Execution boundary:** all Console, IAM, catalog, RTDN and purchase actions below are future owner/authorized-operator steps, not actions authorized or performed by this documentation review. Use synthetic family/child fixtures; no real child data, real payment methods or production founding counts. No real products/purchases/credentials/Console actions in this review.

**Canonical owner policy:** [Subscription Plans — current reconciliation](../phases/M7-commercial-integrations/01-commercial-plans-and-costing/SUBSCRIPTION_PLANS_PRICING_AND_RULES_2026.md#current-canonical-reconciliation--2026-10-30). First **1,008 DISTINCT successfully paying families**, count a family once, founding **₹50/month or ₹500/year per eligible paid child**, including eligible children added later; regular **₹99/₹999**, existing customers retain their applicable prices with **no change**. Prepaid manual top-up only, no auto-renew. Optional **₹100 once / 100 calendar days / +1 child-scoped viewer / +30 combined pooled A/V minutes total** remains candidate provider implementation, dormant during base lapse without clock pause. Media **OFF** pending existing legal/Android/Play gates. No purchase creates guardian authority.

## Phase A: No credentials needed

1. In [Play Console](https://play.google.com/console) open each Android app (Madalasa parent; Alarka child if billing depends on it). Record whether they exist, their **package names**, track readiness and whether developer account production access or closed-test requirement is pending. **Do not record the developer Account ID in public files.**
2. Under **Monetize with Play → Products → Subscriptions** (navigation varies), inspect support for **nonrenewing prepaid** base plans, India availability, exact monthly/yearly prices and allow-extension configuration. Official guidance documents 1-month/1-year durations, but limits subscription offers to auto-renewing base plans: do not assume a prepaid founding offer or auto-renew legacy cohort preserves founding prices. Recommend testing separate prepaid catalog/pricing mapping, including later children, without changing owner prices or enabling auto-renew. N-seat/repeated-child catalog support remains **UNVERIFIED**.[3][4]
3. Under **Monetize with Play → Products → In-app products / One-time products**, inspect a repeatable consumable for proposed ₹100 extra premium viewer lasting **100 calendar days managed on the backend**; Play native 100-day Rent period is not available. Do not purchase or activate unsupported audio/video functionality.
4. Under **Settings → License testing** (or current equivalent), owner configures designated sandbox tester accounts. **Track membership and license-testing status are separate.** A license tester can sideload a matching configured package, even a debug-signed build; an uploaded test-track build is not universally required. For track validation record release/build, opt-in and installation path. A test-track user who is **not** a license tester can incur real charges: stop unless using the intended license tester and Play's test payment instrument/test-purchase notice. Do not use real-card Billing Lab modes. Test taxes are not computed; sandbox cannot prove final tax-inclusive INR settlement.[8]

**Build/setup preflight for a future test:** record the actual Billing Library dependency and supported device/Play Store environment, not just package names. The retrieved testing guide states Billing Library **8+** is required for new apps/updates from 2026-08-31, with a requestable extension only until 2026-11-01; no extension or dependency compliance is assumed here.[8] Confirm actual Console requirements and opt-in before any upload; this is not Android implementation or upload authorization.

## Phase B: Backend purchase verification (needs owner-managed access, never pasted into chat)

1. In [Google Cloud Console](https://console.cloud.google.com/), create/select an isolated project. Go to **APIs & Services → Library** and enable **Google Play Android Developer API**.
2. In **IAM & Admin → Service Accounts**, create a dedicated service account for verification, not broad publisher/editor access.
3. In **Play Console → Users and permissions**, invite that **service-account email**. For server-side billing verification Google currently documents **View financial data, orders, and cancellation survey responses** plus **Manage orders and subscriptions**. Restrict to relevant apps where possible. Do not give account administrator/publishing capabilities.[9]
4. Use **short-lived tokens through trusted server identity/workload identity** where supported, or securely hold any service-account key in a **local encrypted secret manager/outside Git**, never in conversation, Figma, public GitHub, screenshots or CI logs. Rotate and revoke a key if exposed.
5. For a separately authorized sandbox test, backend looks up the **opaque purchase token**, not a self-verifying signed receipt, through **purchases.subscriptionsv2.get** with the expected package and protected server identity. Validate approved product/base plan, prepaid type, provider state/expiry, account binding, linked token and acknowledgement; persist capacity/child allocation idempotently. Client callbacks/product hints never authorize entitlement.[5][6]
6. **Real-time developer notifications are required acceptance coverage** for this design, alongside restore and periodic reconciliation; they are not proof of payment on their own. Future setup needs a Pub/Sub topic, Google Play publisher permissions and authenticated receipt validation. Save only safe project/topic/subscription names. Durable dedup uses message ID plus transactional token/lineage idempotency; fetch latest provider state before entitlement changes. Configure retry/backoff/dead-letter recovery and read back actual resulting state.[7]

## Safe nonsecret details for planning

- App package name(s), whether apps have been created in Console and test tracks enabled.
- Personal account **creation-date category** (before/after 2023-11-13), any production-access/device-verification tasks showing in Console.
- Google Cloud **project ID** and **service account email** (not keys), if you want step-by-step review.
- Proposed Play product IDs and base plan IDs, and whether they are ACTIVE/DRAFT.
- Whether license tester configuration is finished; test outcome/error codes with token values redacted.

## No need to provide

Passwords, 2FA codes, developer account ID, service-account JSON, private keys, OAuth client secret/refresh token, raw purchase tokens, personal card or banking details, child/parent real profile data.

Official setup: https://developers.google.com/android-publisher/getting_started ; permissions: https://support.google.com/googleplay/android-developer/answer/9844686 ; billing test: https://developer.android.com/google/play/billing/test .

## Phase C: Traceable sandbox lifecycle and negative acceptance — NOT RUN

Every row below is **NOT RUN / release evidence missing**. Public guidance establishes test requirements, not a passing integration. Future evidence must include case label below, tested code SHA and build/library version, UTC time, synthetic fixture ID, redacted package/product/base-plan mapping, expected/actual state and expiry, token/predecessor digest references, acknowledgement result/deadline, inbox/ledger/seat-allocation result, command/test harness and exit code, redacted provider evidence and reviewer. Never publish raw tokens, personal account identifiers or keys. Record provider-only UI observations separately from executable test results.

| Case label | Positive lifecycle to prove | Negative / invariant to prove |
|---|---|---|
| M7-BILL-INITIAL | Review → purchased/provider-verified → durable grant + ack retry → acknowledged; one monthly and one annual prepaid case. | Wrong package/product/base plan, fabricated price/capacity, forged token, mismatched account binding or test purchase entering production grants nothing.[5][6] |
| M7-BILL-PENDING | Delayed test instrument resolves PENDING → PURCHASED, with grant only on verification. | Pending, user cancellation and decline never unlock seats or qualify a founding family; canceled pending attempt never revives from stale callback.[6][8] |
| M7-BILL-TOPUP | New token linked to prior token; provider expiry extends accumulated paid time, not capacity; `SUBSCRIPTION_PURCHASED` handled for each top-up. | Check `allowExtendAfterTime`; only one unconsumed top-up. Too-early/repeated requests and duplicate callbacks cannot add time/seats. Display actual full Play charge, not invented proration.[1][2] |
| M7-BILL-ACK | Initial and **every top-up** acknowledged promptly and provider state read back; recovery after server crash/ack timeout. | ≥1-week plans: 3-day deadline; shorter: half-duration. Deliberately missed top-up ack must reconcile potential revocation/refund of **remaining subscription too**. License-tester timing is accelerated; do not wait production days or treat test timing as production timing.[1][2][8] |
| M7-BILL-CAPACITY | Same Play payer: buy first selected child, add second/third, mixed terms and candidate capacity replacement; inspect actual catalog/state/cost/lineage. | Extra tokens/top-ups never mean extra concurrent seats; assignments ≤ verified catalog capacity. Unknown capacity, overlapping replacement or duplicate same-child purchase fails closed; no inferred five-seat production limit.[1][11] |
| M7-BILL-FOUNDING | Isolated synthetic ranks 1,007/1,008/1,009, concurrent first-payment attempts; same family counted once. Founding later-added children and top-ups retain ₹50/₹500; regular stays ₹99/₹999, existing pricing unchanged. | Trial/reinstall/guardian/child/top-up/replayed token cannot increment rank. Client-selected founding product cannot bypass eligibility. Resolve refund/chargeback/fraud slot recycling and checkout reservation/order with owner/finance before PASS; do not invent the policy. |
| M7-BILL-GRANTS | Both authorized adults use one paid child without duplicate payment; exact-child allocation and independent co-parent revocation. | Other child/sibling/family, billing-family membership alone, Google Sign-In alone and revoked/disputed grant cannot authorize child data. Purchase never bypasses consent, Android permission or deletion tombstones. |
| M7-BILL-EXPIRY | No top-up → verified expiry → free fallback, six-hour visible history under independent retention policy; manage/support/refund discoverable. | Prepaid has no renewal to cancel; no auto-debit, grace/hold fabricated from auto-renew flows, blanket no-refund or universal prorated-refund promise.[2][10] |
| M7-BILL-REVERSAL | Refund-only vs refund-with-revoke/void/chargeback reconciled to ledger and current entitlement; late reversal after replacement/consumption tested. | Refund-only not assumed revoked; revocation invalidates affected capacity/viewer/quota without deleting child data as a billing side effect. Old token/late RTDN cannot resurrect access.[6][10] |
| M7-BILL-RESTORE | Reinstall, second authorized parent device, offline reconnect and out-of-app purchase recovery bind to original family. | No double founding count or duplicate grant; API timeout/invalid or expired token does not create capacity. Reconcile within provider token-validity window; financial retention is a separate policy.[2][6] |
| M7-BILL-RTDN | Authenticated message → durable inbox → latest provider read → transactional update; duplicate/out-of-order/delayed/lost messages, API 429/5xx, crash/retry and reconciliation. | Wrong sender/package, malformed payload, same ID replay or distinct IDs for same purchase grant nothing extra. Notification type/time alone cannot override current verified revocation/expiry.[5][7] |
| M7-BILL-VIEWER | Candidate repeatable one-time consumable: verify → durable child-scoped 100-day +1 slot/+30 pooled-minute grant → consume; restore from backend ledger. | Repeat purchase must actually work; consume/grant retry never duplicates. Base lapse dormancy does not pause/reset deadline; renewal does not refill minutes. Refund/expiry removes affected grant; no A/V while media is OFF.[6][8] |
| M7-BILL-PRICE-TAX | Record exact displayed total/currency/term and server cohort mapping; reconcile later authorized non-test settlement evidence separately. | Annual not presented as monthly debit; no silent existing-price increase; test purchases do not establish GST/fee/withholding/net payout, Payments identity or merchant approval.[4][8][12] |

**Current provider/setup blockers:** protected access remains owner-managed; Payments identity/merchant/tax are pending; no configured catalog or account-specific prepaid availability has been inspected; founding prepaid pricing and multi-child capacity/repetition are unproven; no runtime verification/RTDN/refund tests executed. A 100-day backend viewer target is not a verified native Play rental or approved media sale. Hosting region/costs remain deployment decisions, not blockers for synthetic contracts.

## Sources

Official sources retrieved **2026-10-30**. Source numbers match the canonical subscription reconciliation; public pages were read, not Console state. General subscription marketing mentions offers broadly, but the specific Help “Offer” note limits them to auto-renewing plans.[4] Treat account-specific prepaid offer support as unverified rather than resolving this conflict by assuming support.

[1] https://developer.android.com/google/play/billing/subscriptions
[2] https://developer.android.com/google/play/billing/lifecycle/subscriptions
[3] https://support.google.com/googleplay/android-developer/answer/140504
[4] https://support.google.com/googleplay/android-developer/answer/12154973
[5] https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.subscriptionsv2/get
[6] https://developer.android.com/google/play/billing/security
[7] https://developer.android.com/google/play/billing/rtdn-reference
[8] https://developer.android.com/google/play/billing/test
[9] https://developers.google.com/android-publisher/getting_started
[10] https://support.google.com/googleplay/android-developer/answer/2741495
[11] https://developer.android.com/google/play/billing/subscription-with-addons
[12] https://support.google.com/googleplay/android-developer/answer/112622
