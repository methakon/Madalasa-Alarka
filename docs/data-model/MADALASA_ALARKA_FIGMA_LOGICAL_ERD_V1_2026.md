# Madalasa–Alarka • Logical PostgreSQL schema — Figma handoff

**Design stage:** conceptual schema v1 (28 October 2026), **not executed SQL**. [Open Figma database design](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=92-2). The 11-domain models are editable Figma frames with text and foreign-key relationship registers. **120 candidate tables**; some relationships and names intentionally remain proposals, not stable migrations.

## Critical invariants and unresolved gates

- **No cross-child leakage:** billing family, child, adult Google identity, verified parental authority, child-specific grant, prepaid entitlement and live-viewer lease are distinct. Second parent must never automatically see every child. No public Family Link third-party child-parent attestation API has been verified; co-parent sharing stays **fail-closed** until trusted approved verification exists.
- **No automatic renewals:** monthly ₹99 and annual ₹999 public prepaid targets; ₹50/₹500 founding eligible first **1,008 distinct paying families** (including later paid children). Payer selects child-specific seats; second verified guardian shares an approved child's seat without second purchase.
- **Trial:** 48 hours once per eligible family. Anti-retrial/device fingerprint policy remains a privacy/security gate.
- **Concurrent screen:** one simultaneous **premium** viewer per paid child, across approved guardians. +₹100 one-time grants +1 premium viewer for **100 calendar days independent of main prepaid expiry** and +30 **combined** A/V minutes shared by authorized guardians for that child. If base expires, premium viewing pauses but addon remains until day 100, resuming after manual base renewal; no extra child access.
- **Media paid baseline (working proposal):** 60 audio minutes, 20 video minutes, 30 photos, 10 screen minutes per paid child per term, shared among guardians. Media operations remain conditional and legally/platform gated. Server debit only after delivery evidence; OS denial consumes zero.
- **Visibility vs retention:** free parent has live tracking and **six hours** visible history; paid access may expose retained history according to approved policy. The owner's desired full history until closure **conflicts with unresolved DPDP/legal and historical 14/30/90-day retention proposals**. No unlimited history retention authorization is implied; require counsel and actual retention approval before collection.
- **Security:** PostgreSQL RLS forced for child-bearing tenant tables, composite child/tenant constraints, server-side grant checks, key-bound device identities, atomic inbox/outbox and viewer leases, event-time dedupe, append-only audit, revocation epochs, erasure tombstones before offline retries, backup restore tombstone replay.
- **Technology and operational:** PostgreSQL + PostGIS, C++ Drogon, Kotlin Android clients, OCI Chicago proposed subject to legal and load gates. No actual migration or Play SDK SKU is proved by these diagrams. Media must be transparent; do not bypass Android's mic/camera/MediaProjection rules.

## Source documents reviewed (canonical where possible)

[Consolidated SRS](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/01-requirements-and-architecture/SRS.md) · [Whole-project technical specification](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/01-requirements-and-architecture/TECHNICAL_SPECIFICATION.md) · [Data/authorization/recovery](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/DATA_AUTHORIZATION_AND_RECOVERY_CONTRACT.md) · [GPS durable inbox ADR](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M2-location-collection/01-location-collection-and-ingestion/POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md) · [SOS/usage commands](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M4-usage-health-sos/01-usage-health-and-sos/COMMAND_SOS_USAGE_QUEUE_CONTRACT.md) · [Data retention](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M0-foundation-and-approvals/03-legal-and-privacy/DATA_RETENTION_SCHEDULE.md) · [Deletion](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M6-guardian-erasure-security/01-data-erasure-and-access/ACCOUNT_DELETION_DESIGN.md) · [Child-specific co-parent/100-day addon](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/CHILD_SPECIFIC_GOOGLE_PARENT_SHARING_AND_CONCURRENT_SCREEN_ADDONS_2026.md) · [Subscription plans](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M7-commercial-integrations/01-commercial-plans-and-costing/SUBSCRIPTION_PLANS_PRICING_AND_RULES_2026.md) · [Media evidence](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/P3-deferred-research/01-media-and-administrator-research/MEDIA_ACTIVITY_AUDIT_LOGGING_AND_REPORTING_2026.md) · [Admin scope](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/P3-deferred-research/01-media-and-administrator-research/ADMIN_PANEL_SPECIFICATION_2026.md) · [Reference screenshot workflows](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/ui/REFERENCE_SCREENSHOTS_FEATURE_WORKFLOWS_2026.md).

## Figma domain diagrams

### [ERD 01 / Family, identity & explicit guardian authority](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=93-2)

_01   Family, identity & explicit guardian authority — Tenant boundary ≠ a parent's automatic right to view every child. Co-parent access is child-scoped and blocked until trusted relationship verification exists. — M1 SRS FR-001/022 · Data Authorization · M7 two-parent policy · India consent_

**families** · TENANT ROOT  
`PK id : uuid` · `FK billing_owner_id : uuid` · `founding_rank : integer?` · `status : enum` · `created_at : timestamptz` · `revocation_epoch : bigint`

