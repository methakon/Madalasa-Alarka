# Separate Deployment, Google Play, and Operations Readiness Plan

**Created:** 2026-10-28. **Status:** PLANNING ONLY. **NO deployment, upload, signup or Google Play action has been performed.** This document is deliberately SEPARATE from [the 262-task LOCAL DEVELOPMENT ROADMAP](LOCAL_AGENT_DEVELOPMENT_ROADMAP_2026-10-28.md). Local coding agents are prohibited from independently completing release/financial/identity/legal steps.

## 0. Owner-reported Play account status and privacy

The owner reports an **active Google Play Console Personal developer account**. This establishes only that an account exists, **not** its creation date, identity/device verification, profile eligibility, merchant profile, product availability, closed-test result, production access or two-app Play eligibility. The exact developer Account ID was supplied privately and is deliberately **not copied into the public GitHub repo**. Keep any required identifier in an owner-controlled password manager or private release config, never public docs/CI logs.

**Play Console action requires an actual user/authorized operator**. No agent may attest to an app approval, closed test or store publication without a Console evidence reference.

## 1. Separate release tracks and dependency order

| Release stage | Required predecessors | Owner of approval | Evidence and STOP condition |
|---|---|---|---|
| D-00 Local handoff | Local agent L19-008 and relevant task evidence, build SHA, SBOM | Engineering lead | If LOCAL_BLOCKED, no real child pilot |
| D-01 Identity and business/legal controller | Verified publisher, personal vs future organization structure, verified developer email | Publisher + legal | No controller/age/audience/terms means NO RELEASE |
| D-02 India DPIA and data-flow review | Exact feature binary, retention/rights and safeguards, India DPDP commencement/consent/legal authority | India legal/counsel | No real child location/usage/media until approved |
| D-03 Hosting region, security and DPA decision | India-first vs historic Chicago OCI plan reconciled, cost/processor approval | Owner + counsel + SRE | No OCI provisioning before region approval |
| D-04 Target/release toolchain and signed binaries | Local Android/C++ tests + correct Play package names | Android engineer + owner | Missing verified AAB or target SDK => STOP |
| D-05 Play developer profile verification | Real account creation-date, real-device task, identity/profile status, payment profile | Account owner | Cannot infer from “active account” |
| D-06 App listing and disclosure | Privacy policy / terms / deletion / Data Safety accurate from actual binary and SDKs | Product + counsel | False declarations => STOP |
| D-07 Play policy permissions (each app) | Foreground location/monitoring/persistent notices, permissions videos, app access reviewer | Product + Android + Play | Unsupported child monitoring features OFF |
| D-08 Google Play internal test (per app) | AAB, tester access, signing, privacy policy and Play app setup | Console owner | Internal success is not production access |
| D-09 Closed test / production access (if applicable) | Account created after Nov 13 2023? Per-app eligibility check | Console owner | 12 continuously opted-in testers for 14 days if rule applies; production access must be granted |
| D-10 Prepaid SKU/100day addon sandbox | Real Play product config, 1-to-N child capacity, purchase token and refund tests | Owner + billing engineer | No live price claims until checkout verified |
| D-11 Staging environment, backups and recovery | Approved region/DPAs, measured capacity, vulnerabilities resolved | SRE + privacy | Restore, deletion, TLS, rate limits must prove |
| D-12 Controlled pilot with lawful accounts | All legal/Play required approvals and data rights, monitored support | Owner + privacy | Synthetic pilot first; real child pilot only after clearance |
| D-13 Production rollout | Explicit human signoff, Play Console eligible, staged test acceptance, vendor readiness | Owner + Play + SRE | May choose NO-GO despite green local tests |
| D-14 Postlaunch monitoring | Production allowed, incident routing, support and deletion functioning | SRE + support | Pause/rollback if safety, security or policy event |

## 2. Account and Play Console requirements — owner checklist

- Check **creation date** of the Personal developer account in Play Console. If after **November 13, 2023**, Google's published condition is **at least 12 opted-in closed testers continuously for 14 days** before applying for production access. Tester participation must be genuine and compliant; apply through Console. For both Madalasa and Alarka, confirm which apps/tracks require production-access approval.
- Check **device verification** task: newer personal accounts may need Play Console mobile app and a real non-rooted Android 10+ phone. Verify only from owner's console; keep evidence privately.
- Check identity verification, legal/public developer name, contact email and phone, merchant/payment profile and verified public support contacts. Personal and organization account categories are not interchangeable for some business/legal circumstances.
- Use **Play App Signing** and securely held separate upload key. Never put keystore, service-account JSON, Play tokens, client secrets or personal account ID in GitHub, Figma or public build logs.
- Confirm app IDs (distinct parent/child packages), target API **36** required for ordinary new apps/updates from Aug 31, 2026, current Play target policy at actual submission time and 16KB native page-size requirement for every native/SDK library used.
- Google Play **Families** and monitoring policies: confirm target audience, visible monitoring disclosure, unique identifying icon, persistent notification, honest privacy and correct `isMonitoringTool=child_monitoring` metadata across relevant tracks. Marketing must not promise covert recording or spousal monitoring; a parent's permission does not bypass Android FGS/camera/mic OS rules.
- Play testing must include actual app reviewer instructions, test accounts/synthetic child pairing and permission walkthrough; do not expose live parent data to reviewers.
- Do not treat a Google account, Family Link family group or the owner's Gmail access as a verified legal parent-child relationship. External parental attestation remains unresolved and feature must remain OFF absent a supported allowed method.

