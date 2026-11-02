# Madalasa–Alarka — Owner-Controlled Google Admin Access, FAQ CMS, Support, Subscriber Billing and Service-Usage Logs

**Owner direction: 2026-10-28. Status: ACCEPTED PRODUCT REQUIREMENTS / TECHNICAL DESIGN ONLY. Nothing in this file proves a working authentication, approved Google OAuth client, email notification, database migration, support delivery or live administrator permissions.** Canonical admin redesign for the separate web back office. Preserves security restrictions in [existing restricted administrator spec](ADMIN_PANEL_SPECIFICATION_2026.md) and [media audit ADR](MEDIA_ACTIVITY_AUDIT_LOGGING_AND_REPORTING_2026.md).

## A. Initial owner and access authority

- Only `swarna.s.jobs@gmail.com` is the **initial authorized ROOT_OWNER** with authority to approve/reject/suspend other administrator identities and assign/revoke their admin roles.
- Owner MUST first sign in with Google; never grant a role based on a POSTed email or an arbitrary Google credential with an unverified audience. Backend verifies Google ID token **cryptographic signature, issuer, audience, expiration, nonce/CSRF, and email_verified**, and checks owner `(issuer, sub)` against a securely provisioned bootstrap record. Provision it **only after the genuine Gmail identity has been authenticated** under a protected administrative setup; a one-time email-only bootstrap with no verified subject is insecure.
- Exact verified owner email `swarna.s.jobs@gmail.com` is used for bootstrap verification/display and approval inbox routing. Google `sub` is the durable identity key; do not rely on email as the primary key or allow silent owner substitution through an updated email field. Owner account replacement/recovery requires a separately reviewed, audited out-of-band process with strong identity proof (not self-service).
- **All other Google accounts: `NO_ACCESS` until approved.** A Google identity can apply to join the admin staff but may not access admin APIs, subscriber data, ticket content, admin lists or profile data. Public access is limited to the application flow and status for their own request.
- Force MFA/step-up for owner approvals, role change, case-sensitive reads and payment adjustments. Prefer phishing-resistant passkey/security key where available. Short-lived admin sessions with separate `admin` audience, device binding, server revocation, anti-CSRF (if cookie auth), rate limiting, secure headers and append-only audit. Google sign-in alone is insufficient for authorization.
- ROOT_OWNER has **all intended administrative management permissions**, but does **not** override children's private data restrictions. No root admin screen for raw child GPS/location history, geofence names, private route geometry, files, screen recordings, camera/video/microphone capture payloads, device secrets, private chat/message text, child app activities, sensor activation or bypass of policy. Existing exceptional case-scoped privacy/security auditing requires separately approved purpose, minimum fields, MFA and read audit; normal owner overview has no unrestricted private child data.
- Approved staff may get least-privilege `FAQ_EDITOR`, `SUPPORT_AGENT`, `BILLING_VIEWER`, `USAGE_AUDITOR` or combined roles explicitly assigned by ROOT_OWNER. Only ROOT_OWNER may grant/revoke roles or decide new admin applications. If a staff account has no assigned role, deny admin views.

## B. Access-request journey (exact user workflow)