**adult_accounts** · IDENTITY ONLY  
`PK id : uuid` · `oidc_issuer, oidc_subject : unique` · `google_identity_verified_at : time` · `adult_authority_state : enum` · `disabled_at : time?`

**family_memberships** · NOT A CHILD GRANT  
`PK (family_id, adult_id)` · `FK family_id → families` · `FK adult_id → adult_accounts` · `role : owner / member` · `revoked_at : time?`

**children** · ONE CHILD = ONE PRIVACY SUBJECT  
`PK id : uuid` · `FK home_family_id → families` · `display_name : encrypted?` · `device_status : enum` · `erasure_epoch : bigint` · `deleted_at : time?`

**child_parent_verifications** · BLOCKED: GOOGLE API UNVERIFIED  
`PK id : uuid` · `FK child_id → children` · `FK adult_id → adult_accounts` · `method, evidence_ref : enum / opaque` · `state : PENDING / VERIFIED / REVOKED` · `verified_at, expires_at : time?`

**child_guardian_grants** · DENY BY DEFAULT  
`PK id : uuid` · `FK child_id → children` · `FK adult_id → adult_accounts` · `FK verification_id : uuid?` · `scopes : enum set` · `expires_at, revoked_at : time?`

**guardian_invitations** · ONE CHILD INVITE  
`PK id : uuid` · `FK child_id → children` · `inviter_id, invitee_id : uuid` · `secret_hash : bytea` · `expires_at, consumed_at : time?`

**consent_records** · LEGAL RELEASE GATE  
`PK id : uuid` · `FK child_id, adult_id : uuid` · `purpose, notice_version : text` · `granted_at, withdrawn_at : time?` · `legal_basis_review_state : enum`

**family_revocation_epochs** · AUTH CACHE FENCE  
`PK FK family_id → families` · `epoch : bigint` · `changed_at : timestamptz` · `invalidate cached child scopes`

**trial_redemptions** · 48h ONCE  
`PK family_id : uuid` · `anti_abuse_token_hash : bytea?` · `started_at, expires_at : time` · `redeemed_once : boolean` · `privacy/retention review pending`

**Relationships:** families → children; families → family_memberships; adult_accounts → family_memberships; children → child_parent_verifications; adult_accounts → child_parent_verifications; children → child_guardian_grants; adult_accounts → child_guardian_grants; children → guardian_invitations; children → consent_records; families → trial_redemptions; families → family_revocation_epochs.

### [ERD 02 / Devices, permissions & remote commands](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=94-2)

_02   Devices, permissions & remote commands — Devices are separate principals; permissions are observed states, never inferred from a parent's subscription. — M1 implementation, capability-sync ADR, command/SOS queue_

**child_devices** · DEVICE IS NOT CHILD  
`PK id : uuid` · `FK child_id → children` · `enrollment_state : enum` · `android_api, device_mode : int/enum` · `revoked_at, last_seen_at : time` · `public_key_ref : opaque`

**pairing_codes** · ONE-TIME HASHED  
`PK id : uuid` · `FK child_id → children` · `issued_by_adult_id : uuid` · `code_hash : bytea unique` · `expires_at, consumed_at : time`

**enrollment_challenges** · REPLAY-PROTECTED  
`PK id : uuid` · `FK device_id → child_devices` · `challenge_hash : bytea` · `expires_at, consumed_at : time` · `audience, state : text/enum`

**device_key_records** · KEYSTORE PUBLIC PROOF  
`PK key_id : uuid` · `FK device_id → child_devices` · `fingerprint_hash : bytea` · `key_epoch : bigint` · `state, revoked_at : enum/time`

**device_sessions** · SHORT-LIVED  
`PK id : uuid` · `FK device_id → child_devices` · `token_hash, bound_key_id : opaque` · `expires_at, revoked_at : time` · `latest_ip_hash : optional`

**capability_snapshots** · NOT GUARANTEED  
`PK id : uuid` · `FK device_id → child_devices` · `observed_at : timestamptz` · `android_api, management_mode` · `supported_features : jsonb` · `os_reject_reasons : jsonb`

**permission_snapshots** · VISIBLE / CURRENT  
`PK id : uuid` · `FK device_id → child_devices` · `observed_at, version : time/int` · `permission_states : jsonb` · `revocation_epoch : bigint`

**device_health** · STALE AWARE  
`PK FK device_id` · `battery_pct, charging : int/bool` · `network_status : enum` · `last_seen_at : timestamptz` · `queue_pressure : int?`

**device_commands** · STATE MACHINE  
`PK id : uuid` · `FK device_id, child_id : uuid` · `initiator_adult_id : uuid` · `type, state, reason_code : enum` · `idempotency_key : uuid` · `expires_at : timestamptz`

**command_results** · DEVICE CONFIRMATION  
`PK id : uuid` · `FK command_id → device_commands` · `received_at : timestamptz` · `device_proof : opaque` · `result_code, failure_reason`

**Relationships:** child_devices → pairing_codes; child_devices → device_key_records; child_devices → device_sessions; child_devices → capability_snapshots; child_devices → permission_snapshots; child_devices → device_health; child_devices → device_commands; device_commands → command_results; child_devices → enrollment_challenges.

