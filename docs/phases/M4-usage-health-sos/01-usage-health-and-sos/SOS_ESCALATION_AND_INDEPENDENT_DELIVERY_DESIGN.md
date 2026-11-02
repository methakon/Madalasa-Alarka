# Madalasa–Alarka — SOS Delivery, Escalation and Independent Fallback Contract

> **Document control:** M4 / 01-usage-health-and-sos · Proposed owner: Engineering lead (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

> **Current app names:** **Madalasa** (guardian/parent), **Alarka** (child companion). GitHub repository [Madalasa-Alarka](https://github.com/methakon/Madalasa-Alarka), renamed 2026-10-26. [Source story and naming contract](../../M0-foundation-and-approvals/02-market-and-feasibility/BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

**Status:** DESIGN ONLY; **SOS emergency-grade claim is blocked** until tested.  
**Date:** 2026-10-26 | Related: SRS FR-044/049, [Command/SOS protocol](COMMAND_SOS_USAGE_QUEUE_CONTRACT.md), [Hosting resilience](../../M8-operational-readiness/01-cloud-infrastructure/OCI_CHICAGO_RECOVERY_AND_PILOT_READINESS.md), [Third-party cost](../../M7-commercial-integrations/01-commercial-plans-and-costing/THIRD_PARTY_SERVICES_COST_ANALYSIS_2026.md).

## 1. Safety and truthfulness invariant

A child SOS press is not a guaranteed rescue call. It is a device-initiated **best-effort guardian notification workflow**, with explicitly differentiated durable acceptance, provider submission, device notification display (generally unobservable to server), **human guardian acknowledgement** and eventual escalation. FCM returning a message ID proves provider acceptance only; **not** guardian receipt, attention, child safety or emergency dispatch. An offline phone can queue but cannot claim successful transmission.

A single OCI VM hosting API/DB/notification worker can fail simultaneously; another delivery provider alone does not make it resilient if there is no independent execution/control plane able to trigger it. For any public promise beyond best-effort, provision/rehearse a separately operational fallback path, otherwise use careful copy and consider removing “emergency SOS” branding.

## 2. Proposed minimal journey and state machine

1. Child explicitly uses identifiable SOS action (notification shortcut/widget/visible Activity). Capture event UUID, device ID, UTC event time and last known GPS *only if permission/purpose allows*. Save encrypted event in local queue atomically BEFORE networking; show **SEND_PENDING**.
2. Device attempts HTTPS transmission (short bounded backoff); if offline show **OFFLINE_QUEUED — guardians not notified** and provide a local suggestion to call a trusted adult/emergency service via normal dialler, where available. Avoid app pretending to dial/send on child's behalf.
3. API validates enrolled device and legal/feature scope. Commit SOS event + authorized notification outbox + idempotency dedup in one PostgreSQL transaction, then reply **ACCEPTED_BY_SERVER**; do not block SOS on new GPS fix.
4. Priority queue outbox fan-out to explicitly granted guardians with consented verified contact endpoints. Generate FCM notification (minimal text; **do not embed precise location in push**). Mark **PROVIDER_ACCEPTED** when FCM API accepts, not **GUARDIAN_RECEIVED**.
5. Parent app receives FCM; on opening authenticated event it sends **GUARDIAN_ACK** signed/authorized. Ack event includes actor, event and timestamp; only real parent action confirms attention.
6. At bounded delay with no verified guardian ACK and if opt-in SMS fallback has been independently deployed, use verified telecom provider for limited direct guardian messages. If provider says submitted/delivered, annotate accurately; carrier delivery callback is **not** guardian acknowledgement.
7. If no verified guardian acknowledgement after escalation windows, show **ESCALATED_UNACKNOWLEDGED** and continue bounded policy and local guidance. Expire after owner-approved TTL. Never auto-call national emergency numbers via silent app-to-network access.
8. Repeated SOS presses with distinct UUID should be reviewed for legitimate escalation; idempotently dedupe retries of same UUID without suppressing separate distress events. SOS bypasses normal quiet hours; still subject to device OS notification/DND limits.

## 3. Candidate times (not SLA or real delivery guarantee)

| Stage | Initial engineering candidate | Observable evidence / fallback |
|---|---|---|
| Device retry after offline/timeout | 0, 5, 15, 30, 60 seconds with cap/jitter | Local event still PENDING; reconnect WorkManager/foreground-eligible action |
| HTTP durability | Server commits SOS + outbox before 202 | DB receipt with stable event UUID |
| FCM worker dispatch | Aim <15 seconds at healthy server | Provider ack, retry and queue lag |
| Guardian acknowledgement check | At 60 seconds after server acceptance | Guardian ACK or UNACKNOWLEDGED |
| SMS escalation if authorized/available | Proposed after ~60–90 seconds no guardian ACK | Provider accepted/delivery status, not proof human attention |
| Repeat/failover SMS | One different designated guardian or bounded retry after ~180 seconds | Per-family budget and anti-abuse; no blind SMS loops |
| Closure/timeout | Parent-configurable; candidate 15 minutes for acknowledgement window | Event remains in secure history under approved retention |

Clock starts when event is **accepted by server**, not when pressed offline. If server unreachable, no independent cloud fallback exists unless deliberately deployed. Timings require measurement across devices, roaming, DND, bad connectivity and provider outages.

## 4. Independent fallback options and ordering

| Option | Independence | Operating costs | Decision |
|---|---|---|---|
| FCM from same OCI VM | No (server loss prevents new dispatch) | FCM no-charge, OCI costs existing | Primary for limited prototype |
| SMS from same OCI worker after no ACK | Only independent *delivery carrier*, **not backend control plane** | Per SMS/template/route and GST; vendor not selected | **Pilot optional, not yet funded** |
| Separate reliable outbox/queue+worker in another failure domain (can invoke SMS provider) | Independent of primary VM when **event was durably mirrored BEFORE primary failure** | Paid backup worker/queue, extra network, provider SMS and ops | Required design path for any resilience promise |
| Child device directly launches SMS composer/dialler to a trusted contact | Can work if mobile signal/SIM and user action available, even when backend down | Child carrier charges, consent/OS restrictions; no silent sending | Child-visible **manual fallback** UX research |
| Official emergency services | Neither push nor SMS is equivalent | Outside application; local device emergency dialler behavior | Never imply dispatch/guaranteed rescue |

If primary API goes down before receiving the SOS event, a separate server-side worker cannot detect an event still only on the child device. A more independent fallback needs a separate preconfigured HTTPS endpoint or explicit user-initiated native phone/SMS flow, with consent, costs and threat model. No endpoint is selected or operational.

## 5. Privacy and guardian rules

- Send only to people with active **RECEIVE_SOS** child scope and verified chosen contact channel; revoke must remove cached recipients, queued deliveries and pickup viewers after revocation. The family owner approves trusted SOS recipients. Do not send coordinates to unverified phone numbers.
- No app usage history, child identity document, raw location or detailed school name in push/SMS; send event code/time and a link to securely authenticated app where necessary.
- India DPDP child-purpose and guardian-authority review applies. **SOS fallback is not a blanket permission for tracking/child profiling.** See [India DPDP Gate](../../M0-foundation-and-approvals/03-legal-and-privacy/INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md).
- Save provider delivery receipts, event timestamps and guardian ack using data minimization, incident access limits and legal-approved retention; never use client self-ACK as guardian read receipt.
- Emergency medical/helpdesk staff are **not** automatically furnished: no staff or dispatch service selected.

## 6. SMS/voice cost sensitivity — hypothetical, no provider quote

If N active child seats, SOS events per child per month e, messages per escalated event m, escalation fraction f and delivered/billed SMS unit price p:

monthly SMS cost = N × e × f × m × p; add operator platform minimum, sender registration/template/route charges, carrier tax, callbacks, OTP and surge/abuse protections.

**Example only at 1,000 children:** If 10 total SOS incidents/month, half need escalation, 2 SMS per escalated incident and a **hypothetical ₹2/SMS**, that is **₹20/month** SMS usage; at **₹5/SMS** it is **₹50/month**. No actual SMS vendor, delivery price, DLT registration, template, sender ID, phone verification or international route has been approved. A high-activity incident or 10x retries can increase usage. Reserve must be priced using a provider quote and empirical event rates **before public SOS**.

Independent failover VM/queue/API, monitoring, on-call and compliance can cost **much more than messages** and are **not** in the ₹0.20/child hosting or ₹38.86/child/year reserve model. FCM without operational independence is not a guaranteed safety service.

## 7. Acceptance and failure tests (FR-044 / T-FR-044)

| ID | Fault injection | Must pass |
|---|---|---|
| SOS-01 | Device offline when SOS pressed | Encrypted local queued indicator; no false guardian notified |
| SOS-02 | HTTP response lost after durable commit | Retry UUID dedup, one fanout operation |
| SOS-03 | FCM accepted, target phone offline/DND | Provider accepted != guardian ack; escalation operates if enabled |
| SOS-04 | One guardian revoked during dispatch | No data delivered to revoked guardian beyond provider in-flight limitations; cancel/re-check pending sends |
| SOS-05 | Two guardians, one acknowledges | Track exact actor ACK, stop further unnecessary escalation |
| SOS-06 | SMS provider down/cost quota exceeded | Explicit fallback failed; no fabricated delivery, incident alert |
| SOS-07 | Primary OCI VM destroyed | Independent delivery test or **NO emergency-grade availability claim** |
| SOS-08 | Guardian login token stolen/expired | Unauthorized acknowledgement rejected |
| SOS-09 | Abuse bursts/duplicate and repeated presses | Per-event dedup, bounded billing and legitimate new-event visibility |
| SOS-10 | Revoked permission/no fresh GPS | SOS can still be queued with UNKNOWN location and safe purpose |
| SOS-11 | SMS carrier submitted but not delivered | Honest status, further escalation only within cap |
| SOS-12 | Restoration from database backup | No missed notification re-sent as a new emergency without event version/dedupe policy |

## 8. Blockers and release decision

| Blocker | Owner input/test required | Status |
|---|---|---|
| **SOS-B01** | Decide whether SOS is marketed as **best-effort check-in** or resilient emergency service | **OWNER OPEN** |
| **SOS-B02** | Select verified guardian contact methods, consent and revocation/relationship rules | **OWNER + LEGAL OPEN** |
| **SOS-B03** | Select SMS provider, India DLT/templates/fees and budget/caps; test actual delivery | **PROVIDER UNSELECTED** |
| **SOS-B04** | Provision separately recoverable queue/control path if making higher-availability claims | **NOT IMPLEMENTED** |
| **SOS-B05** | Define target ACK/escalation windows and acceptable fail rate from field testing | **NOT MEASURED** |
| **SOS-B06** | Staff on-call, monitoring and escalation response; emergency services statement | **UNFUNDED** |
| **SOS-B07** | Complete India child-purpose counsel review and notices for SOS recipients | **LEGAL OPEN** |

**Conservative MVP decision until B01–B07 resolved:** implement a **non-emergency best-effort child-initiated check-in** with honest statuses and manual call fallback; **do not ship or advertise a guaranteed “Emergency SOS” capability**. Prototype high-priority SOS with synthetic events only.
