# Madalasa–Alarka — Third-Party Services Cost Analysis (EXCLUDING Oracle Hosting)

> **Document control:** M7 / 01-commercial-plans-and-costing · Proposed owner: Product + finance (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

> **Current app names:** **Madalasa** (parent), **Alarka** (child); verified [Madalasa-Alarka GitHub repository](https://github.com/methakon/Madalasa-Alarka). [Brand contract](../../M0-foundation-and-approvals/02-market-and-feasibility/BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

**Document ID:** AP-COST-3P-001  
**Revision:** 1.0 · **Reviewed:** 2026-10-26 · **Status:** researched engineering/financial estimates; no external provider accounts, bills or quotas verified.  
**Scope:** All planned **non-Oracle** service dependencies of Madalasa–Alarka, including Google Maps/Places/Roads, Android/Google location APIs, Firebase Cloud Messaging, parent identity, Google Play Billing, optional Drive, and developer registration. **Oracle compute, Oracle block/object storage, Oracle DNS and Oracle monitoring are entirely excluded**; use the independent [OCI Hosting Financial Plan](../../M8-operational-readiness/01-cloud-infrastructure/OCI_CHICAGO_DEPLOYMENT_AND_FINANCIAL_PLAN.md) for those. Domain fees, already allowed for in that hosting plan, are also excluded to avoid double counting.

**PRICING PRECEDENCE (26 October 2026):** [Subscription Plans, Hidden Charges and Play Rules](SUBSCRIPTION_PLANS_PRICING_AND_RULES_2026.md) supersedes the ₹149-per-child/month selling-price assumption below. **₹149 is now a historical sensitivity example only**; the current proposed plans are **₹50/month or ₹500/year per paying child seat**, subject to tax/Play verification. This cost report remains useful for provider service pricing and request volumes, but its Play-fee and per-child-unit-economics totals must be recalculated from the final selected plan. Oracle hosting remains excluded throughout.

## 1. Executive financial answer

**Under a ₹149/child/month, India-only auto-renewing subscription example, 1,000 paying child subscriptions:**

| Third-party cost category | Monthly, 1,000 children | Annual, constant 1,000 children | Per child/month | Evidence |
|---|---:|---:|---:|---|
| Google Maps SDK native Android | ₹0 | ₹0 | ₹0 | Unlimited/no-cost native Maps SDK SKU, subject to eligibility/terms |
| Android location APIs / Google Play services | ₹0 separate location API fee | ₹0 | ₹0 | No billed per-fix API charge in design; device/network/battery costs not priced |
| FCM notification messaging | ₹0 | ₹0 | ₹0 | Official no-cost Firebase product |
| Google Places Autocomplete + Geocoding + Essentials Details | **₹0 in conservative model** | **₹0** | **₹0** | Each SKU below conditional 70,000/month India free event cap |
| Parent login with social/email auth | **₹0 assumed** | **₹0** | **₹0** | Assumes no-cost eligible auth configuration; actual provider remains undecided |
| Play Billing recurring subscription **service fee** | **₹22,350** | **₹2,68,200** | **₹22.35** | 15% illustrative India subscription fee × ₹149 × 1,000 paying children |
| Optional Roads, Drive API, SMS OTP | **₹0 because disabled/not used** | ₹0 | ₹0 | Do not treat as bundled unlimited entitlement |
| **Total modeled recurring non-Oracle external cost** | **₹22,350** | **₹2,68,200** | **₹22.35** | Excludes tax, refunds, provider changes and unpriced SMS/identity choices |

**Key conclusion:** In the 1,000-child conservative case, **the modeled external vendor expense is ₹22.35/child/month**, overwhelmingly Google Play's subscription fee, **not the Maps API**. This is **separate** from the OCI hosting model's approximately ₹0.20/child/month priced-line estimate or ₹3.24/child/month reserved budget at 1,000 children. Adding ₹22.35 to either hosting figure is illustrative only; a real bill may differ and should not include paid API requests twice.

**If ₹149 is a tax-inclusive selling price, or purchase fees depend on region/transaction/billing programme, the 15%-of-₹149 simplification must be replaced by real Play reports.**

### 1.1 Per-child *combined* expense at 1,000 active subscriptions (cross-document comparison only)

This subsection **cross-references**, but does not incorporate into this document's own third-party-service totals, the independent [Oracle hosting cost model, §14.10](../../M8-operational-readiness/01-cloud-infrastructure/OCI_CHICAGO_DEPLOYMENT_AND_FINANCIAL_PLAN.md#1410-per-child-hosting-cost-at-1000-subscribed-children). Its purpose is to answer: **what is the projected combined expense for one paying child when 1,000 child subscriptions are active?** Oracle charges **remain excluded** from the third-party-only tables in §§1, 6, 8 and 9; never add the combined figures below to those tables.

Assumptions: India launch, 1,000 **paying** children, ₹149 subscription per child per month (hypothetical, pre-tax), an illustrative 15% Google Play subscription fee, no billable India Maps/Places events under the lean case, eligible Oracle Chicago PAYG A1 allowances, and the hosting plan's 4 OCPU / 24 GB configuration with its documented block/backup/domain amounts. All costs are modelled, **not measured or invoiced**.

| Cost component | Project/month for 1,000 children | Project/year (12 months) | **Per child/month** | **Per child/year** |
|---|---:|---:|---:|---:|
| Third-party integrations and Google Play subscription fee (this document) | **₹22,350** | **₹2,68,200** | **₹22.35** | **₹268.20** |
| Oracle infrastructure and modelled domain/backup (**separate hosting plan**) | ~₹199 | ~₹2,385 | ~₹0.20 | ~₹2.39 |
| **Combined estimated direct running expense** | **~₹22,549** | **~₹2,70,585** | **~₹22.55** | **~₹270.59** |
| Hosting-budget contingency **instead of** direct Oracle line (₹3,238/month, includes hosting and its reserves) | ₹3,238 | ₹38,862 | ₹3.24 | ₹38.86 |
| **Combined budget allocation including hosting reserves** (third-party ₹22,350 + *entire* reserved hosting budget ₹3,238) | **~₹25,588** | **~₹3,07,062** | **~₹25.59** | **~₹307.06** |

**Do not double-count:** The last row *replaces* the direct Oracle hosting line with the full hosting budget; it is **not** ₹22,549 plus ₹3,238. The hosting contingency represents money reserved against uncertain charges, **not another invoice**. Annual amounts use the hosting document's displayed rounded annual values; a paise difference can arise from rounding the underlying monthly provider and hosting formulas.

### Revenue remaining per child at the illustrative ₹149 subscription

| Per-child monthly unit economics | Direct-cost view | Including budgeted hosting reserve |
|---|---:|---:|
| Subscription revenue collected (assumed pre-tax) | ₹149.00 | ₹149.00 |
| Third-party + hosting cost / allocation | ~₹22.55 | ~₹25.59 |
| **Amount remaining before unmodelled costs** | **~₹126.45** | **~₹123.41** |

**This remainder is not profit.** Excluded or unverified: sales/GST/VAT and Play fee actual settlement, refunds and payment failures, Google identity/SMS if selected, increased paid Maps/Places/Roads use, database HA/managed services, paid monitoring beyond quotas, operational support, development/staff salaries, incident response, child-data privacy/legal compliance and actual production capacity. In particular, no load test has proven that the planned OCI 4/24 server can serve 1,000 active children at the requested tracking frequency. If the PAYG free compute allowance is unavailable or already consumed, recalculate the hosting portion before fixing subscription prices.

**Financial control:** Use third-party-only §6 to budget providers, hosting §14.10 to budget Oracle, and this cross-check only to understand product unit economics at 1,000 subscriptions.

## 2. Included service inventory and alternatives

| Provider / service | Madalasa–Alarka purpose | Release state | Recurring pricing model | Billing owner |
|---|---|---|---|---|
| Google Maps SDK for Android | Parent-native map, marker, polyline, trip playback | Core P1 | **No Maps SDK event charge** under current pricing; API key/billing project and terms still required | Google Maps billing project |
| Android FusedLocationProvider, Activity Recognition, Geofencing APIs | Child's permitted location, motion and geofence evidence | Core, subject to Android grants | **No standalone provider per-observation charge**; device battery/network and Android limits apply | No external per-fix billing |
| Firebase Cloud Messaging (FCM) | Device status/alerts, best-effort notifications/wake hints | Core planned | **No-cost**; no delivery guarantee or emergency-SLA assumption | Firebase project |
| Google Places Autocomplete | Parent named-place search | Candidate P1 optional convenience | Billable by actual Places Autocomplete SKU/session event, conditional free tier | Maps billing project |
| Google Geocoding API | On-demand parent-selected address geocoding/reverse-geocoding | Optional and capped | Per billable geocode request, free cap | Maps billing project |
| Places Place Details Essentials | Address metadata for selected place | Optional, field-mask limited | Price per billable Place Details Essentials event | Maps billing project |
| Places Text Search Pro / nearby search | Broader address/business text queries | Default **off**; optional | More expensive Pro SKU, conditional cap | Maps billing project |
| Google Roads API | Opt-in vehicle path reconstruction where there are enough fixes | Deferred/research, default **off** | Per request + **possible asset-tracking licensing**, outside simple SKU price | Maps + legal |
| Google Play Billing | Subscription charge and renewal/hold/refund verification | Commercial core | **Percentage of qualifying payment revenue**, not a fee per API call | Google Play developer account |
| Parent authentication (Google sign-in or Firebase Auth/Identity Platform) | Authorized parent account login/session | Core requirement, **vendor not finalized** | Email/social may fall inside no-cost threshold; paid OIDC/SAML/MAU and SMS depend on implementation | Identity project |
| Google Drive API | Optional parent-owned Drive media copies | P2 conditional/deferred | Standard API historically no additional charge; late-2026 excess-quota charges planned, quotas/storage apply | Google Workspace/Cloud and parent account |
| Firebase Crashlytics/App Check (optional) | Crash diagnostics and basic abuse signals | Not yet selected | No-cost products with their own documented quotas/features | Firebase project |
| Other SMS, email, fraud-prevention, helpdesk, analytics vendors | OTP, support, payment/fraud notifications, tickets | **Not selected** | **UNPRICED** until vendor and traffic chosen | Provider-dependent |
| Google Play developer registration | Publisher registration | Required external onboarding | One-time account fee, **not a recurring per-child charge** | Developer account |

**Avoid extra paid components:** Self-hosted PostgreSQL/PostGIS, C++ Drogon and Android UsageStatsManager are not billable third-party hosted APIs. They are software/runtime parts of the **excluded OCI hosting budget**, not new license items here. OCI server-to-client networking is also excluded.

## 3. Baseline currency, sales and eligibility assumptions

- Model dated **2026-10-26**. India subscriber location and an Indian Google Maps billing entity; **India pricing is conditional** on an eligible billing account and a large majority of requested/returned locations in India. OCI Chicago backend hosting does **not** automatically establish India billing eligibility. Validate this with the Maps billing console.
- India Maps paid SKU prices are posted in **USD**, while eligible bills may be paid in INR at Google's conversion rate. For readable illustrations choose **₹95 per US$1** as an intentionally rounded, **nonbinding budget exchange rate**, near the publicly observed 2026-10-23 USD/INR (~₹94.94). It is **not** Google's invoice exchange rate, RBI official guaranteed rate, or a live conversion.
- One subscription per **paying child**. One family may have multiple children and guardians. Guardian logins influence MAU and API traffic; paying child count does not exactly equal total active users or installed devices.
- Example subscription face price **₹149/child/month**, still **not an approved SKU price**. For the India/general remaining-market 2026 Play recurring-subscription situation, use **15%** service fee. New fee structures are phased by region and may change; do not carry the 15% rate into future geographies/year without new review.
- Google Play Billing service fee modeled as **15% × collected pre-tax subscription sales** (assuming 100% paid successful recurring transactions, no discounts, tax, grace, failure, returns or refunds). Refunds, taxes/GST, withheld amounts, alternative billing, chargebacks, family discounts, currency conversion and billing-cycle proration are **not** included.
- Each SKU's monthly India free cap belongs to the **billing account's aggregated eligible usage**, not separately to each child. No free credits are invented beyond per-SKU allowances. Volume discounts beyond 5 million calls/month are excluded from the moderate ranges calculated here.
- Auth case: a no-cost eligible email/social option or Google Sign-In + backend verification; no phone verification/OTP, custom paid OIDC or enterprise identity provider in the numeric baseline. Parent account and device-credential infrastructure still requires engineering/OCI resources **excluded here**.
- Native Android Maps SDK is no-cost in the current published SKU list; **do not confuse it with billable Dynamic Maps web loads, static map requests, Places queries, navigation or road-matching.**
- Optional Drive, Roads, SMS and Pro Places calls are **zero** in the conservative baseline unless explicitly enabled in alternate scenarios. Their absence is a feature-scope decision, not an assumption of free unlimited service.
- All monthly models run for 12 identical months when calculating a constant-size annual expense. A staged growth example is separately calculated.

## 4. Google Maps India SKU cost inputs — verified public list

| Exact modeled Maps SKU / feature | Monthly free cap (billable events) | Paid marginal rate after cap, up to 5M monthly events | Approx INR per 1,000 beyond cap at ₹95/USD | Product choice |
|---|---:|---:|---:|---|
| Maps SDK (India) / native map | Unlimited/no-cost native SDK map events | **US$0** | ₹0 | Enabled |
| Places Autocomplete Requests (India) | 70,000 | **US$0.85/1,000** | ₹80.75 | Limited, debounced |
| Geocoding (India) | 70,000 | **US$1.50/1,000** | ₹142.50 | Parent action only, not every GPS update |
| Place Details Essentials (India) | 70,000 | **US$1.50/1,000** | ₹142.50 | Restrict field mask |
| Places Text Search Pro (India) | 35,000 | **US$9.60/1,000** | ₹912 | Disabled by default |
| Roads Route Traveled (India) | 35,000 | **US$3.00/1,000** | ₹285 | Default disabled; contract gate |
| Routes Compute Routes Essentials (India), not in base models | 70,000 | **US$1.50/1,000** | ₹142.50 | Off; a Google Directions route is not historic child track |
| Places UI Kit / session-mode autocomplete | Distinct SKUs and triggers | May **differ materially** from request-priced autocomplete | Must price after UI/SKU selection | Not silently included |

**Price formula for this model** (valid for calls that actually bill as listed SKUs; no more than 5M paid events per SKU/month):  
Monthly_USD(SKU) = max(0, billable_events_this_month − free_cap) ÷ 1,000 × stated_USD_rate.  
Maps_INR = sum(monthly_USD) × **95**.

### Cost and data-minimization guardrails

1. Show already saved parent labels from Madalasa–Alarka database. Do **not** geocode or call Places for every raw GPS point, map refresh, guardian or trip stop.
2. Cache only to the extent permitted by Google Maps Platform terms; app-owned user-entered place names are separate from storing licensed Maps content.
3. Autocomplete after a meaningful typing threshold with 300–500 ms debounce; select API correctly with session token/termination and **identify actual billed SKU** from Cloud Billing before trusting the request-level model.
4. Retrieve **Place IDs or permitted Essentials fields** where sufficient; extra fields can trigger Pro/Enterprise billing.
5. Use strict Maps project/API key restrictions (Android signing/package for app keys; server-side API key vault), per-API quotas, daily quota gates, anomaly alerts and billing budgets.
6. Turn off Roads if asset-tracking license, attribution, privacy or cache permission is unresolved. A Roads billable event is a **request**, with up to 100 GPS points/request, not 1 request per GPS fix; API bill and license are separate issues.
7. Provider data should be used under original service terms, not scraped to evade costs. Third-party failure returns route/label UNKNOWN or parent manual-entry fallback, **not** invented history.

**Provider evidence:** India Maps price table https://developers.google.com/maps/billing-and-pricing/pricing-india ; India account eligibility https://developers.google.com/maps/billing-and-pricing/india-overview ; new SKU billing overview https://developers.google.com/maps/billing-and-pricing/overview ; Roads licensing https://developers.google.com/maps/documentation/roads/policies .

## 5. Monthly usage per child: three realistic *illustrative* patterns

**Billable events are modeled per paying child, but real activity may follow guardians rather than child profiles.** This is a sizing hypothesis, not customer behavior data.

| Model | Places Autocomplete Requests / child / month | Geocoding / child / month | Essentials Details / child / month | Pro Text Search / child / month | Roads Route Traveled requests / child / month | Interpretation |
|---|---:|---:|---:|---:|---:|---|
| **A — Lean/default** | 8 | 2 | 1 | 0 | 0 | Named-place setup + occasional lookup; no paid tracking interpolation |
| **B — Higher engagement** | 20 | 8 | 4 | 3 | 0 | More active family lookups and paid Pro text searches |
| **C — Optional Roads sensitivity** | 8 | 2 | 1 | 0 | 12 | Lean plus 12 Roads *requests* per child/month, **not enabled or legally cleared** |

Example at **1,000 children**, model A yields **8,000 Autocomplete**, **2,000 Geocoding**, **1,000 Essentials Details** requests per month. All are below their respective 70,000 free caps => **₹0 Maps API fees**. At **10,000 children**, 80,000 Autocomplete billable requests means 10,000 above cap × US$0.85/1,000 = **US$8.50**, modeled **₹807.50/month**. Other Model A calls still fit inside their caps.

**Caution:** A Places autocomplete *session* can trigger different SKUs and payment behavior. These estimates specifically price the **Autocomplete Requests (India)** SKU, not every possible session/field-mask combination.

## 6. Cumulative service costs by subscriber volume — excluding Oracle hosting

The following table combines **external API spend** (Models A/B/C separately) with **Google Play subscription commission**. Never add Model A + Model B + Model C; they are **alternatives**, not three simultaneous products. Models B/C only add paid calls above the relevant SKU free cap.

| Active paying children | Model A external Maps APIs/month | Model B APIs/month | Model C APIs/month | Play 15% fee/month @₹149 | **Model A all third parties/month** | **Model A/year (12×)** | **Model A /child/month** |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 100 | ₹0 | ₹0 | ₹0 | ₹2,235 | **₹2,235** | **₹26,820** | **₹22.35** |
| 500 | ₹0 | ₹0 | ₹0 | ₹11,175 | **₹11,175** | **₹1,34,100** | **₹22.35** |
| 1,000 | ₹0 | ₹0 | ₹0 | ₹22,350 | **₹22,350** | **₹2,68,200** | **₹22.35** |
| 2,500 | ₹0 | ₹0 | ₹0 | ₹55,875 | **₹55,875** | **₹6,70,500** | **₹22.35** |
| 5,000 | ₹0 | ₹2,423 | ₹7,125 | ₹1,11,750 | **₹1,11,750** | **₹13,41,000** | **₹22.35** |
| 10,000 | ₹808 | ₹11,923 | ₹25,033 | ₹2,23,500 | **₹2,24,308** | **₹26,91,690** | **₹22.43** |
| 20,000 | ₹7,268 | ₹63,698 | ₹65,693 | ₹4,47,000 | **₹4,54,268** | **₹54,51,210** | **₹22.71** |
| 50,000 | ₹30,923 | ₹2,45,528 | ₹1,91,948 | ₹11,17,500 | **₹11,48,423** | **₹1,37,81,070** | **₹22.97** |
| 1,00,000 | ₹81,748 | ₹5,48,578 | ₹4,13,773 | ₹22,35,000 | **₹23,16,748** | **₹2,78,00,970** | **₹23.17** |

**All-third-party Model A total includes** Maps/Places/Geocoding charges, modeled Play commission, and ₹0 for FCM, eligible parent login and native Android Maps. It **does not include** SMS OTP/paid email, paid external identity provider, licensed Roads agreement, Google Drive storage plan, developer salaries, OCI/hosting, tax, refunds or enterprise support.

For higher product engagement, the full combined third-party cost (not just Maps) is:

| Paying children | Play commission/month | Model A API/month | Model B API/month | **Model B combined/month** | **Model B combined/year** | **Model B per child/month** |
|---:|---:|---:|---:|---:|---:|---:|
| 1,000 | ₹22,350 | ₹0 | ₹0 | **₹22,350** | **₹2,68,200** | **₹22.35** |
| 5,000 | ₹1,11,750 | ₹0 | ₹2,423 | **₹1,14,173** | **₹13,70,070** | **₹22.83** |
| 10,000 | ₹2,23,500 | ₹808 | ₹11,923 | **₹2,35,423** | **₹28,25,070** | **₹23.54** |
| 20,000 | ₹4,47,000 | ₹7,268 | ₹63,698 | **₹5,10,698** | **₹61,28,370** | **₹25.53** |
| 50,000 | ₹11,17,500 | ₹30,923 | ₹2,45,528 | **₹13,63,028** | **₹1,63,56,330** | **₹27.26** |

**At 1,000 children:** both Model A and Model B are still below the India-priced free caps, so modeled third-party cost is **₹22,350/month**, **₹2,68,200/year** and **₹22.35/child/month** at a ₹149 plan and 15% Play fee. This is a **commercial transaction expense**, not a per-child server charge.

## 7. How paid APIs can materially increase the bill

### A. Without India pricing eligibility

If Google classifies the Maps project under global pricing, SKU caps are commonly **10,000 Essentials** and **5,000 Pro** per month (rather than 70k/35k for eligible India accounts); initial global rates also differ. Example: **1,000 children × 20 Autocomplete Requests = 20,000 events**, giving **10,000 beyond the global Essentials free cap × US$2.83/1,000 ≈ US$28.30 ≈ ₹2,689/month** for **Autocomplete alone**, whereas the same request count would be ₹0 under eligible India pricing. Other services and different price tiers can increase the total further. Eligibility depends on the account's billing location and **where the requested/returned locations are**, not just developer residence or server city.  
Global reference: https://developers.google.com/maps/billing-and-pricing/pricing

### B. Enabling Roads for all children

Model C intentionally considers **12 Roads requests/child/month**. At 5,000 children, that's 60,000 Roads requests, of which 25,000 exceed India's 35,000 free cap: **25 × US$3 × ₹95 = ₹7,125/month**, in addition to baseline. At 10,000 children, Roads calls alone add **₹24,225/month**; at 20,000, **₹58,425/month** (first rate band). These are *API-only* amounts; the specialized asset-tracking licence, permissions and tracking compatibility are not priced. **Roads remains OFF.**

### C. SMS login, verification, phone calls and outbound support messages

No SMS/OTP provider is selected. **Do not assume SMS is free** merely because Firebase social/email login and FCM push are no-cost. Example for **budget sensitivity only, NOT a provider quotation**: if one billable verification for every paying child costs a hypothetical **₹5 each**, monthly expense would be **₹5,000 at 1,000 children** or **₹50,000 at 10,000 children**. If two SMS are sent, multiply by two. The actual number depends on guardians per child, retries, country, risk checks and carrier pricing. Formula: billable_verifications × effective_provider_price_per_verification.

### D. Paid auth / enterprise identities

Firebase Authentication with Identity Platform publishes an eligible no-cost allowance up to **50,000 monthly active users (MAU)** for common email/social methods on Blaze, with tiered costs beyond; SAML/OIDC and SMS can have different limits/costs. It is **parents/guardians signing in, not subscribed children**, who consume parent-login MAUs. The product has not chosen Firebase Auth vs direct Google identity/token verification or another hosted identity service. No vendor invoice is assumed. Do not interpret social login or custom OIDC as universally free.

### E. Drive media upload and Google API requests

Google Drive API standard use is currently documented without extra cost, but **Google's documentation updated in May 2026 says exceeding quota limits is planned to incur Google Cloud charges later in 2026**. A new project and historical project can have different quota treatment. Parent Drive storage plans (Google One/Workspace, if any) are usually their separate expense. OAuth scope verification, media storage, transfer, access revocation and legal review have nonzero engineering/compliance costs and may affect user willingness to pay. **No unpriced Drive upload or quota breach is included in a zero-cost estimate.**

### F. Play subscription price and fee sensitivity

The **fee is proportional to payment revenue**, not location events. Google Play's currently documented India/rest-of-world recurring subscription 15% case is used here; its March 2026 fee reform rolls region by region and must be rechecked before launch/expansion.

| Example per-child gross monthly plan | Modeled 15% Play fee/child/month | Play fee at 1,000 paying children/month | Play fee at 1,000 paying children/year |
|---:|---:|---:|---:|
| ₹99 | ₹14.85 | ₹14,850 | ₹1,78,200 |
| **₹149** | **₹22.35** | **₹22,350** | **₹2,68,200** |
| ₹199 | ₹29.85 | ₹29,850 | ₹3,58,200 |

Actual net receipts depend on taxes, discounts, Play's actual settlement calculation, country, refunds, subscription lifecycle and applicable legal payment programmes. A developer account registration fee (published US$25 one-time in standard conditions) is an **onboarding expense**, not a recurring subscription commission. At ₹95/US$ it would be ~₹2,375 one-time **if actually charged USD25**, ignoring conversion taxes/fees.

## 8. Budget with contingency — without confusing margin and invoice

The following **separate monthly budget concepts** prevent double counting:
- **Service-price estimate** = modelled Maps/Places + modelled Play commission + zero-priced eligible FCM/social login.
- **API risk buffer** = 25% of modeled *paid Maps API expense only*. At 1,000 children, 25% × ₹0 = ₹0; **this does not fund SMS, law firms, account support or catastrophic API misuse**.
- **Unknown-service reserve** = owner-set cash reserve, **not an invoice line**, for optional login verification, additional SDKs, future Drive quota charges, support messaging or changed SKU mix. **Do not assume zero financial risk merely because calculated APIs are zero.**

| Subscribers | Modeled Model A monthly vendor spend | 25% modeled paid-API buffer | Example extra external-service reserve (NOT quoted) | **Monthly external-service budget allocation** |
|---:|---:|---:|---:|---:|
| 1,000 | ₹22,350 | ₹0 | ₹1,000 | **₹23,350** |
| 2,500 | ₹55,875 | ₹0 | ₹2,500 | **₹58,375** |
| 5,000 | ₹1,11,750 | ₹0 | ₹5,000 | **₹1,16,750** |
| 10,000 | ₹2,24,308 | ₹202 | ₹10,000 | **₹2,34,509** |
| 20,000 | ₹4,54,268 | ₹1,817 | ₹20,000 | **₹4,76,084** |

The extra reserve here is merely **₹1/child/month** as an illustration: not measured provider expense, not a telecom-service quote and not comprehensive customer-support coverage. If the selected parent authentication relies on paid SMS/OTP, replace the reserve with the **actual billable SMS cost**.

## 9. First-year cumulative external costs under phased growth

The same hypothetical three-month step pattern used in [OCI Hosting Financial Plan §14.9](../../M8-operational-readiness/01-cloud-infrastructure/OCI_CHICAGO_DEPLOYMENT_AND_FINANCIAL_PLAN.md) is used here, but **none of OCI hosting is included**. Assumes child base and subscription price stay constant *within each quarter*, 100% paying, and 12 recurring cycles.

| Quarter | Paying children | Model A third parties per month | Model A total for 3 months | Model B total for 3 months |
|---|---:|---:|---:|---:|
| Q1 (3 months) | 1,000 | ₹22,350 | ₹67,050 | ₹67,050 |
| Q2 (3 months) | 2,500 | ₹55,875 | ₹1,67,625 | ₹1,67,625 |
| Q3 (3 months) | 5,000 | ₹1,11,750 | ₹3,35,250 | ₹3,42,518 |
| Q4 (3 months) | 10,000 | ₹2,24,308 | ₹6,72,923 | ₹7,06,268 |
| **12-month cumulative** | *1k → 2.5k → 5k → 10k* | — | **₹12,42,848** | **₹12,83,460** |

Cumulative spend is dominated by **Play commission**. This example is **not** cumulative revenue, nor profit, nor a combined Oracle + provider budget.

## 10. Cost-control implementation checklist by provider

| Control | Implementation task | Acceptance check |
|---|---|---|
| Separate Google Cloud projects | Maps, Firebase, Play service identities isolated by approved access roles and environments | API keys and billing accounts documented, no production key in repository |
| Only necessary APIs enabled | Enable Maps SDK/approved Places SKUs, disable Roads, Text Search Pro and high-risk defaults | Unexpected APIs fail in staging; activity alarms configured |
| Place UX and quota | Debounce autocomplete, low-frequency manual address lookup, no geocode-per-GPS-point, quota caps | Synthetic UI test verifies bounded queries/child/month |
| Google Cloud budgets | Threshold alerts for Maps and Firebase; remember Cloud Billing budgets are usually **not hard spending caps** | Test alert; actual per-API quota limit and fallback configured |
| Billing service fee | Server-side Play purchase/renewal/refund reconciliation and gross/net reporting by country | Synthetic and real sandbox subscription reports match accounting |
| Firebase FCM | Rate-limit notifications, deduplicate SOS/commute alerts, don't assume delivery | Offline/pending/replay test and no push-burst loop |
| Parent login | Pick vendor/method; explicitly cost OTP, active guardian MAU, MFA and lost-device recovery | Separate login price worksheet and quota/account review |
| Drive | Disable in core MVP; OAuth only when authorized; quota request audit, storage payer declared | Clear consent, revoke/deletion and cost test |
| Roads/license | OFF until Google Maps terms/legal licensing and real GPS resolution tested | Contract approval and bounded quota + display attribution |
| Scale review | Review per SKU once 50% free cap reached; bill per SKU at 80% cap and above | Automated account-wide monthly SKU dashboard and release gating |

## 11. Outstanding blockers you can resolve

| ID | Decision / proof required | Suggested owner | Current status |
|---|---|---|---|
| 3P-01 | Actual Google Play **India** selling price and whether price is tax-inclusive; free/trial/discount mix | Project owner | **OPEN** |
| 3P-02 | Choose parent authentication: Google sign-in/email or paid OTP; parent/guardian MAU assumptions | Product/security | **OPEN** |
| 3P-03 | Create/verify Google Cloud Maps account billing in India, majority-of-usage eligibility and chosen chargeable SKU | Project owner + engineering | **UNVERIFIED** |
| 3P-04 | Confirm actual per-child monthly Autocomplete/Geocoding/Place Details events during pilot | Parent app QA | **NOT MEASURED** |
| 3P-05 | Confirm Maps Place field masks and session tokens; estimate actual billed SKU rather than name-only assumption | Android engineering | **NOT IMPLEMENTED** |
| 3P-06 | Decide whether Text Search Pro, nearby search, Road matching or Google Routes can launch | Product + legal | **DEFERRED/OFF** |
| 3P-07 | For Roads, secure asset-tracking licence/terms review, privacy policy and retention compliance | Legal/provider | **OPEN; BLOCKS ROADS** |
| 3P-08 | Verify 2026 Drive project quota and any excess-charge launch date, and parent storage ownership | Google Cloud/account owner | **OPEN; OPTIONAL** |
| 3P-09 | Obtain real OTP/SMS/transactional email quote if selected; number of guardians and send/retry rates | Product/security/finance | **UNPRICED** |
| 3P-10 | Verify Play billing service fee for actual target countries and provider settlement/taxes, 2026/2027 phased changes | Finance/Play | **OPEN** |
| 3P-11 | Set **per-SKU** Google Cloud quota, alert thresholds, IAM/API restrictions, abuse detection and cost ownership | Backend/operations | **NOT CONFIGURED** |
| 3P-12 | Confirm FX conversion/tax on actual Google Maps India invoice, not the model's ₹95/USD | Finance | **NOT VERIFIED** |
| 3P-13 | Select domain/mail/support vendor only if *not already counted in OCI plan*; avoid duplicate budgeting | Product/finance | **COST ALLOCATION OPEN** |
| 3P-14 | Decide monthly provider-cost ceiling and optional-feature kill switches for each subscribed-child tier | Project owner | **OPEN** |

**Decision ask:** approve the baseline **Google Maps SDK + minimal Places, FCM, social/email parent login and Play Billing; keep Roads, Drive, SMS and Pro text search disabled** unless separately approved. This minimizes unpredictable per-location charges without losing parent-owned place labels or observed route/history features.

## 12. Official provider references and accounting cautions

1. Google Maps India SKU prices and free event thresholds: https://developers.google.com/maps/billing-and-pricing/pricing-india
2. Maps India eligibility and INR conversion: https://developers.google.com/maps/billing-and-pricing/india-overview
3. Maps pricing changes and free monthly caps: https://developers.google.com/maps/billing-and-pricing/overview
4. Global Maps non-India price list (sensitivity): https://developers.google.com/maps/billing-and-pricing/pricing
5. Roads API permitted usage/licensing/caching: https://developers.google.com/maps/documentation/roads/policies
6. Firebase no-cost FCM, Auth choices and pricing: https://firebase.google.com/docs/projects/billing/firebase-pricing-plans
7. Firebase Auth MAU/Identity Platform: https://firebase.google.com/docs/auth/
8. Firebase SMS and phone verification price calculator: https://firebase.google.com/pricing
9. Drive API 2026 pricing/quota notice: https://developers.google.com/workspace/drive/api/guides/limits
10. Play subscription service fee (India and rollout): https://support.google.com/googleplay/android-developer/answer/112622
11. Google Play global phased fee changes: https://support.google.com/googleplay/android-developer/answer/16954621
12. Google Play developer fee/account: https://support.google.com/googleplay/android-developer/answer/6112435
13. USD/INR 2026-10-23 reference price (~₹94.94): https://indiagraphs.com/data/usd-inr-exchange-rate/usd-to-inr-daily

**Model refresh policy:** Recompute immediately after selecting the actual login method, subscription SKU and location billing country; upon any signed Maps/Roads API contract; upon new Drive/API fee; and monthly after actual provider usage appears. Before publishing prices or claiming profit, reconcile payment taxes/refunds and optionally combine this separate analysis with the OCI hosting report **in a third, unified financial forecast**. **This file deliberately does NOT count any Oracle hosting expense.**

## 13. Current ₹50 / ₹500 pricing, SOS fallback and service-cost correction (2026-10-26)

**Authoritative price proposal:** [Subscription Plans](SUBSCRIPTION_PLANS_PRICING_AND_RULES_2026.md) now specifies **₹50/month or ₹500/year per paying child**; the ₹149/month revenue, 15% Play fee per-child totals and combined revenue rows in §§1, 6–9 are **historical scenarios ONLY**. Maps/API per-SKU pricing and zero-usage examples still apply, but must be recalculated for actual India billing eligibility/guardian traffic.

| 1,000 child-seat current-price example | All monthly recurring | All annual recurring (12-month term) |
|---|---:|---:|
| Child price charged over 12 months | ₹600 | ₹500 |
| Google Play 15% fee, assuming pre-tax fee base | ₹90/year/child | ₹75/year/child |
| Existing OCI reserved hosting **external to this document**, for economic cross-check only | ~₹38.86/year/child | ~₹38.86/year/child |
| Cash available **before GST, staff, paid services, refunds and operations** | ~₹471.14/year/child | ~₹386.14/year/child |
| Illustrative **18%-tax-inclusive** price, Play 15% of net-of-GST, OCI budget deducted | ~₹32.78/month/child | ~₹321.31/year/child |

**Important:** OCI values in this table are **contextual cross-check references, not additional third-party vendor line items**. This file's per-SKU third-party price model still entirely **EXCLUDES ORACLE HOSTING**.

Additional non-Oracle cost gaps: high-priority SOS with SMS escalation requires chosen telecom vendor, guardian opt-in, India DLT registration/templates, a verified sending cost and independent fault path; FCM alone is no-cost but not guaranteed delivery. [SOS provider cost/failure model](../../M4-usage-health-sos/01-usage-health-and-sos/SOS_ESCALATION_AND_INDEPENDENT_DELIVERY_DESIGN.md). Auth via Google Sign-In is only a candidate; adult legal verification may incur external provider cost. [Full viability and staffing model](PRICE_BREAK_EVEN_STAFFING_AND_DELIVERY_CAPACITY.md). Do not infer ₹50/₹500 is profitable at 1,000 subscribers.

## 14. Conditional media R&D service-cost boundary (2026-10-26)

Per [MA-MEDIA-ADR-001](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md), owner accepted conditional media research and truthful parent unavailability reasons, **not an approved launch service**. Proposed P2P-first WebRTC and optional self-hosted coturn/TURN with no VPS media archive are **not covered by the existing Maps/FCM/Play/SMS/Drive vendor rows**. A self-hosted TURN implementation may avoid per-seat vendor licensing but adds OCI relay compute, bandwidth/egress, backups/configuration, observability, security and on-call burden; managed TURN/identity services can add new third-party charges. Model the affected shared OCI transfer allowance and Mumbai tenancy carefully; never assume 500 or 1,000 children can simultaneously stream within a minimal VPS budget. The old ₹149/month subscription scenario is historical; proposed pricing is ₹50/month or ₹500/year per paid child seat. Media costs must be assessed separately from these existing service models before promotion from research.

## 2026-10-27 admin audit / media-activity reporting service dependencies

The metadata-only media log can use **existing Drogon/Postgres infrastructure** as a design candidate, not a new media-storage vendor. Admin browser may require managed workforce identity/SSO/MFA, support-case approval workflow, tamper-evident independent audit storage or monitoring, DLP/export controls and optional security analytics; these are vendor/operational dependencies NOT currently quoted. Log rows, indexes, backups/retention, admin search and 500/1,000-child traffic create infrastructure cost even with zero VPS media-file storage. Require pricing/fit assessment before enabling FR-050/051, without conflating TURN relay egress. [Media Activity Audit ADR](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_ACTIVITY_AUDIT_LOGGING_AND_REPORTING_2026.md), [Administrator Console Specification](../../P3-deferred-research/01-media-and-administrator-research/ADMIN_PANEL_SPECIFICATION_2026.md).

## 2026-10-27 no Redis MVP requirement for child GPS ingestion

Accepted [MA-INGEST-ADR-004](../../M2-location-collection/01-location-collection-and-ingestion/POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md) uses **existing PostgreSQL durable inbox with C++ bulk workers** for 48h offline-device catch-up; Redis (and separate broker) not required in phase one. This **avoids a separate Redis managed-service bill/process**, but **does not eliminate** duplicated raw GPS writes to temporary inbox, WAL, index, backup, worker CPU and extra Postgres disk/IOPS; direct raw bulk/commit may in fact be cheaper until bursts require isolation. Add OCI A1 storage/backup and throughput test against observed vehicle+watch location points, 1–2min eligible upload and full 48h reconnect storm before quoting per-child hosting cost. Location acquisition and API data transfer cost/battery remain conditional on OS and provider support. This is design, not current vendor price assurance.