### [ERD 03 / GPS intake, route evidence & reconstruction](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=94-100)

_03   GPS intake, route evidence & reconstruction — Store original event time and device provenance. A reconstructed route is an interpretation, never fabricated continuous GPS. — M2 GPS ADR-004 · tracking algorithm · SRS route requirements_

**location_ingest_batches** · DURABLE 202 AFTER COMMIT  
`PK batch_id : uuid` · `FK device_id, child_id : uuid` · `batch_hash : bytea unique?` · `accepted_at, status : time/enum` · `payload_ref : encrypted` · `commit_receipt : opaque`

**location_batch_items** · RETRYABLE  
`PK (batch_id, event_id)` · `FK batch_id → ingest_batches` · `device_event_id : uuid` · `observed_at : timestamptz` · `decode_status : enum`

**location_event_dedup** · NO DOUBLE INSERT  
`PK (device_id, event_id)` · `payload_digest : bytea` · `first_seen_at : time` · `last_seen_at : time` · `replay_window : policy`

**location_observations** · POSTGIS PARTITIONED  
`PK (device_id, observed_at, event_id)` · `FK child_id, device_id : uuid` · `geom : geography POINT` · `accuracy_m : float` · `fix_source, quality : enum` · `ingested_at : timestamptz`

**device_latest_positions** · STALE / UNKNOWN  
`PK device_id : uuid` · `FK observation_ref : composite` · `observed_at, accuracy_m` · `quality : enum` · `compare-and-swap only`

**trips** · DERIVED, VERSIONED  
`PK trip_id : uuid` · `FK child_id : uuid` · `start_at, end_at : time` · `current_revision : integer` · `confidence, status : enum`

**trip_revisions** · CORRECTIONS  
`PK (trip_id, revision)` · `evidence_window : time range` · `recomputed_at : time` · `is_provisional : bool` · `algorithm_version : text`

**trip_legs** · OBSERVED / INFERRED  
`PK leg_id : uuid` · `FK trip_id, revision` · `start/end time, distance_m` · `mode_inference : enum` · `confidence, gaps_present`

**stops** · NO FAKE EXACT STOPS  
`PK stop_id : uuid` · `FK trip_id, child_id` · `start_at, end_at` · `center_geom : geography` · `confidence, name_source`

**route_geometry** · NO GAP FABRICATION  
`PK (trip_id, revision, point_no)` · `geom : geography POINT` · `observed_or_inferred : enum` · `source_event_ref : optional`

**reconstruction_jobs** · FENCED WORKERS  
`PK id : uuid` · `FK child_id, device_id` · `affected_interval : tstzrange` · `job_state, lease_epoch` · `retry_count : integer`

**ingestion_outbox** · RECOVERABLE  
`PK id : uuid` · `FK batch_id : uuid` · `kind, state : enum` · `created_at, dispatched_at` · `lease_epoch, attempts`

**Relationships:** location_ingest_batches → location_batch_items; location_batch_items → location_event_dedup; location_event_dedup → location_observations; location_observations → device_latest_positions; location_observations → trips; trips → trip_revisions; trip_revisions → trip_legs; trips → stops; trip_revisions → route_geometry; location_ingest_batches → ingestion_outbox; ingestion_outbox → reconstruction_jobs.

### [ERD 04 / Places, geofence alerts, SOS & check-ins](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=94-214)

_04   Places, geofence alerts, SOS & check-ins — Place notifications are per child and per place. Emergency notifications are best effort, not guaranteed human delivery. — SRS places/SOS · command pipeline · screenshot workflow register_

**named_places** · CHILD SCOPED  
`PK place_id : uuid` · `FK child_id : uuid` · `label, place_kind : text/enum` · `center_geom : geography` · `radius_m : integer` · `archived_at : time?`

**place_notification_rules** · PER PLACE + GUARDIAN  
`PK id : uuid` · `FK place_id : uuid` · `FK adult_id : uuid` · `arrival_enabled, exit_enabled` · `quiet_hours_id : uuid?`

**geofence_events** · DEDUPE / DELAY  
`PK event_id : uuid` · `FK child_id, place_id` · `type : ARRIVE / EXIT / UNKNOWN` · `observed_at : timestamptz` · `confidence, hysteresis_state`

**notification_preferences** · PERSONAL PREFERENCES  
`PK id : uuid` · `FK adult_id, child_id` · `alert_type : enum` · `enabled, quiet_schedule` · `channel_policy : jsonb`

**notification_deliveries** · SENT ≠ SEEN  
`PK id : uuid` · `FK event_ref, recipient_id` · `provider_message_id : opaque` · `submitted_at, acknowledged_at` · `status : PENDING / SENT / ACK`

**sos_events** · CHILD INITIATED  
`PK id : uuid` · `FK child_id, device_id` · `device_event_uuid : uuid unique` · `trigger_at, accepted_at` · `status, location_ref optional`

**sos_acknowledgements** · HUMAN ACK DISTINCT  
`PK id : uuid` · `FK sos_event_id : uuid` · `FK guardian_id : uuid` · `acknowledged_at : time` · `delivery_channel : enum`