1. Visitor opens back-office URL → **Continue with Google**. Backend verifies Google token and maps exact `iss/sub`.
2. If matching ROOT_OWNER: MFA/step-up then full admin shell (subject to privacy restrictions). If ACTIVE approved staff: show only their authorized modules. If unknown/rejected/revoked user: show **Access not granted** and **Request access** (revoked/rejected reapplication subject to cooldown and owner review). Never let a caller choose their role.
3. Requester opens **Complete your profile** form: full name, postal address, date of birth, gender, email address (Google verified email suggested/read-only; any different requested contact email must receive separate verification). For gender, include self-describe/prefer not to say options; it **must not** influence eligibility. DOB/address/gender are personal information; business need, mandatory status, retention and lawful notice require explicit review. UX can present the fields requested by owner but **release gate**: no compulsory collection without necessity and privacy approval. Show form validation, privacy notice, collection purpose, edit/resubmit.
4. Email confirmation: if authoritative Gmail Google ID token has `email_verified=true` and the profile email is identical, confirm it server-side immediately as Google-verified; if different contact email, send an **expiring one-time verification link/code** to that address, store hashed challenge and attempt limit, mark verified only after successful click. No profile can spoof verified email by client state. Do not require Gmail **mail API permission** just to sign in; ordinary Google ID token `openid email profile` is enough.
5. **Request Access** remains disabled until required profile validation and associated contact email verification complete. Submit once idempotently → `PENDING_REVIEW` with opaque request ID and submitted_at. Repeated clicks may show the existing request, not duplicate queue entries.
6. Send minimal **notification email** to `swarna.s.jobs@gmail.com` (new request ID + timestamp + safe deep link to owner dashboard). **Do not email plaintext DOB/address/gender or child information.** Owner can see the full applicant profile only after authenticated Google sign-in + MFA in **Access Requests**.
7. In owner dashboard, filter `PENDING | APPROVED | REJECTED | SUSPENDED`; choose one request; inspect self-declared profile and Google identity verification state, history/audit and reason. Owner chooses **Approve** (select least-privilege role scopes) or **Reject** (required internal reason); step-up and backend authorization required. Atomic server transition; one approval event, no double processing.
8. After approval, requester receives approval notification and can sign in again; server issues a **new authorized admin session with approved role**. An outstanding `NO_ACCESS` token never inherits privileges just because an email was sent. On rejection, display status and limited resubmission/cooldown without revealing other applications. Owner may suspend/revoke instantly and invalidate all old sessions.
9. Access-request profile is **not** the same as parent account or family membership. Being a parent or having paid seats gives no admin rights, and being an admin grants no access to any child as guardian.

## C. Administrative modules and boundaries

| Module | Required function | Allowed data | Never allow by default |
|---|---|---|---|
| ROOT_OWNER / Access Requests | Applicant queue, profile detail, approve/reject, role and suspension, immutable audit | Applicant full profile after MFA, verified Google email and decision history | Client-selected admin role, owner self-replacement, unaudited bulk granting |
| FAQ Pages | List, create, read, edit, reorder, draft, preview, publish/unpublish, revision history, search; English now, translation-ready | FAQ title, slug, category, public body, author/revisions and publish status | Arbitrary HTML/script, public posting without publish permission, deleted revision loss |
| Support Requests | Ticket inbox, status, priority, assignment, safe replies, parent notification, history, reopen/close | Ticket ID, verified parent contact, subject, sanitized text, approved attachment metadata | Child GPS, media, raw private files, other families' tickets; arbitrary outbound Gmail |
| Subscribers / Billing | Search parents, family count, paid child-seat count and specific covered child references; trial/free/expired, manual prepaid term, founding eligibility, renewal and add-on state | Store product, verified purchase status, amount/currency, timestamps, masked order reference, refund status and optional last transaction summary | Card/PAN/CVV, Google payments credentials, Play purchase raw tokens or payment instrument details |
| Children (minimal roster only) | From a particular authorized subscriber show child count and minimal list of child **aliases/masked IDs** and paid-seat status | Child reference, pseudonymous label, seat/trial/paid/free state and permission-to-view flag; child names only if owner/privacy approves necessity | DOB, live/previous GPS, address, device coordinates, geofences, photos, device usage details, child microphone/camera/screen payloads |
| Parent service usage / logs | Filter by parent, date, service type, status, measured duration, result; aggregated day/week/cost/quota consumption | Who used a service, when, duration, service category (location view, request, audio/video session metadata), amount charged to quota, success/failure; paginated and redacted | Route content, maps, precise points, child's app-usage content, photos, recordings, screenshots, messages, child private details |
| System health and audit | Redacted throughput/errors, role actions, login failures, privilege changes, billing reconciliation; audit/retention controls | Anonymized infrastructure aggregates and scoped staff action logs | Raw child database browse, arbitrary SQL query or unrestricted exports |

**Distinction:** parent service usage means actions by the **parent** in Madalasa (when parent accessed a feature, start/end, elapsed time, outcome), not the child's application usage/behavior. Avoid conflating the existing `app_usage_events` child behavioral monitoring dataset with admin `parent_service_usage_events`; only the latter is the routine admin usage feed. Sensitive media metadata remains separately case/purpose controlled per existing MA-ADMIN-001. Store UTC timestamps; present local time clearly.

**FAQ security:** sanitized Markdown or allowlisted HTML converted safely on server; separate draft and public revision; optimistic lock version; audit editor and publisher, rollback. Only `FAQ_EDITOR` or ROOT_OWNER can draft; publication permission may be restricted further.

