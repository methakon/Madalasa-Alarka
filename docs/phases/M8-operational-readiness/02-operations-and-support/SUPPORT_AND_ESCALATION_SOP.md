# Guardian Support, Safety Escalation and Grievance SOP

> **Document control:** M8 / 02-operations-and-support · Proposed owner: SRE + incident lead (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

**Status:** Draft operating procedure. No active support desk, staffed helpline or published complaint contact exists. Must be funded and tested before real-child onboarding.

## Entry points and scope
Support through an approved app/web form and verified private contact (to be chosen), not GitHub issues for child/guardian data. Validate adult guardian account without requesting unnecessary child location/media; require child-specific authorization for discussing status/history. Routine support may view **redacted aggregate health** only. Named child media/GPS detail requires a separate time-limited case/purpose, step-up MFA, and auditable access; general admins/root operators have no default access.

## Ticket categories and illustrative priorities
P0: suspected active child-safety hazard, abusive/unauthorized monitoring, leaked location, admin abuse or SOS false delivery — notify incident commander/security immediately, record time in UTC/IST and preserve confidentiality.
P1: account takeover, other-family visibility, essential location/permission flow fails — urgent security case.
P2: device compatibility, offline GPS backfill, subscription/cancellation or normal app reports — standard support queue.
P3: feature suggestions and nonurgent usability.

Targets for acknowledgment/resolution require staffing; do not publish an unsupported 24x7 SLA. Support must never claim a camera is available, a child is live tracked, or an SOS reached a responder unless a verified receipt exists.

## Triage script
Authenticate adult and child scope; identify platform, app version, Android API/OEM, last verified device observation and command reason code without copying child coordinates. Determine online vs stale vs permissions vs user-action-needed vs feature unreleased. Give safe on-device directions to Alarka system screens where needed, not covert grant instructions. Ask for **redacted synthetic screenshots**, never children's media. For app/Play billing, use official merchant refund channels, not unsupported manual promises.

## Sensitive reports
Custody disputes, abuse and child requests must go to a small specially trained reviewer. Avoid automatically disclosing reports to a potentially abusive guardian; freeze disputed permission where safe, consult legal/child-protection procedure and avoid taking sides based only on account ownership. Immediate danger goes to local emergency services—do not promise app dispatch.

## Escalation matrix
Support → security/incident lead for data access, compromise or monitoring misuse; → India privacy/Grievance Officer for personal-data requests and notices; → Android lead for OS restrictions; → billing owner/Google Play for refunds; → infrastructure for Postgres backlog/outage/backup. Require case ID, owner, response deadline once approved, and a closed-loop outcome log.

## Privacy and closure
Retention for support tickets is still a draft; consult DATA_RETENTION_SCHEDULE.md and grievance legal deadlines. Grant access revocation and account deletion workflows must cover relevant support caches. Gather anonymous satisfaction feedback only where approved. Quarterly staff review and incident tabletop recommended, none conducted.

## 2026-11-01 — Owner-designated support mailbox

The designated two-way communication sender/recipient for support tickets and feedback is **madalasa-alarka@berhampore.in**; notification-only outbound uses **noreply@berhampore.in**. The owner reports local `.env` configuration, but actual SMTP/inbound verification, staffing and deliverability have **not** been checked. Replies require ticket-scoped identity verification, safe attachment handling and auditable retention. Do not infer parent/child authorization from the email From address. See [Email templates and two-way mailbox requirements](../../M7-commercial-integrations/01-commercial-plans-and-costing/EMAIL_LIFECYCLE_AND_SUPPORT_TEMPLATES_2026-11-01.md). This designation replaces the earlier unspecified support contact, but does not imply the help desk is operational.