**child_checkins** · EXPLICIT UI  
`PK id : uuid` · `FK child_id, device_id` · `requested_by : adult?` · `checked_in_at : time` · `status, note : optional`

**alert_delivery_outbox** · RECHECK AUTH BEFORE SEND  
`PK id : uuid` · `FK event_ref, child_id` · `recipient_scope : string` · `attempts, next_retry_at` · `state : enum`

**Relationships:** named_places → place_notification_rules; named_places → geofence_events; geofence_events → notification_deliveries; notification_preferences → notification_deliveries; sos_events → sos_acknowledgements; sos_events → alert_delivery_outbox; child_checkins → alert_delivery_outbox; geofence_events → alert_delivery_outbox.

### [ERD 05 / App usage, screen-time & managed controls](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=95-2)

_05   App usage, screen-time & managed controls — Usage monitoring is legally gated; unsupported Android app-block controls must never be represented as successful. — M4 command/usage contract · SRS FR-005/007 · capability decisions_

**installed_app_inventory** · OS PACKAGE VISIBILITY  
`PK id : uuid` · `FK device_id, child_id` · `package_name : text` · `category_id : uuid?` · `observed_at : time` · `visibility_mode : enum`

**app_usage_events** · USAGE ACCESS GATED  
`PK (device_id, event_uuid)` · `FK child_id, app_id` · `event_at : timestamptz` · `kind : foreground/background` · `duration_ms : bigint?` · `quality : enum`

**usage_period_summaries** · UNKNOWN ≠ ZERO  
`PK (child_id, period, app_id)` · `period_start / period_end` · `observed_seconds : bigint` · `coverage_quality : enum` · `computed_at : time`

**usage_categories** · CONFIGURABLE  
`PK category_id : uuid` · `category_key : text` · `classification_source` · `updated_at : time`

**screen_time_rules** · MANAGED MODE ONLY  
`PK rule_id : uuid` · `FK child_id : uuid` · `app_id or category_id` · `schedule : jsonb` · `daily_limit_seconds : int` · `legal_gate : state`

**rule_assignments** · DEVICE SPECIFIC  
`PK id : uuid` · `FK rule_id, device_id` · `effective_at, expires_at` · `policy_revision : bigint` · `state : requested/applied`

**policy_execution_receipts** · DEVICE CONFIRMED  
`PK id : uuid` · `FK assignment_id` · `execution_at : time` · `os_outcome, reason_code` · `device_proof_ref : opaque`

**scheduled_child_tasks** · OPTIONAL FUTURE  
`PK task_id : uuid` · `FK child_id, adult_id` · `kind, goal, schedule` · `status, completed_at`

**usage_permission_checks** · FAIL CLOSED  
`PK id : uuid` · `FK device_id : uuid` · `observed_at : time` · `usage_access_state` · `legal_feature_gate`

**Relationships:** installed_app_inventory → app_usage_events; app_usage_events → usage_period_summaries; usage_categories → usage_period_summaries; screen_time_rules → rule_assignments; rule_assignments → policy_execution_receipts; usage_permission_checks → app_usage_events.

### [ERD 06 / Prepaid billing, founding seats & 100-day addon](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=95-87)

_06   Prepaid billing, founding seats & 100-day addon — Each selected child has a separate paid seat; two approved guardians can share its benefits. Addon validity is independent of base lapse. — M7 prepaid policy · founding 1008 · 100-day extra viewer · no auto-renew_

**billing_product_catalog** · NOT YET LIVE  
`PK sku_id : text` · `kind : prepaid/addon` · `term_days : int?` · `currency : INR` · `play_configuration_state`

**price_offers** · ACTUAL PLAY PRICE WINS  
`PK offer_id : uuid` · `FK sku_id : text` · `public ₹99/₹999` · `founding ₹50/₹500` · `eligible_rule, dates`

**founding_families** · COUNT FAMILY ONCE  
`PK family_id : uuid` · `qualifying_rank : 1..1008` · `first_paid_at : timestamptz` · `eligibility_active : bool`

**play_purchase_records** · SERVER-VERIFIED  
`PK purchase_id : uuid` · `FK payer_adult_id` · `play_token_hash : unique` · `sku_id, verified_state` · `verified_at, refund_state`

**prepaid_family_batches** · MANUAL RENEW ONLY  
`PK batch_id : uuid` · `FK family_id, purchase_id` · `capacity : int` · `starts_at, expires_at` · `status : prepaid / expired`

**child_seat_assignments** · EXPLICIT CHILD CHOICE  
`PK id : uuid` · `FK batch_id, child_id` · `assigned_at, removed_at` · `capacity_txn_ref` · `active uniqueness`

**child_paid_entitlements** · NO CO-PARENT AUTO ACCESS  
`PK id : uuid` · `FK child_id, assignment_id` · `valid_from, valid_until` · `feature_set_id` · `entitlement_epoch`

**extra_viewer_purchases** · DORMANT, NOT FORFEITED  
`PK id : uuid` · `FK purchase_id, child_id` · `activated_at : time` · `expires_at : +100 days` · `extra_slots : 1` · `extra_AV_seconds : 1800`