**Support replies:** parent-created tickets by authenticated parent, ticket replies via in-app notification or explicitly connected transactional mail provider, no silent use of owner's Gmail inbox. Restrict HTML, redact confidential child content, attachments off by default pending privacy/storage review; support reply audit with delivery/receipt state and distinction between sent and read.

## D. Proposed PostgreSQL extension (canonical logical schema v1.1, not migrated)

```text
admin_accounts(
  id PK, google_issuer, google_sub UNIQUE, verified_google_email,
  email_verified_at, role_state NO_ACCESS|ACTIVE|SUSPENDED|REVOKED,
  owner_bootstrap_approved_at, created_at, last_login_at)
admin_profiles(
  admin_account_id PK/FK, full_name, encrypted_postal_address,
  encrypted_dob nullable, encrypted_gender nullable,
  contact_email, contact_email_verified_at, profile_revision,
  privacy_notice_version, consented_at, last_updated_at)
admin_email_verification_challenges(
  id PK, admin_account_id FK, email_digest, challenge_hash UNIQUE,
  expires_at, used_at, attempt_count, created_at)
admin_access_requests(
  id PK, admin_account_id FK, profile_revision,
  status DRAFT|EMAIL_PENDING|PENDING_REVIEW|APPROVED|REJECTED|SUSPENDED,
  created_at, submitted_at, decided_at, decided_by_admin_id FK,
  decision_reason_encrypted, row_revision, cooldown_until)
admin_roles(
  id PK, code UNIQUE, display_name, owner_assignable)
admin_permission_catalog(
  code PK, description, sensitive_case_required BOOLEAN)
admin_role_permissions(
  role_id FK, permission_code FK, PK(role_id, permission_code))
admin_role_grants(
  id PK, admin_account_id FK, granted_by_owner_id FK, role_id FK,
  created_at, revoked_at, revocation_reason, expires_at)
admin_action_audit(
  id PK, actor_admin_id FK nullable, target_id opaque,
  action, outcome, occurred_at, request_id, ip_hash nullable,
  immutable_digest, case_id nullable)
admin_notifications(
  id PK, recipient_owner_id FK, access_request_id FK,
  kind, status, queued_at, sent_at, dedup_key UNIQUE)
faq_entries(
  id PK, slug UNIQUE, category, status DRAFT|PUBLISHED|ARCHIVED,
  current_revision_id FK nullable, created_at, updated_at)
faq_revisions(
  id PK, faq_id FK, revision_no, title, sanitized_body,
  language_code='en', created_by_admin_id FK, created_at, published_at)
support_tickets(
  id PK, requester_adult_id FK, family_id FK optional,
  subject_sanitized, ticket_status, priority, assigned_admin_id FK nullable,
  created_at, updated_at, closed_at)
support_messages(
  id PK, ticket_id FK, author_kind PARENT|ADMIN,
  author_ref, body_sanitized, created_at, edited_at, delivery_status)
parent_service_usage_events(
  id PK, parent_adult_id FK, child_id FK nullable,
  service_code, action, started_at, finished_at,
  verified_duration_seconds, outcome, quota_consumed_seconds nullable,
  source_receipt_ref opaque, retention_policy_id FK,
  data_classification SERVICE_METADATA_ONLY)
admin_support_read_audit(
  id PK, admin_id FK, ticket_id FK, parent_id FK nullable,
  accessed_at, purpose, result, request_id)
```

**No raw card details table**: payment state comes from server-verified Play purchase and reconciliation records already modeled. `parent_service_usage_events` must not contain coordinates, camera/microphone content, file locations, private messages, or encoded child private sensor data. Child access in admin views should be through a **restricted projection**, not direct arbitrary SELECT on `children`/GPS tables. When using a child identifier in logs, UI displays only a masked reference and never child name by default.

## E. API / security contract — design only

