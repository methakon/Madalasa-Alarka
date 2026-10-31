# Madalasa–Alarka — Subscription Plans, Hidden Charges, Compliance Rules and Revenue Model

> **Document control:** M7 / 01-commercial-plans-and-costing · Proposed owner: Product + finance (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

> **Current product:** **Madalasa** (parent app) + **Alarka** (child app); the GitHub repository is now **[Madalasa-Alarka](https://github.com/methakon/Madalasa-Alarka)**. [English mythological inspiration](../../M0-foundation-and-approvals/02-market-and-feasibility/BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

**Document:** AP-SUB-PRICING-001  
**Version:** 1.0 historical baseline; reconciled 2026-10-30 | **Prepared:** 2026-10-26 | **Status:** owner policy recorded below; provider implementation/sandbox and tax/legal approval pending — not live Play Console products or a binding quote.
**Scope:** India-first Android family safety service with a **price per enrolled paying child**, shared parent/guardian viewing, and Google Play Billing.  
**Financial references:** [Third-Party Cost Analysis](THIRD_PARTY_SERVICES_COST_ANALYSIS_2026.md) (old ₹149 sensitivity) and [Oracle Chicago Deployment & Hosting](../../M8-operational-readiness/01-cloud-infrastructure/OCI_CHICAGO_DEPLOYMENT_AND_FINANCIAL_PLAN.md). Those documents remain separate cost ledgers.  
**Requirement references:** [SRS](../../M1-secure-platform-foundation/01-requirements-and-architecture/SRS.md) FR-012/022/039, [API](../../../openapi.yaml), [Data Security](../../M1-secure-platform-foundation/03-security-and-permissions/DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md).

## Current canonical reconciliation — 2026-10-30

**State:** owner commercial policy recorded; provider/catalog feasibility **UNVERIFIED**, sandbox **NOT EXECUTED**, Payments identity **PENDING**, merchant **PENDING**, accountant/tax **NOT APPROVED**. This is a documentation review, not billing implementation, legal approval or permission to create products/purchases. Publisher is the individual **SWARNA SEKHAR DHAR, India**, using the **same legal entity as the Play publisher**; no company incorporation or verified Payments identity is implied. Account status is owner-reported, not independently inspected.

### Owner decisions (not recommendations)

- First **1,008 DISTINCT successfully paying families**, counted **once per family**, qualify for founding **₹50/month or ₹500/year per eligible paid child**. Later eligible children added to that founding family retain founding pricing. Trial, extra guardian, extra child, device, top-up, restored token or repeated transaction must not count as another founding family.
- Regular prices remain **₹99/month or ₹999/year per paid child**. Existing customers retain their applicable pricing; this review authorizes **no price change**. Founding recognition persists through prepaid lapses where lawfully recognizable; retention/deletion policy still applies.
- **Prepaid manual purchase/top-up only; no auto-renew or automatic charge.** A premium button opens review, never silently purchases. Terms/month-year coverage and actual total come from Play, not fixed 30/365-day arithmetic.
- Payer selects exact covered child IDs. Child-specific adult grants are separate from payer-family membership; paying does not grant a co-parent access, expose siblings, or duplicate a charge for the same shared child. **No Google Family Link relationship lookup prerequisite**; Google Sign-In authenticates an adult, not parenthood. Approved authority/consent remains required.
- One included simultaneous premium viewer per paid child; optional extra viewer target is **₹100 once / 100 consecutive calendar days / +1 concurrent premium viewer / +30 combined pooled audio+video minutes total for that child**, not per month or per guardian. Base lapse makes it dormant, does not pause its clock; renewal before its independent expiry resumes remaining validity. It creates neither child seats nor permissions. Media remains **OFF**, subject to existing legal, Android, Play and safety gates. Repeatable one-time consumable Buy is a **candidate**, not a verified product.

### Official provider guidance checked 2026-10-30 (not account-specific proof)

| Topic | Verified public guidance | Project consequence / remaining gate |
|---|---|---|
| Prepaid availability | Play documents prepaid base plans, including **1 month and 1 year**, region-specific availability/prices and an allow-extension setting.[3][4] | Supports investigating the owner target; does not establish this India-based publisher account's availability, exact INR price, merchant readiness or catalog eligibility. |
| Top-up vs capacity | Top-up purchases extend the **same subscription's time**, charging the full selected period. They are not another concurrent child seat.[1][2] | Never multiply purchased capacity because a token, top-up or line item exists. Use a reviewed server catalog mapping to capacity and explicit child allocations; N-seat products or distinct-child products remain sandbox candidates. No approved five-child maximum is inferred from the old example. |
| Extension limits | Provider `expiryTime` is authoritative; early top-ups accumulate after existing expiry. `prepaidPlan.allowExtendAfterTime` indicates when another top-up is allowed; only one unconsumed top-up is allowed at a time.[2] | Show verified expiry and eligibility; reject early/disallowed repeated top-ups and duplicate extensions. Do not compute a fresh month starting at callback arrival. |
| Token lineage | Each top-up has a **new purchase token** with `linkedPurchaseToken` referencing its predecessor; each emits `SUBSCRIPTION_PURCHASED`, not a guaranteed renewal event. Token API validity ends 60 days after expiry.[2] | Reconcile the chain to the same payer family and capacity without stacking duplicate seats; retain bounded lawful financial evidence, not an indefinitely callable token assumption. |
| Acknowledgement | Initial prepaid purchases **and every top-up** require acknowledgement. Duration ≥1 week: within **3 days**; shorter: within **half the plan duration**. Missing a top-up deadline can revoke/refund the top-up **and remaining subscription**.[1][2] | Durable grant and acknowledgement-retry obligation, prompt server acknowledgement, deadline monitoring and refund/revocation recovery; never apply an unconditional three-day rule to every duration. |
| Cancel, expire, refund | Prepaid does not auto-renew and has no renewal to cancel: let it expire if no top-up. Refund-only and refund-with-revoke are different outcomes; reviewed refund policy and applicable law still apply.[2][10] | Provide manage/support/refund routes without a false “cancel next debit” promise. Revoke premium at verified expiry/revocation, not just on a UI cancel click; preserve free fallback, privacy/deletion rights. Account deletion is separate from provider refunds. |
| Founding price implementation | Help text explicitly limits subscription **offers to auto-renewing base plans** and says new prices apply to prepaid top-ups. Auto-renew legacy price cohorts are not a prepaid price-lock mechanism.[4] | Automatic founding eligibility is owner policy, **not proven prepaid offer support**. Recommend testing separate prepaid pricing/catalog mapping and strict server eligibility; do not switch to auto-renew to obtain offers. Protect later children and existing prices before launch. |
| Subscription add-ons | Play's subscription-with-add-ons requires auto-renewing plans, same recurring period and distinct product IDs.[11] | Cannot use that feature to assert repeatable prepaid child seats or the 100-day viewer product. |
| Fees and taxes | Current remaining-market fee table specifically gives 15% for **automatically renewing** subscriptions and separately lists fee-tier eligibility.[12] | No automatic 15% prepaid/one-time fee entitlement; merchant reports and accountant must establish rate, fee base, tax inclusivity, withholding/credits and net settlement. Test purchases do **not** compute taxes.[8] |

**Source ambiguity to preserve:** the lifecycle guide's prepaid field summary lists ACTIVE/PENDING/CANCELED, while describing expiry/revocation elsewhere; evaluate actual `subscriptionState`, line-item expiry and void/refund evidence together. Never infer paid access from an ACTIVE label after its expiry, nor treat a historical auto-renew grace/hold table below as prepaid semantics.[2]

### Proposed traceable server state/lifecycle (acceptance specification, not implemented)

Each attempt needs a redacted evidence reference binding payer family, selected child allocation, reviewed package/product/base-plan/capacity mapping, price cohort decision, token digest and predecessor digest, provider state/expiry, acknowledgement status/deadline, inbox processing result and financial reversal. Keep restricted raw API tokens outside public records. Token uniqueness, provider event deduplication, financial transaction uniqueness and family founding uniqueness are **separate** controls; order ID alone is not a universal purchase key.[6][7]

| Local state/event | Required source of truth and transition | Negative acceptance |
|---|---|---|
| REVIEW / PENDING | Authenticated payer request; pending/declined/canceled checkout grants nothing. Verify server-side using `purchases.subscriptionsv2.get` with the configured package and token.[5][6] | Client success, fake price/capacity, test token in production, wrong package/product/base plan or foreign-family binding never unlocks seats. |
| VERIFIED → GRANTED / ACK_DUE → ACKED | Validate line items, prepaid type, state, expiry, account binding and lineage. Atomically persist entitlement/allocation plus durable ack retry; call `purchases.subscriptions.acknowledge` promptly and read acknowledgement state back.[2][6] | Crash/retry or ack timeout creates neither a second grant nor a second founding count; unresolved identity/capacity fails closed and enters reviewed support/refund handling. |
| ACTIVE → TOP_UP_VERIFIED | Read fresh provider state; bind replacement token to same family, retire predecessor's independent authority, set provider expiry once and preserve audit lineage.[2][6] | Top-up cannot become a second child or grant to another family. Callback replay cannot add another month/year. |
| ACTIVE → EXPIRED / REVOKED | Enforce server expiry even if RTDN is delayed; fetch current state on notification, restore and reconciliation. Refund-only is reconciled financially without inventing revocation.[2][7][10] | No late callback, stale ACTIVE response, old token or offline cache resurrects revoked entitlement, guardian grants or deletion tombstones. |
| EXTRA_VIEWER_ACTIVE ↔ DORMANT → EXPIRED | Independently verified one-time purchase and fixed 100-day server deadline; base expiry gates usability, not the calendar clock. Consume only after durable exactly-once grant if consumable design is approved.[6] | Replay cannot add slots/minutes; base renewal does not reset 100 days or replenish 30 minutes; no purchase enables media while gates are OFF. |

**RTDN recommendation:** authenticated Pub/Sub ingestion, strict expected package validation, durable inbox dedup by message ID, transactional per-token/lineage processing, retry/backoff/dead-letter handling and reconciliation. RTDN is a change hint; fetch current Developer API state, never grant from notification type alone. Distinct message IDs can still describe one purchase, and out-of-order delivery must not roll entitlement backwards or revive revoked state.[5][7] These are required engineering tests, not verified implementation.

**Founding-count recommendation requiring implementation proof:** atomically assign a unique family rank/qualification on the first eligible successfully verified paid base purchase; concurrency at ranks 1,008/1,009 cannot over-allocate. **Open owner/finance decision:** refund/chargeback/fraud disqualification, slot recycling, first-checkout reservation/order and fair fallback if founding capacity changes during checkout. Do not silently choose these policies or charge a regular price after displaying founding pricing. License-test payments must be isolated from production founding rank.

### Release blockers and evidence boundary

- Publisher/Payments/merchant/tax approval as stated above; no payment details or private account IDs in evidence. Future Developer API access requires enabled API and narrowly scoped server identity/Play permissions; this review configured none.[9]
- Sandbox proof of same-Play-account multi-child capacity, repeated purchase behavior, top-ups, mixed terms/replacements, founding price access including later children and no existing-price migration.
- Executed state, negative and reconciliation tests in the [sandbox checklist](../../../roadmap/PLAY_BILLING_SANDBOX_ACCESS_CHECKLIST_NO_SECRETS_2026-10-29.md), with code SHA, commands/exit codes, sanitized provider responses, expected/actual entitlement transitions and reviewer. No test is marked PASS by this review.
- Legal child-data scope and Android capability remain separate gates. Hosting region/economics is a deployment decision, **not** a prerequisite for synthetic billing work. No real products, purchases, credentials, Console mutations or deployment were performed or authorized here.

## Sources

Official sources for the current reconciliation, retrieved **2026-10-30**. The historical material following this list is preserved separately below, not freshly certified.

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

## Historical 2026-10-26 proposal — superseded where inconsistent with current reconciliation

Sections 1–12 preserve the original auto-renew, universal ₹50/₹500, seat-catalog and financial sensitivities for audit history. Their approval rows and “recommended/official” wording are **not current decisions**. They must not be used as launch instructions. Later owner addenda remain effective only as reconciled above.

## 1. Historical decision and product-offer proposal

**Madalasa–Alarka's NEW recommended public price point is ₹50 per paying child per month OR ₹500 per paying child per year**, subject to Google Play Console validating the India offer/total displayed payable amount, merchant/tax setup, platform compliance and implementation of family-seat checkout.

| Term | Parent is charged | Covered service time | Renewing? | Equivalent per-child month | Effective benefit |
|---|---:|---|---|---:|---|
| Monthly | **₹50 per child** | One month | Propose **auto-renewing** | ₹50.00 | Cancel future renewal when desired |
| Annual | **₹500 per child** | Twelve months | Propose **auto-renewing** | ~₹41.67 *equivalent* | Saves ₹100 against 12 × ₹50 (16.67%) |

**Do not imply the annual plan is charged ₹41.67 monthly.** The actual recurring annual debit must be visibly shown as **₹500 every 12 months**, and the monthly as **₹50 every month**, including whether applicable taxes are already part of the visible price. The 15% fee assumption applies to an eligible **auto-renewing subscription** in India under Google's current remaining-market policy; **do not silently apply that fee to prepaid plans, alternative billing or other countries**.

No premium tier, paid camera/mic/remote capture, paid add-on or trial is approved in this document. Optional premium features must undergo separate platform/device, legal and cost gate.

## 2. What does one child subscription include?

**Proposed paid scope, subject to real Android and product release capability:** child enrollment under one approved family account, available location/latest status, observed route/trip history, parent-named places and supported alerts, child/device health/reliability information, authorized app-usage reports and manageable child-specific guardian grants. A guardian's viewing invitation does **not** add another paying child; payment attaches to a **child-seat capacity**, not a guardian login or the number of map views.

**Feature promises are gated by hardware and OS:** standard Android installation and fully managed DPC differ; OS permission rejection can make a feature unavailable even when subscription is paid. App must disclose capability before purchase; don't market unsupported controls as included.

**Noncommercial rights must always remain available regardless of payment:** view/cancel subscription, review disclosure/consent, report a problem, withdraw grants, protect/delete child data and account, request exported records where applicable, understand what monitoring is active and see accurate unsupported/offline states. Emergency/child-initiated SOS behavior must be safety-reviewed and transparent; do **not** block a previously advertised emergency feature solely because a payment retry failed without a clear plan for safe fallback.

**Not included without an explicit later plan:** guaranteed real-time location intervals or 24/7 emergency response, OS-bypass capabilities, Google Maps Roads street-level asset tracking, remote hidden mic/camera/video, bulk file extraction, watch-specific precision/SLA, Google Drive storage charges, or unlimited premium API usage.

## 3. Families with two or more children: Play Billing design blocker

**Critical constraint:** Multiple Play products can be bundled as add-ons, but **the same product ID cannot occur twice in one add-ons purchase**, and add-on items must share the same billing period and be auto-renewing; removing a single add-on independently has other lifecycle caveats. Do **not** assume one normal child subscription SKU can be purchased 2/3/4 times in the same Google billing account or repeated as identical line items.

### Recommended implementation: one family subscription with N child seats

**One paying family/account → one active family seat-count subscription** whose entitlement is an integer N. Owner selects capacity N, then securely assigns N active child profiles to those seats. A second parent/guardian can view authorized children without purchasing a second seat. This avoids duplicate identical product IDs and simplifies invoices.

**Candidate product catalog, all prices illustrative and subject to Play Console approval:**

| Active child-seat capacity | Proposed monthly family charge | Proposed annual family charge | Saving vs 12 monthly charges | Checkout representation |
|---:|---:|---:|---:|---|
| 1 | ₹50 / month | ₹500 / year | ₹100 / year | Proposed family seat product 1 |
| 2 | ₹100 / month | ₹1,000 / year | ₹200 / year | Proposed family seat product 2 |
| 3 | ₹150 / month | ₹1,500 / year | ₹300 / year | Proposed family seat product 3 |
| 4 | ₹200 / month | ₹2,000 / year | ₹400 / year | Proposed family seat product 4 |
| 5 | ₹250 / month | ₹2,500 / year | ₹500 / year | Proposed family seat product 5 |

- Create **separate Google Play subscription products for family capacity**, each with monthly and annual auto-renewing base plans. Suggested provisional IDs: family_children_1, family_children_2, ..., family_children_5. Final product IDs must be reviewed before activation; Play product IDs cannot be reused/changed after creation.
- **Initial family maximum candidate:** five child seats. Families with more than five children need product decision, new SKU(s), an approved family-wide pricing schedule or supported upgrade design. Don't imply no limit.
- A seat is activated for a verified, owner-approved child profile (not each phone/watch); multiple devices for one child still require capability, limits and fair-use design, not a second child subscription.
- Server's family active-seat count must never exceed the **current verified purchased capacity**; don't accept client text indicating more seats.
- **Increasing/decreasing N:** flow is a subscription product replacement/upgrade/downgrade. Google may calculate prorated charges or defer changes depending replacement mode; display **actual Play Billing purchase-screen amount and effective date** rather than promising a simple instant ₹50 increment.
- Mixed monthly and annual children in the *same family* are **not** included in the simple MVP seat catalog, because one family subscription has one period. Offer a clear period for the family; mixed billing requires a separate tested design.
- Canceling a family plan cancels renewal for **all child seats** after the paid period, without revoking anyone's privacy/deletion rights. Individual seat removal/child reassignment has owner confirmation, duplicate prevention and billing adjustment rules.
- Separate payment owner from child's guardian roles. Don't let a secondary guardian alter paid capacity unless delegated by the verified family owner.

**Feasibility gate:** create the products in a licensed Play Console test track and verify a real 1→2 seat upgrade, annual↔monthly switch, cancel, refund, trial/offer, resubscribe and multi-guardian access **before calling per-child billing implemented**. Alternative: distinct per-child products, but prove repeated purchase lifecycle and scalable SKU count in Play, not inferred.

## 4. Transparent charges and the difference between price and provider expense

Potentially confusing charge types must be disclosed distinctly:

| Charge or rule | Who pays / how billed | Included in ₹50 / ₹500 calculation? | Risk and control |
|---|---|---|---|
| Public subscription price | Parent payer | YES, customer-facing selected family capacity × per-child price | Display exact total at checkout and auto-renew |
| Google Play recurring service fee | **Developer** from eligible revenue; estimated **15%** India current model | Included as operating cost; **not extra charged on top of advertised app price** | Actual fee based on transaction, country and Play fee rules |
| GST / consumer tax on digital service | Responsibility depends on developer residency, market and Google tax rules | **NOT independently validated** whether chosen round number is final tax-inclusive user price | Finalize tax-inclusive Play checkout and payout reports |
| GST on Google's service fee / India tax obligations | Potential developer tax cash liability, sometimes input credit based on registration | **NOT included in flat 15%** | Check GSTIN/registration/invoices, input-credit eligibility with accountant |
| Withholding tax / GST TCS deducted or deposited by Google | Tax/compliance and payout/cash-flow item, may have reporting/credit implications | **NOT modeled as automatic extra permanent expense** | Reconcile actual settlement; don't double count TCS as a fee if creditable |
| Oracle hosting and backup | Developer pays Oracle | Separate [OCI forecast](../../M8-operational-readiness/01-cloud-infrastructure/OCI_CHICAGO_DEPLOYMENT_AND_FINANCIAL_PLAN.md) | Free allowances and capacity are unverified |
| Maps/Places/Geocoding | Developer via Google Maps billing | Lean India model currently ₹0 at 1k children | SKU rate, eligibility, field masks, session billing, abuse and quota |
| FCM push | No-cost messaging product under stated terms | ₹0 provider fee in model | Delivery not guaranteed; server/network cost elsewhere |
| Parent identity/login | Developer/provider | ₹0 **assumed** email/social login | Paid OIDC, guardians MAU, SMS OTP fees unresolved |
| Roads, Google Drive optional API/parent storage | Provider and/or parent storage purchaser | **Not enabled** | Asset-tracking license, quota/cost/consent unknown |
| Refunds, disputes, failed auto-renewals | Reduced developer collections, potential negative settlement | **NOT** guaranteed captured by the standard 15% deduction | Track reversal/refund and collection failures |
| Domain / third-party mail / support line | Developer | Domain already in OCI model; other vendor tools unpriced | Prevent double-counted domain; budget customer service |
| Play publisher registration | Developer | One-time onboarding; not recurring per-child | Google lists US$25 account registration fee in standard setup; confirm payment/country |
| Paid HA, audit, incident and support staffing | Developer | NOT included in cheap low-volume operating model | Production child-safety service needs separate signoff |

**Customer price rule:** Madalasa–Alarka itself should not add undisclosed "location refresh", "guardian access", "GPS", "server", "SOS", or "activation" fees to these plans. Changes or optional charged add-ons need separate opt-in checkout and truthful price display. Google Play/payment method may apply payment terms or regional tax according to final checkout; verify final amounts before marketing as all-inclusive.

### Tax-inclusive example — NOT a tax determination

If the **₹500 annual payment includes an illustrative 18% consumer GST**, the pre-consumer-tax amount is about **₹423.73**, not ₹500. If the illustrative 15% Play fee is calculated on that assumed pre-tax amount, it is about **₹63.56** rather than ₹75. After the 1,000-child model's ~₹38.86/year allocated hosting budget, that leaves approximately **₹321.31 per child/year** before other costs and any tax on service fees.

Likewise a **₹50 tax-inclusive monthly charge** implies ~₹42.37 before consumer GST; subtract ~₹6.36 illustrative Play fee and ~₹3.24 hosting allocation, leaving about **₹32.78 per child/month** before other expenses. **Actual applicable GST classification, seller location, collection mechanics, Play service-fee base, input credits and exact settlement must be confirmed by accountant and real Play reports.** Do not assume 18% universally applies, add GST twice, or portray TCS as a lost fee when creditable.

For an **illustrative separate fee-tax sensitivity**, if 18% GST were additionally payable on a gross ₹75 Google service-fee invoice with **no usable tax credit**, that would be **₹13.50 further cost per ₹500 annual purchase**. This is a conditional example, **not** a statement of the actual tax payable. It must not be stacked blindly on the inclusive-tax model above.

## 5. Financial model at exactly 1,000 active paying children

**Assumptions:** stable 1,000 child seats for a full year; each subscription pays on time; all 1,000 on one term in first two rows; India 15% **auto-renew** Play service fee; per-year **budgeted hosting allocation ~₹38.86/child** (₹3,238.47/month for 1,000, or ~₹38,862/year total), not solely the ~₹2.39 direct hosting bill; lean Maps/Places no overage and no paid SMS. Gross revenues modeled **before tax**, refunds, customer acquisition and staffing. Parent family count can be below 1,000 if multiple child seats.

| Per paying child / 12-month normalized | Gross receipts if fully collected | Modeled Play 15% fee | Allocated hosting budget | **Remaining before additional costs** |
|---|---:|---:|---:|---:|
| Monthly: 12 paid cycles | ₹600 | ₹90.00 | ₹38.86 | **₹471.14** |
| Annual: one paid year | ₹500 | ₹75.00 | ₹38.86 | **₹386.14** |
| 50% annual / 50% monthly | ₹550 | ₹82.50 | ₹38.86 | **₹428.64** |

**Annual plan math:** ₹500 − ₹75 Play fee − ~₹38.86 hosting budget = **~₹386.14 per child/year**; at 1,000 child seats = **~₹3,86,138/year** remaining before unpriced expenses.

**Monthly plan math:** 12 × ₹50 = ₹600; 12 × ₹7.50 Play = ₹90; minus ~₹38.86 annual hosting budget = **~₹471.14 per child/year**, equivalent ~₹39.26 per child/month; at 1,000 = **~₹4,71,138/year** before unpriced expenses.

**50/50 seat mix at stable enrollment:** about **₹5,50,000/year gross collected** across 1,000 children, **₹82,500 Play fee**, ~**₹38,862 budgeted hosting**, leaving **~₹4,28,638/year**, with one half paying annually and the other paying every month. A mix of 1,000 *families* with multiple children is not the same as 1,000 *child subscriptions*.

### Cash-flow timing is different

- **Annual**: ₹500 per child is charged upfront when each child-seat family plan is purchased (at the applicable family amount), then service is provided for 12 months. If 1,000 paid seats start in the same month, nominal gross upfront amount is ₹5,00,000; this money is **not 12 months of profit**. Revenue recognition, settlement delay, refund reserve and accrued future hosting/support are separate.
- **Monthly**: ₹50 per child every month *only while payment succeeds and renewal continues*. "₹600/year" requires **12 paid renewals/payment periods**; churn, account hold, failed payment, UPI/autopay setup and cancellation can reduce collected revenue.
- The annual ₹500 price is **16.67% below** 12 × ₹50. It may improve upfront cash and retention but increases refund/prepayment obligations.
- Never market ₹500/year as "₹41.67 charged monthly" or treat a current active child as guaranteed to renew for a whole year.

## 6. Scale scenarios: pricing sensitivity, external API usage and hosting **allocation**

Rows below combine **an existing OCI hosting budget with reserves** and **the lean non-Oracle paid Maps event estimate** (₹0 at or below 5k assumed Indian children, ~₹808/month at 10k), plus Play's modeled fee. These figures are **for total business revenue comparison only**: they are not extra provider bills, and Oracle/third-party costs remain in their own authoritative documents.

**Monthly column:** assumes all seats pay ₹50 each month.  
**Annual column:** assumes all seats pay ₹500 for each full year; annual remaining amount deducts **12 months** of hosting/Maps allocation.

| Paying child seats | Monthly gross @₹50 | Monthly Play fee | Hosting+Maps budget/month | **Remaining/month (all monthly)** | Annual gross @₹500 | Annual Play fee | **Remaining/year (all annual)** |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 500 | ₹25,000 | ₹3,750 | ₹1,680 | **₹19,570** | ₹2,50,000 | ₹37,500 | **₹1,92,340** |
| 1,000 | ₹50,000 | ₹7,500 | ₹3,238 | **₹39,262** | ₹5,00,000 | ₹75,000 | **₹3,86,138** |
| 2,500 | ₹1,25,000 | ₹18,750 | ₹9,878 | **₹96,372** | ₹12,50,000 | ₹1,87,500 | **₹9,43,962** |
| 5,000 | ₹2,50,000 | ₹37,500 | ₹20,267 | **₹1,92,233** | ₹25,00,000 | ₹3,75,000 | **₹18,81,795** |
| 10,000 | ₹5,00,000 | ₹75,000 | ₹43,428 | **₹3,81,572** | ₹50,00,000 | ₹7,50,000 | **₹37,28,870** |

**At 10,000 seats, the loaned VM size and API traffic are scenario assumptions, not certified support for 10,000 children.** Product must measure raw GPS observation volume, server load, Maps billing, actual guardian usage and required high availability before accepting a final profit forecast.

### 6.1 Break-even price floor is NOT ₹38.86

The ~₹38.86/year reserve allocation is a **partial modeled infrastructure budget per child at 1,000 seats**, not the product's true full cost. A viable price floor needs: Play percentage of tax-adjusted sale, real hosting including backups and HA, paid Maps/SMS/identity, payment collection risk, real customer support, app security audits, compliance/legal, family onboarding, device/OS support, app maintenance salaries and customer acquisition. No honest fully loaded break-even or profit number exists yet.

## 7. Payment, renewal, cancellation and refund rules

| Customer event | Product promise and UI behavior | Backend rule |
|---|---|---|
| New purchase | Show total due now, covered seat capacity, term, next regular charge and auto-renewing disclosure **before** Google checkout | Verify Play purchase token/state on backend; allocate seats after PURCHASED |
| Successful renewal | Continue existing child seats and grant scope | Verify current subscriptionsv2 state and expiry; update entitlement idempotently |
| Pending payment | Show PENDING, don't silently claim paid entitlement | Do not unlock paid seats from pending token |
| Grace period / silent retry | Explain payment issue privately to payer, preserve access while Play reports entitlement active/grace | Follow current Play state; do not shorten recognized grace ad hoc |
| Account hold | Clearly show paid premium features unavailable; provide repair link | Remove paid entitlement during hold, protect child data and core privacy rights |
| Voluntary cancellation | **Stop future renewal**; normally retain purchased benefits until current paid expiry | Don't immediately delete data or revoke a still-paid term |
| Expiration after cancellation | No future charge; move premium functions to disclosed fallback | Revoke premium entitlement, preserve record access/deletion under retention policy |
| Refund without revoke | Explain that refunds and access depend on Play resolution and law | Follow verified order/purchase state; don't assume immediate expiry |
| Revocation or chargeback | Explain status and dispute/support path | Revoke affected entitlements, audit reason, don't destroy user data automatically |
| Monthly↔annual plan change | Show actual Play-calculated payable amount, proration and next renewal date | Handle linked purchase token/new SKU, prevent duplicate overlapping paid seats |
| 1→2 child seat upgrade | Price shown from actual Play checkout, no invented immediate amount | Change capacity only when new subscription state verified |
| Remove one child | Explain when reduction is effective and what happens to stored records | Seat reassignment or downgrade policy; no implicit partial refund claim |
| User deletes account | Show data deletion and **separate subscription cancellation action** as necessary | Revoke credentials, run deletion jobs, reconcile Play purchase and lawful refunds |

All subscription plans must have an in-app **Manage / Cancel subscription** route linked to Play's online management screen, transparent self-service information and working support path. On Android where Play owns payment, open Play subscription management via the correct purchased product id and application package; do not fabricate a third-party payment cancellation flow.

**Refunds:** Google Play and developer-specific refund rules, consumer law and Play API capabilities apply. We cannot declare "all sales final", deny refunds categorically, charge a made-up cancellation fee, or promise universal prorated refunds. Publish a reviewed refund policy with process and time expectations; reconcile chargebacks and refunded entitlements using Play APIs. A refund can create **negative developer payouts** and collection obligations.

**No automatic free trials at launch** as the safe default. If added later, Play requires prominent duration, post-trial charge, auto-renew, cancellation method and availability of a no-trial option.

## 8. Billing implementation in Kotlin Android + C++20 backend

### 8.1 Suggested server resources

- billing_accounts(family_id, payer_principal, play_package, store_country, current_verified_plan, store_subscription_product, seats_paid, period, expires_at, renewal_state, pricing_currency, auto_renew_flag, purchase_token_reference_hash, generation).
- verified_play_purchases(purchase_token_hash UNIQUE, package, play_product_id, base_plan_id, order_key, expiry, verification_at, raw_provider_state_ref, acknowledgment_at). Store encrypted raw tokens only in restricted secret-backed storage if required for API calls; hashes prevent duplicates.
- child_seat_assignments(family_id, child_id UNIQUE within family, seat_index, assigned_at, transferred_at), composite family/child foreign key and owner controls.
- provider_event_inbox(message_id/notification_id unique, received_at, verified_at, state, retry_count) and financial_order_ledger(order_id when available, event type, transaction currency, gross, tax, fee, net, settlement_ref), **all idempotent**.
- Seat_count consistency under transaction/lock: active assigned children <= verified seats for family, no sharing token between families.

### 8.2 Backend purchase protocol

1. Native parent selects count and billing period; fetch product details/price and offer token from **real Play Billing product catalog**; show exact Play totals and subscription renewal/cancellation information.
2. Google Play purchase is made by parent payer; client gives purchase token to backend over authenticated TLS, along with product hint (hint **never** authorizes).
3. Backend calls **Google Play Developer API purchases.subscriptionsv2.get** with authorized server credentials, verifies package name, line items, state, expiry, linked token/replacement and original purchase/account binding; reject tokens assigned to another family.
4. Record verified purchase and family capacity in one transactional, idempotent operation; apply verified paid state, then acknowledge any new purchased token promptly (Google documents an approximately **three-day** acknowledgment deadline for purchased subscriptions; missing it may lead to refund/revoke). Retrying ack is safe with dedup.
5. Configure Real-time Developer Notifications (RTDN) to an authenticated server-side ingestion path (transport infrastructure must be scoped, secured and priced). Treat notifications as **hints** to fetch actual Play state, not direct entitlement authority.
6. Handle PURCHASED, RENEWED, IN_GRACE_PERIOD, ON_HOLD, CANCELED, EXPIRED, RECOVERED, REVOKED and purchase-token replacements; synchronize in app login/restore and nightly reconciliation. Detect refund/voided purchases as separate lifecycle events.
7. Only user owner/payer can change plan; guardian child data access continues to require child-specific scopes in addition to active subscription/capability check. No server/client can make Android permissions appear by paying.
8. Parent UI shows paid child seats, assigned child names, Play-provided actual next billing date/price, payment status, manage link, and explanation of staleness/unsupported capabilities.
9. Billing events cannot create new family grants, increase device management rights, reactivate revoked child data or bypass deletion tombstones.
10. Reconciliation must distinguish **active paid child seats** from active parents, active families, concurrent devices and guardian members.

### 8.3 Tests before launch

- Purchase, 1→2→3 family seat SKU upgrade; canceled purchase; pending state; duplicate/forged token across families; Play account differs from owner; 2+ guardians on one paid child.
- Monthly and annual renewal; annual downgrade; midperiod effective date/proration; declined UPI/autopay, silent grace, explicit grace, account hold, recovery, cancel, expire, re-subscribe and refund/revoke.
- Refund and payment withholding reconciliation; Play reporting amounts vs backend ledger; price country and tax totals; price changes and legacy price cohorts; bad/fraudulent receipts.
- Restore after parent-app reinstall and child-device transfer; lost payer Google account support scenario; owner change and temporary guardians.
- Open Manage Subscriptions and cancellation/online disclosure without hidden menu; pre-purchase capability check on standard Android vs DPC.
- Low-network/device clock-skew RTDN out of order; ack request timeout; callback replay and duplicate purchase token; no leaked payment or child identifiers in logs.

## 9. Google Play, Indian consumer and privacy compliance rules

| Rule | Project implementation |
|---|---|
| Play subscription transparency | Cost, billing frequency, auto-renew, included benefit, trial if any, and cancellation **shown upfront**; no misleading effective-monthly annual charge |
| Ongoing value | Charge recurring subscriptions only for sustained ongoing service, not a one-time child setup |
| Billing system | Use supported Play Billing for applicable in-app digital subscriptions; alternative billing in India has its own enrollment, reporting, processor, fee and compliance obligations and is **OFF by default** |
| 15% fee | As of reviewed October 2026 India auto-renewing subscription default for remaining markets; re-check regional rollouts before publishing, never assume worldwide |
| Tax obligations | Registered seller/controller location and exact GST/withholding/TCS need accountant review; obtain service-fee tax invoices and reconciled country reports |
| Offers and price changes | Correct Play base-plan/offer eligibility, price cohorts and user notices/consent when needed; do not silently migrate existing users to a higher price |
| Refund policy | Clearly available to purchaser; apply mandatory consumer rules and Google refunds; use provider APIs for proper entitlement updates |
| Monitoring/child data policy | Payment doesn't authorize secret capture, background permission bypass, inaccessible privacy controls or indefinite child-data retention |
| Parent cancellation and data deletion | Independent flows and disclosures; no loss of right to revoke child access or erase eligible records on cancellation |
| Family seat billing | Don't silently bill each guardian; parent payer approves N children and sees full amount before checkout |
| Overseas customers | **Not priced or enabled by this India-only plan**; country pricing, fee/tax, supported platforms and legal requirements require separate approval |

**Potential hidden fee conditions to monitor:** (a) Google fees on changed price/country, (b) GST on customer service or Google's invoice, (c) payout withholding/TCS, (d) payment failures/refund clawback and negative balances, (e) Identity/SMS verification traffic, (f) Places Pro API and Google Roads, (g) additional storage/HA/operating staff, (h) a charged alternative billing processor, (i) currency conversion and foreign markets, (j) Google Play registration/verification, and (k) legal security/support costs needed to operate minors' safety data responsibly.

## 10. Release decisions and blockers (specific owner checklist)

| Blocker ID | Required decision/evidence | Owner | Status |
|---|---|---|---|
| SUB-01 | Approve actual retail price **₹50 monthly / ₹500 yearly per child** and country India | Project owner | **PROPOSED** |
| SUB-02 | Decide whether displayed price is **final tax-inclusive payable** and tax/GST legal setup | Project owner + accountant | **OPEN — important** |
| SUB-03 | Verify Play Console accepts exact ₹50 and ₹500 as base-plan prices after tax/localized price setup | Play publisher | **NOT TESTED** |
| SUB-04 | Confirm existing/new account's actual India Play subscription fee/merchant and settlements | Publisher/finance | **UNVERIFIED** |
| SUB-05 | Confirm **one family capacity subscription** design (1–5 child seats) and what to do for 6+ | Owner + Android billing engineer | **PENDING APPROVAL** |
| SUB-06 | Choose seat upgrades/downgrades effective dates, refund/support and multi-owner transfers | Owner + billing engineer | **OPEN** |
| SUB-07 | Choose which capabilities are included in base price, fair use, Wear and managed feature boundaries | Owner/product/legal | **OPEN** |
| SUB-08 | Confirm launch login provider, whether SMS OTP is used and guardian-per-family allowance | Owner/security | **OPEN** |
| SUB-09 | Agree India Maps billing eligibility, API quotas, fee caps and optional Roads/Drive OFF | Owner/Maps project | **UNVERIFIED** |
| SUB-10 | Check actual OCI and device scalability, backup and production HA/support costs for 1k child seats | Backend/SRE/QA | **NOT BENCHMARKED** |
| SUB-11 | Verify Play Billing Library compatibility, sandbox products, RTDN, purchase ack, refunds and cases | Developers/QA | **NOT IMPLEMENTED** |
| SUB-12 | Publish legal Terms, Privacy, subscription disclosure, online cancel guidance and refund rules | Publisher/legal | **NOT PUBLISHED** |
| SUB-13 | Decide minimum customer support and incident/SOS promises and monthly spend | Owner/operations | **UNPRICED** |
| SUB-14 | Determine country rollout, prices beyond India, FX, taxes and 2026/2027 new Play fee applicability | Owner/finance | **DEFERRED** |
| SUB-15 | Decide trial (default NONE), prepaid (default NONE), coupons and alternative billing (default NONE) | Owner | **DEFAULT DISABLED** |
| SUB-16 | Final signoff on 1k subscription per-child economics from real invoices, refunds, taxes and retention | Finance | **NOT VERIFIED** |

**Recommendation:** Approve **₹50 monthly / ₹500 annual per child as the proposed entry tier**, with **1 family subscription containing paid seats**, **no trial or surprise paid add-ons**, Google Play as the only billing rail for launch, India only, and **tax-inclusive final checkout amounts if accountant/Play allow these exact prices**. Do not declare the remaining modeled ₹386–₹471/year per child to be profit; those figures omit important fixed and variable costs.

## 11. Sources checked for the 2026-10-26 plan

- Google Play subscription transparency and ongoing value requirements: https://support.google.com/googleplay/android-developer/answer/9900533
- Create subscriptions, base plans/offers, cancellation method and tax price settings: https://support.google.com/googleplay/android-developer/answer/140504
- Google Play regional subscription fee and India remaining-market 15%: https://support.google.com/googleplay/android-developer/answer/112622
- Play Billing family add-on limitations (distinct product IDs, shared periods): https://developer.android.com/google/play/billing/subscription-with-addons
- Subscription pricing, prepaid/auto-renew, billing period switch: https://developer.android.com/google/play/billing/subscriptions
- Play subscription lifecycle: https://developer.android.com/google/play/billing/lifecycle/subscriptions
- Billing Library acknowledgment and updates: https://developer.android.com/google/play/billing/integrate
- Real-time developer notifications: https://developer.android.com/google/play/billing/rtdn-reference
- Play refunds, price-change and developer obligations: https://support.google.com/googleplay/android-developer/answer/2741495
- India digital-sale GST, Google service-fee GST, TCS/withholding responsibilities: https://support.google.com/googleplay/android-developer/answer/138000
- Play India user choice billing conditions (not a free 4-point saving): https://support.google.com/googleplay/android-developer/answer/13306652
- Oracle baseline and per-child reserve at 1,000: [Hosting Financial Plan §14.10](../../M8-operational-readiness/01-cloud-infrastructure/OCI_CHICAGO_DEPLOYMENT_AND_FINANCIAL_PLAN.md)
- External API and earlier illustrative ₹149 pricing: [Third Party Cost Analysis](THIRD_PARTY_SERVICES_COST_ANALYSIS_2026.md)

**Historical document precedence (superseded by current canonical reconciliation above):** This was the 2026-10-26 proposal baseline for Madalasa–Alarka subscription prices. The ₹149/month figures in older cost analyses are **historical price sensitivity examples only**, not official or recommended public prices. No price, billing SKU, tax-inclusive status or merchant configuration has yet been activated in Play Console.

## 12. Pre-launch India legal and full cash break-even correction

This document is **not a launch clearance**. For under-18 Indian children, require legal counsel interpretation of DPDP Act section 9, Rule 10 verifiable parent and Fourth Schedule Rule 12 real-time safety exception; separate decisions for historical routes and app-usage behavioural monitoring, and section 16 processing of Indian minors' data on OCI Chicago in the US. Child-related DPDP provisions have staggered commencement ~May 2027; this is not a compliance holiday. [India child-data legal gate](../../M0-foundation-and-approvals/03-legal-and-privacy/INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md). Unapproved history/usage are OFF until signed legal scope; avoid selling a subscription for legally blocked capabilities.

**Pricing sustainability:** A budgeted OCI hosting cost of ₹38.86/child/year and Play's assumed 15% fee do NOT cover support, independent Android QA, security/legal review, cross-tenant incident on-call, server recovery/HA, SMS SOS fallback, Maps paid APIs, chargebacks or marketing. At 1,000 paid seats, if ₹50/₹500 consumer prices **include illustrative 18% GST**, available monthly cash after a modeled Play fee and **existing hosted reserves** is only **~₹32.78/child/month** on all-monthly or **~₹26.78/child/month equivalent** on all-annual; staffing ₹50,000/month alone exceeds both. Detailed formula, fixed-cost sensitivity and staffing inventory: [Break-Even and Team Capacity](PRICE_BREAK_EVEN_STAFFING_AND_DELIVERY_CAPACITY.md).

**Owner must approve** publisher/countries/child ages, purpose-specific retention, who can add/revoke guardians, login/age verification, safe resettable Android test phone, RPO/RTO and named team + customer support budget before any real-child pilot or revenue/profit claim. [Decision register](../../M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md).



## 2026-10-27 owner commercial/UI direction — supersedes conflicting historical proposals

**State: owner-approved design direction, NOT deployed, legally signed off, or Play Console/device tested.** Launch is India-first, **manual-renewal Google Play prepaid only**. No automatic renewal, background charge, or charge triggered by opening premium feature; parents explicitly confirm each purchase/top-up in Play. At verified prepaid expiry, downgrade to free: live tracking at a reduced adaptive GPS interval (moving design target approximately 10–15 minutes, slower stationary; no Android timing guarantee), most recent **six hours of visible location history**, and no paid media. Premium requests show payment review instead of silently charging. Deleting the account revokes child/guardian access and future ingest, and cannot generate an auto-renewal; handle any legacy auto-renewing purchase independently if ever issued.

**Price targets per paid child:** public ₹99/month or ₹999/year; founding ₹50/month or ₹500/year for the first **1,008 distinct successfully paying families** counted once each. All eligible paid children in a founding family, including added later, qualify. Founding eligibility persists through prepaid lapses when lawfully recognizable. Automatic eligible early-access offer, no coupon entry, subject to real Play prepaid products/offer support, taxes, fee confirmation and purchase-screen amount. Trial activation does not count as a paying founding family.

**Introductory experience:** once per eligible verified family, 48 hours of conditional Super Access with no auto-conversion, independently server timed. Across the FULL trial per eligible child, shared between authorized guardians: 5 audio minutes (3 min max/session), 2 video minutes (1 min/session), 3 successful photo snapshots, 2 screen-view minutes (1 min/session). Paid Balanced per paid child per month: 60 audio minutes (5 min max/session), 20 video minutes (2 min/session), 30 photos, 10 screen-view minutes (2 min/session). Count confirmed delivered session consumption, not failed OS attempts. Media remains **OFF / P3 conditional research** until Android, legal, Google Play, safety and device gates permit. No implied covert or guaranteed background sensor access.

**No repeated trial:** verify adult parent identity and prior redeemed or paid eligibility server-side, with a minimized bounded lawful anti-abuse ledger; optional Play Integrity/Device Recall subject to availability and review. Reinstall, logout, closure/recreation, or adding a child never restarts a lawfully recognized trial. Do not store child routes, images, microphone recordings, Aadhaar or IMEI to enforce eligibility. Legitimate families incorrectly blocked require review; permanent matching of an erased identity is not guaranteed.

**Storage vs visibility:** six-hour free history is an access limit, NOT a retention authorization. Earlier child location data can only remain for independently approved purpose-specific periods, not automatically until account closure. Deletion revokes token access, cuts off late offline uploads, and erases eligible data including backups as policy dictates. Legal retention, deletion exceptions, guardian authority and cross-border processing remain open gates.

**Parent UI:** replace oversized purple 48h hero with compact off-white/teal-style dismissible trial strip/pill (around 48–64 dp): “✦ Super Access · 47h left” plus accessible close X. The close dismisses marketing banner for the current in-app navigation session, NOT trial entitlement/countdown; a small plan/status entry remains visible. No flashing, support reduced motion. The opening welcome announcement may show once, then small strip; real countdown derives from backend. Trial-ended messaging clearly explains free tracking and manual prepaid upgrade.

**Costing:** existing OCI 1,000-child allocation (~₹3,238/month) explicitly excluded media. Provisional separate ₹3,000/month testing reserve is NOT a TURN/WebRTC provider quote, nor a production capacity promise; measure concurrency, relay ratio, bandwidth, storage, taxes, prepaid Play fees and full operating expenses. Older ₹50/₹500 as universal public pricing, auto-renewing products, 15% auto-renew fee cases, and corresponding revenue scenarios in preceding sections are HISTORICAL and need a full prepaid recalculation. Confirm Play Console purchase/top-up/seat-count/offer behavior before enabling billing.

**Screen consistency and traceability:** base UI source [existing 81-screen Figma handoff](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=6-2) (off-white/teal parent visuals). Update dashboard/map/history trial strip and billing screens P-47/P-48/P-49 plus deletion P-44, capabilities P-46, trial eligibility and media views to show this rule. Do not claim static Figma designs are working Android screens.


## 2026-10-28 — Two parents, one child payment; select paid children (supersedes conflicting assumptions)

**Owner working decision:** one verified prepaid **paid child entitlement** may be used by *both separately signed-in, explicitly authorized parent accounts* within the same Madalasa family. Second parent does **not** buy a second plan for the same child. Primary billing adult selects which child IDs are covered by N paid seats; nonselected siblings stay on free features. Permissions remain scoped per adult-child grant, shared quotas meter per child across both parents, and co-parent access is revoked independently of purchase. One family is counted once for first-1,008 founding-family eligibility. Prepaid/manual renewal only, no auto debit; when expired both parents revert to the child's free tracking/reduced frequency/six-hour visible history. Other rules unchanged.

**Google verification:** [Family Link supports a second adult parent](https://support.google.com/families/answer/7295768) but does NOT automatically authorize Madalasa or expose a verified public parent-relationship API to this app. [India does not support new Play Family Library/family payment signups](https://support.google.com/googleplay/answer/16719923), and [family payment methods exclude subscriptions](https://support.google.com/googleplay/answer/15775614). Google Play purchases stay with the paying Play account; backend verifies and binds unique purchase tokens to family capacities/child entitlements, NOT guardian devices. [Play prepaid add-ons are unavailable](https://developer.android.com/google/play/billing/subscription-with-addons) because add-ons are currently auto-renew-only. Play Console sandbox must prove suitable N-seat prepaid SKUs, explicit seat reassignment, upgrades, top-ups and founding offers before any launch pricing promise.

**Canonical implementation design:** [Two-parent Shared Child Entitlements and Seat Selection](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/TWO_PARENT_SHARED_CHILD_PREPAID_ENTITLEMENTS_2026.md) (use an appropriate relative path from each document). Figma added [P-47 family child seats](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=81-179) and [P-49 covered by family](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=81-201), editable mockups only. Media and other restrictive Android features remain gated.

## 2026-10-28 owner change — child-by-child co-parent grants and extra concurrent screen

**This addendum overrides preceding broad "shared family" access assumptions:** primary payer assigns paid seats to selected children and must separately choose **exact child+co-parent pairs** for sharing. Nothing about paying for Child A unlocks Child B; new spouses and their children remain private by default. **Google-recognized parental accounts requirement superseded by later owner direction and the six-gate handoff:** separate adult authentication plus exact-child accepted invitation and approved authority/consent replaces Google Family Link lookup. Google Sign-In alone does not prove parenthood. No guessing/fake verification, no forced broad sharing; real child-data processing remains legally gated.

**Concurrency working policy:** one included simultaneous **premium viewer screen per paid child** across every authorized parent device; free tracking and safety notices remain available. Additional +1 concurrent premium viewer slot is **₹100 target one-time, no auto-renew**, fixed 100-calendar-day entitlement; remains valid through base prepaid lapses though premium use pauses. The former provisional 30-day proposal is **superseded** by the owner-selected **100 independent calendar days** below. Each purchased slot contributes **30 minutes combined audio+video** to that *child's* shared balance, not 30 each. These are child- and period-scoped; they don't add child seats or extra permissions. Capture still disabled until Android/Play/legal gates and media feature flags pass. Google Play one-time consumable (or time-bound rent alternative) requires Play Console feasibility tests, backend purchase verification and exact displayed pricing; prepaid subscription add-ons are auto-renew-only and cannot be used.

[Canonical child-specific sharing + concurrent viewer/add-on specification](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/CHILD_SPECIFIC_GOOGLE_PARENT_SHARING_AND_CONCURRENT_SCREEN_ADDONS_2026.md). [Figma SH-01..05 preview](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=84-179). Any historic family-wide access, automatic second-parent entitlement, or unlimited concurrent screen statements are superseded. Extra streaming bandwidth must be costed.

## 2026-10-28 owner-selected extra-screen validity: 100 independent calendar days

**Overrides former 30-day or base-expiry cutoff:** ₹100 one-time, +1 simultaneous child-scoped premium viewer screen for 100 consecutive days from verified purchase, with no automatic renewal. Child's base monthly/annual prepaid expiry does **not** shorten or erase purchased extra-screen validity. On a base lapse, extra premium viewing becomes temporarily dormant; if manually renewed within day 100, the same paid extra viewer slot resumes until its original independent expiry. Countdown is calendar-time and does not pause. 30 combined audio/video extra minutes remain one total add-on quota across the entire 100 days, not renewed monthly and not usable without the legal/Android media capability. Real Play pricing and tax/fees pending. Google Play native rental periods do not offer 100 days; implement via repeatable one-time Buy product with verified server-side entitlement after sandbox approval. https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/CHILD_SPECIFIC_GOOGLE_PARENT_SHARING_AND_CONCURRENT_SCREEN_ADDONS_2026.md.

## 2026-11-01 — Mail notifications and immediate free fallback

The owner designated **noreply@berhampore.in** for one-way OTP and plan alerts, and **madalasa-alarka@berhampore.in** for two-way support, feedback and tickets. Prepaid, manual-renew plans now have a documented one-shot reminder schedule at verified expiry T−30d, T−7d, T−24h, T−9h, T, T+24h and T+7d. At T, server authorization **immediately** falls back to the free tier unless verified coverage has been extended, regardless of email delivery. No automatic charge; access to already-retained history follows the existing free/paid entitlement contract. Read [Email lifecycle and support templates](EMAIL_LIFECYCLE_AND_SUPPORT_TEMPLATES_2026-11-01.md). **Status: design and copy only, not coded or provider-tested.**
