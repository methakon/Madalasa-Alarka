# Madalasa–Alarka — Transactional email and two-way support communications

**Date:** 2026-11-01 | **Status:** Owner-requested template and dispatch design; transport and deliverability **verified live bidirectional** on 2026-11-01 (see [evidence](../../../../evidence/local/infrastructure/EMAIL_TRANSPORT_AND_DELIVERY_VERIFICATION_2026-11-01.md)). Synthetic-only QA; no provider passwords or SMTP credentials in git.

## Sender allocation and transport

| Use | Sender | Reply handling |
|---|---|---|
| Security OTP, expiry reminders, expiry event, renewal prompts | Madalasa Notifications <noreply@berhampore.in> | Do not imply replies are monitored; clear support link to madalasa-alarka@berhampore.in |
| Support ticket opened, human support replies, feedback acknowledgement, two-way resolution | Madalasa Support <madalasa-alarka@berhampore.in> | Monitored inbound mailbox, ticket-associated two-way threading; verify sender ownership, strip quoted private details |

The owner configured both mailboxes in local `.env`. Transport connectivity and bidirectional delivery were independently verified on 2026-11-01 (see [transport verification evidence](../../../../evidence/local/infrastructure/EMAIL_TRANSPORT_AND_DELIVERY_VERIFICATION_2026-11-01.md)). Never commit `.env`, SMTP passwords, API keys or mailbox tokens. Use separate scoped sender identities and secrets; prohibit header injection, mail spoofing and user-controlled Reply-To. Configure SPF, DKIM, DMARC, TLS, DNS/MX, verified From domains and bounce processing before deployment. Environment variable *names only*: `MAIL_NOTIFICATIONS_FROM`, `MAIL_SUPPORT_FROM`, `MAIL_SMTP_HOST`, `MAIL_SMTP_PORT`, `MAIL_SMTP_USERNAME`, `MAIL_SMTP_PASSWORD`, `MAIL_SUPPORT_IMAP_HOST` (only if used), `MAIL_SUPPORT_IMAP_USERNAME`, `MAIL_SUPPORT_IMAP_PASSWORD`, `MAIL_PUBLIC_APP_BASE_URL`. Provider-specific names may replace these in the implementation; no secrets in templates.

## Canonical expiry event schedule

Use **verified server-side child entitlement expiry** `expires_at_utc` from Google Play purchase validation, not a client-side guess, receipt timestamp, nominal month duration or email delivery. Evaluate distinct paying child IDs; preserve founding-family pricing eligibility and never assume all a family's children expire together.

| Template | Trigger relative to verified expiry | Recipient / dedupe scope |
|---|---|---|
| `PLAN_EXPIRY_30D` | T−30 calendar days, if the entitlement is still active | Verified payer/contact, one per covered child/expiry cycle |
| `PLAN_EXPIRY_7D` | T−7 days | Same |
| `PLAN_EXPIRY_1D` | T−24h | Same |
| `PLAN_EXPIRY_9H` | T−9h | Same |
| `PLAN_EXPIRED_NOW` | **At T**, following a server state transition to FREE (without relying on mail delivery) | Same |
| `PLAN_RENEWAL_1D` | T+24h if still expired/unpaid | Same |
| `PLAN_RENEWAL_7D` | T+7d if still expired/unpaid | Same |
| `SECURITY_OTP` | Explicit account-security verification challenge; short TTL | Verified address for requested operation |
| `SUPPORT_RECEIVED` | Successful ticket commit | Verified ticket contact |
| `SUPPORT_REPLY` | Authorized human or reviewed agent reply | Verified ticket participant |
| `FEEDBACK_RECEIVED` | Successfully accepted feedback | Address supplied and verified, if messaging consent/necessity permits |

**Operational interpretation:** T−30d only applies if the paid period lasts long enough; do **not** send a 30-day reminder at the start of a one-month prepaid plan merely because its expiry is ~30 days away. Gate T−30d until at least 24h after purchase and suppress if already purchased/extended. All notices are *one-shot*, not a daily campaign. T−7d, −1d, −9h and follow-ups must recheck latest entitlement immediately before dispatch. A top-up extends expiry and **invalidates pending old-cycle reminders**; a restored payment or new coverage suppresses expired/follow-up notices. "1 month expiry" is a remaining-30-day reminder, not a hard-coded billing period.

**Free fallback:** when trusted server time reaches expiry and there is no verified renewal/extension, entitlement calculation yields FREE immediately, independent of job queue or SMTP. Free access follows product rules, including limited tracking/history visibility; do not delete retained history merely because entitlement lapsed. The active/inactive family seven-day tracking policy is **separate**: expired child moves to the free-tier sampling profile, and if parent engagement has been absent ≥168h, to FREE_INACTIVE. Legal/consent/OS restrictions override all tiers. Do not claim a child device received a new policy until acknowledged.