**payment_reconciliation_inbox** · RTDN VERIFICATION  
`PK event_id : uuid` · `purchase_token_hash` · `Play event_type : enum` · `received_at, verified_at` · `idempotent_state`

**purchase_adjustments** · REVOKE UNUSED  
`PK id : uuid` · `FK purchase_id` · `reason : refund/chargeback` · `effective_at : time` · `reconciled_at : time`

**trial_eligibility_checks** · 48H ONCE  
`PK id : uuid` · `FK family_id : uuid` · `FK trial_redemptions` · `risk_result : enum` · `checked_at : time`

**family_checkout_intents** · EXPLICIT PRICE CONFIRM  
`PK id : uuid` · `FK family_id, payer_id` · `selected_child_ids snapshot` · `offer_reference` · `intent_expires_at, status`

**Relationships:** billing_product_catalog → price_offers; price_offers → family_checkout_intents; family_checkout_intents → play_purchase_records; play_purchase_records → prepaid_family_batches; prepaid_family_batches → child_seat_assignments; child_seat_assignments → child_paid_entitlements; play_purchase_records → extra_viewer_purchases; play_purchase_records → purchase_adjustments; play_purchase_records → payment_reconciliation_inbox; founding_families → prepaid_family_batches.

### [ERD 07 / Premium viewer leases, media & delivered quotas](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=96-2)

_07   Premium viewer leases, media & delivered quotas — One viewer per paid child (+1 per valid 100-day addon). Media capabilities are gated, child-visible and charged only when delivered. — P3 media ADR · accepted Balanced usage · M7 concurrent viewer contract_

**premium_viewer_leases** · ATOMIC TTL ADMISSION  
`PK lease_id : uuid` · `FK child_id, adult_id` · `device_session_id : uuid` · `screen_kind : enum` · `heartbeat_at, expires_at` · `entitlement_epoch : bigint`

**viewer_takeover_requests** · NO SILENT TAKEOVER  
`PK id : uuid` · `FK child_id, active_lease` · `requester_adult_id` · `state, requested_at` · `expires_at : time`

**media_command_requests** · LEGAL + OS CHECK  
`PK command_id : uuid` · `FK child_id, device_id` · `FK adult_id : uuid` · `kind : audio/video/photo/screen` · `reason_code, state`

**media_sessions** · SESSION EVIDENCE  
`PK media_session_id : uuid` · `FK child_id, command_id` · `authorized_adult_id : uuid` · `started_at, ended_at` · `transport_mode, exit_reason`

**media_lifecycle_events** · METADATA, NOT FILES  
`PK event_id : uuid` · `FK media_session_id` · `event_at : timestamptz` · `state, reason, device_proof` · `duration_s, bytes_sent`

**child_media_quota_pools** · SHARED ALL GUARDIANS  
`PK pool_id : uuid` · `FK child_id, entitlement` · `base_audio_s : 3600` · `base_video_s : 1200` · `base_photos : 30; screen_s : 600` · `extra_combined_av_s : 1800/slot`

**media_quota_ledger** · DEBIT ONLY DELIVERED  
`PK id : uuid` · `FK child_id, pool_id` · `FK media_session_id?` · `media_kind, delivered_amount` · `reserved_at, committed_at`

**capture_artifact_refs** · NO VPS MEDIA BINARIES  
`PK id : uuid` · `FK media_session_id, child_id` · `kind : media artifact` · `parent_controlled_uri_ref` · `expires_at, erasure_state`

**media_access_audit** · AUDIT READS  
`PK id : uuid` · `FK child_id, adult_id` · `FK media_session_id` · `action, result, accessed_at` · `case_id optional`

**media_capability_gates** · FAIL CLOSED  
`PK (feature, api, mode)` · `android_gate : state` · `play_legal_gate : state` · `last_verified_at : time` · `released : boolean`

**Relationships:** premium_viewer_leases → viewer_takeover_requests; media_command_requests → media_sessions; media_sessions → media_lifecycle_events; child_media_quota_pools → media_quota_ledger; media_sessions → media_quota_ledger; media_sessions → capture_artifact_refs; media_sessions → media_access_audit; media_capability_gates → media_command_requests.

### [ERD 08 / Privacy, deletion, retention & admin-case access](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=96-98)

_08   Privacy, deletion, retention & admin-case access — Six-hour free history VISIBILITY is separate from DATA RETENTION. Full account-lifetime history is not approved without India legal review. — M0 DPDP/retention · M6 deletion · P3 admin/media audits_

**purpose_authorizations** · SEPARATE FROM OS PERM  
`PK id : uuid` · `FK child_id, adult_id` · `purpose_key, version` · `lawful_authority_state` · `granted_at, withdrawn_at`

**retention_policy_versions** · NO UNAPPROVED FOREVER  
`PK policy_id : uuid` · `data_category : enum` · `period_days : nullable` · `policy_status : DRAFT/APPROVED` · `effective_from, approved_by`

**history_visibility_rules** · VIEW ≠ STORAGE  
`PK rule_id : uuid` · `tier : FREE / PAID / TRIAL` · `visible_hours : FREE=6` · `paid_range : policy approval` · `effective_at : timestamptz`

