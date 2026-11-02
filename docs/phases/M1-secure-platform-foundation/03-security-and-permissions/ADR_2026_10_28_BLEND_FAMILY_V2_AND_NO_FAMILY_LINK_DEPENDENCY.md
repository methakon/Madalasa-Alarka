# ADR 2026-10-28: Blended-family authorization V2; no Google Family Link relationship API dependency

**Status: OWNER DECISION — logical design accepted for implementation; migration and Indian legal approval outstanding.** Supersedes all earlier `Google-supported parent account only`, `Google Family Link attestation hard launch gate`, and `sharing impossible until Google parent-role verification` assumptions. **Do not confuse removal of the Google-specific technical prerequisite with removal of parental/legal authority verification required by law.**

## Decision and source evidence

Google Family Link supports adding a second parent *within the Google family group*, through a manual Google interface: https://support.google.com/families/answer/7295768 . Its documented parent privileges are not a public developer relationship-attestation interface. Google Identity/OIDC verifies `iss`, `aud`, `exp` and stable `sub` for a signed-in account; **it does not assert any parent-child relationship**: https://developers.google.com/identity/sign-in/android/backend-auth and https://developers.google.com/identity/gsi/web/guides/verify-google-id-token . We have **not identified a documented public API** giving a consumer third-party app a signed `(adult Google sub, child Google sub, parent role)` claim. This is documentation evidence of unsupported integration, **not mathematical proof that no private or future Google service could ever exist**.

**Owner-approved replacement:** Google login verifies each adult independently; Madalasa's *own* child-specific grant workflow controls product access, independent of Family Link relationship lookup or shared Google family group membership. No automatic sharing by surname, household, new spouse, Family Link group, family billing membership or account import.

**Law separate:** DPDP Act Section 9 requires verifiable consent from a parent/lawful guardian for a child, subject to commencement and specific exceptions. A Google login or first parent's click alone **is not evidence of statutory legal parenthood**. Build a versioned `lawful_authority_review_state` and consent record; use only approved evidence/verification practice after Indian counsel/legal decision. For synthetic local tests use `LOCAL_TEST_APPROVED` fixture behind test-only flag; real-data production must fail-closed on the legal authority/consent gate until lawful process documented. Do not create a self-asserted consent shortcut.

## Concrete V2 scenario

- Adult A is the subscriber/payer for Child A and Child B (distinct parents).
- Adult B receives an invitation **for Child A only**; Adult C can separately be invited for Child B, even if B/C have their own billing family/profile. They authenticate with individual Google IDs, accept one-use invitation and receive only approved Child A/Child B scopes after applicable authority/consent checks. Co-parent never gains billing-owner permissions.
- Child A's seat can be shared across its approved adults without a second purchase. Unshared sibling Child B is not discoverable in B's UI, API counts, search, error messages, notifications or quota summaries.
- On relationship dispute, consent withdrawal, device deletion or guardian revoke, immediately deny access and invalidate viewer leases, service tokens, cached child data and signed URLs. Disputed access is suspended until a human-approved, legally supported resolution, **not** auto-granted to the bill payer.
- The visible Alarka child application should list currently authorized guardians when appropriate; important changes are disclosed and logged. Never grant camera/microphone/screen privileges merely because a new adult was invited.

## Physical database model: versioned migration (DESIGN ONLY, do NOT edit 0001)

Current `backend/persistence/migrations/0001_m1_identity.sql` has:
```sql
FOREIGN KEY (family_id,principal_id)
  REFERENCES ap_m1.guardian_memberships(family_id,principal_id)
```
in `child_guardian_grants`; and `has_scope()` inner-joins membership, denying authorized adults outside the payer's family. This is not suitable for blended-family co-parents and must be migrated, **not rewritten**.

**Proposed migration:** `0002_child_scoped_cross_family_guardians.sql` after M1 baseline; use expand/backfill/verify/switch/contract rather than destructively dropping FKs in production.

