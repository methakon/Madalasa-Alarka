# Incident and Breach Response Procedure

> **Document control:** M8 / 02-operations-and-support · Proposed owner: SRE + incident lead (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

**Document:** MA-IR-001 · **Updated:** 2026-10-30 · **State:** DOCUMENTED_REVIEW_PENDING, NOT EXERCISED, CONTACTS AND LEGAL SIGN-OFF PENDING. Publisher/controller for planning is the owner-declared individual **SWARNA SEKHAR DHAR**, India; Google Payments identity verification is pending. This does not appoint the technical, legal or incident-response roles below.
**Scope:** Android Alarka/Madalasa, connected Wear OS devices, future C++20 Drogon API, PostgreSQL/PostGIS, temporary GPS inbox, encrypted local queues, guardian/child access, admin console, third-party APIs, OCI, GitHub/CI, Play Console and personnel.  
**Companion:** [Security Policy](../../../../SECURITY.md), [Threat Model](../../M1-secure-platform-foundation/03-security-and-permissions/THREAT_MODEL_STRIDE.md), [Runbooks](OPERATIONS_RUNBOOKS.md), [Data Retention](../../M0-foundation-and-approvals/03-legal-and-privacy/DATA_RETENTION_SCHEDULE.md), [DPIA](../../M0-foundation-and-approvals/03-legal-and-privacy/DPIA.md).

**Deployment reality:** No production backend or child Android app has been verified in the repository. This is a *planned procedure*, not evidence of an active 24×7 incident team. No real child location, usage or media data may be introduced until the open release gates close.

## 1. Prepare before real-data onboarding

Preparation can proceed while identity verification is pending: run a synthetic tabletop for forged guardian authority, cross-child data exposure, compromised upload credential, unsafe screen capture and missing deletion suppression after restore. Record T0, incident lead, containment decision, minimal evidence inventory, statutory/contractual applicability decision and recovery validation. No actual regulator notification, Console change, credential rotation or real-child evidence collection is authorized by this preparation. Keep operational clock decisions tied to the current [India legal review](../../M0-foundation-and-approvals/03-legal-and-privacy/INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md), not the payments verification outcome. **Exercise status: NOT_EXECUTED.**

| Role | Required assignment before pilot | Responsibility |
|---|---|---|
| Incident Commander + backup | [ASSIGN] | Severity, technical decisions, evidence chronology |
| Security/engineering lead | [ASSIGN] | Incident containment and technical recovery |
| India legal/privacy lead | [ASSIGN] | Applicable deadlines, CERT-In and future DPDP review, affected-person safety |
| Communications/grievance lead | [ASSIGN] | Accurate guardian messaging, child-safety escalation |
| Scribe/evidence custodian | [ASSIGN] | UTC awareness timestamp, evidence hashes, immutable incident trail |
| OCI/Google/Play contact owners | [ASSIGN] | Vendor and release coordination |

Owner must verify reachable emergency contact methods in **private infrastructure**; never put personal staff numbers, children or secrets in public GitHub. Protect a case-specific incident channel and timeline with least privilege. Verify privileged console read audits, logging in India where required, synthetic tabletop exercises and backup drills.

## 2. Severity and initial clocks

| Severity | Examples | Suggested internal action |
|---|---|---|
| SEV-1 Critical | Verified cross-family child-data leak, active precise GPS exfiltration, admin abuse, signing key compromise, SOS safety false-positive or false delivery | Immediately page owner/security/legal; contain first; watch reporting clock |
| SEV-2 High | Probable active exploit, authenticated-session theft, localized encryption/security failure | Urgent investigation and guarded containment |
| SEV-3 Medium | Reproducible vulnerability with no evidence of child data exposure | Track security issue privately and remediate |
| SEV-4 Low | Suspicious event with little verified impact | Monitor, document and re-evaluate |

Set **T0** to earliest documented awareness that triggers the relevant legal rule, not time of later formal classification. Record both **UTC and IST**, source, affected system, whether children could be physically endangered, access tokens and real-data exposure evidence. Preserve evidence without over-collecting child coordinates.

## 3. External reporting decision table — enforce dates by applicable law

| Authority / audience | Applicable clock | How to act |
|---|---|---|
| **CERT-In Directions dated 28 April 2022** | **Report covered incidents within 6 hours of noticing or being brought to notice**, subject to Annexure I and official FAQs | India counsel/security determine reportability immediately; partial information may be reported within clock and updated later; designate and maintain contact |
| **CERT-In ICT security logs** | Covered entities retain secured ICT logs for rolling **180 days within Indian jurisdiction** | Use separate metadata-minimized ICT logs; does **not** require 180 days of raw child GPS, recordings or application-use history |
| **DPDP Rules 2025, Rule 7** | **Phased commencement**: eighteen months from Gazette publication; 13-versus-14 May2027 planning date depends on publication evidence, not instrument drafting date. The current India legal gate reserves the precise date for counsel and checks the corrigendum | Once in force and applicable: affected individuals without delay; Board initial intimation without delay; detailed Board report generally within **72 hours** or written extension. In Oct2026 **do not state it already applies identically to every entity**; recheck notifications on incident date |
| Sector/vendor/platform duties | Contractual or applicable-law specific | Security/legal owner checks processors (Oracle/Google), Google Play declarations, police/child-safety emergency escalation, and any jurisdiction-specific law |

**Sources (verify current versions at real incident):**
- CERT-In 2022 Directions: https://www.cert-in.org.in/PDF/CERT-In_Directions_70B_28.04.2022.pdf
- CERT-In FAQs: https://www.cert-in.org.in/PDF/FAQs_on_CyberSecurityDirections_May2022.pdf
- MeitY DPDP notification/timeline/corrigendum: https://www.meity.gov.in/documents/act-and-policies/digital-personal-data-protection-rules-2025-gDOxUjMtQWa

**No legal deadline should be silently postponed to finish root-cause analysis.** Counsel must verify the precise reporting recipient, mechanism and statutory trigger, but the team should organize evidence and report rapidly rather than waiting for all details. Do not make fabricated statutory or contractual notification promises.

## 4. First 60 minutes and containment

1. Report suspicion through the verified private channel listed in [Security Policy](../../../../SECURITY.md). Assign Incident Commander, severity and scribe; start T0/timeline.
2. Determine potentially compromised categories: guardian/child identity; GPS and current location; historical routes; app usage; media-event metadata; encrypted local Alarka queue; temporary PostgreSQL inbox/WAL/backups; parent-local recordings; admin-case searches; payment details; push payloads.
3. Immediately isolate vulnerable endpoint/credential/device enrollment or feature flag. If tenant-isolation failure is suspected, **disable affected read/command routes** before resuming any monitoring; honor child safety.
4. For confirmed misuse of monitoring, **disable affected command/grant paths**, preserve evidence and manage guardian safety/custody reports without exposing reporter identity.
5. Preserve system logs, control-plane event IDs and minimal evidence; avoid copying raw child GPS/media into support tickets, Slack/GitHub/public issues.
6. Decide CERT-In reportability based on Annexure I; record reporting reason, owner, deadline, initial/updated submission reference.
7. Engage appropriate vendor contacts (OCI, Google/Play, FCM, TURN) privately when compromise could affect hosted services or signing.

## 5. Playbooks

### A. Wrong-family child data exposure
- Freeze vulnerable API route, invalidate relevant access sessions, block any wildcard admin rights.
- Preserve minimized request IDs, scopes, signed grants and admin read audit; determine affected families/children, not guesses.
- Fix RLS/policy and add **same-family wrong-child** as well as cross-family negative tests; independent security approval before restore.
- Notify based on current law and credible physical safety risks; do not reveal other guardians' private contacts.

### B. GPS, history, and durable inbox compromise
- Assume potential child physical-safety risk. Secure PostgreSQL location_inbox payload, raw PostGIS, WAL, backup store and Android local encryption material.
- Revoke leaked device credentials, reject queued batches from revoked enrollment generations and prevent 48h offline replay from resurrecting deleted data.
- Identify precise exposure window by *event observed_at* and *server received_at*, distinguish uncommitted, inboxed and processed records.
- Preserve backed-up evidence under chain of custody; implement least-privilege access and key rotation.

### C. Alarka camera/microphone/streaming incident
- Remote media features remain **research disabled**; any unapproved capture is critical.
- Kill feature flags and credentials; Android indicators and child-visible app identity cannot be hidden. Review on-device sensor state without covert remote actions.
- No VPS media file by design, but assess streams, TURN buffers, parent-local recordings and media activity metadata.

### D. Signing, Play Console or GitHub supply-chain compromise
- Freeze release/CI; revoke deployment keys, service accounts and packages, check signed artifact digests.
- Coordinate official Play key recovery and notify qualified reviewers; never print keystore secrets in issue/PR.
- Roll out verified signed update only after trust-chain review.

### E. SOS unavailable or false delivery
- Mark alert path degraded, never claim emergency service dispatch; inform affected authorized guardians about uncertainty where feasible.
- Escalate credible immediate danger to emergency services via authorized humans, not fabricated in-app delivery.

### F. Administrator abuse and grievance/custody safety
- Disable case grant/account, preserve independent admin search and autocomplete logs; audit all named-child reads.
- Verify report safety; do not automatically notify an accused guardian about a sensitive abuse report.

### G. OCI outage, missing backups, invalid restore
- Use [Operations Runbooks](OPERATIONS_RUNBOOKS.md). A single VM and same-domain backups provide no HA.
- Restore only to an isolated endpoint, reapply deletion tombstones/revocations before reopening any parent API and verify latest committed inbox ACK receipts.
- RPO/RTO remain proposals until proven by a signed exercise record.

## 6. Evidence and chain of custody

Incident record captures ID, T0 UTC+IST, classifications, reporter, impacted systems/tenants (minimized), token revocations, containment timeline, facts/uncertainties, notification clock, recipient and receipt, evidence filename/hash/access, mitigation, owner, signoff. Restrict raw child data to exceptionally justified confidential incident storage with documented reason and legal retention; **do not** store evidence in public repo, CI artifacts or spreadsheets accessible to normal support.

## 7. Guardian, DPDP and CERT-In notice templates — controlled drafts

**CERT-In initial:** incident category, time noticed (timezone), affected system/company contact, known impact, timeline, immediate containment and pending unknowns. Submission through currently published CERT-In procedure; report partial knowledge in six-hour window if required, then amend.

**Future applicable DPDP Board notice:** initial nature/extent/timing/location/likely impact without delay; detailed explanation and mitigation within applicable 72-hour rule after it commences, if no extension; keep evidence of affected-principal notices.

**Guardian plain-language note:** description of what happened, affected child data/time interval (not another child), impact, protective actions (review linked guardians/credentials and physical safety as necessary), measures taken, verified service-contact method, how to request access/grievance, and what is not yet known. Translate as appropriate; follow specific legal rights of adults/children/custody.

## 8. Closure and improvement

- Independent security review of remediation + relevant regression test before enabling affected capabilities.
- Verify restore and permission / device revocation work; check inbox/raw/route events did not lose or duplicate acknowledged GPS data.
- Postincident report: root cause, timeline, notices, effective controls, followups with owners/dates, revised STRIDE/DPIA/vendor contracts.
- Proposed tabletop every six months and before real-minor pilot. **No tabletop or incident-response rehearsal has been performed by writing this procedure**.

## 9. Mandatory completion fields and NO-GO criteria

- [ ] Actual incident owner, deputy, secure reporting contact and backup reachability.
- [ ] CERT-In contact/notification owner, Indian ICT log store and report mechanism verified.
- [ ] Phased DPDP Rule commencement and incident-date legal notification matrix signed by India counsel.
- [ ] Proof of encrypted offsite backups, recoverable RPO/RTO and nonresurrection of deleted GPS after PITR.
- [ ] Separate auth/admin read audit, runbooks, incident tabletop, realistic threat-model cases and app release gate.
- [ ] Reliable confidential user/child-safety grievance address and publication/legal review.

**Until those are completed: status DRAFT; only synthetic data environments.**

## 10. Uploaded MA-IR-001 procedure review — operational detail incorporated, statutory clocks remain conditional

The uploaded 222-line MA-IR-001 template was reconciled with this newer project-specific procedure. Its staged response, formal role ownership, evidence record and specific notification fields are retained below. **The uploaded blanket claim that DPDP breach notices applied immediately in October 2026 was not adopted:** the 13 November 2025 Gazette provides phased commencement (many substantive duties scheduled for May 2027, subject to amendments). **CERT-In covered incidents have a distinct 6-hour reporting direction that must be assessed now.** The legal lead shall verify applicable law as of incident date; this document is not legal advice.

### Operational checklist — first awareness and next 60 minutes (planned)

1. **T0:** person receiving alert opens a protected incident ticket with UTC+IST awareness time, reporter, private return contact, alleged child(s)/tenants/region only as necessary; do not create a public GitHub issue.
2. Immediately page the named Incident Commander, security lead and legal/privacy backup, ideally through a **pretested 24×7 confidential contact method**. No such method has been verified in this repository.
3. Classify SEV-1…4; activate the **6-hour CERT-In reportability investigation** for covered Annexure I categories without waiting for full root cause; record exact decision and known facts.
4. Contain unauthorized family/child/guardian access and administrative misuse; may disable sensitive parent/API routes, revoke tokens and stop sensor/media feature flags. Keep SOS safe and do not claim a request was delivered.
5. Preserve logs and affected artifact hashes with chain-of-custody and least access. A child GPS inbox row, private route, parent-local media or secret **must not be pasted** into ordinary incident tickets or public documents.
6. Contact actual OCI/Play/FCM/TURN/Google DPA contacts using internally verified methods; legal determines any additional applicable sector/contract notices.
7. Issue accurate, limited updates to affected guardians in understandable language where warranted; do not reveal protected abuse reporter or another child/family.
8. Assign independent owner, ETA and regression test for root cause; **no live service restart** until security sign-off of family-scoped permissions, state recovery and deletion/consent tombstones.

### Additional playbooks from uploaded draft

**A. Guardian device takeover / custody threat:** Revoke affected account and device sessions; list last child-scoped access in redacted form. Do **not** automatically notify an alleged abusive guardian of the reporter identity or precise location; route through safeguarded grievance/counsel procedure.

**B. Hidden surveillance / sensor activation discrepancy:** Immediately turn off affected P3 media feature, inspect OS grant/indicator/notification on safe synthetic device, verify whether child audio/camera ever started and whether any parent-local recording/relay was involved. **Never** try to prove the incident by secretly starting a new recording.

**C. Compromised signing/Play developer account:** Freeze publication and CI deployment; revoke CI/Cloud secrets; collect artifact signature/digest provenance; use official Google Play signing recovery instructions. No unreleased APK side-loading workaround for policy violations.

**D. SOS, FCM or relay delivery silently fails:** Stop claiming SOS sent/delivered/received until verified; advise authorized guardians that the service cannot substitute for local emergency services; keep delivery receipts and sequence of timeouts.

**E. Vendor processor data breach:** Record vendor/incident clock and disclosed incident category; do not copy a full child's route, saved media filename or raw phone number into a generic vendor escalation. Legal determines whether our own covered reporting/notice is triggered.

### Incident record template (private controlled form; not GitHub customer-data issue)

~~~text
Incident ID: MA-IR-YYYY-NNN
T0 first awareness (UTC and IST):
Reporter/source and trusted return channel:
Incident Commander / backup / scribe:
Initial and final severity; rationale:
Affected services, environments, tenant count, subject count (method):
Affected data classes (current GPS, historical route, UsageStats, media METADATA,
  parent-local media, inbox/WAL, credential, billing, admin access log, etc.):
Identity/grant and API request/correlation IDs (minimized):
Containment ordered timeline and approving owner:
Evidence locations (restricted), hashes, chain-of-custody and legal hold:
CERT-In Annexure I/reportability decision, 6-hour clock, submission reference:
DPDP applicability/commencement check by India counsel, any principal/Board notice:
Other sector/vendor/Google Play notices and exact audience:
Guardian/child-safety communication approval and contact method:
Root cause / fixes / verification (RLS wrong-family and wrong-child tests):
Backup/restore and device queue replay/deletion-tombstone outcomes:
Follow-up control owners, deadlines and incident retrospective:
Closure authorizer/date; retention classification and legal hold review:
~~~

### Preparedness and rehearsal

The source document suggested twice-yearly exercises; retain a **semiannual synthetic tabletop target**, especially cross-tenant GPS disclosure, app guardian misuse, admin audit bypass, data delete/restore, SOS false-delivery and signing-key compromise. Verify incident role roster, CERT-In portal/contact, off-hours escalation, six-hour clock, India-held ICT logs, evidence storage, and customer grievance method **before real-data pilot**. Record each rehearsal build/date/tester/evidence and failures; do not claim it happened merely because a written playbook exists.

**Legal references:** CERT-In Directions https://www.cert-in.org.in/PDF/CERT-In_Directions_70B_28.04.2022.pdf ; CERT-In FAQ https://www.cert-in.org.in/PDF/FAQs_on_CyberSecurityDirections_May2022.pdf ; DPDP Act phased commencement Gazette https://egazette.gov.in/WriteReadData/2025/267647.pdf .

**Do not publish actual staff phone lists, security findings, raw GPS, or incident details in this repo.**