**account_deletion_requests** · NO REVIVAL  
`PK id : uuid` · `FK requested_by_adult` · `family_id, child_id optional` · `received_at, confirmed_at` · `state, scope, deadline`

**child_erasure_tombstones** · FENCE OFFLINE REPLAY  
`PK child_id : uuid` · `revoke_epoch : bigint` · `delete_started_at` · `deny_future_ingest : bool` · `source_request_id`

**erasure_jobs** · VERIFY CLEANUP  
`PK job_id : uuid` · `FK deletion_request_id` · `target_store : primary/backup` · `state, attempts, last_error` · `completed_at : time`

**erasure_job_targets** · ALL STORES  
`PK id : uuid` · `FK erasure_job_id` · `category / partition` · `completed_at, proof_ref`

**backup_erasure_manifests** · RESTORE SAFETY  
`PK id : uuid` · `FK deletion_request_id` · `backup_ref, restore_epoch` · `replay_tombstone_status` · `purge_by, verified_at`

**admin_principals** · NO BLANKET CHILD ACCESS  
`PK id : uuid` · `identity_subject : text` · `role : limited / audited` · `MFA_state, disabled_at` · `break_glass_expiry`

**admin_cases** · NEED-TO-KNOW  
`PK case_id : uuid` · `purpose, approver_id` · `affected_child_id` · `opened_at, expires_at` · `case_status`

**admin_case_scopes** · DUAL APPROVAL GATE  
`PK id : uuid` · `FK case_id, admin_id` · `permitted_fields` · `valid_from, valid_until` · `second_approver_ref`

**admin_read_audit** · EVERY SENSITIVE READ  
`PK id : uuid` · `FK case_id, admin_id` · `child_ref, action, result` · `accessed_at : time` · `immutable_digest`

**Relationships:** retention_policy_versions → erasure_jobs; account_deletion_requests → child_erasure_tombstones; account_deletion_requests → erasure_jobs; erasure_jobs → erasure_job_targets; erasure_jobs → backup_erasure_manifests; admin_principals → admin_case_scopes; admin_cases → admin_case_scopes; admin_case_scopes → admin_read_audit; purpose_authorizations → account_deletion_requests.

### [ERD 09 / Operations, evidence gates & resilient event flow](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=96-208)

_09   Operations, evidence gates & resilient event flow — PostgreSQL-backed inbox/outbox and per-child tenant isolation; audit, billing, data minimization and production gates remain explicit. — M1 operations/security · M2 inbox ADR · M8 OCI Chicago cost · M9 Play release_

**durable_event_inbox** · DURABLE ACK  
`PK id : uuid` · `source_device, message_hash` · `accepted_at : time` · `processed_at, attempt_count` · `status / error_reason`

**processing_outbox** · RETRY-SAFE  
`PK id : uuid` · `event_kind, subject_ref` · `payload_digest : bytea` · `next_attempt_at : time` · `state, lease_epoch`

**idempotency_claims** · PURCHASE / COMMAND SAFE  
`PK (namespace, key_hash)` · `actor_ref : opaque` · `created_at, expires_at` · `result_digest : bytea`

**worker_lease_fences** · SINGLE-ACTIVE WORKER  
`PK worker_name : text` · `lease_epoch : bigint` · `owner_instance_ref` · `valid_until : time`

**feature_release_gates** · DISABLED BY DEFAULT  
`PK feature_id : text` · `android_status : enum` · `google_play_status : enum` · `india_legal_status : enum` · `released_at, approver_id`

**external_service_accounts** · NO RAW CREDENTIALS  
`PK provider_ref : uuid` · `service : maps / FCM / Play` · `credential_secret_ref` · `scope, state, expires_at` · `residency_check : state`

**security_audit_events** · REDACTED / IMMUTABLE  
`PK id : uuid` · `actor_ref, child_ref optional` · `action, outcome : enum` · `occurred_at : time` · `trace_id, digest`

**support_cases** · DATA ACCESS CASE-GATED  
`PK case_id : uuid` · `account_ref / child_ref` · `issue_category, priority` · `consent_scope, opened_at` · `resolved_at : time`

**export_requests** · DATA SUBJECT RIGHTS  
`PK request_id : uuid` · `FK principal_id, child_id` · `approved_scope` · `status, expires_at` · `delivery_ref : encrypted`

**telemetry_aggregates** · MINIMAL OP METRICS  
`PK period + service + metric` · `count, p50, p95` · `no child coordinates` · `retained_until : time`

**cost_usage_snapshots** · ₹100/100D LOAD TEST  
`PK period + cloud_service` · `turn_gb, outbound_gb` · `viewer_concurrency_peak` · `estimated_cost_inr` · `scenario_status : estimate/actual`

**architecture_decisions** · TRACEABLE CHANGE LOG  
`PK adr_id : text` · `decision, supersedes_adr` · `status : DRAFT/APPROVED` · `owner, approved_at`

**Relationships:** durable_event_inbox → processing_outbox; processing_outbox → worker_lease_fences; idempotency_claims → durable_event_inbox; feature_release_gates → external_service_accounts; support_cases → export_requests; support_cases → security_audit_events; telemetry_aggregates → cost_usage_snapshots; architecture_decisions → feature_release_gates.