```text
POST /admin/auth/google             # verify Google OIDC token, create restricted owner/staff/NO_ACCESS session
GET  /admin/access/me               # own status only; no admin data for NO_ACCESS
PUT  /admin/access/profile          # self service, validated allowed fields
POST /admin/access/verify-email     # send hashed, expiring challenge if needed
POST /admin/access/confirm-email    # verify OTP/link
POST /admin/access/requests         # only verified email and valid profile; idempotent
GET  /admin/access/requests/me      # own request/status only
GET  /admin/owner/access-requests   # owner-only, MFA; page/sort/filter
POST /admin/owner/access-requests/{id}/decision # approve+roles or reject with reason
POST /admin/owner/grants/{id}/revoke # owner-only, MFA, session invalidation
GET/POST/PUT /admin/faqs            # read/write by permission; list draft and revision workflow
POST /admin/faqs/{id}/publish       # permission scoped
GET  /admin/support/tickets         # scoped, paginated
POST /admin/support/tickets/{id}/reply # support role and audit
GET  /admin/subscribers            # scoped to billing metadata
GET  /admin/subscribers/{id}/children # restricted projected aliases/seat statuses ONLY
GET  /admin/subscribers/{id}/payments # masked store receipts, not card details
GET  /admin/usage/parents          # measured parent service metadata, range/cursor filter
GET  /admin/security/audit         # privileged auditor/owner but no deletion
```

RLS and service-view authorization are mandatory; browser state not trusted. Every endpoint performs server permission checks, session revocation epoch, optional step-up, logging and filtering. Queries are paginated, no wildcard exports. Owner `approve/reject` writes must be atomic compare-and-swap transactions, with a server-side audit row and outbox event for notification. If audit storage fails, **do not approve**, nor expose sensitive detailed reads. Verify support reply idempotency and XSS prevention.

## F. Screen handoff (editable Figma)

Create separate desktop admin-operations design page without changing existing restricted media audit views:

- **BO-01:** Google login → `NO_ACCESS`, “Request access”.
- **BO-02:** Complete profile and verify email; Request Access disabled until verified.
- **BO-03:** Application submitted / pending review; status and no admin data.
- **BO-04:** Owner Access Requests inbox, verified applicant detail and Approve/Reject + role selection.
- **BO-05:** FAQ CMS list, draft and preview/edit/publish.
- **BO-06:** Support tickets, conversation/reply and delivery status.
- **BO-07:** Subscriber list and subscription/payment ledger.
- **BO-08:** Subscriber minimal child list and parent service usage logs.
- **BO-09:** Owner dashboard, role-guarded navigation and access audit overview.

Prototype examples must use **synthetic identities, not real parent/child profile content**. “Design only” environment badge in screen header, owner role visible and child-private-data wall conspicuous.

## G. Tests and release gates

T-BO-01 spoofed email, tampered ID token, wrong aud, expired/nonverified token, replay → zero access; owner bootstrap may only bind genuine verified Google `sub`; T-BO-02 Google login of unapproved account → only form; T-BO-03 form incomplete/unverified contact → submit unavailable; T-BO-04 verification token reuse/replay fails; T-BO-05 duplicate request returns same ID; T-BO-06 owner inbox notification has no plain profile PII; T-BO-07 only owner may approve/reject and grant roles; T-BO-08 denied request cannot access subscribers even with direct API URL; T-BO-09 staff role changes immediately revoke sessions; T-BO-10 FAQ safe HTML, draft version and rollback; T-BO-11 support tickets and replies scoped to requester and assigned staff; T-BO-12 payments never include raw card/Play token; T-BO-13 child list projection omits location/age/media/private device data; T-BO-14 parent-service duration logs show verified times and never child usage contents; T-BO-15 audit-store failure blocks owner approval and sensitive reads; T-BO-16 export and breakout case grant denied by default; T-BO-17 applicant DOB/gender/address privacy/necessity and retention reviewed; T-BO-18 deletion subject requests and record expiry tested.

## References

- [Google server-side ID-token verification](https://developers.google.com/identity/gsi/web/guides/verify-google-id-token)
- [Google OpenID Connect](https://developers.google.com/identity/openid-connect/openid-connect)
- [Google Play User Data policy](https://support.google.com/googleplay/android-developer/answer/18258653)
- [Existing admin specification](ADMIN_PANEL_SPECIFICATION_2026.md)
- [Whole-project SRS](../../M1-secure-platform-foundation/01-requirements-and-architecture/SRS.md)

## Owner frontend decision — 2026-11-01

Admin frontend is **HTML/CSS + HTMX + CSP-compatible Alpine.js**, with C++20 Drogon as the HTML/fragment and API server. Security authority remains server-side; client state must never grant admin roles or child-private access. The existing React implementation is a migration reference, not an approved framework decision. Details and migration acceptance: [Admin frontend stack ADR](ADMIN_FRONTEND_STACK_DECISION_2026-11-01.md). No production integration is implied.
