# Frozen historical M1 physical table catalog — through0004

**Archived source snapshot, not a separately maintained current report.** Source:
`b507e5f47e78d453db2703d02a3d80dcb45fa1dc`, M1 migrations0001–0004 only.
The original mapping bytes are preserved in `M1_PHYSICAL_TO_LOGICAL_CATALOG.json`;
they are historical evidence, not the runtime/default checker input. Do not regenerate
this frozen snapshot with the current mapping. The maintained current historical M1
report (through0006, including retention holds) is
[`../../M1_PHYSICAL_TABLE_CATALOG.md`](../../M1_PHYSICAL_TABLE_CATALOG.md).

- Physical tables (schema `ap_m1`, manifest-selected `m1` lineage): **18**
- Logical ERD entities: **120**; mapped to a physical table: **17**; not yet physical (M2 and later, design only): **103**
- Physical tables with no ERD entity: **1**

The ERD is a conceptual design; the migrations are what actually exists. Every difference below is known and recorded. The largest one is the tenant model: M1 is family-scoped with forced row-level security, while the owner-approved ERD V2 is child-scoped. This is the historical M1-only checkpoint, not the converged runtime. See `../local-postgresql/README.md` for V2 execution evidence.

| Physical table | ERD entity | Renamed columns | Physical only | ERD only |
|---|---|---|---|---|
| `families` | `families` | `state` → `status` | `label` | `billing_owner_id`, `founding_rank`, `revocation_epoch` |
| `parent_principals` | `adult_accounts` | - | `created_at` | `adult_authority_state`, `disabled_at`, `google_identity_verified_at` |
| `guardian_memberships` | `family_memberships` | `principal_id` → `adult_id`, `membership_role` → `role` | `created_at` | - |
| `children` | `children` | `family_id` → `home_family_id` | `alias`, `created_at`, `state` | `deleted_at`, `device_status`, `display_name`, `erasure_epoch` |
| `child_guardian_grants` | `child_access_grants_v2` | `principal_id` → `adult_id`, `scope` → `scopes`, `expires_at` → `expires`, `revoked_at` → `revoked` | `created_at`, `family_id` | `authority_review_id`, `revocation_epoch` |
| `pairing_codes` | `pairing_codes` | `code_sha256` → `code_hash`, `issued_by` → `issued_by_adult_id` | `attempt_count`, `created_at`, `family_id` | - |
| `devices` | `child_devices` | - | `algorithm`, `created_at`, `family_id`, `spki_public_key` | `android_api`, `device_mode`, `last_seen_at`, `public_key_ref` |
| `enrollment_challenges` | `enrollment_challenges` | `nonce_sha256` → `challenge_hash` | `created_at`, `redeemed_at` | `audience`, `state` |
| `device_key_records` | `device_key_records` | `fingerprint_sha256` → `fingerprint_hash` | `created_at` | `key_epoch` |
| `capability_snapshots` | `capability_snapshots` | `features` → `supported_features`, `device_mode` → `management_mode` | `is_device_owner`, `received_at` | `os_reject_reasons` |
| `device_health` | `device_health` | `battery_percent` → `battery_pct` | `observed_at`, `permission_revision`, `recorded_at` | `last_seen_at`, `network_status`, `queue_pressure` |
| `commands` | `device_commands` | `created_by` → `initiator_adult_id`, `command_type` → `type`, `command_state` → `state` | `created_at`, `family_id` | `child_id`, `idempotency_key`, `reason_code` |
| `command_results` | `command_results` | `outcome` → `result_code`, `recorded_at` → `received_at` | `observed_at` | `device_proof`, `failure_reason` |
| `audit_events` | `security_audit_events` | `observed_at` → `occurred_at`, `result_code` → `outcome` | `actor_device_id`, `actor_principal_id`, `family_id` | `actor_ref`, `child_ref`, `digest`, `trace_id` |
| `revocation_epochs` | `family_revocation_epochs` | `generation` → `epoch`, `updated_at` → `changed_at` | - | - |
| `idempotency_keys` | `idempotency_claims` | `key_sha256` → `key_hash`, `actor_id` → `actor_ref` | `body_omitted`, `completed_at`, `request_sha256`, `response_body`, `response_status` | `result_digest` |
| `device_credentials` | `device_sessions` | `token_sha256` → `token_hash`, `key_id` → `bound_key_id` | `issued_at`, `issued_via` | `latest_ip_hash` |

## Notes per table

- **`families`**: M1 is family-scoped. Billing owner, founding rank and the revocation epoch belong to later milestones; the revocation generation is kept in revocation_epochs. `label` is M1-only.
- **`parent_principals`**: M1 stores only the OIDC identity. Google verification time, adult-authority state and disable time are not modelled until the consent and authority work (ADR child-scoped V2).
- **`guardian_memberships`**: Same shape; two renamed columns and a created_at. revoked_at exists on both sides.
- **`children`**: Tenant-model difference: M1 children belong to exactly one family (family_id); the ERD names it home_family_id and adds cross-family V2 access. Physical `alias` replaces encrypted display_name for synthetic M1 data. Erasure epoch, deletion time and device_status are later work.
- **`child_guardian_grants`**: M1 grants are inside one family and carry family_id for row-level security. The ERD grant is cross-family and needs an authority review and a revocation epoch (V2); not implemented.
- **`pairing_codes`**: Physical adds family_id (RLS), attempt_count (20-attempt cap) and created_at.
- **`devices`**: Physical stores the SPKI public key and algorithm directly; the ERD keeps only an opaque public_key_ref. android_api and device_mode live in capability_snapshots in M1; last_seen_at is not stored.
- **`enrollment_challenges`**: Physical records both consumed_at (challenge spent, migration 0001) and redeemed_at (activation completed, migration 0003) instead of a state enum, and has no audience column (one purpose in M1).
- **`device_key_records`**: No key_epoch in M1: key rotation is out of scope (decision C-06).
- **`capability_snapshots`**: Physical stores android_api and device_mode (assumed equal to the ERD management_mode; confirm when the ERD is revised) plus is_device_owner and received_at; os_reject_reasons is not stored in M1.
- **`device_health`**: One current row per device (device_id is the key, as in the ERD). M1 stores battery, charging, permission revision and observed/recorded times; network status, queue pressure and last_seen_at are later work.
- **`commands`**: Physical carries family_id (RLS). child_id, reason_code and the idempotency_key column are not stored on the row: idempotency lives in idempotency_keys.
- **`command_results`**: Device proof and failure_reason are not stored in M1 (proof is verified at enrollment and renewal only, decision C-03).
- **`audit_events`**: M1 audit rows reference the acting principal or device in two columns instead of one actor_ref, and have neither child_ref, digest nor trace id.
- **`revocation_epochs`**: Same purpose; renamed columns.
- **`idempotency_keys`**: Deliberate deviation (migration 0004): the primary key includes the actor so callers cannot collide or probe each other; the table also stores the request hash and the response so a replay can be answered. Reconcile the ERD entity with this design.
- **`device_credentials`**: Short-lived opaque device bearer credential (decision C-01). Physical adds issued_at and issued_via; latest_ip_hash is not stored.

## Physical tables without an ERD entity

- **`credential_renewal_challenges`**: Introduced by migrations 0002/0003 (device credential renewal). The ERD has no entity for single-use renewal challenges; add one next to device_sessions when the ERD is next revised.
