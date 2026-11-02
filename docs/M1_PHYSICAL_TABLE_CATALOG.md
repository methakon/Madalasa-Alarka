# M1 physical table catalog (generated)

Generated from `docs/data-model/M1_PHYSICAL_TO_LOGICAL_CATALOG.json` by `backend/tests/check_physical_catalog.py --write`. **Do not edit by hand**; edit the JSON and regenerate. CI fails if this file is stale or if the migrations or the ERD drift from the mapping.

- Physical tables (schema `ap_m1`, manifest-selected common + M1 through0006 only): **18**
- Logical ERD entities: **120**; mapped to a physical table: **17**; not yet physical (M2 and later, design only): **103**
- Physical tables with no ERD entity: **1**

The ERD is a conceptual design; the migrations are what actually exists. Every difference below is known and recorded. The largest one is the tenant model: M1 is family-scoped with forced row-level security, while the owner-approved ERD V2 is child-scoped (see `ADR_2026_10_28_BLEND_FAMILY_V2`). This report describes the historical M1 baseline through0006, not the converged V2 runtime. See `data-model/local-postgresql/README.md` for separately scoped V2 execution evidence; `data-model/historical-m1/PHYSICAL_TABLE_CATALOG.md` is the frozen source-through0004 snapshot, not a second current report.

| Physical table | ERD entity | Renamed columns | Physical only | ERD only |
|---|---|---|---|---|
| `families` | `families` | `state` → `status` | `label` | `billing_owner_id`, `founding_rank`, `revocation_epoch` |
| `parent_principals` | `adult_accounts` | - | `created_at` | `adult_authority_state`, `disabled_at`, `google_identity_verified_at` |
| `guardian_memberships` | `family_memberships` | `principal_id` → `adult_id`, `membership_role` → `role` | `created_at` | - |
| `children` | `children` | `family_id` → `home_family_id` | `alias`, `created_at`, `state` | `deleted_at`, `device_status`, `display_name`, `erasure_epoch` |
| `child_guardian_grants` | `child_access_grants_v2` | `principal_id` → `adult_id`, `scope` → `scopes`, `expires_at` → `expires`, `revoked_at` → `revoked` | `created_at`, `family_id` | `authority_review_id`, `revocation_epoch` |
| `pairing_codes` | `pairing_codes` | `code_sha256` → `code_hash`, `issued_by` → `issued_by_adult_id` | `attempt_count`, `created_at`, `family_id`, `retention_hold` | - |
| `devices` | `child_devices` | - | `algorithm`, `created_at`, `family_id`, `retention_hold`, `spki_public_key` | `android_api`, `device_mode`, `last_seen_at`, `public_key_ref` |
| `enrollment_challenges` | `enrollment_challenges` | `nonce_sha256` → `challenge_hash` | `created_at`, `redeemed_at`, `retention_hold` | `audience`, `state` |
| `device_key_records` | `device_key_records` | `fingerprint_sha256` → `fingerprint_hash` | `created_at` | `key_epoch` |
| `capability_snapshots` | `capability_snapshots` | `features` → `supported_features`, `device_mode` → `management_mode` | `is_device_owner`, `received_at` | `os_reject_reasons` |
| `device_health` | `device_health` | `battery_percent` → `battery_pct` | `observed_at`, `permission_revision`, `recorded_at` | `last_seen_at`, `network_status`, `queue_pressure` |
| `commands` | `device_commands` | `created_by` → `initiator_adult_id`, `command_type` → `type`, `command_state` → `state` | `created_at`, `family_id` | `child_id`, `idempotency_key`, `reason_code` |
| `command_results` | `command_results` | `outcome` → `result_code`, `recorded_at` → `received_at` | `observed_at` | `device_proof`, `failure_reason` |
| `audit_events` | `security_audit_events` | `observed_at` → `occurred_at`, `result_code` → `outcome` | `actor_device_id`, `actor_principal_id`, `family_id` | `actor_ref`, `child_ref`, `digest`, `trace_id` |
| `revocation_epochs` | `family_revocation_epochs` | `generation` → `epoch`, `updated_at` → `changed_at` | - | - |
| `idempotency_keys` | `idempotency_claims` | `key_sha256` → `key_hash`, `actor_id` → `actor_ref` | `body_omitted`, `completed_at`, `request_sha256`, `response_body`, `response_status` | `result_digest` |
| `device_credentials` | `device_sessions` | `token_sha256` → `token_hash`, `key_id` → `bound_key_id` | `issued_at`, `issued_via`, `retention_hold` | `latest_ip_hash` |