## 3. Legal and controller gate (hard stop for real child data)

- Verify country/ages: under-18 child data, guardian legal authority, tracking/behavior monitoring restrictions and applicable DPDP exemptions **feature by feature**, including phased commencement. Do NOT rely on a general safety exemption for every consumer feature.
- Decide and sign actual retention for raw GPS, derived trips, app usage, inbox/outbox, audits, media session metadata, backups and tax evidence. A six-hour free **visibility** rule is not approval to keep raw precise GPS forever until account deletion.
- Verify right to erase/export, account deletion web/in-app workflow, simultaneous guardians/custody disputes, trial anti-abuse minimization, role-revocation and restoration of backup with erasure tombstones.
- Approve processor inventory and agreements: OCI, Google Play/Billing, maps, FCM, email provider, error telemetry, payment processor if any. Verify cross-border handling and local Indian legal obligations.
- Update privacy policy, public Terms, Data Safety and app notices from final binaries, permissions, SDKs, network traffic and backend data mapping. DRAFT file presence ≠ published legal page.
- Riskier media (audio/video/photo/screenshots/files, child app behavior monitoring/managed-device blocking) must remain default OFF until independent Android, India legal, Play and child transparency gates; a paid offer must not promise unavailable capture.

## 4. Hosting choice is intentionally UNDECIDED

Existing docs conflict: older OCI Chicago cost/topology planning and later India-first Mumbai-preferred milestone/DPDP guidance. **Do not deploy to Chicago or Mumbai solely because one document says so.** Record approved tenancy region, backup region, data localization/cross-border basis, processor agreement, RTO/RPO and costs in an ADR signed by owner/legal.

After decision only, provision:
1. Separate staging and production tenancy/environment/subnet/service identities, least privilege and audited IAM.
2. VPC/VCN firewall/HTTPS ingress, rate limits/WAF as necessary, no public PostgreSQL, ephemeral admin access and hardened C++ Drogon service.
3. Managed secrets, encryption at rest/in transit, restricted GPS partitions, row-level security, WAL/PITR, backup encryption and restore tombstone checks.
4. Durable GPS inbox/outbox worker lease, queue saturation monitor, FCM and provider retries, app attestation and logging with no precise child-location traces.
5. Blue-green/canary rollback plan, database migration backward compatibility and irreversible erasure controls; DB rollback must not resurrect children.
6. Cost guardrail for 1k/10k/100k children, mobile GPS cadence, map bills, 100-day viewer extra relay egress/TURN CPU, 10TB OCI tenancy shared free egress where relevant, ongoing support and incident costs.
7. Alert/synthetic monitors for 202 ACK→commit, expired token and viewer slot races, Play purchase verification, quota mismatch, GPS stale quality, SOS delivery, erasure deadlines, permission policy and admin audit health.

## 5. Paid product approval and test-catalog evidence

- Public target ₹99/month, ₹999/year, founding first **1,008 distinct paying families** ₹50/month or ₹500/year for selected eligible paid children including children added later. Prices are **per selected paid child**, not per parent. One paid child can share coverage only with verified, child-specifically authorized co-parents; other siblings hidden.
- **Manual prepaid only**; no auto-renewing subscriptions. Check feasibility of independently purchasing additional child-seat capacity in Play Console. Do not substitute auto-renew subscription add-ons; those currently support auto-renewing bases only.
- ₹100 one-time extra concurrent premium viewer, exact **100 calendar days** independent of base expiry, **30 combined A/V minutes** per purchased extra slot shared at child-level, not 30 audio plus 30 video. Base lapse pauses premium use, retains paid addon and unused time until original day-100 expiry.
- Test purchase tokens against verified Play Developer API, acknowledgement, refunds, chargebacks, real-time developer notifications, reconnect, duplicate receipts, expired monthly/annual top-ups, token theft prevention and cross-family transfer.
- Before sale show actual Play-confirmed amount/currency/tax, validity start/end and dormant-base explanation. Do not display a functional checkout for a feature Android/Play forbids.
- Reconcile invoice/tax/customer support rights with actual India accountant/legal guidance; without completed tax/payout arrangements label prices only as proposal.

## 6. Android store app packaging / media permission evidence