1. Add `ap_m1.child_access_invites` with `id, child_id, invited_by_adult_id, invited_google_sub_digest/contact_ref, one_time_secret_hash, expires_at, accepted_by_adult_id, accepted_at, state`; delivery must not leak existence of unshared siblings.
2. Add `ap_m1.child_authority_reviews` with `id, child_id, adult_id, claimed_relationship, state(PENDING/APPROVED/DISPUTED/REVOKED), lawful_basis_version, method_code, evidence_pointer_encrypted_nullable, reviewed_at, expires_at`; **APPROVED** only by a legally approved, auditable process. NO raw ID in publicly readable tables.
3. Add `ap_m1.child_access_grants_v2` with `id UUID PK, child_id UUID FK children(id), adult_id UUID FK parent_principals(id), scope, origin_invite_id FK, consent_record_id FK, issued_by, created_at, expires_at, revoked_at, revocation_epoch`. Deliberately **no** FK `(child.family_id,adult_id)` to `guardian_memberships`. Add unique partial index for one active `(child_id,adult_id,scope)`, not null scope, check expiry and disallow privilege escalation. No `BYPASSRLS` for API principals.
4. Keep `families`, `children.family_id`, `guardian_memberships` for **payer/family management**, and `child_paid_entitlements` for purchased child seats. Never confuse `member` with `child guardian`.
5. Implement audited `has_child_scope_v2(child_id,adult_id,scope)` to check valid invite acceptance, scope and nonrevoked grant, legal authority/consent gate where required, child/device status, revocation epoch and expiry. It must not rely on session's `ap.family_id` for child access. **Server**, not client, sets verified `ap.principal_id`. Read via RLS enforced by restricted grants or narrowly audited definer function. RLS conditions for all 15 M1 tables referencing family membership must be assessed, including `devices`, snapshots, `commands`, `pairing_codes`, `children`, `audit_events`; don't fix only the FK.
6. Phase backfill existing M1 family-bound grants as historical sources after checking lawful access; deny if verification cannot be supported, never silently widen permissions. Introduce `session/child revocation epochs` so revoke works with cache, offline device queues, concurrent premium viewer leases.
7. Cut over APIs to V2 authorization, establish non-superuser RLS policies and negative tests; only then retire old grant writes, preserve audited migration history. No automatic multi-family ownership transfer.

## Required V2 tests (must execute before marking implemented)

- Same family: Parent A sees only Child A, not ungranted Child B.
- Cross family: authorized B can read Child A but not Child B or billing-family metadata.
- Other family: authorized C cannot use B's token or another child's ID.
- Invite cannot be guessed/replayed; exact intended adult accepts; expired/revoked invite rejected.
- Malicious caller cannot set `ap.principal_id` or `ap.family_id` (DB session context created by verified backend only).
- Child A grant revocation/authority dispute closes active leases and cached views, but doesn't remove A's paid child seat.
- Synthetic legal gate can pass in LOCAL TEST only; no unchecked production consent.
- Owner payout and seat count remain restricted; no sibling metadata in API error payloads.
- Migration from v0001 tested in disposable PostgreSQL with existing `backend/tests/m1_tenant_isolation.sql` plus new `backend/tests/m2_blended_family_isolation.sql` (not yet implemented).
- If `has_child_scope_v2` uses a `SECURITY DEFINER`, audit its ownership, search_path, grants, predicates and bypass-RLS surface; never expose arbitrary query privileges.

## Local coding agent scope and approval

**No Google Family Link verification task or product gate remains.** Coding agents can implement synthetic invitation/acceptance/RLS flows, but any real child-data production enablement remains subject to India legal consent, child safety, Android and Play policies. Backend C++ code must be validated with SQL and API negative tests. Hosting region, OCI topology and actual bandwidth cost belong to separate **deployment** decision plan, not schema/API local blockers.

## Official references

- https://support.google.com/families/answer/7295768
- https://developers.google.com/identity/sign-in/android/backend-auth
- https://developers.google.com/identity/gsi/web/guides/verify-google-id-token
- https://www.meity.gov.in/documents/act-and-policies/digital-personal-data-protection-rules-2025-gDOxUjMtQWa
- https://www.meity.gov.in/static/uploads/2024/02/Digital-Personal-Data-Protection-Act-2023.pdf
