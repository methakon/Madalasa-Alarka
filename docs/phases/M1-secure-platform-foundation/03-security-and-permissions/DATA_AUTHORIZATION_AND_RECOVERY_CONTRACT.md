# Madalasa–Alarka — Canonical Data, Authorization, Event Recovery and Deletion Contracts

> **Document control:** M1 / 03-security-and-permissions · Proposed owner: Security + Android/backend (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

> **Current app names:** **Madalasa** (guardian/parent), **Alarka** (child companion). GitHub repository [Madalasa-Alarka](https://github.com/methakon/Madalasa-Alarka), renamed 2026-10-26. [Source story and naming contract](../../M0-foundation-and-approvals/02-market-and-feasibility/BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

**Version:** 1.0 (implementation design) | **Date:** 2026-10-25 | **Status:** NOT EXECUTED/NOT MIGRATED  
**Linked SRS:** FR-001, FR-006, FR-013, FR-022–FR-027, FR-029, FR-032, FR-034, FR-035, FR-040 and all data-bearing requirements.

## 1. Rules that cannot be relaxed

- Family is a tenant privacy boundary. Child is not the same entity as device. Multiple guardians and device sources can be independently assigned to one child.
- A family membership **does not itself** authorize viewing every child. A separate, unexpired, nonrevoked guardian-to-child grant and action scope are required.
- Parent account credentials and device credentials are distinct identity types; client-supplied family_id, role, grant or device_id cannot bestow permission.
- An ingest HTTP 202 response means a **durable server-side commit**: in the current preferred design, the authenticated GPS batch is committed in the **PostgreSQL inbox**, while raw GPS and reconstruction outbox are committed later by independent bulk workers; direct raw+outbox commit remains a benchmark alternative. In neither design does a 202 prove trip reconstruction. See MA-INGEST-ADR-004.
- Device event ID is stable across retries. A 200/202 response to a retry cannot represent a duplicate as a new observation.
- Clear separation of trusted raw records, inference and provider-derived map content. Do not persist Roads data contrary to licensing rules.
- Guardian revocation takes effect on API, SSE streams, cache access and token-bound session at authorization time; device revocation prevents offline reingest after reconnection.
- Before data deletion completes, all relevant caches, temporary exports, derived trips and pending worker jobs are fenced to prevent recreation of deleted data.

## 2. Logical model with referential invariants

| Table | Identity and unique constraints | Sensitive relationships | Retention |
|---|---|---|---|
| families | id PK, creator, region, state | root tenancy | until deletion |
| parent_principals | id PK, OIDC subject UNIQUE | identity only | provider/legal |
| guardian_memberships | (family_id, principal_id) UNIQUE | role + inviter + expiry | until revoked/deleted |
| children | (family_id, id) unique; child ID PK | family FK | until erased |
| child_guardian_grants | id PK; (family_id, child_id, principal_id) references validated family | scopes array/normalized rows, expiry, revoked_at, generation | revoke/review |
| devices | id PK; (family_id, child_id) composite FK to children | enrolled key fingerprint, mode, capabilities, revoked_at | until unpair/deletion |
| device_key_records | key_id PK; device_id FK, status, rotation epoch | Keystore proof reference, no secret key | short after revoke |
| location_event_dedup | (device_id,event_id) PK, observed bucket, digest | prevents replay across time partitions | retention-safe |
| location_observations | (device_id, observed_at, event_id) PK including partition key | family_id, child_id, accuracy, source, flags | policy-controlled |
| device_latest_position | device_id PK; observed_at, event_id, quality | compare-and-set update only | recent state |
| named_places | id PK; family_id + child_id; version | title, location, radius, category | user-managed |
| trips/stops/segments | versioned composite key (device_id, trip_id, revision) | source event-range, provisional state | policy |
| reconstruction_jobs | id PK; device_id, affected interval, state, lease epoch | work dedupe/coalescing | short operational |
| device_reconstruction_lock | device_id PK, lease_epoch | fence stale workers | until device deletion |
| privacy_access_receipts | id PK; actor, child, action, coarse time | no raw GPS in audit | policy |
| deletion_tombstones/jobs | family/child/device, generation, state, deadlines | prevent reingest and resurrection | legal/safety |
| subscriptions | account/provider transaction ref UNIQUE | product/grace/refund | financial legal |

**Referential implementation:** child must reference its family; device and named place must reference the correct family+child pair; grants must match both family and real principal membership; do not use a single naked child_id join if queries can cross tenants.

## 3. Example migration fragments (illustrative, review before running)

~~~sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE families (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 state text NOT NULL DEFAULT 'ACTIVE',
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE children (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 family_id uuid NOT NULL REFERENCES families(id),
 display_name text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE (family_id,id)
);
CREATE TABLE devices (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 family_id uuid NOT NULL,
 child_id uuid NOT NULL,
 mode text NOT NULL CHECK (mode IN ('STANDARD','MANAGED')),
 revoked_at timestamptz,
 UNIQUE (family_id,id),
 FOREIGN KEY (family_id,child_id) REFERENCES children(family_id,id)
);
CREATE TABLE child_guardian_grants (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 family_id uuid NOT NULL,
 child_id uuid NOT NULL,
 principal_id uuid NOT NULL,
 scope text NOT NULL,
 valid_from timestamptz NOT NULL DEFAULT now(),
 expires_at timestamptz,
 revoked_at timestamptz,
 generation bigint NOT NULL DEFAULT 1,
 FOREIGN KEY (family_id,child_id) REFERENCES children(family_id,id),
 CHECK (expires_at IS NULL OR expires_at > valid_from)
);
CREATE INDEX grants_authorization_idx
ON child_guardian_grants(principal_id,child_id,scope,revoked_at,expires_at);
CREATE TABLE named_places (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 family_id uuid NOT NULL,
 child_id uuid NOT NULL,
 title text NOT NULL CHECK (char_length(title) BETWEEN 1 AND 100),
 location geography(Point,4326) NOT NULL,
 radius_m integer NOT NULL CHECK(radius_m BETWEEN 50 AND 2000),
 row_version bigint NOT NULL DEFAULT 1,
 FOREIGN KEY (family_id,child_id) REFERENCES children(family_id,id)
);
CREATE INDEX places_geo_idx ON named_places USING gist (location);
CREATE TABLE device_event_dedup (
 device_id uuid NOT NULL REFERENCES devices(id),
 event_id uuid NOT NULL,
 event_digest bytea NOT NULL,
 first_seen_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY (device_id,event_id)
);
CREATE TABLE location_observations (
 family_id uuid NOT NULL,
 device_id uuid NOT NULL,
 event_id uuid NOT NULL,
 observed_at timestamptz NOT NULL,
 received_at timestamptz NOT NULL DEFAULT now(),
 latitude double precision NOT NULL CHECK (latitude BETWEEN -90 AND 90),
 longitude double precision NOT NULL CHECK (longitude BETWEEN -180 AND 180),
 accuracy_m double precision NOT NULL CHECK (accuracy_m >= 0),
 speed_mps double precision,
 provenance text NOT NULL,
 PRIMARY KEY (device_id,observed_at,event_id),
 FOREIGN KEY (family_id,device_id) REFERENCES devices(family_id,id)
) PARTITION BY RANGE(observed_at);
CREATE INDEX observation_device_time_idx ON location_observations(device_id,observed_at);
~~~

The parent time-partitioned primary key includes observed_at because PostgreSQL requires the partition key in a partitioned UNIQUE/PRIMARY KEY. **Cross-partition stable event_id dedupe** is enforced in the separate device_event_dedup ledger, atomically with the raw insert. A duplicate event ID with altered payload digest is a conflict/security signal (do not overwrite accepted raw content). Maintain partition creation and a safe policy for late events targeting expired partitions. The ledger must outlive the maximum allowed device retry/offline replay horizon, or the service must reject events older than the oldest replay-safe time boundary; it cannot simply expire dedup tokens and then accept arbitrary historic replays.

## 4. Authorization matrix (deny by default)

| Resource and action | Family owner | Explicit guardian | Pickup viewer | Child device | Support |
|---|---|---|---|---|---|
| View latest child location | YES if child grant | Scoped grant | Child-specific, TTL, current/recent only | NO | NO default |
| View historic trips/stops | YES if child grant | Optional history grant/range | NO | NO | NO default |
| Change named places | YES | If manage_places | NO | NO | NO |
| Read app usage | YES | If view_usage | NO | NO | NO |
| Issue device restriction | YES if device + capability | Only if manage_policy | NO | NO | NO |
| Child SOS subscribe/ack | YES if receive_sos | If receive_sos | Optional separate explicit scope | Raise for self | NO |
| Edit guardian membership | OWNER only | NO unless delegated as a signed product decision | NO | NO | NO |
| Grant temporary pickup access | OWNER only as safe default | NO | NO | NO | NO |
| Device data batch ingest | NO | NO | NO | Only for own enrolled device | NO |
| Export/delete family records | OWNER + step-up | NO by default | NO | NO | NO default |
| Access diagnostic logs | Own sanitized information | Own authorized child if granted | NO | Upload redacted diagnostics | Named support case only |

No permission comes from a family name, guessed URL, or merely holding a JWT. Signed-in owner/guardian status AND action-specific grant AND feature availability must all pass.

### Auth enforcement sequence

1. Verify parent OIDC token signature, issuer, audience, expiry and required auth strength or verify device proof with nonce/expiry/revocation.
2. Look up current family membership and child-specific scope from authoritative DB, not cached unchecked client claims.
3. Authorize target resource and subscription/capability separately.
4. Within DB transaction set **trusted transaction-local tenant context**, execute all SQL under low-privilege role.
5. Apply child-level row conditions for reads/writes; encode generation/last_revoked epoch in cache keys and SSE audience.
6. On revoke, bump generation, invalidate cache and actively terminate or reauthorize SSE; reject new operations.
7. Emit audit with actor, child, permission scope and result code, **not raw coordinates**.

### PostgreSQL RLS defense in depth

~~~sql
ALTER TABLE named_places ENABLE ROW LEVEL SECURITY;
ALTER TABLE named_places FORCE ROW LEVEL SECURITY;
CREATE POLICY places_tenant_read ON named_places FOR SELECT
  USING (family_id =
    NULLIF(current_setting('app.family_id',true),'')::uuid);
CREATE POLICY places_tenant_write ON named_places FOR INSERT
  WITH CHECK (family_id =
    NULLIF(current_setting('app.family_id',true),'')::uuid);
-- Add explicit UPDATE and DELETE policies plus child-grant controller checks.
~~~

Production app SQL login must not be superuser, owner or BYPASSRLS. Context set from authenticated request only with SET LOCAL inside transaction; pooled connection must not retain prior family context. Family filter alone is insufficient for a guardian granted only one child. Use bounded service worker role and trusted internal APIs, not a generally accessible bypass credential.

**Reference:** https://www.postgresql.org/docs/current/ddl-rowsecurity.html

## 5. Durable ingestion: exact transaction semantics

1. Authenticate device and confirm active enrollment; reject if deletion tombstone/revoked.
2. Validate count/bytes, JSON schema, timestamps, finite coordinate bounds, rate limits, event ids, maximum past age and clock skew policy.
3. Start DB transaction, using authoritative family_id/child_id from device enrollment.
4. For each event, compute canonical data digest. Insert device_event_dedup (device_id,event_id,digest) ON CONFLICT DO NOTHING. On conflict compare digest; exact match is DUPLICATE, mismatch is CONFLICT.
5. For newly accepted events only insert into correct time-partitioned location_observations table. If target partition missing, reject with safe timestamp error or create partition via planned migration process, not ad-hoc untrusted DDL.
6. Update latest position only if quality is accepted and observed_at strictly newer than old latest, considering revoked/expired devices.
7. Append/coalesce a reconstruction job/outbox in same transaction for accepted timestamps, and append minimal ingestion audit/receipt.
8. COMMIT, then respond 202 with per-event accepted/duplicate/rejected IDs and processing=pending.
9. If connection drops before ack, child retries stable same event IDs; the durable dedup ledger ensures idempotent business effect.

**Exactly-once network delivery is not assumed.** The desired property is **at-least-once transport with exactly-once accepted-event effect**, enforced transactionally.

## 6. C++ reconstruction workers: fencing and correction

- Key logical work by device_id so only one active reconstruction writer may own a device.
- Claim work using PostgreSQL SKIP LOCKED on queue rows and increment a **monotonic lease_epoch** in a device_reconstruction_lock row.
- Claim+epoch issuance is atomic. Worker carries device_id + lease_epoch + algorithm_version.
- Process outside claim transaction using bounded windows and observations sorted by observed_at. Keep provisional checkpoints.
- On writing trips/stops, begin transaction, lock the lock-row and check current lease_epoch == worker epoch **and** device still active/nondeleted; stale writer must abort without commit.
- Replace/revise derived intervals atomically with revision increment, reason LATE_DATA / ALGORITHM_UPGRADE and outbox notification.
- Lease timeouts and crash retries are at-least-once. A periodic reconciler finds events with no completed processing and poisoned jobs; capped exponential retries and dead-letter review.
- Offline observations older than normal lateness window trigger targeted bounded backfill; a record older than published retention is rejected, not resurrected.
- Do not acknowledge trip reconstruction as complete until persisted; ingestion completion and trip processing completion are separate states.

PostgreSQL SKIP LOCKED is suitable for queue consumers but yields an inconsistent view, so **not** a general application query consistency primitive.

## 7. Deletion and revocation transaction ordering

**Stop collection/authorization before deletion:**
1. Verify guardian owner and step-up account authorization; record idempotent deletion request.
2. Revoke all device credentials, grants, OAuth references and active access tokens; mark family/child/deletion tombstone and increment auth epochs, invalidate cache/SSE.
3. Stop pending commands and reconstruction jobs, and fail future child ingest fast even if an offline phone reconnects.
4. Delete derived trips/stops/segments and raw locations **across all time partitions**, usage aggregates, media records, places, snapshots, support exports, billing metadata subject to lawful retention and application logs according to policy.
5. Delete selected cloud media and any app-owned Drive copies where authorized; explicitly clarify ownership/limits of parent-owned Drive data.
6. Record job progress, exponential retry and irreversible completion or real failure; never claim success after merely queuing a deletion.
7. Enforce backup expiry or restore-time erasure manifest so restored database cannot resurrect an erased child/family. Document legally retained limited records and retention dates.

**Unpair vs delete:** unpair stops new access/sync, while old history may remain under explicitly selected retention. Delete account has larger scope. Temporary guardian revoke restricts that guardian's access; does not automatically delete every family record.

## 8. C++/Kotlin key and storage rules

- Child per-device private key should be generated inside Android Keystore if device supports it; never exported into backend. On reinstall/key invalidation, require approved re-enrollment and revoke old key.
- SQLite is not encrypted by default. Select reviewed SQLCipher or envelope-encrypted payload store with Android Keystore-protected key. Document direct-boot behavior, backup exclusions and how queued data is discarded safely when account is revoked.
- Parent mobile OIDC flow with PKCE, secure token refresh and short-lived access credentials; step-up for deletion/sharing where configured.
- Use vetted TLS/crypto, never a hand-written C++ JWT validator or encryption scheme. Redact sensitive request bodies and raw GPS from normal logs/metrics.
- Backup keys and OAuth refresh tokens held in managed secret system, least-privilege role and rotation process.

## 9. Outstanding choices and proof gates

This document defines **how** the data boundary should work but does not supply executable migrations, tested RLS, real cloud backup/deletion, or a passing load test. Unresolved owner choices: retention periods, hosting region, guardian invite policy, legal authority and supported countries. See [Blockers and Owner Decisions](../../M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md), B-02/B-07/B-08/B-09/B-18.

Before release: migration apply/rollback in isolated DB; cross-family and child-scope negative tests; 3h-late ingest/replay; retry with digest mismatch; expired worker epoch attempt; private location leak scans; deletion-restore rehearsal with an offline child device.

## Primary references

- https://www.postgresql.org/docs/current/ddl-partitioning.html
- https://www.postgresql.org/docs/current/ddl-rowsecurity.html
- https://www.postgresql.org/docs/current/sql-select.html
- https://postgis.net/docs/ST_DWithin.html
- https://owasp.org/API-Security/

## 10. Guardian-authority and Indian legal scope qualification

**Implementation default pending owner approval:** only an independently verified family owner can create/revoke child-specific guardian grants, no default history scope, pickup current-location-only and ≤45-minute candidate TTL. These are architectural protections, **not settled guardian/authority policy B-09/B-18**. Enforce RBAC and DB RLS separately from any legal adult identity/parental authority verification. A Google Sign-In account token does not prove custody.

India's DPDP s.9/rules 10/12 may permit only a narrow real-time safety location purpose; do not populate location_observations, trips/stops, usage tables or SOS recipient fanout with **real Indian minors' data** until the corresponding purpose and India-to-US Chicago transfer have been signed off by counsel and owner. For real pilot use a server-side deny-by-default purpose registry with versioned verification/consent receipt and revoke epoch; never allow client claims to override legal denial. [India legal release gate](../../M0-foundation-and-approvals/03-legal-and-privacy/INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md).

Retention: raw 14d, derived 90d, usage OFF, audit 365d, backup 30d are only engineering candidates, not signed processing commitments. Revocation, erasure across time-partitioned data and restored backups remain implementation testing gates.

## 2026-10-27 latest capability snapshot trust/recovery contract

[MA-CAP-ADR-002](CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md) adds owner-accepted design of Alarka pairing-bound capability snapshots. Proposed DB entity `device_capability_snapshots` enforces device_id PK, enrollment generation, report version, observed_at, server received_at, schema version and allowlisted bounded feature payload; `device_capability_changes` holds minimal time/reason history with explicit TTL. Device credential self-scope is the only report writer; parent GET requires current family/child-specific authorization and safe redaction. No parent-submitted "Android granted" bit is authoritative.

**Recovery invariants:** only accept a higher version within same generation, same version+digest idempotent, same version+different digest conflict, old generation or revoked device denied. Authenticated server ACK after commit, then parent update hint. Recover from retry/out-of-order/FCM loss through canonical GET; do not resurrect an old GRANTED state after revoked-version backup/restore. On family/device deletion, tombstone/report purge and cache/incremental sync invalidation must prevent offline reingest. Child force-stop/revocation may delay a report, so parent always shows last-verified time and STALE/UNKNOWN on missing fresh evidence. No raw GPS or audio/video in capability report.

## 2026-10-27 media activity metadata, append events and restricted admin read design

[Media Activity Audit ADR](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_ACTIVITY_AUDIT_LOGGING_AND_REPORTING_2026.md) and [Admin Console Specification](../../P3-deferred-research/01-media-and-administrator-research/ADMIN_PANEL_SPECIFICATION_2026.md) add planned (not migrated) data objects media_activity (one safe summary per permitted request, family/child/device/requesting guardian IDs, media_kind/action/outcome, request_at, nullable verified capture start/end/active_duration_ms/file_size_bytes/bytes_transferred, storage_outcome, reason_code+evidence) and append-only media_activity_events (source_id+unique event_id, verified evidence). Parent-local saves are a historical receipt only, not retrievable server files; VPS DB never holds audio/images/video, thumbnails, file paths or transcripts. Admin reads write separate admin_access_audit with actor, approved case/purpose/expiry, filtered scope, count/result and request ID.

Security invariants: scope authorization at both C++ Drogon controller and Postgres RLS; only enrolled child and approved parent source receipts can mutate event stream. Admin role does not imply unrestricted parent/child query; must prove step-up + case-specific subject scope even for name/ID autocomplete. Query by family+child+request_at and guardian+time; stable opaque keyset cursor, parent/child/date restrictions remain enforced on **every page**. Same source_event_id duplicate has idempotent result, conflicting digest is quarantined, late reconciliation appends new event rather than erasing original. False reported VIEWED_ONLY/SAVED_PARENT_LOCAL are never marked verified without parent display/local storage receipt.

Deletion/recovery: include events, summary projections, indexes/caches, bounded access audit and backups in category-specific deletion/retention matrix. Parent/child account deletion prevents late Android/parent re-ingest; qualified legal hold requires counsel and data subject process; never silently recreate deleted logs on restore/replay. Test RLS cross-family, admin scope, revocation, restore, expired case and audit fail closed. **NOT_IMPLEMENTED / NOT_MIGRATED.**

## 2026-10-27 addendum: accepted two-transaction inbox and bulk durability contract

The opening invariant that an ingest success commits `raw observations + reconstruction outbox` is **superseded for the default location-batch route** by [MA-INGEST-ADR-004](../../M2-location-collection/01-location-collection-and-ingestion/POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md). The same durability principle holds, but its **ACK boundary changes**: the preferred C++20 Drogon POST may respond 202 after durable **location_ingest_inbox** batch transaction COMMIT (Tx A) with `processing=QUEUED`, even when raw observations have not yet been inserted. The previous Tx-A raw+dedup+outbox direct commit is retained solely as *Option B load-test control*. No success before durable storage in either mode.

**Tx A:** authenticated enrolled device/self scope and family/child generation; event count/bytes/schema/time/coordinate checks; unique(device_id,batch_id) and batch digest; one inbox payload per verified upload. Replaying same ID and digest yields idempotent receipt; different digest yields conflict. Deleting child queue occurs only for positively durable-ACKed batches, never for timeout/uncommitted/memory-only queue. **Tx B:** C++ worker claims bounded inbox batches with SKIP LOCKED leases+fencing, merges into prepared bulk/optional COPY temp staging, commits event dedup ledger + final time-partitioned raw GPS + reconstruction outbox + inbox PROCESSED **atomically**. Recovery re-leases on worker/API crash; quarantine poison/stale lease, do not silently lose ACKed data. The inbox is sensitive temporary raw GPS content, protected by child-bound roles/RLS, retention, encrypted backups and deletion tombstones; no parent or general support reads it directly.

Existing `device_event_dedup`, partition-key uniqueness constraints, guardian isolation, account deletion/backup restore and 48h late-data boundaries remain. Correct client parent-facing statuses: `INBOX_COMMITTED` does not mean route reconstructed, latest GPS only from verified raw/qualified state, no guessed live position. Include T-ING-01…24 in the evidence chain. Parent grants still determine who may read raw/processed data; child revocation blocks future replay even if offline queue still exists.

## 2026-10-28 child-specific verification and screen-lease authorization

A payer's family account does NOT confer access to all children. Authorization tuple is `(verified_adult_identity, child_id, allowed_scopes, parent_relationship_verification_state, grant_epoch)`; child-specific relationship must be approved before any co-parent reading/capture. Google Account identity or Google group invitation is not proof of verified Family Link parental role. Strict owner requirement: block shared access until a supported, auditable child-specific Google-parent verification method is found and independently approved. Pending states do not grant data; no support-bypass without owner/legal policy revision. Revoke child-adult scopes and signed URLs upon relationship change/child deletion and immediately close affected viewer sessions.

Premium viewer lease admission key `child_id`, `adult_id`, `device_session_id`; backend grants capacity one per paid child plus valid separately purchased child-scoped extra slots. Leases ~60–90s TTL, heartbeat ~20s (tunable), atomic count, server-time enforcement, last-seen cleanup, idempotent acquire, permission/grant/prepaid/feature rechecks. A shared guardian token cannot duplicate a seat. One concurrent viewer cap does NOT restrict free basic location or emergency rights. Session tokens bound to role and single device; no hidden screen recording or Android MediaProjection permission bypass. Google Play consumable tokens verified and assigned once, refunds/revocations remove unused capacity and extra media pool. Details: https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/CHILD_SPECIFIC_GOOGLE_PARENT_SHARING_AND_CONCURRENT_SCREEN_ADDONS_2026.md.

### 2026-10-28 non-destructive base lapse for purchased 100-day add-on

The server-signed extra-viewer capacity grant expires exactly 100 calendar days after verified activation, unaffected by base monthly/yearly expiry. A base lapse immediately denies new premium leases, revokes active premium streams, and preserves the purchase grant (and any unspent 30 combined AV minutes) in a **dormant** state until day 100; on verified manual renewal of the same child prepaid plan, normal child/adult authorization checks reactivate it until its original end. Revoked guardian authority, deleted child/account, refunds and security sanctions are distinct overriding access controls; do not retain illegal child data merely to honor remaining add-on time. All client countdowns derive from UTC server timestamps. https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/CHILD_SPECIFIC_GOOGLE_PARENT_SHARING_AND_CONCURRENT_SCREEN_ADDONS_2026.md.

## 2026-10-28 admin owner access / privacy / operations amendment

Separate web back-office authorization, isolated from parent/child identities. Only securely bootstrapped **verified Google account** `swarna.s.jobs@gmail.com` with durable Google OIDC `sub` and MFA can approve/reject admin access requests or grant/revoke staff roles. Any other Google login starts as `NO_ACCESS`. Applicants fill name, address, DOB, gender, contact email, confirm authoritative Google email or expiring independent email challenge, and may submit only after email verification plus profile validation. DOB/gender/address collection must receive necessity/consent/retention approval. Owner receives minimal notification and reviews private profile in owner dashboard; not via plaintext Gmail.

Access to FAQ authoring, support replies, subscriber/prepaid/payment statuses, minimal child alias/paid-seat roster, and parent **service access** duration/outcome logs is separately RBAC-gated. Child live location/trips, app activity, media content, files, messages, and device secrets are excluded even for ROOT_OWNER. Named sensitive media activity requires separate approved case-scoped `MEDIA_AUDIT_READ`, step-up and append-only access audit; neither Gmail login nor owner title overrides that. Session revocation on role changes, CSRF protections, opaque IDs, no PII in notifications, no card details or raw Play purchase tokens in API payloads. Plan admin domain in [ERD-10](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=108-2); full contract: https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/P3-deferred-research/01-media-and-administrator-research/ADMIN_OWNER_GOOGLE_ACCESS_FAQ_SUPPORT_BILLING_AND_USAGE_2026.md. Nothing implemented/tested by documentation.


## OWNER SUPERSESSION — 2026-10-28: drop Google Family Link parental-role API dependency

**New decision overrides every older claim in this document that a co-parent may be invited ONLY if Google's Family Link parental role is programmatically verified, or that no sharing is possible until a public Family Link attestation API appears.** Google sign-in still verifies each adult independently (`iss/aud/sub/exp`). Madalasa's backend uses an exact-child single-use invitation, separately accepted and revocable scoped grants, device/child transparency, dispute hold, no sibling disclosure and security/authorization tests. **Legal verification of adult parental/lawful guardian authority and valid child-data consent is a distinct mandatory compliance gate, NOT waived**; synthetic local tests may use controlled fixtures, real child processing requires approved lawful method. A paid family seat is never a guardian permission and a second adult never inherits the entire family's children. See [V2 ADR](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/ADR_2026_10_28_BLEND_FAMILY_V2_AND_NO_FAMILY_LINK_DEPENDENCY.md) and [India legal brief](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/INDIA_CHILD_CONSENT_RETENTION_DELETION_ACTION_BRIEF_2026-10-28.md). Use new versioned DB migration, do not mutate M1 baseline. This is design only; no verified runtime has been built.