Two separate app binaries need independently reviewed manifests, icons, descriptions, Data Safety forms, target audience, account deletion info and privacy disclosures. Create videos showing approved monitoring notice, runtime permission choices and foreground service behavior with genuine test devices. Background GPS may be constrained by system/Play restrictions; don't promise always-live GPS. Microphone/camera/MediaProjection background execution is OS-gated, and remote capture without required visible user action is not a workaround target.

For app approval: document all declared permissions and libraries in submitted AAB, Google Play review status, 16KB page size checks for NDK if present, screenshot-to-function truth and evidence of persistent monitoring notification across reboots/OEM cases.

## 7. Test tracks, rollout, rollback and observability

- Build unsigned debug and Play-signed release AABs **separately**; use app signing with protected upload key and record fingerprints out of public repo. Debug AAB presence is not equivalent to a Play-ready AAB.
- Internal test using synthetic accounts and Play sandbox; collect crash/ANR, battery, location permission and mapping accuracy evidence. Evaluate any personal-account closed testing threshold for **each app** and actual console eligibility.
- Closed test real user participation/feedback under applicable Google rules; never enroll real children before lawful data-processing approval.
- Set rollout thresholds with owner and SRE: anonymous crash-free sessions, GPS delivery latency/quality, device battery usage, SOS notification failure, consumer support response and payment error limits. No invented universal numeric SLO.
- Staged deployment can be paused or rolled back via version and feature flag; app version rollback may not revert irreversible DB changes, so migrations use expand/contract. Implement refund/outage/revocation handling.
- Incident response needs 24/7 contacts if promised, data breach assessment, device revocation, Play listing takedown procedure, parent communications and account deletion/backup restoration.
- After full approval, record actual rollout in private signed RELEASE_EVIDENCE.md with Console screenshots, release IDs, owner names, dates, manifests, policy approvals and signed checklist. **This roadmap contains no deployment evidence.**

## 8. Separate deployment evidence ledger (template only)

```text
Gate ID: D-00..D-14
State: NOT_STARTED / BLOCKED / APPROVED / FAILED / COMPLETE
Git SHA and signed AAB hash:
Play Console package / track / version:
Developer account creation-date eligibility verified by owner: YES/NO
Independent counsel/privacy approval:
Actual processor / region contracts:
Testers count / 14 continuous days if applicable:
Real Android models and OS API:
Review/approval links (private):
Recorded UTC date:
Owner signature:
Rollback command run and observed result:
```

No coding agent may prefill `COMPLETE` without independently verified evidence.

## 9. Current official rules cited

- [Google Play Personal developer accounts: app testing](https://support.google.com/googleplay/android-developer/answer/14151465) (created after Nov 13, 2023: 12 testers / 14 continuous days).
- [New personal account real Android device verification](https://support.google.com/googleplay/android-developer/answer/14316361).
- [Developer identity verification](https://support.google.com/googleplay/android-developer/answer/10841920) and [developer account type](https://support.google.com/googleplay/android-developer/answer/13634885).
- [Target API levels in Aug 2026](https://developer.android.com/google/play/requirements/target-sdk) (API 36 for ordinary phone apps).
- [Google Play monitoring application rules](https://support.google.com/googleplay/android-developer/answer/9888380) and [isMonitoringTool flag](https://support.google.com/googleplay/android-developer/answer/12955211).
- [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756), [16KB page sizes](https://developer.android.com/guide/practices/page-sizes), [prepaid](https://developer.android.com/google/play/billing/subscriptions), [auto-renew-only subscription add-ons](https://developer.android.com/google/play/billing/subscription-with-addons).
- [DPDP Act 2023](https://www.meity.gov.in/static/uploads/2024/02/Digital-Personal-Data-Protection-Act-2023.pdf) and [2025 phased Rule commencement Gazette](https://www.meity.gov.in/static/uploads/2025/11/53450e6e5dc0bfa85ebd78686cadad39.pdf).

**END: no server/domain/Play change authorized from this document alone.**

## Owner update (2026-10-28): hosting and bandwidth decisions reserved for deployment

**DEFERRED_TO_DEPLOYMENT, NOT A CODING BLOCKER:** choosing between OCI Chicago, OCI Mumbai/other India locations, final data transfer pricing, provider bandwidth/TURN architecture, quotas and cash margin estimates. Local engineering is environment-agnostic, uses local PostgreSQL/PostGIS, fake Play/FCM and synthetic GPS/AV benchmark loads and records real CPU/bytes/latencies only. Final region/cloud costs, transfer legality, processor inventory/agreements, domains, TLS, production backups and actual rollout topology are owner/legal/SRE deployment actions. **Child-data consent remains mandatory before any actual child data**, regardless of where a later server is hosted. No live OCI provisioning required in development.

**Owner also removed Google Family Link parent-role API dependency**, replaced by own exact-child invite/accept/approval and separately lawful authority/consent verification; see [V2 ADR](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/ADR_2026_10_28_BLEND_FAMILY_V2_AND_NO_FAMILY_LINK_DEPENDENCY.md). Google login alone does not prove parenthood.
