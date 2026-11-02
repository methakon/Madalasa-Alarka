# Final API and DB Gap Register — Madalasa–Alarka

**2026-10-28 · design audit, not implementation evidence.** Reviewed existing `docs/openapi.yaml` (**134 paths**, 95 schemas). All 26 endpoint proposals below are screened by exact method and path, not name similarity. **26 exact method/path gaps** remain. Prioritize only after product/legal gate and request contract review.

**Screen inventory:** [187 screen states](SCREEN_API_DB_AUDIT_INVENTORY_2026-10-28.json), linked from handoffs. Not every narrative/local-only state requires an API. Existing path **does not prove running handler or auth tests**.

| Priority | Missing method + path | Screens | Proposed DB tables | Contract/guardrail |
|---|---|---|---|---|
| P0 | `GET /admin/owner/staff/{adminId}` | BO-04,BO-09 | admin_accounts, admin_role_grants | Owner staff-detail with role history, MFA assurance, revocation state |
| P0 | `POST /admin/owner/access-requests/{requestId}/revoke` | BO-04 | admin_access_requests, admin_action_audit | A reviewed request cannot be retroactively revoked; use grant-revocation route if already approved |
| P0 | `GET /admin/owner/roles` | BO-04 | admin_roles, admin_permissions, admin_role_permissions | List assignable role catalogue instead of hardcoding names |
| P0 | `GET /admin/access/profile` | BO-02 | admin_profiles | Read own draft profile, field completeness and verified contact state |
| P0 | `GET /admin/access/email-verification/status` | BO-02,BO-02V | admin_email_challenges, admin_profiles | Own verified contact + resend-after without leaking challenge |
| P0 | `GET /admin/owner/access-requests/summary` | BO-09 | admin_access_requests | Pending count computed owner-only |
| P1 | `POST /admin/faqs/{faqId}/unpublish` | BO-05 | faq_entries, faq_revisions, admin_action_audit | Owner/editor unpublish explicit with revision guard |
| P1 | `POST /admin/faqs/{faqId}/restore` | BO-05 | faq_entries, faq_revisions | Restore immutable published/draft revision |
| P1 | `GET /admin/support/tickets/{ticketId}` | BO-06 | support_tickets, support_messages | Ticket detail and safe conversation author/times |
| P1 | `GET /admin/support/tickets/{ticketId}/messages` | BO-06 | support_messages | Cursor paginated messages, ticket-scoped |
| P1 | `GET /admin/usage/parents/summary` | BO-08 | parent_service_usage_events | Verified aggregate per service without child activity content |
| P1 | `GET /admin/subscribers/{familyId}/entitlements` | BO-07,BO-08 | child_paid_entitlements, child_seat_assignments | Explicit per-child prepaid coverage vs minimal aliases |
| P1 | `GET /admin/billing/reconciliation-status` | BO-07 | payment_reconciliation_inbox, purchase_adjustments | Store-verified billing reconciliation health; no raw token |
| P1 | `GET /children/{childId}/places/{placeId}/notifications` | P-operations geofence | place_notification_rules | Get per-place per-guardian current toggle state |
| P1 | `PATCH /children/{childId}/screen-time-rules/{ruleId}` | P-operations policy | screen_time_rules, rule_assignments | Edit versioned policy, gate conditional managed mode |
| P1 | `DELETE /children/{childId}/screen-time-rules/{ruleId}` | P-operations policy | screen_time_rules, rule_assignments | Revoke rule and device receipt; do not pretend blocked |
| P1 | `GET /children/{childId}/viewer-takeover-requests/{requestId}` | SH-03 | viewer_takeover_requests | Owner-visible decision, state/expiry |
| P1 | `POST /children/{childId}/viewer-takeover-requests/{requestId}/decision` | SH-03 | viewer_takeover_requests, premium_viewer_leases | Consensual accept/deny; no silent takeover |
| P1 | `GET /children/{childId}/extra-viewer-addons` | SH-04,SH-06 | extra_viewer_purchases | Independent 100-day expiry and dormancy UI |
| P1 | `GET /parents/me/media-activity/export-requests/{id}` | PA-media audit | media_access_audit | If export is approved, lifecycle and expiry; default OFF |
| P2 | `GET /children/{childId}/checkins` | C-child check in | child_checkins | Parent-safe check-in feed, authorization/redaction |
| P2 | `GET /children/{childId}/usage/coverage` | P-usage | usage_permission_checks, usage_period_summaries | Unknown coverage rather than falsely zero usage |
| P2 | `GET /families/{familyId}/members` | P-family | family_memberships | Members != child guardian grants; never reveal unshared children |
| P2 | `POST /children/{childId}/guardian-invitations/{inviteId}/cancel` | P-family | guardian_invitations | Invite expiry/revocation, only authorized inviter |
| P2 | `GET /children/{childId}/notification-rules` | P-place notifications | place_notification_rules | Scoped recipient-specific geofence alert preferences |
| P2 | `GET /admin/faqs/{faqId}/preview` | BO-05 | faq_revisions | Safe server-rendered preview, no public draft access |