**Delivery model:** timer/scheduler selects eligible events from durable transactional outbox, `UNIQUE(tenant, child, entitlement_period_or_expiry_version, template_id, recipient)`, with bounded retries, rate limits, provider IDs, UTC timestamps, bounce/unsubscribe classification and sanitized audits. Event transaction commits entitlement transition and event outbox atomically. Deduplicate repeated purchase/RTDN events. If the scheduler catches up late, skip stale pre-expiry reminders and *never send an expired email if already renewed*. Never delay expiry fallback waiting on an email. OTP is separately rate-limited and atomic one-time verification, expires quickly, is never logged and does not establish lawful guardianship by itself. Use secure, short-lived, allowlisted renewal links; no raw purchase tokens, precise GPS, child names unless necessary, or payment details in email. Non-transactional marketing requires separate consent and opt-out.

## Shared brand and accessibility

Theme C: parchment #FFF7E7, ink #292A31, indigo #233F69, vermilion #B73527, teal #28756C; simple single-column 600px responsive HTML, system-safe sans fonts, accessible contrast, semantic headings, 44px-tall CTA, text-only alternative, no external tracker pixels, no child location/maps or account secrets. Display expiry in **Asia/Kolkata** (IST) plus machine UTC evidence internally; user-configured locale/timezone may supersede. Prefer explicit dates over relative "tomorrow" language when scheduled delivery is delayed. Every external URL must be configured as an allowlisted HTTPS application origin.

### Safe variables

`{{app_name}}` (Madalasa), `{{recipient_display_name}}` (optional, verified), `{{plan_label}}`, `{{child_display_label}}` (default "your selected child plan" to avoid PII), `{{expiry_date_ist}}`, `{{expiry_time_ist}}`, `{{days_remaining}}`, `{{verified_plan_price}}` (show only from Play-approved metadata), `{{renew_url}}`, `{{support_email}}`, `{{ticket_ref}}`, `{{ticket_subject}}`, `{{support_message}}`, `{{otp_code}}`, `{{otp_ttl_minutes}}`.

All substitutions must be context-escaped, subject/header values CRLF-sanitized, and HTML bodies rendered server-side. Never allow arbitrary replacement strings to create HTML or URLs. For security, OTP codes are not embedded in support logs, ticket responses or analytics.

## Approved copy — subjects and text-first bodies

Each example includes the template identifier, sender and a concise English master body. Native HTML should wrap this exact text in the shared brand frame, not change billing meaning.

### SECURITY_OTP — From noreply@
**Subject:** Madalasa verification code: {{otp_code}}

Hello,

Your Madalasa verification code is **{{otp_code}}**. It expires in {{otp_ttl_minutes}} minutes.

Use this code only in the Madalasa app or the official website. Do not share it with anyone. If you did not request it, ignore this message and contact support if you notice suspicious activity.

Madalasa Security · Questions: {{support_email}}

### PLAN_EXPIRY_30D — From noreply@
**Subject:** Your Madalasa plan is scheduled to expire on {{expiry_date_ist}}

Hello,

Your prepaid {{plan_label}} for {{child_display_label}} is scheduled to expire on **{{expiry_date_ist}} at {{expiry_time_ist}} IST** (approximately one month from now).

Madalasa does not renew or charge you automatically. You can review coverage and extend the plan in the app: {{renew_url}}.

If you already renewed, the verified updated expiry shown in the app takes priority.

Madalasa Billing · {{support_email}}

### PLAN_EXPIRY_7D — From noreply@
**Subject:** 7 days left on your Madalasa plan

Hello,

Your {{plan_label}} for {{child_display_label}} expires on **{{expiry_date_ist}} at {{expiry_time_ist}} IST**.

You can renew manually at {{renew_url}}. If coverage ends, paid features become unavailable and the applicable free-plan limits apply. Your saved history is not deleted solely due to expiry.

Madalasa Billing · {{support_email}}

### PLAN_EXPIRY_1D — From noreply@
**Subject:** Your Madalasa plan expires in 24 hours

Hello,

Your prepaid {{plan_label}} for {{child_display_label}} ends on **{{expiry_date_ist}} at {{expiry_time_ist}} IST**.

No automatic payment will be taken. Review your plan and renewal options: {{renew_url}}.

Madalasa Billing · {{support_email}}

### PLAN_EXPIRY_9H — From noreply@
**Subject:** 9 hours remaining on your Madalasa plan

Hello,

Your paid access for {{child_display_label}} is scheduled to end at **{{expiry_time_ist}} IST on {{expiry_date_ist}}**.

To maintain paid features, extend the plan through the official app: {{renew_url}}. No automatic charge will occur.

Madalasa Billing · {{support_email}}

### PLAN_EXPIRED_NOW — From noreply@
**Subject:** Madalasa plan expired — free features remain available

Hello,

Your prepaid {{plan_label}} for {{child_display_label}} expired on **{{expiry_date_ist}} at {{expiry_time_ist}} IST**. Your plan is now on the available **free tier**, unless a newer verified purchase has already restored coverage.