### [ERD 10 / Admin accounts, access requests, FAQ, support and parent-service logs](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=108-2)

Owner 2026-10-28: separate back-office, only verified owner swarna.s.jobs@gmail.com may approve/reject applicant staff profiles. Admin applicant needs valid profile and verified email. Collecting full DOB/address/gender is a privacy/legal design gate; Google login alone grants zero permissions.

**admin_accounts** · OWNER BOOTSTRAP  
`PK id : uuid` · `google_issuer, google_sub : UNIQUE` · `verified_google_email : text` · `email_verified_at : timestamp` · `state : NO_ACCESS/ACTIVE/REVOKED` · `session_revocation_epoch : bigint`

**admin_profiles** · PERSONAL • ENCRYPTED  
`PK/FK admin_id → admin_accounts` · `name : encrypted text` · `address : encrypted text` · `dob, gender : encrypted? (gate)` · `contact_email, verified_at` · `profile_version, privacy_notice`

**admin_email_challenges** · HASHED SINGLE USE  
`PK id : uuid` · `FK admin_id : uuid` · `contact_email_digest : bytea` · `challenge_hash : unique` · `expires_at, used_at` · `attempts : int`

**admin_access_requests** · OWNER APPROVES ONLY  
`PK id : uuid` · `FK admin_id : uuid` · `profile_version : bigint` · `state : DRAFT/PENDING/APPROVED` · `submitted_at, decided_at` · `decided_by_owner_id, reason`

**admin_roles** · ROLE CATALOG  
`PK role_id : uuid` · `code : ROOT_OWNER/FAQ_EDITOR/...` · `description, active : text/bool` · `owner_assignable : bool`

**admin_permissions** · PERMISSION CATALOG  
`PK code : text` · `module : enum` · `requires_case, step_up : bool` · `description : text`

**admin_role_permissions** · RBAC JOIN  
`PK (role_id, permission_code)` · `FK role_id → admin_roles` · `FK permission_code → permissions`

**admin_role_grants** · OWNER ISSUED / REVOKABLE  
`PK grant_id : uuid` · `FK admin_id, role_id` · `FK granted_by_owner_id` · `created_at, revoked_at` · `expires_at : time?`

**admin_action_audit** · NO OFF SWITCH  
`PK audit_id : uuid` · `FK actor_admin_id : uuid` · `action, result, target_ref` · `occurred_at, request_id` · `digest / case_ref`

**admin_notifications** · PII MINIMAL  
`PK id : uuid` · `FK access_request_id : uuid` · `recipient_owner_id : uuid` · `queued_at, delivered_at` · `dedup_key, status`

**faq_entries** · PUBLIC ONLY IF PUBLISHED  
`PK faq_id : uuid` · `slug : unique` · `category, status : enum` · `current_revision_id : uuid?` · `created_at, updated_at`

**faq_revisions** · REVISION HISTORY  
`PK revision_id : uuid` · `FK faq_id : uuid` · `language_code : en` · `title, safe_body : text` · `created_by_admin_id, published_at`

**support_tickets** · AUTHENTICATED PARENT  
`PK ticket_id : uuid` · `FK parent_adult_id : uuid` · `family_id : uuid? (restricted)` · `subject, state, priority` · `assigned_admin_id, timestamps`

**support_messages** · SANITIZED REPLIES  
`PK message_id : uuid` · `FK ticket_id : uuid` · `sender_parent_or_admin_ref` · `safe_body : text` · `sent_at, delivery_state`

**parent_service_usage_events** · SERVICE METADATA ONLY  
`PK event_id : uuid` · `FK parent_adult_id : uuid` · `child_ref : masked optional` · `service_code, outcome` · `started_at, ended_at, duration_s` · `quota_debit, receipt_ref`

**admin_support_read_audit** · EVERY SENSITIVE READ  
`PK id : uuid` · `FK admin_id, ticket_id` · `request_id, purpose` · `accessed_at, outcome` · `immutable_digest`

**Relationships:** admin_accounts → admin_profiles; admin_accounts → admin_email_challenges; admin_accounts → admin_access_requests; admin_accounts → admin_role_grants; admin_roles → admin_role_permissions; admin_permissions → admin_role_permissions; admin_roles → admin_role_grants; admin_accounts → admin_action_audit; admin_access_requests → admin_notifications; faq_entries → faq_revisions; admin_accounts → faq_revisions; support_tickets → support_messages; admin_accounts → admin_support_read_audit; support_tickets → admin_support_read_audit; admin_accounts → parent_service_usage_events.

**Permission boundary:** Owner controls staff roles, FAQ, support, subscriptions and parent service logs but does not get any unrestricted child private location, media or messages. Google OIDC sub is the durable identity key; named child media auditing remains a separate scoped gate. [Admin workflow design](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/P3-deferred-research/01-media-and-administrator-research/ADMIN_OWNER_GOOGLE_ACCESS_FAQ_SUPPORT_BILLING_AND_USAGE_2026.md).


### [ERD 11 / Figma API gap closure additional persistence (CONCEPT ONLY)](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=121-2)