## Notes per table

- **`families`**: M1 is family-scoped. Billing owner, founding rank and the revocation epoch belong to later milestones; the revocation generation is kept in revocation_epochs. `label` is M1-only.
- **`parent_principals`**: M1 stores only the OIDC identity. Google verification time, adult-authority state and disable time are not modelled until the consent and authority work (ADR child-scoped V2).
- **`guardian_memberships`**: Same shape; two renamed columns and a created_at. revoked_at exists on both sides.
- **`children`**: Tenant-model difference: M1 children belong to exactly one family (family_id); the ERD names it home_family_id and adds cross-family V2 access. Physical `alias` replaces encrypted display_name for synthetic M1 data. Erasure epoch, deletion time and device_status are later work.
- **`child_guardian_grants`**: M1 grants are inside one family and carry family_id for row-level security. The ERD grant is cross-family and needs an authority review and a revocation epoch (V2); not implemented.
- **`pairing_codes`**: Physical adds family_id (RLS), attempt_count (20-attempt cap), created_at and migration0006 retention_hold. The hold preserves this pairing artifact only; no redeemed-device FK is inferred.
- **`devices`**: Physical stores the SPKI public key and algorithm directly; the ERD keeps only an opaque public_key_ref. android_api and device_mode live in capability_snapshots in M1; last_seen_at is not stored. Migration0006 retention_hold preserves the device and its credential/enrollment/renewal artifacts during cleanup; it grants no authentication or guardian authority.
- **`enrollment_challenges`**: Physical records both consumed_at (challenge spent, migration0001) and redeemed_at (activation completed, migration0003) instead of a state enum, and has no audience column (one purpose in M1). Migration0006 retention_hold prevents artifact deletion without extending validity.
- **`device_key_records`**: No key_epoch in M1: key rotation is out of scope (decision C-06).
- **`capability_snapshots`**: Physical stores android_api and device_mode (assumed equal to the ERD management_mode; confirm when the ERD is revised) plus is_device_owner and received_at; os_reject_reasons is not stored in M1.
- **`device_health`**: One current row per device (device_id is the key, as in the ERD). M1 stores battery, charging, permission revision and observed/recorded times; network status, queue pressure and last_seen_at are later work.
- **`commands`**: Physical carries family_id (RLS). child_id, reason_code and the idempotency_key column are not stored on the row: idempotency lives in idempotency_keys.
- **`command_results`**: Device proof and failure_reason are not stored in M1 (proof is verified at enrollment and renewal only, decision C-03).
- **`audit_events`**: M1 audit rows reference the acting principal or device in two columns instead of one actor_ref, and have neither child_ref, digest nor trace id.
- **`revocation_epochs`**: Same purpose; renamed columns.
- **`idempotency_keys`**: Deliberate deviation (migration 0004): the primary key includes the actor so callers cannot collide or probe each other; the table also stores the request hash and the response so a replay can be answered. Reconcile the ERD entity with this design.
- **`device_credentials`**: Short-lived opaque device bearer credential (decision C-01). Physical adds issued_at, issued_via and migration0006 retention_hold; latest_ip_hash is not stored. A hold prevents cleanup, never revocation or expiry.

## Physical tables without an ERD entity

- **`credential_renewal_challenges`**: Introduced by migrations0002/0003 (device credential renewal), with retention_hold added by0006. The ERD has no entity for single-use renewal challenges; add one next to device_sessions when the ERD is next revised. This does not add a physical table or approve a conceptual ERD change.
