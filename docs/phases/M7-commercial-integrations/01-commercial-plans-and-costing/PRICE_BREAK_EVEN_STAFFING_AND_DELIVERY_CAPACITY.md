# Madalasa–Alarka — Prepaid Pricing, Break-Even, Staffing and Capacity Gate

> **Document control:** M7 / 01-commercial-plans-and-costing · Proposed owner: Product + finance (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

> **Current app names:** **Madalasa** (guardian/parent), **Alarka** (child companion). GitHub repository [Madalasa-Alarka](https://github.com/methakon/Madalasa-Alarka), renamed 2026-10-26. [Source story and naming contract](../../M0-foundation-and-approvals/02-market-and-feasibility/BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

**Status:** decision model; not validated profit forecast, not a hiring plan.  
**Date:** 2026-10-26; canonical reconciliation 2026-10-30 | **Authoritative owner price policy:** [Subscription Plans — current reconciliation](SUBSCRIPTION_PLANS_PRICING_AND_RULES_2026.md#current-canonical-reconciliation--2026-10-30).
**Cost sources:** [OCI hosting](../../M8-operational-readiness/01-cloud-infrastructure/OCI_CHICAGO_DEPLOYMENT_AND_FINANCIAL_PLAN.md) and [Third-party provider SKU model](THIRD_PARTY_SERVICES_COST_ANALYSIS_2026.md). Old **₹149/month** in those reports is **historical sensitivity only**.

## Current commercial and costing boundary — 2026-10-30

**Owner policy, unchanged:** prepaid manual purchase/top-up, **no auto-renew**; regular **₹99/month or ₹999/year per paid child**; founding **₹50/month or ₹500/year** for the first **1,008 DISTINCT successfully paying families**, counting a family **once**, including eligible children added later. Existing customers retain their applicable pricing; no repricing is approved here. A family can pay for multiple selected children, so **family count, paid child-seat count, purchase count and simultaneous viewer count are different denominators**. Adding a child, guardian, top-up or device must not consume a second founding-family rank. Trial does not qualify as paid.

**Publisher/setup:** individual **SWARNA SEKHAR DHAR, India**, same legal entity as Play publisher (owner-reported). **Payments identity pending; merchant pending; tax/accountant not approved.** These are release/commercial gates, not evidence of a functioning merchant or tax position.

**Provider verification dated 2026-10-30:** Play documents prepaid monthly/yearly base plans and manual time-extension top-ups; top-up extends the same subscription rather than establishing additional concurrent child capacity.[3] General Help copy mentions offers broadly, but its specific Offer note restricts offers to auto-renewing base plans and applies new prices to prepaid top-ups.[4] Thus neither founding prepaid price preservation nor repeatable child seats is a proven provider feature. Actual capacity catalog, founding access for later children and unchanged existing prices must be sandbox-proven; recommend a separately reviewed prepaid catalog/eligibility mapping, **not switching owner policy to auto-renew**.

**Historical model quarantine:** sections 1–6 below are the **2026-10-26 auto-renew/universal ₹50/₹500 sensitivity**, not current public pricing, prepaid fee evidence, an approved staffing budget or a demonstrated break-even. Current remaining-market fee guidance explicitly states 15% for automatically renewing subscriptions; do not inherit that as the prepaid/one-time rate without publisher-specific verification.[12] Sandbox test purchases do not compute taxes, so test checkout cannot establish final GST-inclusive proceeds or settlements.[8] No new numerical forecast is certified by this review.

### Required recalculation and evidence (recommendation; NOT executed)

| Input/control | Required evidence before financial acceptance |
|---|---|
| Cohort and term mix | Separate founding/regular paid child-months and child-years; deduplicate founding family qualification, not revenue seats. Include later-added eligible children, lapse/rejoin, churn and manual top-up success. Resolve refund/fraud disqualification and slot-recycling policy with owner/finance. |
| Customer charge vs earned revenue vs cash | Use actual Play total/currency and verified covered dates. Annual upfront receipts and manual top-ups are not monthly recurring cash or immediate profit. Allocate revenue/support obligations over coverage, with settlement delay and refunds separately reconciled. |
| Fees/tax/merchant | Actual applicable prepaid and consumable fee tier/base, consumer GST treatment, service-fee tax, credits/withholding, refunds/chargebacks and settlement currency; accountant approval and merchant identity completion. Do not apply a blanket 15% or add tax twice. |
| Capacity and lineage | Sandbox same-account multi-child purchase/repetition/replacement; reviewed product→capacity mapping and child allocation ledger. New top-up token means more time, not automatically more seats; duplicate RTDN/restore never increases revenue or capacity twice. |
| Extra viewer | **₹100 once / 100 consecutive calendar days / +1 child-scoped premium viewer / +30 combined pooled A/V minutes TOTAL**; repeatable one-time consumable is candidate only. Base lapse is dormant while clock continues. Do not book ₹100 each month or refill minutes per renewal. No production media revenue while legal/Android/Play gates keep media **OFF**. |
| True incremental cost | Measured base and extra-viewer fan-out, relay ratio, bitrate/minutes, compute, storage/retention/deletion, backup/recovery, fraud/support/refunds and independent security/legal/Android QA. Historical media reserve or shared egress allowance is not proof of profitable capacity. |
| Deployment separation | Hosting jurisdiction/provider, bandwidth economics and tenancy headroom remain owner deployment decisions. They do not block portable synthetic billing tests and are not fixed to historical Chicago estimates. |

**Recalculation model (not a result):** sum verified net proceeds over each founding/regular term and product, subtract observed variable costs, hosting/HA, support/staffing, legal/security, acquisition, refund liabilities and reserves without double-counting credits or allocations. Retain cost provenance and reconciliation date. Do not divide one family's revenue by its guardian count or model all founding families as one paid child each.

**Acceptance:** use the [sandbox lifecycle/negative checklist](../../../roadmap/PLAY_BILLING_SANDBOX_ACCESS_CHECKLIST_NO_SECRETS_2026-10-29.md#phase-c-traceable-sandbox-lifecycle-and-negative-acceptance--not-run) and canonical subscription reconciliation. All provider/runtime cases are **NOT RUN** in this review; no products, purchases, credentials, Console changes, staffing commitments or deployments were made.

## Sources

Official sources retrieved **2026-10-30**; numbering follows the canonical subscription reconciliation. Historical sensitivities below are not freshly certified.

[3] https://support.google.com/googleplay/android-developer/answer/140504
[4] https://support.google.com/googleplay/android-developer/answer/12154973
[8] https://developer.android.com/google/play/billing/test
[12] https://support.google.com/googleplay/android-developer/answer/112622

## 1. Historical sensitivity: at 1,000 paying child seats the cash arithmetic

Assume 1,000 enrolled **paid** child seats (not necessarily 1,000 families), Google Play **15%** auto-renewing subscription service fee (subject to country/contract), modelled existing OCI hosting cash **reserve** ₹3,238.47 per month, and no paid Maps-overage/SMS/identity/HA/support/engineering. We do **not** know actual support costs or commercial production reliability costs.

| Twelve paid months normalized / per child | ₹50 monthly plan (12 successful cycles) | ₹500 annual plan |
|---|---:|---:|
| Customer face price for 12 months | **₹600.00** | **₹500.00** |
| Play 15% (simple before-tax example) | ₹90.00 | ₹75.00 |
| Budgeted OCI hosting/year (with reserves) | ~₹38.86 | ~₹38.86 |
| **Contribution before all other costs, pre-tax assumption** | **~₹471.14/year** | **~₹386.14/year** |
| Monthly contribution equivalent | **~₹39.26** | **~₹32.18** |

**Warning:** If selling prices are final consumer payments that *include* illustrative 18% GST, under the explicitly hypothetical Play-fee-on-net-of-GST arithmetic, the funds remaining after Play fee and **budgeted** OCI cost fall to about **₹32.78/child/month** on the monthly plan and **₹321.31/child/year**, or **₹26.78/month equivalent**, on annual. Actual India GST liability, collection, input credit and service-fee base require independent accountant/Play settlement verification.

### All-monthly and all-annual company picture (at 1,000 fully paid seats)

| View | All ₹50/month | All ₹500/year |
|---|---:|---:|
| Annual customer gross | ₹6,00,000 | ₹5,00,000 |
| Example Play 15% of gross | ₹90,000 | ₹75,000 |
| Model hosting *reserved budget* | ~₹38,862 | ~₹38,862 |
| **Unallocated balance before tax, staff, support, API, refunds and incidents** | **~₹4,71,138/year** | **~₹3,86,138/year** |
| Monthly-equivalent available **pre-tax case** | **~₹39,262** | **~₹32,178** |
| Monthly-equivalent available **illustrative tax-inclusive case** | **~₹32,778** | **~₹26,776** |

These balances are **not profit**. Income-tax or company expenses are additional; reserves are cash allocation, not already-paid invoices. If there are paying guardians beyond the child seats, count them as account-access usage but **not another subscription**.

## 2. Fixed operating expenses immediately challenge break-even

The following assumes 1,000 child seats stay paid for all 12 months; expense K is **additional fixed monthly operations and staffing** beyond the existing small OCI budget, Maps and modeled Play fees (and no other variable expenses). Illustrative tax-inclusive cash-available ceilings are about ₹32,778/month on all-monthly or ₹26,776/month on all-annual.

| Additional fixed monthly expense | Monthly-plan remainder, tax-inclusive illustration | Annual-plan monthly-equivalent remainder, tax-inclusive illustration | Viability before refunds/CAC/APIs |
|---:|---:|---:|---|
| ₹0 | +₹32,778 | +₹26,776 | Unpriced obligations still exist |
| ₹10,000 | +₹22,778 | +₹16,776 | Very little staffed coverage |
| ₹30,000 | +₹2,778 | **−₹3,224** | Annual plan already short |
| ₹50,000 | **−₹17,222** | **−₹23,224** | Not viable at 1,000 on assumptions |
| ₹1,00,000 | **−₹67,222** | **−₹73,224** | Major deficit |

For context, paying one engineer/operator **₹50,000/month** alone would exceed the modeled tax-inclusive contribution of **1,000** yearly-paying children. Multiple paid engineers plus security, customer support and independent audit would require more subscribers, a higher price, lower costs, founder financing or different scope. This is not advice about actual salary levels.

### Break-even formula, not invented profit

Let P = customer payment per child per month equivalent, t = included customer tax rate, f = actual Play fee applied to the validated fee base, V = other variable paid vendor cost per child, H(N) = cloud hosting allocation at N children, F = monthly fixed salaries + support + legal/security + incident/other overhead, C = monthly acquisition/churn/refunds cost.

**Illustrative tax-inclusive model only:**  
contribution per child = P/(1+t) × (1−f) − V − H(N)/N;  
monthly net operating remainder = N × [P/(1+t) × (1−f) − V] − H(N) − F − C.

Find **N** from real observed costs; H(N) is **not constant** as capacity, replication, retentions and API traffic scale. A closed-form “N=1,527” based on the 1,000-seat model is not reliable across server upgrades or legal support workload. Do not market “₹500/year profitable at 1,000 users” without the missing terms.

## 3. Explicit engineering staffing and accountability

A realistic team needs multiple skill domains even if one person fills several roles. **One person owning everything creates review/security and operational continuity risk**, especially for child location and 24-hour incident response. The following are **allocation proposals**, not project owner staffing commitments or actual employment contracts.

| Workstream | Accountable owner / scope | Candidate effort | Can one person hold multiple roles? |
|---|---|---|---|
| Product/commercial/privacy decisions | Founder/product owner, legal publisher and budget approvals | 0.5–1.0 person equivalent initially | Yes, but needs legal/finance reviewers |
| Kotlin child Android/permission + DPC test | Android engineer, real OEM lifecycle, Keystore, battery/perms | 1.0 engineer equivalent | May share Android parent work but slows timeline |
| Kotlin parent app/Maps/Billing | Android engineer, UX, guardian grants, child status, revenue | 1.0 engineer equivalent | Yes only with rescope |
| C++ Drogon API/PostGIS/worker/geospatial | C++ backend and data/geo engineer, auth and event-time worker | 1.0–1.5 engineer equivalents | Strong test discipline required |
| Independent QA/test automation | QA/integration engineer, real phone/managed hardware and API contract tests | 0.5–1.0 equivalent | Cannot self-approve security release alone |
| Security/privacy architecture review | Qualified security reviewer | 0.2–0.5 external/fractional equivalent + independent signoff | Separate reviewer for BOLA/secret handling |
| OCI SRE/backup/on-call | Cloud engineer/operator, recoveries, alerts, incidents, budgets | 0.2–0.5 before launch; staffed rota for production | Founder can administer dev but not guarantee 24/7 |
| India legal/DPDP counsel and tax accountant | Licensed external professionals | Project-based; ongoing updates and audits | **Not replaceable by code or documents** |
| Customer support/escalation | Named support person/team, custody disputes, deletion and SOS contact questions | Depends on customers and service promises | Requires published hours and escalation rules |

**Initial staffed MVP reference:** approximately **3–5 engineering person equivalents plus fractional QA/SRE/security**, with separate Indian legal/tax review; actual schedule depends on reuse, team seniority, managed-DPC scope, compliance and outsourcing. **Not financed by the current 1k-seat cash-flow assumptions.** A founder-led one-person build may have lower *cash* burn but does not eliminate opportunity cost, peer review or operational duty.

## 4. Financial staffing scenarios (not quotes)

| Candidate direct monthly people/operations cash budget | Annual cash budget | Extra cost per paying child/month at 1,000 seats |
|---:|---:|---:|
| ₹30,000 | ₹3,60,000 | ₹30.00 |
| ₹50,000 | ₹6,00,000 | ₹50.00 |
| ₹1,00,000 | ₹12,00,000 | ₹100.00 |
| ₹2,50,000 | ₹30,00,000 | ₹250.00 |
| ₹5,00,000 | ₹60,00,000 | ₹500.00 |

At 1,000 seats and ₹50/month face price, **₹50,000 monthly staffing alone is ₹50/child/month**, before Play, tax, hosting and other provider fees. Therefore low subscription pricing may only work with a **deliberately constrained feature/support/service-level scope**, adequate scale, external funding or higher-margin tiers. SOS resilience, privacy legal review and real Android QA are **not optional budget omissions** if those features are sold.

## 5. Hardware and M1/M2 capacity checklist

| Requirement | Decision/proof |
|---|---|
| At least one non-managed older Android phone | OS version, API, brand/model, permission/FGS/Doze test log |
| At least one recent Android phone | API 34–36 candidate, typed FGS/permission/backgr-start test results |
| One Samsung/other mainstream OEM phone if available | Battery and reboot/OEM-kill behavior |
| **One spare phone safe to factory-reset** | Owner's written approval after backups; eligible Android fully managed DPC provisioning and actual device-owner proof |
| Child-side and parent-side separate devices/accounts | Pairing, revoked guardian, network loss and app permission flows |
| Managed device failure fallback | Standard mode remains functional; do not claim DPC restriction on a nonmanaged phone |

No real phone inventory has been supplied to the repo. Accept **emulators/synthetic GPS** for initial architecture tests only; M1 hardware proof and M2 device test acceptance remain blocked without devices. **Do not ask anyone to factory reset a phone before its data has been backed up and the device owner has approved.**

## 6. Mandatory decisions and execution logistics

| Blocker | Needed from owner | Consequence |
|---|---|---|
| TEAM-01 | Team roster/count and who actually owns child Android, parent Android, C++, QA/security and OCI | Schedule and definition of done cannot be committed |
| TEAM-02 | Monthly cash payroll/contractor budget and development runway | Cannot conclude break-even |
| TEAM-03 | Support channels, response hours, custody/legal escalations and planned paid SOS scope | Cannot price support/incident coverage |
| TEAM-04 | Real hardware list/API/OEM plus safe-to-reset device | Cannot pass Android lifecycle/DPC acceptance |
| TEAM-05 | India-qualified DPDP lawyer/tax accountant and paid review budget | Cannot pass real child data legal gate |
| TEAM-06 | Current prepaid collection: founding ₹50/₹500 vs regular ₹99/₹999, actual tax-inclusive status, manual top-ups, trial conversion, churn, refunds and Play settlements | Revenue estimates unverified; former universal-price auto-renew case is historical |
| TEAM-07 | Maximum hosting+provider+staff spend for pilot, and go/no-go thresholds | No credible release cash plan |
| TEAM-08 | Phone-first vs managed DPC vs Wear in launch; fixed milestone responsibilities | Avoid costly spread of thin team |

**Recommended gate order (corrected 2026-10-30):** retain owner-reported individual publisher entity, complete Payments/merchant and tax review; approve limited child/guardian/retention scope and login; list hardware and owner/QA engineers; implement synthetic-data vertical slice; fund independent security/Android/device testing and real backup recovery; pilot only after written legal/owner clearance. Hosting region/costs are deployment decisions, not a Chicago prerequisite for local coding. Review economics after measured invoices and churn; **no repricing or existing-price change is authorized**.

This document answers the specific gap: **founding ₹50/month and ₹500/year are owner policy, not demonstrated sustainable all-in costs; regular ₹99/₹999 is also not a verified profit forecast.**

## 2026-10-27 media event history and restricted admin UI new scope cost reminder

Owner-added FR-050/051 (parent media audit + new case-gated administrator panel) are **not included** in the historical hosting/engineering break-even plan. Estimate C++ Drogon event ingest, PostgreSQL indexed metadata and admin access-audit growth, Android parent audit screens, admin web frontend, SSO/MFA, case approval, QA/penetration testing, legal/privacy, retention/delete, support operations and audit infrastructure as separate engineering/run-cost workstream before treating ₹50/month or ₹500/year as sufficient. No binary media archive on VPS, but operations/metadata cost and privacy duties remain. See [Media Activity Audit ADR](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_ACTIVITY_AUDIT_LOGGING_AND_REPORTING_2026.md), [Administrator Console Specification](../../P3-deferred-research/01-media-and-administrator-research/ADMIN_PANEL_SPECIFICATION_2026.md).

## 2026-10-27 GPS ingestion worker and 48h offline capacity economics — not in historical price model

The user-accepted [MA-INGEST-ADR-004](../../M2-location-collection/01-location-collection-and-ingestion/POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md) adds a durable PostgreSQL inbox, a C++ bulk-insert worker with SKIP LOCKED/recovery, device encrypted up-to-48h queue logic and an alternate direct bulk benchmark. Redis licensing/VM is NOT mandatory initially but Postgres inbox write amplification, WAL, retention/deletion, worker on-call, API + Android/OEM testing and school-run 48h reconnect bursts require engineering/infra cost allocation. The earlier 300 location fixes/child/day and illustrative per-child OCI spend cannot be treated as guaranteed under moving vehicle/live tracking/phone+watch source combinations. Validate 1k/10k/100k load and India legal/Google Play gates before break-even/pricing promises.


## 2026-10-27 owner commercial/UI direction — supersedes conflicting historical proposals

**State: owner-approved design direction, NOT deployed, legally signed off, or Play Console/device tested.** Launch is India-first, **manual-renewal Google Play prepaid only**. No automatic renewal, background charge, or charge triggered by opening premium feature; parents explicitly confirm each purchase/top-up in Play. At verified prepaid expiry, downgrade to free: live tracking at a reduced adaptive GPS interval (moving design target approximately 10–15 minutes, slower stationary; no Android timing guarantee), most recent **six hours of visible location history**, and no paid media. Premium requests show payment review instead of silently charging. Deleting the account revokes child/guardian access and future ingest, and cannot generate an auto-renewal; handle any legacy auto-renewing purchase independently if ever issued.

**Price targets per paid child:** public ₹99/month or ₹999/year; founding ₹50/month or ₹500/year for the first **1,008 distinct successfully paying families** counted once each. All eligible paid children in a founding family, including added later, qualify. Founding eligibility persists through prepaid lapses when lawfully recognizable. Automatic eligible early-access offer, no coupon entry, subject to real Play prepaid products/offer support, taxes, fee confirmation and purchase-screen amount. Trial activation does not count as a paying founding family.

**Introductory experience:** once per eligible verified family, 48 hours of conditional Super Access with no auto-conversion, independently server timed. Across the FULL trial per eligible child, shared between authorized guardians: 5 audio minutes (3 min max/session), 2 video minutes (1 min/session), 3 successful photo snapshots, 2 screen-view minutes (1 min/session). Paid Balanced per paid child per month: 60 audio minutes (5 min max/session), 20 video minutes (2 min/session), 30 photos, 10 screen-view minutes (2 min/session). Count confirmed delivered session consumption, not failed OS attempts. Media remains **OFF / P3 conditional research** until Android, legal, Google Play, safety and device gates permit. No implied covert or guaranteed background sensor access.

**No repeated trial:** verify adult parent identity and prior redeemed or paid eligibility server-side, with a minimized bounded lawful anti-abuse ledger; optional Play Integrity/Device Recall subject to availability and review. Reinstall, logout, closure/recreation, or adding a child never restarts a lawfully recognized trial. Do not store child routes, images, microphone recordings, Aadhaar or IMEI to enforce eligibility. Legitimate families incorrectly blocked require review; permanent matching of an erased identity is not guaranteed.

**Storage vs visibility:** six-hour free history is an access limit, NOT a retention authorization. Earlier child location data can only remain for independently approved purpose-specific periods, not automatically until account closure. Deletion revokes token access, cuts off late offline uploads, and erases eligible data including backups as policy dictates. Legal retention, deletion exceptions, guardian authority and cross-border processing remain open gates.

**Parent UI:** replace oversized purple 48h hero with compact off-white/teal-style dismissible trial strip/pill (around 48–64 dp): “✦ Super Access · 47h left” plus accessible close X. The close dismisses marketing banner for the current in-app navigation session, NOT trial entitlement/countdown; a small plan/status entry remains visible. No flashing, support reduced motion. The opening welcome announcement may show once, then small strip; real countdown derives from backend. Trial-ended messaging clearly explains free tracking and manual prepaid upgrade.

**Costing:** existing OCI 1,000-child allocation (~₹3,238/month) explicitly excluded media. Provisional separate ₹3,000/month testing reserve is NOT a TURN/WebRTC provider quote, nor a production capacity promise; measure concurrency, relay ratio, bandwidth, storage, taxes, prepaid Play fees and full operating expenses. Older ₹50/₹500 as universal public pricing, auto-renewing products, 15% auto-renew fee cases, and corresponding revenue scenarios in preceding sections are HISTORICAL and need a full prepaid recalculation. Confirm Play Console purchase/top-up/seat-count/offer behavior before enabling billing.

**Screen consistency and traceability:** base UI source [existing 81-screen Figma handoff](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=6-2) (off-white/teal parent visuals). Update dashboard/map/history trial strip and billing screens P-47/P-48/P-49 plus deletion P-44, capabilities P-46, trial eligibility and media views to show this rule. Do not claim static Figma designs are working Android screens.

## 2026-10-28 extra concurrent viewer economics — separate unvalidated scenario

Commercial target +₹100 per optional simultaneous premium viewer screen (owner-confirmed one-time 100-calendar-day entitlement, independent of base prepaid child expiry) with +30 combined shared audio/video minutes per add-on for that child. This is GROSS Play checkout target before fees/taxes, not ₹100 net profit. Unlike additional paying child seats, the add-on increases WebRTC/TURN **fan-out to more receiving guardian devices** and session broker overhead while not adding another monitored child. Recompute egress as `stream_output_bitrate × concurrent_receivers × seconds × TURN_relay_fraction`, plus signaling, transcoding if needed, abuse prevention, customer support and unused/refund ratio; do not borrow earlier "free transfer" estimates as proof. For 2 extra slots candidate max 3 viewers/child, but server caps require OCI load test. Additional 30 combined audio/video minutes must be metered per child, not per guardian or per stream. Do not include unapproved media revenue/features in production forecast until Android, DPDP/Play and offer checks pass. More: https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/CHILD_SPECIFIC_GOOGLE_PARENT_SHARING_AND_CONCURRENT_SCREEN_ADDONS_2026.md.

## 2026-10-28 ₹100 / 100-day extra viewer viability — preliminary sensitivity, NOT a provider quote

Owner changed +1 premium simultaneous viewer to **100 calendar days**, valid independently of base prepaid expiry (premium viewing pauses during base lapse, resumes on manual renewal within 100 days). Extra **30 combined audio/video minutes total** over the purchased 100 days, not 30min per month and not 30 of each kind. Repeatable one-time Play Buy product with server expiry; native Play Rent currently offers periods up to 60 days, not 100. No auto-renew.

| 100-day customer-price sensitivity | Hypothetical value |
|---|---:|
| Gross paid once | ₹100.00 |
| GST-exclusive amount assuming included 18% GST | ₹84.75 |
| Eligible Play fee assumed 15% of ex-GST | ₹12.71 |
| **Illustrative available before hosting, staff, refunds** | **₹72.03 / 100 days** |
| Equivalent per 30 days sold validity | **₹21.61** |

**Fee and tax assumptions are NOT verified settlements**; Play fee eligibility/rate and actual India digital service GST handling remain open. With a 30% Play fee illustrative amount falls to ~₹59.32/100 days before costs. Actual refunds, withholding, support and net tax settlements may further reduce contribution. The forecast must treat ₹100 as 100-day earned revenue, not ₹100 each month.

**Network math per extra receiving device:** 30minutes of 1Mbps encoded AV is ~0.225GB (225MB); 2Mbps is ~0.45GB. A hypothetically unmetered 1Mbps stream used continuously for all 100 days reaches ~1,080GB (1.08TB) **per viewer**, so 100-day long concurrent-screen validity must NEVER mean unmetered 100-day live video/screen time. A guardian may duplicate the base child's monthly media transmissions over more than one main-plan renewal, so add base-quota fan-out, screen-view quota and relay fraction to traffic model. Oracle's first 10TB/month outbound tier is a SHARED tenancy allowance, not a per-user free pool. North America outbound beyond 10TB is published around ₹0.77/GB; compute, load balancing, logging, maps, operations and support are separate. Source: https://www.oracle.com/in/cloud/price-list/ and https://www.oracle.com/cloud/networking/virtual-cloud-network/pricing/.

**Historical hypothesis, NOT owner-approved operating decision or verified viability:** ₹100 might cover ordinary low-bandwidth live-map viewing plus 30 capped pooled AV minutes if shared egress headroom and relay compute exist; **not proven** for ordinary use, high sustained streaming or peak concurrent calls. Only sell after measuring p50/p95 extra-viewer bitrates, minutes, child base media fan-out, 100-day utilization, TURN relay rate, 10TB shared allowance, burst CPU and refunds. Restrict active AV sessions to quota, keep screen-view and photo quota unchanged, disallow free-tier unlimited media, and cap maximum additional viewers via measured server capacity. Review add-on profit as **incremental true cost vs net proceeds**, separately from historical ₹3,238/month OCI allocation for 1,000 paid children (which excluded media). https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/CHILD_SPECIFIC_GOOGLE_PARENT_SHARING_AND_CONCURRENT_SCREEN_ADDONS_2026.md.