## Schema missing or insufficiently specified (not necessarily an additional physical table)

1. **Owner-only RBAC:** `admin_roles`, `admin_permissions`, `admin_role_grants`, staff audit and MFA step-up must have explicit constraints and revocation epochs. Google verified `iss/sub` only, never user-posted email. Add role catalogue and profile status read models.
2. **Admin identity and applicant:** verified contact challenge, profile revision, consent/retention policy, decision CAS and owner notification outbox. Applicant name/address/DOB/gender may only be compulsory after necessity review.
3. **Support/FAQ:** `faq_revisions` publish vs draft pointers, revision rollback and concurrency; `support_messages` read receipt, sanitization and ticket-scoped paginated messages. Implement read audit on sensitive support access.
4. **Paid child + parent usage metadata:** `child_seat_assignments`, `child_paid_entitlements`, `extra_viewer_purchases`, `parent_service_usage_events`, aggregated read model, no card numbers, child location or app usage logs.
5. **Concurrent viewer:** `premium_viewer_leases`, `viewer_takeover_requests`, `media_quota_ledger` atomic lease CAS / one child slot included, +1 addon slot, 1800s combined audio/video, 100 days independent of base lapse.
6. **Geo visibility vs retention:** `location_observations`, event-time partitions, `history_visibility_rules` (free six hours) and approved `retention_policy_versions` distinct. No automatic unlimited history storage decision.
7. **Android app policy:** `screen_time_rules`, `rule_assignments`, `policy_execution_receipts` need state/last OS rejection and capability gate; reject management on standard consumer device.
8. **Child-specific grants:** `child_parent_verifications` and `child_guardian_grants` are distinct from `family_memberships`; fail closed until verified external parent relationship method, no sibling leakage.
9. **Deletion replay:** tombstones and backup manifests must precede offline device queue deletion/restore so deleted child's stale uploads are refused.

## API contract fixes independent of missing paths

- For each mutation: unique operationId, role/security scheme, exact-child scope, idempotency, negative 401/403/404/409/422 and 429, body limits and audit policy.
- For each list: opaque cursor, bounded page, minimum projection, chronological UTC timestamps and stable sort. Do not return full child objects from admin minimal roster.
- For Play: backend-verified token and product price; avoid accidental auto-renew subscription SKU or separate audio/video add-on pools.
- For media: explicit OS denial, human-visible status and zero quota debit unless delivery verified; no permission bypass or media contents in admin logs.
- For device API: device-bound PoP and replay hash; zero acceptance after account deletion tombstone or revoked key.
- Do not alter the M1 contract blindly while extending the full API; maintain compatibility and generated Kotlin/C++ clients.

## Completion evidence (future)

This is a proposed endpoint registry. **Nothing is implemented by writing it.** Promote each gap to an executable OpenAPI operation only after the relevant screen action and legal availability are verified. For each: DB migration with RLS, authenticated C++ handler, typed parent/device/admin client, negative auth test, concurrency/idempotency tests, UI state snapshot and evidence file. Distinguish required/P3 from release-gated routes; deleted/unavailable features must return typed errors instead of fictional success.