Paid-only features are unavailable. Free location and history limits apply, subject to device permissions, legal eligibility and connection status. Existing eligible history is not erased merely because your plan expired.

You can renew manually: {{renew_url}}. We do not charge automatically.

Madalasa Billing · {{support_email}}

### PLAN_RENEWAL_1D — From noreply@
**Subject:** Your Madalasa plan ended yesterday — renewal is optional

Hello,

Your {{plan_label}} for {{child_display_label}} ended on {{expiry_date_ist}}. Your available free features continue, subject to their normal limits.

If you wish to restore paid access, review and manually purchase a new eligible period: {{renew_url}}. No payment has been scheduled automatically.

Madalasa Billing · {{support_email}}

### PLAN_RENEWAL_7D — From noreply@
**Subject:** A reminder: Madalasa paid features can be restored

Hello,

It's been seven days since your {{plan_label}} for {{child_display_label}} expired. Your account can continue using eligible free features.

You can choose to renew when convenient: {{renew_url}}. This is the final post-expiry reminder for this entitlement cycle.

Madalasa Billing · {{support_email}}

### SUPPORT_RECEIVED — From support@
**Subject:** [{{ticket_ref}}] We received your Madalasa support request

Hello,

We received your request: **{{ticket_subject}}**.

Reference: **{{ticket_ref}}**. Reply to this email to add information to the same ticket. Please do not send OTP codes, passwords, a child's precise location or private recordings.

We will respond according to the published support availability; no 24-hour response guarantee is implied.

Madalasa Support · {{support_email}}

### SUPPORT_REPLY — From support@
**Subject:** Re: [{{ticket_ref}}] {{ticket_subject}}

Hello,

{{support_message}}

Reply to this message if you need to continue the conversation. Keep the ticket reference in the subject so we can associate your response securely.

Madalasa Support · {{support_email}}

### FEEDBACK_RECEIVED — From support@
**Subject:** Thank you for your Madalasa feedback

Hello,

Thank you for sharing feedback about Madalasa. We have received it and will review it as part of product improvement. This is not a confirmation that a requested feature will be implemented.

If you need help, reply to this email or contact {{support_email}}.

Madalasa Support

## Inbound two-way mail safeguards

- Support ticket and feedback replies are routed by signed/verifiable ticket reference plus verified participant identity; never use subject or From address alone to authorize child-account access.
- Inbound messages are content-scanned, size-limited, HTML-sanitized and attachment-quarantined; support staff never receive raw authentication secrets or unrestricted child records.
- Store immutable ticket audit events and minimal body/attachment metadata under access-controlled retention. Replies to an expired/closed ticket have an explicit reopen or new-ticket state, never silent access.
- Respect grievance, safeguarding, privacy, emergency escalation and opt-out rules in the existing M8 support SOP.
- Do not expose `madalasa-alarka@berhampore.in` as an unverified 24/7 emergency response line.

## Implementation backlog, owner checks and test gates

**MAIL-01** Verify domain ownership, SMTP sender authorization, inbound support mailbox routing, SPF/DKIM/DMARC, HTTPS renewal links, bounce handling (without putting secrets in the repo).

**MAIL-02** Implement rendering with strict allowlisted placeholders, contextual escaping, branded responsive HTML + plain-text MIME alternative and accessible previews for all 11 IDs.

**MAIL-03** Add entitlement-cycle scheduler and event outbox; same DB transaction controls fallbacks. Idempotent T−30d/−7d/−24h/−9h/T/T+24h/T+7d; never alter billing entitlements based on successful email delivery.

**MAIL-04** Implement two-way ticket threading, reply ingestion, attachment filtering, sender re-verification and auditable role-restricted support handlers.

**MAIL-05** Synthetic test matrix: exact expiry boundary, leap day, DST/display timezone, same-minute top-up, refunded/revoked purchase, multiple children with differing expiry, 1008-founding family, delayed queue, duplicate RTDN, repeated provider retries, email hard bounce, permission revoked and free-inactive sampling after downgrade.

**MAIL-06** Review legal communication requirements, privacy retention, support staffing, Google Play prepaid product eligibility, real-provider sandbox test and release controls.

**Acceptance:** no customer-facing dispatch until transport/delivery evidence, security review, verified entitlement lifecycle and owner approval exist. Product implementation is pending.

## Source artifact and test-evidence reconciliation — 2026-11-01

Eleven HTML/plain-text template pairs plus a manifest are now present at email/templates/ (commit c611dfaf). Owner reports that a local worker successfully sent outbound test emails using configured mailboxes; this report has not been independently checked against sanitized SMTP/provider logs. Existing successful test sends do not prove these specific templates, scheduled expiry alerts, payment fallback or inbound ticket replies work. No secrets were inspected. Status: TEMPLATE_SOURCE_PRESENT; OUTBOUND_SEND_WORKER_REPORTED; INTEGRATED_LIFECYCLE_NOT_VERIFIED.