**8 newly identified screen-backed logical entities (no migration executed).** P-02/P-04 parent sessions, CAP permission changes, P-19 per-parent notification reads, P-29/P-30 commute plan/version history, P-51 adaptive cadence, P-52 public outage status, P-57/P-58/C-20 conditional device media approvals. [Physical schema / RLS migration review](FIGMA_SCREEN_GAP_PHYSICAL_SCHEMA_REVIEW_2026-10-28.md).

**parent_auth_sessions** · AUTH LOGOUT/REVOKE  
`PK id : uuid` · `FK adult_id → adult_accounts.id` · `token_hash : bytea unique` · `issued_at, expires_at : timestamp` · `revoked_at, revocation_epoch` · `client_audience : PARENT`

**device_permission_change_events** · REVOCATION HISTORY  
`PK id : uuid` · `FK device_id → child_devices.id` · `FK child_id → children.id` · `permission_key, old_state, new_state` · `observed_at, received_at : timestamp` · `device_state_revision : bigint`

**parent_notification_read_receipts** · ONE GUARDIAN READ  
`PK (delivery_id, adult_id)` · `FK delivery_id → notification_deliveries.id` · `FK adult_id → adult_accounts.id` · `read_at : timestamptz` · `is_read : boolean` · `source_revision : bigint`

**commute_plans** · M3 ROUTE PLAN  
`PK plan_id : uuid` · `FK child_id → children.id` · `start_place_id, end_place_id : uuid?` · `schedule_json : validated` · `version, created_by_adult_id` · `legal_history_gate : enum`

**commute_plan_revisions** · REVISIONS / NO FAKE ARRIVAL  
`PK (plan_id, revision)` · `FK plan_id → commute_plans.plan_id` · `expected_window : tstzrange` · `change_reason, edited_by : uuid` · `created_at, supersedes_revision`

**tracking_policy_revisions** · FREE / PAID CADENCE  
`PK id : uuid` · `FK child_id → children.id` · `FK device_id → child_devices.id` · `policy_version : bigint` · `frequency_class : enum` · `effective_at, device_ack_at`

**service_incidents** · NO PRIVATE TELEMETRY  
`PK id : uuid` · `component, status : enum` · `public_message : sanitized text` · `began_at, resolved_at` · `severity, release_stage` · `no child data or coordinates`

**media_request_device_approvals** · EXPLICIT USER-AUTHORIZED  
`PK id : uuid` · `FK command_id → media_command_requests.id` · `FK device_id → child_devices.id` · `device_ui_consent_state : enum` · `requested_at, decided_at` · `os_decision_reason : enum`

**Relationships:** adult_accounts.id → parent_auth_sessions.adult_id; child_devices.id → device_permission_change_events.device_id; notification_deliveries.id → parent_notification_read_receipts.delivery_id; children.id → commute_plans.child_id; commute_plans.plan_id → commute_plan_revisions.plan_id; child_devices.id → tracking_policy_revisions.device_id; media_command_requests.id → media_request_device_approvals.command_id; child_devices.id → media_request_device_approvals.device_id.

## Migration / test gates

1. Review naming, nullable columns, exact FK joins and tenant constraints with backend/security, including changing legacy same-family membership requirements for separately authorized external co-parents.
2. Resolve DPDP legal basis, full-history retention, parental-role attestation and Play prepaid SKU blockers before enabling sensitive tables.
3. Author numbered PostgreSQL DDL migrations, check constraints, partial unique indexes, appropriate PostGIS and event-time partitioning, real RLS policies and cross-tenant tests.
4. Benchmark ingestion batch inserts, partition indexes, atomic viewer leases with simultaneous parents, refunds and 100-day dormancy/reactivation, deletion/restore non-revival, and finance cost simulations.
5. Keep Figma and this exported register synchronized when migrations are approved; mark table states DRAFT/APPROVED/IMPLEMENTED instead of assuming all 120 tables must be shipped immediately.


## 2026-10-28 V2 family-grants schema amendment — supersedes Google parent role lookup

The initial Figma `child_parent_verifications` conceptual name and 'BLOCKED: GOOGLE API UNVERIFIED' label were **superseded**. The editable [Figma ERD-01](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=93-2) now uses `child_authority_reviews` (statutory lawful authority/consent process, separate review), `child_access_invites` (hashed, one-use child-specific invite accepted by intended adult) and `child_access_grants_v2` (scope for exact child+adult, not a FK to billing-family membership). [Machine-readable JSON registry](MADALASA_ALARKA_FIGMA_LOGICAL_ERD_V1_2026.json) contains the revised fields. [Versioned physical migration ADR](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/phases/M1-secure-platform-foundation/03-security-and-permissions/ADR_2026_10_28_BLEND_FAMILY_V2_AND_NO_FAMILY_LINK_DEPENDENCY.md) is the implementation contract. Existing `backend/persistence/migrations/0001_m1_identity.sql` must remain unchanged and is NOT yet supplemented by an executable `0002`. Google Sign-In verifies account identity only; the Family Link parent-role lookup is not a dependency. Applicable India parental/lawful guardian authority verification remains legally separate and **not approved** by this documentation.
