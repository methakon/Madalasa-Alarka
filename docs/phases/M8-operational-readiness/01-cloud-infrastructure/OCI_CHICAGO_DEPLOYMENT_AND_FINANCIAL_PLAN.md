# Madalasa–Alarka — Oracle Cloud Chicago Deployment, Capacity and Financial Plan

> **Document control:** M8 / 01-cloud-infrastructure · Proposed owner: Engineering lead (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

> **Current app names:** **Madalasa** (guardian/parent), **Alarka** (child companion). GitHub repository [Madalasa-Alarka](https://github.com/methakon/Madalasa-Alarka), renamed 2026-10-26. [Source story and naming contract](../../M0-foundation-and-approvals/02-market-and-feasibility/BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

**Decision reference:** OCI-CHI-001  
**Revision:** 1.0 · **Research/pricing checked:** 2026-10-25  
**Selected target home region:** US Midwest Chicago, **us-chicago-1** (OCI commercial realm OC1; three availability domains).  
**Status:** **Deployment plan committed; Oracle tenancy/VM NOT created; no cloud credentials or active instance were available in this session.**  
**Project:** [Madalasa–Alarka](../../../../README.md), [Canonical Technical Specification](../../M1-secure-platform-foundation/01-requirements-and-architecture/TECHNICAL_SPECIFICATION.md), [Secure M1 Implementation](../../M1-secure-platform-foundation/01-requirements-and-architecture/M1_ANDROID_CPP_ARCHITECTURE_AND_IMPLEMENTATION.md), [Data/Security Contract](../../M1-secure-platform-foundation/03-security-and-permissions/DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md), [Blocker Register](../../M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md).

## 1. Executive decision, why Chicago, and what is unverified

**Use Oracle OCI Ampere A1 (ARM64) in us-chicago-1 as the primary dev/MVP infrastructure target.** In the initial resource-constrained model, **Drogon C++ API, independent C++ reconstruction worker, PostgreSQL/PostGIS and HTTPS edge all run on one VM**, as separate processes with individual resource ceilings.

**Why Chicago:**
- Three availability domains (ADs); when an A1 Always Free instance receives an out-of-host-capacity error, retrying another AD within the selected home region is an Oracle-documented option.
- Same published OCI A1 price/free allowance as other eligible commercial regions; we are **not** claiming Chicago has higher A1 quotas or cheaper future paid compute.
- Longer-term PAYG expansion can use other ADs or request subscribed-region limits, subject to the actual account.
- User chose priority of free-quota and extensibility over local proximity.

**Unknown and cannot be confirmed from public information:** live free ARM capacity/placement in Chicago; actual tenancy shape limits; available AD placement on the day of enrollment; current account free entitlement; paid capacity/SLA terms. Oracle does **not** expose a reliable real-time public per-AD capacity inventory. Successful creation is the actual proof.

**Important child-data risk:** a US-hosted database for minors may require jurisdiction-specific consent, lawful cross-border transfer terms, processor notices and privacy/legal review. Chicago is a technical home-region decision **subject to B-02 and privacy signoff**; do not start real child-data production collection until that decision is resolved.

Official sources: [Oracle regions/ADs](https://docs.oracle.com/en-us/iaas/Content/General/Concepts/regions.htm) and [Oracle Always Free](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm).

## 2. Verified free-tier and PAYG charging rules

| Resource | Always Free tenancy | PAYG tenancy | Billing risks and notes |
|---|---|---|---|
| Ampere A1 VM | **1,500 OCPU-h + 9,000 GB-h/month**; typically 2 OCPU + 12 GB 24/7 | Published paid price list: **3,000 OCPU-h + 18,000 GB-h/month** equivalent ~4/24 for full month | Paid account entitlement **must be verified before relying on 4/24**; allowances shared across all A1 VMs/container instances in tenancy |
| E2.1.Micro AMD | Up to two micro VMs | Follow applicable entitlement | Only 1 GB each; do not depend on them for PostgreSQL |
| Boot + block volumes | **200 GB total** home-region | Same listed Always Free allotment | A 50 GB boot volume counts; **not 200 GB in addition to boot** |
| Volume backups | **Five** Always Free volume backups | Same listed allowance | Five objects, not unlimited historical backup storage/recovery promises |
| Object/archive storage | **20 GB combined** | **10 GB Standard + 10 GB Infrequent + 10 GB Archive** | Paid object capacity/bandwidth/API calls beyond quotas; free requests allowance subject to Oracle limits |
| Object storage requests | 50,000 requests/month | Same free requests allowance listed | Monitor large upload frequency |
| Outbound data transfer | 10 TB/month included | Follow OCI free transfer policy | Child telemetry is mostly inbound; map API responses/backup transfer are outbound |
| HTTPS/monitoring | Free-tier-compatible VCN, logging/monitoring and certificate quotas | Free allowances/paid excess | Public domain registration and outsourced alerting are separate costs |
| Service support | Always Free lacks enterprise SLA/standard Oracle Support | PAYG can offer support options | Single free VM **is not a high-availability child safety service** |

Oracle free account is not charged for paid services **unless deliberately upgraded or using time-limited promotional trial resources**. If Free Trial created excess A1 beyond 2/12, it may be disabled/removed after credits expire. Never rely on promotional $300 trial credits as recurring economics.

**Account documentation distinction:** The Always Free resource page says 2/12 for a free-only tenancy. Oracle India **paid price list** says PAYG first 3k/18k usage hours free. They are **not the same allowance**. Verify the individual PAYG account's billing screen and limits; if entitlement differs, revise all projections.

Sources: [Oracle Always Free](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm), [Oracle India price list](https://www.oracle.com/in/cloud/price-list/), [OCI Free Tier account lifecycle](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier.htm), [OCI public price geography](https://www.oracle.com/cloud/economics/).

## 3. Architecture by stage

### Stage A — Always Free lab and controlled pilot

~~~text
Google Play native Parent Android (Kotlin, Compose, Maps)
  |
  | HTTPS/TLS, parent OIDC, child-specific grants
  v
OCI Chicago single A1 ARM64 VM — 2 OCPU, 12 GB
   Caddy/Nginx: TLS reverse proxy (443 only)
   Drogon C++20 API service (limits, JWT/device proof, data access)
   C++20 worker process (GPS event-time recon + usage + jobs)
   PostgreSQL + PostGIS (localhost/private socket ONLY)
   Background retention/backup tasks and metrics agents
       |
       +--> Free OCI Block Volume (database)
       +--> Encrypted daily logical backup to Object Storage
       +--> OCI Monitoring/Notifications (quota limited)
  ^
  |
Child Android Kotlin location/usage + small C++ NDK core
Encrypted local queue + batched authorized telemetry
~~~

**VM deployment candidates:**
- Region: us-chicago-1; AD: whichever of the 3 ADs actually provisions A1.
- Image: Ubuntu/Oracle Linux **arm64** Always Free eligible image, supported/patched.
- Shape: VM.Standard.A1.Flex, 2 OCPU / 12 GB.
- Boot: 50 GB; separately attached database block volume: **100 GB** initially; total 150 GB, leaving **50 GB** of free allocation unused as headroom.
- Public endpoint: one HTTPS reverse proxy on port 443. Keep PostgreSQL port 5432 closed to the internet. Admin through OCI Bastion or otherwise hardened management access. Firewall denies all unnecessary inbound traffic.
- Service manager: systemd/Podman with limits; do not need Kubernetes, external Redis, message broker or separately hosted workers on day 1.
- Data protection: encryption at rest through supported OCI volume encryption, TLS to clients, device Keystore signatures, family/child ACL and DB RLS, non-root least-privileged processes, protected secrets with approved rotation.
- Process budget candidate: OS/cache 1–2 GB, PostgreSQL 3–4 GB, Drogon API 0.5–1 GB, C++ worker ~0.5–1.5 GB, spare page cache/metrics. These are tuning budgets, not measured process footprints.
- Worker CPU concurrency 1 initially; Drogon event loop must never synchronously reconstruct trips. Parent latest position hits indexed qualified row; GPS uploads are batched and acknowledged after durable DB commit.

**Why single VM first:** eliminates separate C++ worker-hosting fees and cross-host queues. Backend grows by horizontal API/service scaling later, **without discarding the C++ domain architecture**. Single node is vulnerable to VM failure, maintenance, free-tier reclamation or database loss; don't market emergency uptime guarantees.

### Stage B — PAYG account, optimize without new architecture

- Upgrade deliberately to OCI PAYG only after confirming entitlement, payment/tax information and spending safeguards. PAYG is a billing mode: **it does not automatically resize the existing instance when subscribers grow**.
- Consider **4 OCPU / 24 GB** A1 equivalent if the paid-account quota is confirmed. Under the published 3k/18k monthly allowance this size has ~₹0 **A1 compute usage** for a full 730-hour planning month; storage, regional backup, paid networking, support, Maps and taxes can still cost.
- Upgrade VM shape/restart or provision additional VM and move load using tested migrations; dynamic autoscaling requires OCI instance pools/metrics and usually additional paid infrastructure, not an automatic free-VM feature.
- Separate Drogon API processes and C++ worker compute budgets first, then move DB to a private instance/managed database or add application replicas as latency, reliability and data growth demand.

### Stage C — Commercial high-availability topology (not costed in cheap single-VM model)

- Distinct API and reconstruction VM pools, managed/private database, replication/failover, off-machine encrypted backup and restore tests, load balancer, monitoring/on-call and region/AD fault plan.
- Set production SLA from actual testing; at least two failure domains for critical service and no single free VM for guaranteed emergency/SOS.
- PAYG 4/24 shared monthly allowance does not imply high availability; even two VMs within free hours will not make a standalone primary PostgreSQL highly available without database architecture work.
- Provider fees for load balancers/managed DB/extra backups/egress, and **human operations/support**, must be priced separately before promising a commercial SLA.

## 4. Deployment procedure and checkable steps

| Step | Exact planned action | Evidence/rollback |
|---|---|---|
| D-01 | Register/verify OCI account, select home region **US Midwest Chicago** at creation; configure MFA, billing admin and compartment | Screenshot/redacted region and account mode; do not share passwords/keys |
| D-02 | Check Limits/Quotas and Usage in Chicago; try VM.Standard.A1.Flex 2/12 on AD1, AD2 or AD3 if available | Live VM OCID, shape/AD; if out-of-host-capacity, no VM exists |
| D-03 | Create a dedicated compartment, VCN, subnet, ingress rules 443 and restricted admin, outbound as required | No 5432 to public internet; network scan |
| D-04 | Provision Always Free eligible ARM64 image, 50 GB boot and 100 GB attached DB block; keep remaining free capacity in reserve | Boot + block quota and volume attachment screenshot |
| D-05 | Set user/service accounts, automatic security updates, SSH/Bastion, firewall, systemd limits and time sync; avoid hard-coded secrets | Security baseline and recovery access tested |
| D-06 | Compile/build for aarch64: C++20 Drogon API and C++ worker, PostgreSQL/PostGIS, supported TLS reverse proxy | Native ARM compile, unit test, signed version hash |
| D-07 | Apply versioned SQL migrations, child/family ACL, authorized pairing and device keys, backup roles; no real child GPS before security tests | Migration/revert, two-family IDOR/RLS test |
| D-08 | Deploy HTTPS domain endpoint with free ACME certificate, healthcheck, failure statuses and limited log retention | TLS test; domain fee is external |
| D-09 | Enable encrypted daily PostgreSQL logical backup with WAL-safe strategy when applicable to OCI Object Storage; schedule restore drills | Test a **separate** restore environment; backups on same VM are insufficient |
| D-10 | OCI metrics/budget alarms for CPU, RAM, disk, egress, queue backlog, backup failures; do not inflate utilization to avoid idle reclamation | Test alert receipt and automatic rollback procedures |
| D-11 | Synthetic 10, 100, 300, 500 device workloads, then labeled/authorized device pilot | Measured latency, queue lag, retention, memory, battery, GPS trust |
| D-12 | Add paid account/resize only after budget approval and real trigger; test migration and downshift | Before/after costs, billing alerts, backup proof |
| D-13 | Final privacy/controller/region review, Play monitoring disclosure, live deletion URLs and release binary evidence | Policy approval; no “production-ready” claim before completion |

**No cloud resources are created by this document.** Provisioning requires authorized OCI account access and actual successful shape allocation. Avoid automatically upgrading to PAYG on capacity errors: only an informed owner should change billing mode.

## 5. Usage model: one subscription per active child, not per parent

| Variable | Planning assumption | Change sensitivity |
|---|---|---|
| Billable unit | **One actively enrolled child profile with tracking entitlement per subscription** | Parent with 3 children = 3 subscriptions; can link more than one source device to child under policy |
| Parent login count | One or several approved guardians per child | Increases parent reads, SSE/alerts but **not** child subscription count |
| Average GPS observations | **300 accepted fixes per child per day** | Frequency/accuracy and active travel significantly alter cost |
| Device API batches | ~30 fixes per HTTPS request | ~10 batch requests per child per day, before retries |
| Retention model | 30 days raw GPS, 90 days derived trips/usage as **financial scenario only** | Unapproved owner choice B-07; actual policy may be different |
| Raw + index footprint | 0.5–1.0 KB per stored GPS observation | Requires Postgres measured table/index/WAL storage, not guaranteed |
| Parent map/read traffic | Moderate; latest fix and paginated trips, one active viewer per account typically | Continuous live viewing, long replay and excess polls change memory/egress |
| Excluded heavy workload | No remote media streams, recordings, giant downloads or paid road matching | Such features create entirely different bandwidth/storage/provider bills |
| Hours per full month | 730 | Formula recompute for actual invoice/calendar month |

**Warning:** A child with a watch and phone may generate multiple tracking source streams. Subscription count by child does not guarantee resource consumption per child remains constant. Billing/limit policy must prevent disproportionate multi-device usage or account for it.

At 100 active children: 30,000 fixes/day, ~900,000 fixes/month, **0.45–0.9 GB raw+indexes** under the 0.5–1KB model. At 500 children: 150,000/day, 4.5 million/month and **2.25–4.5 GB raw+indexes**. At 1,000: 300,000/day, 9 million/month and **4.5–9 GB**. The figures exclude derived trip rows, usage, WAL, indexes beyond assumed budget, temporary files, backups and customer exports.

## 6. Actual prices and compute-only formula

**Oracle India price list at review:**
- Ampere A1 CPU **₹0.95545 per OCPU-hour** over applicable allowance.
- Ampere A1 RAM **₹0.1433175 per GB-hour** over applicable allowance.
- Block volume above free allowance **₹2.4363975/GB-month** storage, plus performance **₹0.1624265/VPU/GB-month** (10 VPUs ≈ ₹1.624265/GB-month), so **balanced block volume totals ~₹4.06/GB-month** when billed and excluding taxes. Use Basic/lower VPU only after measured I/O safety check.
- Object Storage Standard over applicable free allotment **₹2.4363975/GB-month**, plus operations/retrieval/other tier rules as applicable.
- These are published OCI India-list illustrations; actual invoice currency/contract/tax and region of purchased services require account confirmation. **Do not use a made-up exchange rate.**

**Monthly compute formula (PAYG 730 hours, after paid account benefit verification):**

~~~text
ocpu_billable_hours = max(0, (total_A1_OCPU × 730) − 3000)
ram_billable_gbh    = max(0, (total_A1_RAM_GB × 730) − 18000)
A1_compute_INR      = ocpu_billable_hours × 0.95545
                      + ram_billable_gbh × 0.1433175
AlwaysFree-only: use 1500 OCPU-h and 9000 GB-h instead.
~~~

For a real 31-day month, use actual 744 hours. Free hours and GB-hours apply to all A1 resources in tenancy combined. An additional always-on machine may begin charging when the **sum** exceeds the quota, even if the original machine remains unchanged.

**Compute is not a child-based Oracle price.** The following machine sizing is **illustrative scenario allocation only, NOT a benchmark proving each configuration can handle N children.**

## 7. Monthly infrastructure scenario projections in INR

> **For updated total monthly and annual expenses that explicitly include excess paid disk and backup storage, use §14.** The figures in this §7 are older CPU-plus-reserve projections and must **not** be added on top of §14 totals.

Two separate columns prevent a false “free commercial operations” claim:
1. **A1 compute:** calculated against Oracle published allowances.
2. **Planning reserve:** illustrative **noncompute/operational contingency** set by Madalasa–Alarka planning for domains, independent encrypted backups, monitoring, billing reconciliation and unmeasured external charges. **Not an OCI quoted charge and NOT a sufficient staffed 24/7 support budget.** Adjust it after provider bills.

**Scenarios (monthly 730-hour model):**

| Active subscribed children | Billing scenario | OCPU / RAM GB | Raw GPS 30d | Oracle A1 compute | Optional noncompute reserve | Illustrative infra budget | Infra budget / child |
|---:|---|---:|---:|---:|---:|---:|---:|

| 100 | Always Free | 2 / 12 | 0.5–0.9 GB | ₹0 | ₹1,500 | **₹1,500** | ₹15.00 |
| 300 | Always Free | 2 / 12 | 1.4–2.7 GB | ₹0 | ₹1,500 | **₹1,500** | ₹5.00 |
| 500 | Always Free | 2 / 12 | 2.3–4.5 GB | ₹0 | ₹2,000 | **₹2,000** | ₹4.00 |
| 1,000 | PAYG free A1 quota* | 4 / 24 | 4.5–9.0 GB | ₹0 | ₹3,000 | **₹3,000** | ₹3.00 |
| 2,500 | PAYG paid excess | 6 / 36 | 11.3–22.5 GB | ₹2,505 | ₹6,000 | **₹8,505** | ₹3.40 |
| 5,000 | PAYG paid excess | 8 / 48 | 22.5–45.0 GB | ₹5,156 | ₹12,000 | **₹17,156** | ₹3.43 |
| 10,000 | PAYG paid excess | 12 / 72 | 45.0–90.0 GB | ₹10,456 | ₹25,000 | **₹35,456** | ₹3.55 |

**Interpretation:** In an Always Free account, 100–500 is a **test-planning range**. At 1,000 the table assumes you **deliberately switched to PAYG** and verified the larger A1 allowance; 4/24 compute may remain ₹0 despite being a **paid account**. At 2,500–10,000 the CPU/RAM calculations are reliable arithmetic but actual infrastructure would likely require **multiple VMs, dedicated database, backup and HA**, so these figures **understate a production-grade deployment**.

Cost drivers increasing earlier than child count alone:
- Capturing every 5–15 seconds instead of adaptive 300 points/day.
- Large long-term raw GPS/history or media storage.
- Extended multi-device (phone/watch) records per subscribed child.
- Frequent real-time parent viewers and third-party geocoding/Roads API calls.
- Paid managed PostgreSQL, load balancing, disaster recovery regions, contractual support and professional security/operations.
- Need for cross-border compliance, customer support staffing and high service availability.

## 8. Paid subscription per child: revenue and unit economics

**Policy assumption:** each **child profile** requires its own monthly subscription; one parent may manage 1, 2, 3 or more children; all approved guardians share authorization, **not duplicate child subscription charges**. The suggested base price used here is **₹149 per child/month as a modelling example, not an approved product price**.

**Google Play recurring subscriptions:** official guidance lists a 15% service fee in currently applicable standard regimes, but the actual country/product agreement and payment scheme must be verified. Illustrations treat 15% of listed pre-tax price as an expense. The treatment of GST/VAT, taxes included/excluded in end-user price, payment declines, refunds/chargebacks, regional fees and alternative billing may change realized revenue.

| Charge or income per paying child | Example at ₹149/month |
|---|---:|
| Subscription collected (pre-tax **assumed**) | **₹149.00** |
| Play 15% fee (illustrative) | ₹22.35 |
| After illustrative Play fee, before tax/other costs | **₹126.65** |
| Allocated A1 compute cost at 2,500-child case | ~₹1.00 |
| Allocated full illustrative infra budget at 2,500-child case | ~₹3.40 |
| Additional app-store taxes/refunds, support, engineering, security, legal, marketing, extra APIs | **UNPRICED and potentially much larger** |

**Family billing examples:** parent with 1 child pays ₹149/month; parent with 2 children ₹298/month; parent with 3 children ₹447/month **before tax/discounts**, with one corresponding subscription per child. There is no separate Oracle per-parent fee, though parent traffic counts toward capacity.

### Revenue sensitivity at hypothetical ₹149/child

| Paying children | Gross pre-tax subscription sales | Illustrative Play fee (15%) | Sales after Play fee | Compute + modelled infra reserve | Remainder before tax, staff, marketing, legal, refunds, other APIs |
|---:|---:|---:|---:|---:|---:|

| 100 | ₹14,900 | ₹2,235 | ₹12,665 | ₹1,500 | ₹11,165 |
| 300 | ₹44,700 | ₹6,705 | ₹37,995 | ₹1,500 | ₹36,495 |
| 500 | ₹74,500 | ₹11,175 | ₹63,325 | ₹2,000 | ₹61,325 |
| 1,000 | ₹1,49,000 | ₹22,350 | ₹1,26,650 | ₹3,000 | ₹1,23,650 |
| 2,500 | ₹3,72,500 | ₹55,875 | ₹3,16,625 | ₹8,505 | ₹3,08,120 |
| 5,000 | ₹7,45,000 | ₹1,11,750 | ₹6,33,250 | ₹17,156 | ₹6,16,094 |
| 10,000 | ₹14,90,000 | ₹2,23,500 | ₹12,66,500 | ₹35,456 | ₹12,31,044 |

**This remainder is emphatically not net profit.** It omits application development salaries, ongoing support/operations, customer acquisition, GST/VAT/income tax, chargebacks/refunds, insurance, audits, security professionals, paid geocoding and other costs. Subscription cancellations reduce paid units but previously stored data may still incur permitted retention/deletion processing expense.

### Pricing variants for product discussion

| Hypothetical child plan/month pre-tax | Play fee at assumed 15% | Sales after fee before other costs |
|---:|---:|---:|
| ₹99 | ₹14.85 | ₹84.15 |
| ₹149 | ₹22.35 | ₹126.65 |
| ₹199 | ₹29.85 | ₹169.15 |

**Do not set a final subscription price from compute arithmetic alone.** Add full product economics, taxes, region differences, unit support cost, retention costs, premium features, refunds and Play Billing policy before launch.

## 9. Third-party and financial line items often forgotten

| Expense | Start estimate | Treatment and risks |
|---|---|---|
| OCI Always Free VM 2/12 | ₹0 compute if eligible/available | Shared CPU, potential reclamation, no SLA; needs recovery strategy |
| OCI PAYG 4/24 A1 | Potentially ₹0 A1 compute under verified 3k/18k benefit | PAYG account can incur chargeable services immediately |
| OCI block volumes first 200GB | ₹0 quota | Boot included; excess volume storage+performance billed |
| Encrypted Object Storage backup | Free only within applicable tier/requests | 20GB combined free-only; paid account separate 10GB per tier; replication/backup tests |
| OCI outbound transfer | 10 TB/month included | Check traffic billing in account; unusual media or sync can change |
| Domain name | **Budget ₹1,000–2,000/year** hypothetical | Registrar/TLD-specific; not Oracle compute |
| TLS certificates | Free ACME certificates can be used | Proper renewals/configuration still require admin effort |
| DNS hosting | Could be included by registrar; OCI DNS may add cost | Confirm zone/query charges for chosen setup |
| PostgreSQL/PostGIS/Drogon software | Open source, no per-child license fee in the proposed stack | Maintenance, admin and security operations are not free |
| Firebase Cloud Messaging | Listed as no-cost | Third-party dependency, delivery **not guaranteed** |
| Google Maps SDK for Android | Mobile Maps SDK usage listed as unlimited/no SKU charge, with billing project/key required | Dynamic Street View, Places, Routes, Roads, geocoding are distinct paid SKUs |
| Maps Places/Geocoding/Roads | **Excluded until separately estimated** | Quota/cost caps, Maps Terms, Roads tracking license review |
| Play developer account | **US$25 one-time** | Payment/currency/tax per country; separate from subscription service fees |
| Play Billing recurring subscription fee | Example 15% | Verify actual subscription agreement/taxes and country details |
| Google Drive backup | Optional OAuth; potentially parent pays Drive storage | API/authorization, media bandwidth, token/storage processor risks |
| Customer support/maintenance | **Not included** | Staff/consultant time can dominate at small subscriber counts |
| Legal/privacy/security reviews | **Not included** | Children's precise location and US data residency require independent review |
| App store refunds/taxes | **Not included** | Material to per-child contribution and profitability |
| Off-region disaster-recovery backup | **Not included** | Cross-region data movement, encryption/storage and legal implications |
| Managed PostgreSQL or HA load balancer | **Not included** | Reliability premium, separate quote and architecture |

Sources: [OCI price list India](https://www.oracle.com/in/cloud/price-list/), [Maps SDK Android usage](https://developers.google.com/maps/documentation/android-sdk/usage-and-billing), [Google Maps SKU pricing](https://developers.google.com/maps/billing-and-pricing/), [Firebase FCM pricing](https://firebase.google.com/pricing), [Play subscriptions service fee](https://support.google.com/googleplay/android-developer/answer/112622?hl=en-in), [Play Console registration](https://support.google.com/googleplay/android-developer/answer/6112435).

## 10. Real upgrade triggers: when billing actually starts

**Neither Oracle nor your architecture has an automatic “500 children = paid” threshold.** Start measuring with 10/100/300 child simulations, then take a product decision:
- **Consider upgrade or optimization** if CPU >65–70% sustained at representative peaks, PostgreSQL memory pressure/swap, DB disk >65–70% (with 30-day growth projection), API p95 >500ms or ingestion/reconstruction queues fall consistently behind; thresholds are **initial engineering candidates**.
- **Consider PAYG for service support/capacity**, even at 10 paying children, if you need reliable recovery/support or a critical SLA. Upgrading account alone doesn't remove single-node failure risk.
- **If OCI reclaims Always Free A1 or capacity is unavailable**, service downtime/data restore may force a paid resource regardless of subscriber count.
- **If heavy Maps/Roads/Places/media or paid storage** used, bill may be nonzero even with 2/12 A1 compute.
- **If free-only account**, no automatic PAYG overflow charge; a service may fail to allocate rather than silently expand. Never auto-upgrade without authorization.

**Suggested release planning, not capacity certification:**
- 0–100 children: small controlled pilot within free 2/12 if created and tested.
- 100–500: careful battery/server/DB and queue monitoring, begin backup and resilience improvement.
- 500–1,000: consider PAYG and 4/24 only with tenancy free-benefit confirmation and tested performance.
- 1,000+: benchmark distributed DB/workers, load and security; do not place all paid family safety workloads on a single free node.
- Re-estimate at every order-of-magnitude usage increase and when observation cadence or retention changes.

### Capacity review checklist for every +100 active child devices

1. 7-day p50/p95 ingest latency, failed receipts and queue lag.
2. Parent history query and simultaneous map viewers.
3. PostgreSQL connections/RSS, WAL, storage growth and free 200 GB remaining.
4. Device source count per child and actual observations/child/day.
5. Snapshot/object backup bytes, successful restore age and legal retention.
6. Oracle tenancy quota usage, paid service fees and budget alerts.
7. User-facing staleness and SOS delivery without guaranteed emergency response claims.

## 11. Reliability and privacy controls for a location-safety business

- This is a **single-node MVP**; it is not suitable for promises of guaranteed emergency availability. Provide child/parent last-seen, stale, offline and unavailable statuses clearly.
- Never bypass Android background/monitoring restrictions to satisfy server performance promises.
- Separate backend processes on same machine for predictable CPU and memory, but protect Postgres durability from worker overload using job budgets.
- Use encrypted off-machine backup, quarterly (or more frequent) restore tests, IAM least privilege, MFA, OCI budget alarm, credential rotation and documented incident response.
- Disable sensitive microphone/camera capture and arbitrary private file transfers in this hosting model; even when a separate authorized future feature is considered, its legal/power/storage budget must be recalculated.
- Hosting minors' precise location in a US region must be included in privacy policy, Data Safety disclosures, subprocessor registers and country/legal review. **Owner must decide data residency and acceptable retention before production.**
- A sample policy of raw location 30 days here is a **financial modelling assumption** only; current blocker B-07 is still open. If approved retention is longer, recompute and price storage/backup.

## 12. Current hard blockers and signoff ledger

| ID | Blocker | Who can resolve | Current state |
|---|---|---|---|
| OCI-01 | Create and verify Oracle tenancy **us-chicago-1** home region | Project owner with OCI credentials | **NOT CREATED** |
| OCI-02 | Obtain A1 2/12 in one of Chicago's 3 ADs | OCI capacity allocation/account | **NOT VERIFIED** |
| OCI-03 | Confirm Always Free and PAYG 4/24 benefit in **your** tenancy | Account billing dashboard/Oracle Support | **NOT VERIFIED** |
| OCI-04 | Select legal publisher, target markets, minors' data transfer legality and US residence | Project owner/privacy counsel | **BLOCKS production data** |
| OCI-05 | Approve raw/trip/usage/audit retention and backup deletion | Product/privacy owner | **OPEN** |
| OCI-06 | Choose real domain, support contact, DNS/certificate and identity provider | Product/operations | **OPEN** |
| OCI-07 | Implement C++ server, worker, migrations, SQL ACL and Android agent/parent | Developers | **NOT IMPLEMENTED** |
| OCI-08 | Load test 10–1,000 synthetic children and security/power/backup drills | QA/SRE | **NOT TESTED** |
| OCI-09 | Configure budgets, OCI IAM, encrypted off-machine backup and restore | Cloud engineer | **NOT CONFIGURED** |
| OCI-10 | Approve subscription price per child, taxes and Play Billing provider terms | Product/finance | **OPEN** |
| OCI-11 | Verify external Maps/Roads, FCM, third-party SDK fees before optional feature enabled | Finance/developers/legal | **OPEN** |
| OCI-12 | Define minimum SLA, production HA architecture and on-call staffing | Product/SRE | **OPEN** |

**Decision already made:** choose Chicago as the **target design**, prioritize Oracle Always Free 2/12 and C++ Drogon+PostGIS, keep worker on same VM initially. **No cloud VM, billing account, DNS/domain or runtime deployment has been provisioned.**

## 13. Source ledger and update policy

- OCI regions / 3 ADs / subscribed region limit: https://docs.oracle.com/en-us/iaas/Content/General/Concepts/regions.htm
- OCI Always Free: https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm
- OCI free account lifecycle and trial cap: https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier.htm
- OCI India current rate card: https://www.oracle.com/in/cloud/price-list/
- OCI price consistency worldwide: https://www.oracle.com/cloud/economics/
- Oracle paid account first 3k OCPU-h/18k GB-h: same published India rate card (verify in tenancy)
- Android Maps SDK billing: https://developers.google.com/maps/documentation/android-sdk/usage-and-billing
- Firebase FCM pricing: https://firebase.google.com/pricing
- Play subscription service fee: https://support.google.com/googleplay/android-developer/answer/112622?hl=en-in
- Google Play Console registration: https://support.google.com/googleplay/android-developer/answer/6112435

Re-run this financial model when Oracle changes free-tier limits, when account switches billing type, on new Maps provider quotas, when the product introduces extra media capture, or when the real tracking samples/day materially differ from **300**. All figures **exclude taxes unless clearly stated**.

**Document status:** researched deployment/cost design, not actual provisioning or a provider quote.

## 14. Cumulative recurring hosting cost beyond Free Tier — monthly, annual and scaling sensitivity

**This is the direct answer to the total hosting expense question.** This section supersedes the **simple computer-plus-unpriced-reserve budgets in §7** for cumulative/monthly/yearly comparisons. The older §7 is retained as a historical high-level projection; do not add its totals to these totals. These prices are illustrative **service usage forecasts**, not a quote, invoice, provider guarantee, or measured production capacity. Updated 2026-10-26 using Oracle's published India price list and the selected OCI Chicago infrastructure design.

### 14.1 What is counted and what is not

**Included in the priced-line hosting subtotal:**
1. All **A1 compute** for the stated aggregate OCPU and RAM capacity across all VMs/processes, after PAYG monthly A1 allowance (if confirmed in tenancy).
2. All provisioned **boot + block volume capacity**, after 200 GB Always Free allocation in the home region; model additional storage at **10 VPU/GB balanced performance**. This is billed provisioned capacity, not just used database rows.
3. Stored compressed, encrypted **off-instance logical backup objects** (assume PAYG first 10 GB Standard Object Storage free; Free-only baseline assumes its combined 20 GB allowance is allocated to these standard objects). Model stored *average occupied GB*, not the number of backup runs.
4. **₹150/month** for a hypothetical domain/DNS provision; **not an OCI tariff** (actual registrar and DNS may differ).

**Excluded from the priced-line subtotal:** taxes/GST, OCI paid requests/Logging beyond free allotments, paid load balancer, managed database, standbys/HA architecture, other paid OCI services, off-region disaster recovery, optional paid provider APIs, Maps/Places/Roads, app-store fees, salaries, customer support, legal/security consulting, hardware, development or marketing. A1 free consumption/volume allocations apply tenancy-wide and may be shared with unrelated workloads. Network egress is assumed within Oracle's 10 TB/month free outbound allowance. An OCI paid account may still have a bill despite zero A1 compute charges.

**Not an actual concurrency benchmark:** Number of children in each row is a **scenario label only**, not evidence that the indicated machine can serve that number reliably, or that the same amount of RAM is sufficient for PostGIS, workers and database. Production HA and data residency will materially change actual cost.

### 14.2 Official price inputs and billing formula

| Item | Planning rate / allowance | Basis |
|---|---:|---|
| A1 processor | **₹0.95545/OCPU-hour** | Oracle India rate card |
| A1 memory | **₹0.1433175/GB-hour** | Oracle India rate card |
| PAYG A1 recurring free amount | **3,000 OCPU-hours + 18,000 GB-hours per month** | Oracle price list, verify actual tenancy |
| Free-only A1 recurring amount | **1,500 OCPU-hours + 9,000 GB-hours per month** | Oracle Always Free resources |
| Home-region block + boot volumes | **200 GB included** | All eligible tenancies; boot counts |
| Extra block storage | **₹2.4363975/GB-month + ₹0.1624265/VPU/GB-month** | Assumed 10 VPUs adds ₹1.624265/GB/month; ~₹4.0606625 total for each billed GB |
| Standard Object Storage backup | **₹2.4363975/GB-month** beyond modelled included quota | Model PAYG 10 GB Standard free; additional requests/storage tiers may vary |
| Modelled domain/DNS | **₹150/month** | Owner-controlled estimate, not Oracle list price |
| Service utilization | **730 hours/month, 8,760 hours/year (12 × 730)** | Long-run monthly average; real 28/30/31 day billing differs |
| Uncertainty allowance | **20% of the priced-line subtotal** | Budget margin, not an OCI billed line |

~~~text
PAYG_A1_₹/month =
  max(0, combined_A1_OCPUs*730 - 3000) * 0.95545
  + max(0, combined_A1_RAM_GB*730 - 18000) * 0.1433175

PAID_BLOCK_₹/month = max(0, all_boot_and_block_GB - 200) * (2.4363975 + 10*0.1624265)
BACKUP_₹/month     = max(0, stored_standard_object_GB - 10) * 2.4363975

HOSTING_PRICED_LINE_SUBTOTAL_₹/month =
  PAYG_A1 + PAID_BLOCK + BACKUP + 150 (domain/DNS estimate)

RISK_MARGIN_₹/month = HOSTING_PRICED_LINE_SUBTOTAL * 0.20
PLANNING_HOSTING_BUDGET_₹/month =
  HOSTING_PRICED_LINE_SUBTOTAL + RISK_MARGIN
  + SCENARIO_SPECIFIC_ADDITIONAL_HOSTING_CONTINGENCY

ANNUAL_RECURRING_BUDGET_₹ = MONTHLY_RECURRING_BUDGET * 12
~~~

**Important:** The additional hosting contingency is a **reserved budget**, not an expected Oracle charge. It creates room for unmodelled observability, paid request usage, backup transfer, emergency storage growth, DNS, additional VM, deployment or recovery needs; it is **NOT** a price quote for real commercial HA/SRE and should be higher when service-level guarantees are promised.

### 14.3 Priced-line cumulative hosting charges

The following monthly table **adds all specifically priced host items**, rather than showing A1 compute alone. Object backup volume and provisioned disk are new explicit assumptions; remeasure them before buying resources.

| Hypothetical active children | Aggregate compute profile | Provisioned boot+DB block | Retained Object backups | A1 paid CPU+RAM/month | Extra block/month | Backup objects/month | Domain/month | **Priced-line subtotal/month** | **12-month subtotal** |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 500 (illustrative) | Free-only 2/12 | 150 GB | 20 GB | ₹0 | ₹0 | ₹0 | ₹150 | **₹150** | **₹1,800** |
| 1,000 (illustrative) | PAYG 4/24 | 200 GB | 30 GB | ₹0 | ₹0 | ₹49 | ₹150 | **₹199** | **₹2,385** |
| 2,500 (illustrative) | PAYG 6/36 | 300 GB | 80 GB | ₹2,505 | ₹406 | ₹171 | ₹150 | **₹3,232** | **₹38,782** |
| 5,000 (illustrative) | PAYG 8/48 | 500 GB | 160 GB | ₹5,156 | ₹1,218 | ₹365 | ₹150 | **₹6,889** | **₹82,671** |
| 10,000 (illustrative) | PAYG 12/72 | 1000 GB | 350 GB | ₹10,456 | ₹3,249 | ₹828 | ₹150 | **₹14,683** | **₹1,76,200** |
| 20,000 (illustrative) | PAYG 16/96 | 1500 GB | 600 GB | ₹15,757 | ₹5,279 | ₹1,437 | ₹150 | **₹22,624** | **₹2,71,483** |
| 50,000 (illustrative) | PAYG 24/144 | 3000 GB | 1200 GB | ₹26,359 | ₹11,370 | ₹2,899 | ₹150 | **₹40,778** | **₹4,89,337** |

**Example at 5,000 children (illustration, not capacity claim):** A1 8/48 uses paid monthly resources above the 3k/18k allowance; compute ≈ **₹5,156/month**, additional 300 GB block ≈ **₹1,218/month**, 150 GB chargeable object backups ≈ **₹365/month**, domain ≈ **₹150/month**. **Priced-line total ≈ ₹6,889/month**, or **₹82,671/year** at constant use/rates, excluding reserve/tax/unlisted services.

### 14.4 Safer cash planning budget: what to allocate to hosting

These are **cash allocations**, not invoices: the priced-line service subtotal + 20% calculation uncertainty + the owner's discretionary extra hosting contingency. Extra contingency amounts are **₹1,500, ₹3,000, ₹6,000, ₹12,000, ₹25,000, ₹45,000 and ₹1,00,000/month** as the scenarios grow. These are chosen planning allowances (roughly increasing with workload/operational risk), **not charges from Oracle**.

| Illustrative children | Priced subtotal/month | 20% risk margin/month | Additional *reserved* hosting contingency/month | **Recommended monthly hosting allocation** | **Annual hosting allocation (12×)** | Allocation/child/month |
|---:|---:|---:|---:|---:|---:|---:|
| 500 | ₹150 | ₹30 | ₹1,500 | **₹1,680** | **₹20,160** | ₹3 |
| 1,000 | ₹199 | ₹40 | ₹3,000 | **₹3,238** | **₹38,862** | ₹3 |
| 2,500 | ₹3,232 | ₹646 | ₹6,000 | **₹9,878** | **₹1,18,538** | ₹4 |
| 5,000 | ₹6,889 | ₹1,378 | ₹12,000 | **₹20,267** | **₹2,43,205** | ₹4 |
| 10,000 | ₹14,683 | ₹2,937 | ₹25,000 | **₹42,620** | **₹5,11,440** | ₹4 |
| 20,000 | ₹22,624 | ₹4,525 | ₹45,000 | **₹72,148** | **₹8,65,780** | ₹4 |
| 50,000 | ₹40,778 | ₹8,156 | ₹1,00,000 | **₹1,48,934** | **₹17,87,205** | ₹3 |

**How to read it:** For 2,500 hypothetical children with 6/36 A1, 300 GB total volume and 80 GB object backups: **~₹3,232** specifically priced services per month. With ~₹646 risk margin and ₹6,000 optional additional hosting reserve, **allocate ~₹9,878/month = ₹1,18,538/year**. This is not a claim that Oracle will bill ₹9,878; unspent reserve remains unspent.

**If you want the minimum plausible OCI bill rather than your safer business hosting budget, use §14.3**, not the larger allocations in this table. Neither version pays for actual human support, development, Play fees, media APIs or production-grade HA.

### 14.5 What changes if the PAYG A1 free-hours benefit does not apply?

A conservative sensitivity is to charge **every A1 OCPU-hour and RAM-hour** at the published rate, with no A1 credits; all other priced assumptions remain unchanged. This is **not** an assertion that Oracle will withhold the published benefit; it is a what-if if a billing scenario, consumed shared quota, capacity/eligibility or deployment arrangement differs.

| Aggregate A1 profile | A1/month WITH published PAYG allowance | A1/month with NO A1 allowance | Compute-only increase/month |
|---|---:|---:|---:|
| PAYG 4/24 | ₹0 | ₹5,301 | +₹5,301 |
| PAYG 6/36 | ₹2,505 | ₹7,951 | +₹5,446 |
| PAYG 8/48 | ₹5,156 | ₹10,602 | +₹5,446 |
| PAYG 12/72 | ₹10,456 | ₹15,903 | +₹5,446 |
| PAYG 16/96 | ₹15,757 | ₹21,203 | +₹5,446 |
| PAYG 24/144 | ₹26,359 | ₹31,805 | +₹5,446 |

The A1 credit accounts for up to **~₹5,446/month** of compute at these 730-hour and rate assumptions once a plan fully consumes both allowances. **Do not spend against credits not visible in your OCI Cost Analysis/Billing dashboard.** Free-only tenancies cannot simply exceed free provisioning quota and guarantee a paid-scale deployment.

### 14.6 What is the added cost when we scale?

At 730 hours, after the combined A1 free pool has been exhausted:
- **+1 OCPU** adds ~**₹697/month**, or **₹8,370/year**, compute only.
- **+1 GB RAM** adds ~**₹105/month**, or **₹1,255/year**, compute only.
- A proportional step of **+2 OCPU and +12 GB** adds ~**₹2,650/month**, or **₹31,805/year**, compute only.
- **+100 GB balanced paid boot/block** adds ~**₹406/month**, or **₹4,873/year**. Only true once the shared free 200 GB has already been consumed.
- **+100 GB paid backup objects** adds ~**₹244/month**, or **₹2,924/year**, provided stored object GB exceed their free allowance.

Additional A1 capacity is **not** the same as an equally reliable service: DB replicas and load balancers, network security/operations and multi-domain failover require separately designed paid resources and larger budgets. Extra 10 TB outbound or provider API calls may trigger materially different costs; this model assumes no such charges.

### 14.7 Production-grade/high-availability scenario is not priced by the free-node plan

A **single VM** (even 12/72) is a single point of failure and is not commercial HA. A serious paid deployment should independently estimate: at least two API failure domains, bounded reconstruction workers, PostgreSQL replication and verified failover, private network, a load balancer if used, cross-domain backup/restore, incident response and monitoring/on-call.

**For rough scale reference only**, doubling combined A1 use from 4/24 to 8/48 changes modeled A1 compute from ₹0 to ~₹5,156/month before volume, LB and operations costs. Two API VMs sharing one unreplicated database **are not HA**. Commercial HA price remains **UNPRICED/BLOCKED** until provider topology, RPO/RTO, support and live cost estimator are approved. Do not use the §14.4 budgeting figures as an uptime SLA quote.

### 14.8 Blockers that prevent conversion of forecasts to invoices

| ID | What is missing | Who must resolve |
|---|---|---|
| COST-01 | Actual eligible PAYG allowance and OCI Cost Analysis screenshots for Chicago | OCI account owner |
| COST-02 | Available A1 sizes and quota in Chicago | OCI account owner / provider |
| COST-03 | Measured per-child telemetry, location precision, 30/90-day retention, raw+index+WAL+backup storage | Android QA / backend |
| COST-04 | Measured concurrent parent requests, query p95 and C++ CPU/memory footprint | Backend load test |
| COST-05 | Real backup retention and stored Object Storage usage by tier | SRE/privacy owner |
| COST-06 | Whether single VM is acceptable for pilot; target uptime, RPO/RTO and HA topology/prices | Product + SRE |
| COST-07 | Which payable services exceed quotas: logging, DNS, egress, LB, dedicated DB, access proxies, support | OCI Cost Estimator/account |
| COST-08 | Real invoice currency, tax treatment, committed discounts and production operating region | Finance/OCI billing |
| COST-09 | Owner-approved monthly **hard spending cap**, alerts and action on overrun | Project owner |
| COST-10 | Selected Drive/Maps/Roads and real service request rates | Product/provider billing |

**Before production:** replicate the scenario in OCI Cost Estimator with region us-chicago-1, review tenancy allowance, verify taxes, and record a signed monthly budget envelope. Set compartment quotas and budget alerts; OCI budget alerts alone should not be assumed to hard-stop billing.

### Sources (verified 2026-10-26)

- Oracle India current rates and PAYG A1 allowances: https://www.oracle.com/in/cloud/price-list/
- Oracle Always Free storage, limits and outbound allowance: https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm
- Block Volume VPUs and lower-cost vs balanced tier: https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeelasticperformance.htm
- Oracle OCI Cost Estimator: https://www.oracle.com/cloud/costestimator.html

**Executive number:** On the selected A1 architecture, **5,000 hypothetical children** at 8/48 and 500 GB provisioned disk imply about **₹6,889/month (~₹82,671/year) priced-line hosting**, while **₹20,267/month (~₹2,43,205/year)** is an intentionally larger hosting **planning allocation** with reserves. These are illustrative, not evidence that this hardware tier can run 5,000 children, and omit commercial HA and staff.


### 14.9 Example: cumulative expenditure during a year of gradual scaling

An annual budget is **not always 12 times the biggest final-month VM**. If the selected plan moves through four levels, each for exactly **three months**, while object-storage and volume assumptions instantly change to the corresponding row:

| Quarter (3 months each) | Illustrative child scenario | Priced-line host cost per month | **Three-month incurred subtotal** | Reserved monthly allocation | **Three-month budget allocation** |
|---|---:|---:|---:|---:|---:|
| Q1 | 1,000 / PAYG 4/24 | ₹199 | ₹596 | ₹3,238 | ₹9,715 |
| Q2 | 2,500 / PAYG 6/36 | ₹3,232 | ₹9,695 | ₹9,878 | ₹29,634 |
| Q3 | 5,000 / PAYG 8/48 | ₹6,889 | ₹20,668 | ₹20,267 | ₹60,801 |
| Q4 | 10,000 / PAYG 12/72 | ₹14,683 | ₹44,050 | ₹42,620 | ₹1,27,860 |
| **Total first 12 months** | *Staged hypothetical growth* | — | **₹75,009** | — | **₹2,28,011** |

Values are calculated using the unrounded rate formulas and rounded for display; the displayed per-quarter rounded values may differ by ₹1 on summation. The budget allocation includes **unused reserves** and is not a predicted OCI invoice. A real year may have different growth timing, partially utilized machines, retained excess backups or overlapping old/new VM deployments during migration. Those materially change the cumulative spend.

**Important procurement point:** upgrading to a larger VM while the smaller VM remains online for the transition temporarily consumes the **sum** of both machines' OCPU-hours and memory GB-hours; the free PAYG benefit is a shared pool, **not per VM**.


### 14.10 Per-child hosting cost at 1,000 subscribed children

**Planning answer:** Assuming **1,000 paying child subscriptions** (not 1,000 separate families), a constant **PAYG A1 4 OCPU / 24 GB** total server allocation, **200 GB combined provisioned boot/database block volumes**, **30 GB Standard Object Storage backups**, and the published PAYG A1 recurring allowance applying to this OCI tenancy, **the modeled direct recurring hosting charge is about ₹0.20 per child per month**. The **safer hosting budget with discretionary reserves is about ₹3.24 per child per month**.

| Cost view for 1,000 child subscriptions | Monthly project total | Annual project total (12 months) | **Per child / month** | **Per child / year** |
|---|---:|---:|---:|---:|
| A1 compute after assumed PAYG free allowance | ₹0 | ₹0 | ₹0.00 | ₹0.00 |
| Extra boot/block volume beyond 200 GB included | ₹0 | ₹0 | ₹0.00 | ₹0.00 |
| 20 GB billable Object Storage backups | ~₹49 | ~₹585 | ~₹0.05 | ~₹0.58 |
| Modelled domain/DNS allowance (not Oracle invoice) | ₹150 | ₹1,800 | ₹0.15 | ₹1.80 |
| **Combined priced-line hosting estimate** | **~₹199** | **~₹2,385** | **~₹0.20** | **~₹2.39** |
| Additional 20% cost uncertainty margin | ~₹40 | ~₹477 | ~₹0.04 | ~₹0.48 |
| Additional discretionary hosting reserve | ₹3,000 | ₹36,000 | ₹3.00 | ₹36.00 |
| **Safer hosting budget allocation** | **~₹3,238** | **~₹38,862** | **~₹3.24** | **~₹38.86** |

**Calculation:** ~₹199 ÷ 1,000 = **~₹0.20/child/month**; ~₹3,238 ÷ 1,000 = **~₹3.24/child/month**. Annual figures are based on the underlying unrounded monthly rate model for a constant 12-month configuration; displayed line items/per-child totals are independently rounded and may differ by a few rupees/paise on summation.

**Important distinction:** The ₹3,000/month discretionary reserve and 20% uncertainty allowance are **budget reserves, not charges payable to Oracle**. If the official PAYG 3,000 OCPU-hour and 18,000 GB-hour allowances do **not** apply (or are consumed elsewhere in the tenancy), the same 4/24 VM consumes roughly **₹5,301/month of A1 compute alone**, increasing the project and per-child hosting estimate correspondingly. The normal model also assumes the free block-storage allocation and outbound data-transfer limits are not exceeded.

**Not included in either figure:** GST/taxes, Oracle paid monitoring or other chargeable services beyond budget reserves, Google Maps/Places/Roads, Play subscription service fees, employee/technical support costs, incident operations, legal/privacy/security work, managed PostgreSQL, paid load balancing, database replication/production-grade HA, and optional media/Drive expenses. Real costs can be much higher if these are required.

**No verified capacity claim:** The 1,000-child row is a commercial planning **scenario**. It does not prove that one 4/24 VM can reliably ingest and serve 1,000 children with the desired GPS collection and concurrent parent-map load. Confirm actual enrollment, observation frequency, data retention, query latency and OCI usage with load tests and the tenancy's Cost Analysis before relying on this per-child number for subscriptions or production launch.

**2026-10-26 PRICE UPDATE:** The product's NEW proposed customer prices are **₹50/month or ₹500/year per child seat**, described in [Subscription Plans, Hidden Charges and Play Rules](../../M7-commercial-integrations/01-commercial-plans-and-costing/SUBSCRIPTION_PLANS_PRICING_AND_RULES_2026.md). The ₹149/month examples in this financial hosting report remain **historical scenarios**, not official launch pricing. OCI hosting line items do not change automatically with consumer subscription price, but the illustrative Play fee and revenue calculations **must** be recalculated before launch.

## 15. Separate third-party API and subscription processing costs

**Excluded from all OCI hosting figures above:** fees for Google Play Billing subscriptions, paid Google Maps Places/Geocoding/Roads calls, optional SMS/identity vendor, Drive API over-quota behavior, and other provider costs. They are calculated separately in [Third-Party Services Cost Analysis (excluding Oracle)](../../M7-commercial-integrations/01-commercial-plans-and-costing/THIRD_PARTY_SERVICES_COST_ANALYSIS_2026.md). In the India ₹149/child/month, 1,000 paying-child illustrative case, the external-provider model gives approximately **₹22,350/month** (₹22.35/child/month), primarily the modeled 15% Play subscription service fee; **this is not part of Oracle's ₹199/month priced-line hosting model**. Add OCI + provider amounts only for a wider business operating-cost projection, taking care not to add discretionary cash reserves as actual invoices or duplicate domain costs.


### 15.1 Cross-document unit economics at exactly 1,000 paying child subscriptions

The standalone [third-party cost analysis §1.1](../../M7-commercial-integrations/01-commercial-plans-and-costing/THIRD_PARTY_SERVICES_COST_ANALYSIS_2026.md#11-per-child-combined-expense-at-1000-active-subscriptions-cross-document-comparison-only) provides this **informational** combined view. At the hypothetical **₹149/child/month** plan and 15% Play fee, with Indian Maps free-usage eligibility and the planned OCI A1 PAYG allowance:

| Cost basis | Per child per month | Total for 1,000 per month | Total for 1,000 per year |
|---|---:|---:|---:|
| Third-party service fees (primarily Play) | ₹22.35 | ₹22,350 | ₹2,68,200 |
| Direct hosting cost, **separate model** | ~₹0.20 | ~₹199 | ~₹2,385 |
| **Combined direct estimated cost** | **~₹22.55** | **~₹22,549** | **~₹2,70,585** |
| **Combined planned cash budget with hosting reserve** | **~₹25.59** | **~₹25,588** | **~₹3,07,062** |

**Revenue remaining per child before taxes, paid optional APIs, support, payroll, legal/security, refunds and HA costs:** approximately **₹126.45/month direct-cost basis**, or **₹123.41/month after allocating reserved hosting budget**. Do not classify either amount as net profit.

The combined view is **not** an OCI-only expense and does not alter the OCI-only model in §14. Rounding, free allowance eligibility, tax treatment and server load tests are still open.

## 16. Current subscription-price viability and mandatory DR budget correction (2026-10-26)

**Current public-price PROPOSAL is ₹50 per child/month or ₹500 per child/year. The ₹149/month tables in §8 are HISTORICAL commercial sensitivity only, NOT the recommended product price.** Billing fee scales down with subscription receipts; revenue scales down too. Do not reuse §8 historical profit/revenue rows as the new forecast. [Current price/fully loaded break-even analysis](../../M7-commercial-integrations/01-commercial-plans-and-costing/PRICE_BREAK_EVEN_STAFFING_AND_DELIVERY_CAPACITY.md).

At **1,000** fully paid child seats and using this report's existing **₹3,238.47/month budgeted OCI hosting including reserve**, the illustrative tax-INCLUSIVE (18% consumer GST example, 15% Play fee calculated on net of GST) revenue remaining after Play fees + hosting is approximately **₹32.78 per child per month** at ₹50 monthly, or **₹321.31 per child per year** at ₹500 annually. These are NOT full profits: they exclude paid guardian/SOS SMS, support, developer salaries, real production HA, higher Maps usage, churn, acquisition, refunds and legal counsel. 18% is a hypothetical tax example pending accountant confirmation.

**Single-VM availability correction:** one OCI A1 VM can be reclaimed/lose disk/network; API, PostgreSQL and C++ workers share fate. [Recovery plan](OCI_CHICAGO_RECOVERY_AND_PILOT_READINESS.md) defines *unverified* dev RPO 24h/RTO 48h, real-data pilot proposed RPO≤4h/RTO≤12h, production target ≤1h/≤4h requiring separate funded resilience and rehearsed restore. **None of those are guaranteed or included in historic ₹0.20 per-child/month direct hosting**. FCM from same VM cannot guarantee SOS; [independent delivery](../../M4-usage-health-sos/01-usage-health-and-sos/SOS_ESCALATION_AND_INDEPENDENT_DELIVERY_DESIGN.md) remains blocked by provider/fallback funding.

**Legal transfer stop:** Chicago is a TECHNICAL PLANNING REGION, NOT authorization to export Indian children's precise GPS. [India DPDP child-data and US hosting gate](../../M0-foundation-and-approvals/03-legal-and-privacy/INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md) requires legal entity, section 9/16 review, verifiable guardian authority, data categories and retention approval before real collection. No VM created, quota or paid HA cost verified.

## 17. Historical comparison only — India OCI region is the new preferred hosting direction

**2026-10-26 supersession:** User prefers hosting in India if it reduces data-transfer complexity. New deployment target is **Mumbai ap-mumbai-1**, alternate **Hyderabad ap-hyderabad-1**, subject to OCI home region, A1 quota and actual cost. This **Chicago cost model is historical**; its ₹0.20/child direct, ₹3.24/child reserved, and annual tables must not be advertised as validated Indian-region invoices. One-VM failure and SRE/SOS concerns remain regardless of geography. The new authoritative location/owner gate is [India OCI Region and M0 Decision](../../M0-foundation-and-approvals/03-legal-and-privacy/INDIA_REGION_AND_M0_OWNER_DECISION_GATE.md).

## 18. Conditional no-VPS-media-file transport cost sensitivity (2026-10-26)

As separate **research only** under [MA-MEDIA-ADR-001](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md), investigate encrypted WebRTC P2P-first plus optional coturn/TURN fallback, without storing media files on the VPS; optionally store encrypted recordings locally on Madalasa. This historical Chicago forecast **excluded media traffic** and has been superseded by OCI Mumbai as preferred, subject to actual tenancy and new Mumbai estimate.

Illustrative conditional budgets only: existing reserved hosting **₹1,680/month for 500 children** or **₹3,238/month for 1,000** plus an assumed **₹1,200/month incremental TURN capacity**, and no incremental egress bill if actual total OCI outbound remains inside applicable shared allowance, produce **₹2,880/month for 500 (~₹5.76/child/month; ₹69.12/year)** and **₹4,438/month for 1,000 (~₹4.44/child/month; ~₹53.26/year)**. These are *partial planning allocations*, not Mumbai quotes or proven relay capacity. They exclude egress overage, concurrency-driven upgrade, GST, traffic beyond moderate usage, supported legal/Play safeguards, security audits, support, incident recovery and HA. Profile bitrate, minutes, P2P success rate, peak relayed streams, relay ingress+egress/CPU, abuse and real OCI region billing before proposing a price or service entitlement.

## 2026-10-27 projected media-event metadata and administrator console budget scope

FR-050/051 propose metadata-only media_activity summary, append events, audit of administrator reads, parent/admin paginated reports and web admin console **without VPS media files**. Existing 500/1000-child hosting allocations and hypothetical TURN budgets were not load-tested for new event writes, indexed searches, admin access-audit DB growth, long retention/backups, DB IOPS, admin web TLS/MFA, security review or on-call incidents. Separate monthly sizing and regional OCI Mumbai evidence are REQUIRED; do not represent additional database/audit costs as zero simply because there are no media binaries. No real release before India legal/Google Play gates and measured cost sensitivity. Source [Media Activity Audit ADR](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_ACTIVITY_AUDIT_LOGGING_AND_REPORTING_2026.md).

## 2026-10-27 ingestion capacity addendum — 48h mobile queue, PostgreSQL inbox, worker bulk INSERT

Accepted design [MA-INGEST-ADR-004](../../M2-location-collection/01-location-collection-and-ingestion/POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md) supersedes assumptions that every accepted GPS batch directly writes only final raw points. The initial architecture has encrypted device-local buffer up to 48h, eligible 1–2min JSON upload target, PostgreSQL **durable inbox stored once per HTTP batch**, C++ leased bulk workers and partitioned PostGIS raw table/outbox. Thus **new temporary inbox bytes, WAL write amplification, vacuum/bloat, backup/restore, queue backlog and worker load** must be included in OCI Mumbai/Chicago financial sizing. The old 300 observations/child/day and 30 fixes/upload are explicitly *pricing assumptions*, not enforceable daily point cap or current movement sampling objective. More frequent moving-vehicle fixes, multiple phone/watch sources, bounded Live Mode and simultaneous 48h reconnect can exceed them materially.

Do not assume inbox uses fewer system resources than direct bulk. Compare **(A) Postgres inbox+bulk C++ worker (accepted as default)** with **(B) direct prepared bulk GPS+dedup+outbox COMMIT (lower-write alternative)** on the same OCI A1/Postgres resources and representative 1k/10k/100k synthetic load: ACK p95, throughput, WAL MB/s, DB disk IOPS, RAM/CPU, internal backlog, parent map read quality, cleanup cost and 48h replay. No Redis VM is necessary in stage one; if cache introduced it is not authoritative GPS durability. Small 2/12 or 4/24 Ampere budget isn't a guarantee until measured. Location storage region, India minor processing and cross-border hosting remain independent legal NO-GO items.

### 2026-10-28 extra concurrent-viewer 100-day reserve warning

The add-on is now **₹100 once for 100 calendar days** (+1 concurrent premium viewer for one paid child, with +30 minutes pooled A/V total), **not** monthly revenue and **not cancelled on base prepaid lapse**. Existing 1,000-child ₹3,238/month planned OCI allocation and media testing reserve omit real TURN relay egress/CPU, high peak concurrency, safety/compliance work. OCI first 10TB/month outbound for tenancy is not extra per add-on. Worst-case continuous 1Mbps per second viewer for 100 days reaches ~1.08TB/add-on, so rate-limit/cap actual stream minutes, restrict media features until approved, re-run load tests, and do NOT claim ₹100 covers 100 days of unmetered video. 100-day add-on remains dormant if main prepaid expired and resumes with verified renewal before independent expiry. Link: https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/CHILD_SPECIFIC_GOOGLE_PARENT_SHARING_AND_CONCURRENT_SCREEN_ADDONS_2026.md.
