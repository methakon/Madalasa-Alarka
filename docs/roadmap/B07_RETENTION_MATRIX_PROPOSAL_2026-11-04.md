# B-07 Retention Matrix — DRAFT (per-category, implementation-grounded)

**Status:** PUBLISHED PROPOSAL, REVIEW PENDING. Catalogue entry DOC-075; not a governance decision and not legal advice.
**Blocker:** B-07 = `HIGH` / **OPEN / UNDECIDED** (`BLOCKERS_AND_OWNER_DECISIONS.md` L74, L160, L221, L239, L283).
**Prepared:** 2026-11-04 · Branch under inspection: `api` (read-only) · Canonical sources read from `origin/main`.
**No tracked file was modified and no commit was made.**

## 0. The one constraint that invalidates most casual readings

> **The six-hour free-tier window is a query-access predicate, NOT a storage retention period.**

Both statements are independently true and must never be merged:

| | Six-hour window | Retention period |
|---|---|---|
| What it is | How far back a free-tier guardian may **read** | How long the server may **keep** the row |
| Enforced at | `ap_m1.can_read_location_history()` (0005 L159-167) and `free_location_reads.h` L66 (`interval '6 hours'`) | `ap_m1.location_collection_policies.retain_for` (0005 L11) → `ap_m1.purge_expired_location()` (0019 L279) |
| Consequence of short value | Less is *shown* | Less is *stored* |

`0005_location_ingestion_and_history.sql` L6 states this verbatim: *"Separate physical retention/collection authorization from six-hour UI visibility."* L384: *"Six-hour visibility never drives physical deletion."* The roadmap repeats it (`FREE_FIRST_108_CHILD_RELEASE_ROADMAP_2026-11-03.md` L7: *"Six hours is NOT a data-retention schedule"*). **Any row below proposing 6 hours, or inferring 6 hours from the free tier, is wrong.**

## 1. Implemented enforcement primitives (verified, not inferred)

The repo already contains a **fail-closed two-gate design**. Both gates are currently unarmed.

### Gate A — category TTL registry: `ap_m1.retention_policy_versions` (`0003_consent_authority_and_retention.sql` L21-38)
```
category, version, state IN ('DRAFT','APPROVED','RETIRED'),
period_days, clock_basis IN ('OBSERVED_AT','CREATED_AT','CLOSED_AT','REVOKED_AT','BACKUP_COMPLETED_AT'),
purpose, deletion_method, backups_bound_days, exception_review_reference,
approval_reference, effective_from
CHECK(state<>'APPROVED' OR (period_days IS NOT NULL AND backups_bound_days IS NOT NULL
      AND effective_from IS NOT NULL AND length(approval_reference)>0))   -- 0003 L40-41
```
Resolver: `ap_m1.retention_deadline(category, original_time)` (0003 L44-50) returns `original_time + make_interval(days=>period_days)` **only** for `state='APPROVED' AND effective_from<=now()`, else NULL.

**Verified live state (read-only SELECT against `.local-db/connection.json` → `test` DSN, `SET TRANSACTION READ ONLY`):**
```
retention_policy_versions total  => 0
APPROVED rows                    => 0
location_collection_policies     => 0
retention_holds                  => 0
backup_inventory                 => 0
```
Corroborated by `retention-ownership-manifest.json`: **all 144 tables** carry `"approval_state": "OWNER_COUNSEL_PENDING"`, `"candidate_period": null`, `"partition_policy": "NONE"`. There is **not one approved retention value in the repository**, proving the manifest is internally consistent with the empty table.

### Gate B — per-child GPS TTL: `ap_m1.location_collection_policies` (`0005` L8-16)
`retain_for interval NOT NULL CHECK(retain_for > 0 AND retain_for <= 365 days)` — the **only hard numeric bound on any retention value in the schema** (ceiling 365 days). No default row ⇒ `ingest_location_batch()` raises `COLLECTION_POLICY_REQUIRED` (0005 L175). **Collection is disabled by default; today no GPS is stored at all.**

### What is actually scheduled (the real gap)
`backend/scripts/run_purge.sh` + `backend/deploy/systemd/ma-purge.timer` (`OnCalendar=hourly`, `Persistent=true`) run exactly **three** jobs, none of them child-data retention:
- `ap_m1.purge_credential_artifacts()` — credential/challenge/abandoned-device artifacts
- `ap_m1.purge_idempotency_keys()`
- `ap_m1.purge_pairing_codes($MA_PURGE_PAIRING_GRACE)` — no default; fails closed if unset

**Not scheduled anywhere:** `purge_expired_location()`, `purge_expired_privacy_audit()`. A repo-wide grep for callers outside `backend/tests/` and `docs/` returns **zero** for both. `purge_expired_privacy_audit()` is granted only to `ap_privacy_worker` (0010 L367), a `NOLOGIN` role with no service, timer or worker in the tree. `purge_expired_location(uuid)` is deliberately **not** API-executable — asserted by `backend/tests/database/test_reconciliation_lifecycle.py` L376-384 (`'retention purge stays internal to worker/migration roles'`) — and is owned by `ap_db_executor`.

**Net implemented behaviour: the retention engine exists, is unit-tested, and is never driven. No retention clock is running in any environment.**

## 2. Summary matrix

| # | Category | Proposed value | Owner status | Enforced today? |
|---|---|---|---|---|
| R1 | Raw GPS observations | 14 d (vs 30 d, unresolved) | **PROPOSAL** | **No** — no policy row, no scheduled purge |
| R2 | Location history — *visible* window | 6 h free / paid lease | **OWNER_APPROVED** (product, not retention) | **Yes** — L66 + `can_read_location_history()` |
| R3 | Location history — *stored* derived (trips/stops/routepoints/places) | 90 d | **PROPOSAL** | **No** — coupled to R1's single `retain_for` |
| R4 | SOS / alerts / check-ins | 12 months | **PROPOSAL** | **No** — no category, no purge function |
| R5 | Media — server content | **never stored** | **OWNER_APPROVED** (mechanism) | **Yes** — DB `CHECK` constraints |
| R6 | Media — metadata / access audit | 12 months | **PROPOSAL** | **No** |
| R7 | Audit/security — 4 wired tables | 90 d / 365 d / 24 mo (3-way conflict) | **PROPOSAL** | Wired, **never invoked** |
| R8 | Audit/security — unwired tables | none exists | **PROPOSAL (no candidate)** | **No** — absent from budget |
| R9 | Telemetry / aggregates | none exists | **PROPOSAL (no candidate)** | **No** |
| R10 | Backups / PITR | 30 d (vs 35 d, unresolved) | **PROPOSAL** | **No** — `expires_at` nullable, FK to absent policy |
| R11 | Erasure / deletion records | derived: ≥ R10 bound | **PROPOSAL (no candidate)** | Partly — restore suppression works; audit purge unscheduled |

---

## 3. Per-category rows

### R1 — Raw GPS observations

**Purpose.** Real-time child-safety location and the evidentiary basis for all derived history. Highest-sensitivity category in the system; §9(3)/Rule 12 purpose limitation (real-time safety) does not obviously authorise long historical retention (`BLOCKERS` L304).

**Current implemented mechanism.**
| Element | Location |
|---|---|
| Table | `ap_m1.location_observations` — `0005_location_ingestion_and_history.sql` L33-53 |
| Clock column | `observed_at` (L35) — matches `clock_basis='OBSERVED_AT'`, **not** `received_at` |
| TTL source | `ap_m1.location_collection_policies.retain_for` (0005 L11) |
| Deletion | `ap_m1.purge_expired_location(c)` — `0019_reconciliation_and_child_binding.sql` L279-303, `DELETE … WHERE observed_at<cutoff` (L286) |
| Acceptance fence | `ingest_location_batch()` 0005 L200 rejects any event with `t < clock_timestamp()-policy.retain_for` **or** `t < clock_timestamp()-policy.max_upload_age` |
| Device-queue bound | `max_upload_age` (0005 L12-13), hard `CHECK(… <= interval '48 hours')`, default 48 h |
| Supporting rows | `location_event_dedup.first_seen_at` (0005 L23-32), `location_ingest_batches.accepted_at` (L15-22), `location_batch_items` (0015 L5-12, **no time column** — inherits batch), `device_latest_positions` (0005 L54-60, no clock; cascades), `ingestion_outbox` (0005 L61-70, cascades from batch) |

**Enforcement gaps in the implemented code.** (a) `retain_for` is **per-child row config**, not a global category — an owner decision alone installs nothing; a data migration must insert one policy row per child. (b) `purge_expired_location` is **never called** (§1). (c) There is **no partition policy** — manifest says `"partition_policy": "NONE"` for every table, so this is row-by-row `DELETE`, not partition drop; at 1,008 children × 10–15 min cadence this will not scale and will bloat WAL. (d) `retain_for` also silently doubles as an *acceptance* window, so lowering it retroactively changes ingestion behaviour, not just deletion.

**Proposed value.** **14 days**, measured from `observed_at`.
**Status.** **PROPOSAL.** `DATA_RETENTION_SCHEDULE.md` records an unresolved **14 vs 30 day** conflict (R-03: *"CONFLICT: older 14 days; neither approved"*); B-07 planning candidate is 14 d (`BLOCKERS` L74); LG-05 also 14 d (L221).

**Exact enforcement mechanism the code should use.**
1. `INSERT INTO ap_m1.retention_policy_versions(category,version,state,period_days,clock_basis,purpose,deletion_method,backups_bound_days,approval_reference,effective_from)` with `category='LOCATION_RAW'`, `state='APPROVED'`, `clock_basis='OBSERVED_AT'`, `backups_bound_days` = R10's decided value, and the owner's signed reference — this is the only legal way to arm Gate A.
2. `INSERT INTO ap_m1.location_collection_policies(child_id, enabled, retain_for, max_upload_age, policy_reference)` per child, `retain_for='14 days'`, referencing the `retention_policy_versions.id`.
3. Replace the hard-coded policy lookup in `purge_expired_location` with `ap_m1.retention_deadline('LOCATION_RAW', o.observed_at)` so one signed value governs both gates and cannot drift.
4. Convert `location_observations` to `PARTITION BY RANGE (observed_at)` **before** real data exists, and purge by `DROP PARTITION`; keep row-level `DELETE` only as the fallback path. Note `location_batch_items` and `location_event_dedup` must be re-partitioned consistently or the FK order in 0019 L290-301 will fight the drops.
5. Add a fourth job to `backend/scripts/run_purge.sh` + `ma-purge.timer` under a dedicated `ap_privacy_worker` login (currently `NOLOGIN`), with `MA_PURGE_LOCATION_BATCH` bounded per child per tick.

---

### R2 — Location history, **visible** (free vs paid)

**Purpose.** Product access control. This is the row that must **not** be entered as a retention value.

**Current implemented mechanism.**
| Element | Location |
|---|---|
| RLS predicate | `ap_m1.can_read_location_history(c,t)` — 0005 L159-167 |
| Free window | `CASE WHEN t>=statement_timestamp()-interval '6 hours' THEN true ELSE _has_premium_history_lease(c) END` (L163) |
| Paid extension | `ap_m1._has_premium_history_lease(c)` — 0005 L131-158 (paid access + `VIEW_HISTORY` scope + live trusted-session lease + viewer capacity slot) |
| HTTP hard floor | `backend/src/free_location_reads.h` L64-68: `AND o.observed_at>=statement_timestamp()-interval '6 hours'`; response emits `out["history_window_hours"]=6` (L73) |
| Policies | `history_read` on `location_observations` (0005 L316); `trips_read`/`revisions_read`/`routepoints_read` (L320-322); `latest_read` on `device_latest_positions` (L317-319) |

**Notable**: `latest_read` (L317-319) applies the **same** 6-hour bound to last-known position, so a device quiet for >6 h returns *nothing* rather than a stale fix — deliberate, but it means "live location" silently degrades to UNAVAILABLE. Any owner decision on retention does not change this.

**Proposed value.** **6 hours (free) / paid lease for older** — retained as product access policy only.
**Status.** **OWNER_APPROVED** as product behaviour (`AGENTS.md`; roadmap L7; DATA_RETENTION_SCHEDULE 2026-10-27 owner direction: *"six-hour free history is an access limit, NOT a retention authorization"*). **Explicitly NOT a retention value** — must not appear as a `period_days` anywhere.
**Exact enforcement mechanism.** Keep exactly as implemented (predicate + RLS + HTTP floor). Do **not** wire it to `retention_policy_versions`. Add a negative test asserting `purge_expired_location` never reads `interval '6 hours'`.

---

### R3 — Location history, **stored** derived (trips, revisions, routepoints, stops, named places)

**Purpose.** Trip reconstruction, parent history views, stop/arrival semantics (B-13 still open). Derived geometry re-exposes home/school even after raw purge, so it cannot inherit R1's clock unexamined — it needs its own, and plausibly **shorter**, period (schedule: *"derived details may require shorter period"*).

**Current implemented mechanism.**
| Table | Migration | Clock used by purge |
|---|---|---|
| `ap_m1.trips` | 0005 L252-259 | `first_observed_at` — `DELETE FROM ap_m1.trips WHERE child_id=c AND first_observed_at<cutoff` (0019 L285) |
| `ap_m1.trip_revisions` | 0005 L261-268 | none; `ON DELETE CASCADE` from trips |
| `ap_m1.trip_routepoints` | 0005 L270-283 | none; cascades from revisions; also FK `source_event_id → location_observations ON DELETE CASCADE` |
| `ap_m1.stops` | `0012_screen_dependency_completion.sql` L208-221 | none; cascades from `trip_revisions` |
| `ap_m1.named_places` | 0005 L284-288 | **none at all** — only `archived_at` (manual, `archive_named_place` 0005 L371) |

**Gap.** R3 has **no TTL of its own**: trips are purged by the *raw GPS* `retain_for`, and `named_places` is **never** purged by age — a home/school pin survives indefinitely after all location data is gone. That is a live privacy defect independent of the owner's number. `trip_routepoints.source_event_id`'s `ON DELETE CASCADE` also means purging raw GPS silently mutates retained trip geometry rather than expiring it deliberately.

**Proposed value.** **90 days** from trip end / `evidence_end`; `named_places` until manually archived or child erasure, **not** a TTL.
**Status.** **PROPOSAL** (R-04: *"90-day rolling"*, unapproved; B-07 planning candidate 90 d; schedule warns it may need to be shorter). `named_places` sentinel: R-04a proposes manual-only deletion — **PROPOSAL**.
**Exact enforcement mechanism.** Add `category='LOCATION_DERIVED'`, `clock_basis='CLOSED_AT'`, own `period_days`, own `backups_bound_days`; rewrite `purge_expired_location` to use `retention_deadline('LOCATION_DERIVED', t.last_observed_at)` for trips (delete oldest-first, not by `first_observed_at`) and a separate `n.trip_routepoints` sweep keyed on `observed_at`; add an explicit `named_places` **archival** job (soft, `archived_at`), never a hard delete while a `stops.place_id` FK still references it.

---

### R4 — SOS / alerts / check-ins

**Purpose.** Safety-critical event record, delivery proof and truthful failure receipts. Must survive long enough to support a safeguarding review or a dispute — the reason its candidate (12 months) is far longer than location.

**Current implemented mechanism.**
| Table | Migration | Clock | Purge |
|---|---|---|---|
| `ap_m1.child_signals` | 0006 L10-18 (`kind IN ('SOS','IM_SAFE','PLEASE_CALL','NEED_PICKUP')`) | `observed_at`, `accepted_at` | **none** |
| `ap_m1.alert_events` | 0006 L19-30 | `observed_at`, `created_at` | **none** |
| `ap_m1.alert_delivery_outbox` | 0006 L31-35 | `created_at` | **none** |
| `ap_m1.notification_deliveries` | 0006 L36-45 | `submitted_at`, `delivered_at` | **none** |
| `ap_m1.alert_delivery_attempts` | 0006 L46-53 | `attempted_at` | **none** |
| `ap_m1.signal_acknowledgements` | 0006 L54-58 | `acknowledged_at` | **none** |
| `ap_m1.parent_notification_read_receipts` | 0006 L59-63 | `read_at` | **none** |

Only implemented bound: ingestion rejects signals older than 48 h (0006 L92) and usage intervals likewise (0006 L191). There is **no `retention_policy_versions` category, no purge function, and no erasure ordering entry for alerts** — `erasure_store_inventory` does purge them on child erasure (`alert_delivery_attempts` 41, `alert_delivery_outbox` 44, `signal_acknowledgements` 45, `alert_events` 50, `child_signals` 51), which is *not* retention.

**Proposed value.** **12 months** from `observed_at`; delivery attempts 90 days (proof value decays faster than the signal).
**Status.** **PROPOSAL** (R-07 *"12 months"*, unapproved; B-07 does not cover SOS at all — a gap to raise).
**Exact enforcement mechanism.** `category='SOS_ALERT'`, `clock_basis='OBSERVED_AT'`, 12 months; a new `ap_m1.purge_expired_alerts()` mirroring the 0010 shape — `DELETE … WHERE retention_deadline('SOS_ALERT', observed_at)<=statement_timestamp() AND NOT EXISTS(unreleased retention_holds for the child)` — ordered children→downstream, and granted to `ap_privacy_worker`. Must consult `retention_holds` (0010 L273-278) because a safeguarding hold is exactly the case this table exists for.

---

### R5 — Media, **server content**

**Purpose.** Audio/video/photo/screen capture. Owner accepted conditional media R&D but precluded any server-side media archive.

**Current implemented mechanism — the strongest control in the schema (DB-level, not policy-level).**
| Constraint | Migration |
|---|---|
| `capture_artifact_refs.storage_location text NOT NULL CHECK(storage_location='PARENT_LOCAL_ACK_ONLY')` | 0009 L119-128 (single-valued enum) |
| `erasure_state text NOT NULL DEFAULT 'NOT_SERVER_STORED' CHECK(erasure_state='NOT_SERVER_STORED')` | 0009 L127 |
| `acknowledgement_id uuid NOT NULL UNIQUE` — *"An opaque local acknowledgement ID, never a URL/path or downloadable server media"* (comment L125) | 0009 L126 |
| `media_sessions.transport_mode … CHECK(transport_mode='LOCAL_SYNTHETIC_NO_CAPTURE')` | 0009 L53 |
| file header: *"Metadata-only local domain. No URLs, filenames, media blobs or transport secrets."* | 0009 L1 |
| `media_capability_gates` + `media_command_requests.state CHECK(state='UNSUPPORTED')`, `reason_code CHECK(reason_code='FEATURE_NOT_RELEASED')` | 0009 L29, L37-46 |

**Proposed value.** **0 days — no VPS media content is ever stored.**
**Status.** **OWNER_APPROVED** as *mechanism* (owner design decision 2026-10-27, `BLOCKERS` L269-271: *"Keep no VPS media files"*). Note this is approval of the storage mechanism, not a B-07 duration; the constraint makes a duration moot.
**Exact enforcement mechanism.** Already enforced by the four `CHECK` constraints above — keep them single-valued (never widen to a second `storage_location`), and add a test asserting `capture_artifact_refs` has no `bytea`/`text` column capable of holding a URL or path. Record in `retention_policy_versions` as `period_days` is impossible — this category must be represented as a **documented exclusion**, not a row with 0 days (`period_days>0` is a `CHECK`). `capture_artifact_refs.expires_at` (0009 L128) is nullable and **nothing enforces it** — if it is meant to bound the parent-device ack reference, it needs a sweep.

---

### R6 — Media metadata and media access audit

**Purpose.** Bounded authenticated media-operation metadata (child/actor/kind/status/duration/size/viewed-vs-saved/true failure reason). Still sensitive: it reveals when a child was photographed or watched.

**Current implemented mechanism.**
| Table | Migration | Clock | Purge |
|---|---|---|---|
| `ap_m1.media_command_requests` | 0009 L37-46 | `created_at` | none |
| `ap_m1.media_sessions` | 0009 L47-56 | `started_at`, `ended_at` | none |
| `ap_m1.media_lifecycle_events` | 0009 L57-64 | `event_at` | none |
| `ap_m1.media_quota_ledger` | 0009 L109-117 | `committed_at` | none |
| `ap_m1.media_access_audit` | 0009 L130-135 | `accessed_at` | none |
| `ap_m1.media_export_requests` | 0009 L137-142 | `requested_at` | none |

No `retention_policy_versions` category; no purge function. Erasure only (`erasure_store_inventory` 290-350).

**Proposed value.** **12 months** metadata; `media_access_audit` follows R7's admin/access-audit number (24 months) rather than 12.
**Status.** **PROPOSAL** (R-08 *"12 months"*, unapproved; *"highly sensitive"* per schedule). Media features are OFF, so no clock is accruing.
**Exact enforcement mechanism.** `category='MEDIA_METADATA'` (`clock_basis='CLOSED_AT'`, effective from session `ended_at`) + a separate `category='MEDIA_ACCESS_AUDIT'`. Because media is OFF and `media_sessions.ended_at` is `NOT NULL DEFAULT clock_timestamp()` (0009 L52), closed sessions are already purge-eligible the day the feature ships — the clock must be armed **before** `media_capability_gates` is opened, not after.

---

### R7 — Audit/security — the four **wired** tables

**Purpose.** Independent, restricted admin-access and consent/erasure evidence. Must outlive the data it describes and must not be erasable by the staff it audits.

**Current implemented mechanism — the only place in the repo where a retention deadline actually drives a `DELETE`.**
| Table | Migration | Clock | Category key |
|---|---|---|---|
| `ap_m1.admin_action_audit` | `0008_admin_identity_rbac_and_support.sql` | `occurred_at` | `'ADMIN_AUDIT'` (0010 L285) |
| `ap_m1.admin_support_read_audit` | 0008 | `accessed_at` | `'SUPPORT_ACCESS_AUDIT'` (0010 L289) |
| `ap_m1.consent_decision_audit` | 0003 L15-21 | `occurred_at` | `'CONSENT_AUDIT'` (0010 L293) |
| `ap_m1.erasure_evidence` | 0010 L35-40 | `created_at` | `'ERASURE_AUDIT'` (0010 L297) |

Driver: `ap_m1.purge_expired_privacy_audit()` — 0010 L281-302. Correctly fail-closed: 0010 L284 comment *"Absence of approved category policy evaluates to NULL, never to forever/zero."* Each `DELETE` is guarded by `NOT EXISTS(… retention_holds h WHERE h.category=… AND h.released_at IS NULL AND (h.subject_ref IS NULL OR h.subject_ref=<row ref>))` — a **blanket (NULL subject) hold is supported**, and `retention_holds.review_by` has `CHECK(review_by>created_at)` (0010 L273-278) so a hold cannot be created already-expired.

**Because all four category rows are absent, every subquery returns NULL and `NULL <= now()` is NULL — the function deletes nothing even if it were called.** It also is not called (§1).

**Proposed value.** 4-way conflict: **90 days** (B-07 planning candidate) / **24 months** (`R-11`) / **365 days** (`LG-05` "audit 365d legal candidate") / **180 days** (CERT-In rolling ICT logs, `R-10`).
**Status.** **PROPOSAL.** All four are unapproved. `R-10` is the only one with an external legal driver and it applies to **ICT/security logs**, not to admin case access — collapsing them is exactly the error the schedule warns against.
**Exact enforcement mechanism.** Four distinct `retention_policy_versions` rows — `ADMIN_AUDIT`, `SUPPORT_ACCESS_AUDIT`, `CONSENT_AUDIT`, `ERASURE_AUDIT` — with their own `period_days`, `clock_basis` (`CREATED_AT`/`OBSERVED_AT` as appropriate), `deletion_method`, and `backups_bound_days`. Then: promote `ap_privacy_worker` to a `LOGIN` role with no table privileges, add it as a fourth job in `run_purge.sh`, and add a test asserting that with zero approved rows `purge_expired_privacy_audit()` returns 0 **and** that with a hold present it still returns 0 after expiry.

---

### R8 — Audit/security — tables **outside** the retention budget

**Purpose.** Same evidentiary role as R7, but no clock is wired. These are silent unbounded-growth and unbounded-liability surfaces.

**Current implemented mechanism (i.e. none).**
| Table | Migration | Time column present? | In `purge_expired_privacy_audit`? |
|---|---|---|---|
| `ap_m1.security_audit_events` | `0011_operations_integrity_and_indexes.sql` L49-54 | `occurred_at` | **No** |
| `ap_m1.audit_events` | `0001_m1_identity.sql` L157-166 | `observed_at` | **No** |
| `ap_m1.media_access_audit` | 0009 L130-135 | `accessed_at` | **No** (see R6) |
| `ap_m1.entitlement_audit` | 0004 | `observed_at` | **No** |
| `ap_m1.admin_sessions` / `admin_email_challenges` | 0008 | session/expiry only | **No** |

`ap_m1.security_audit_events` is the table a CERT-In 180-day obligation would attach to — and it has **no retention wiring whatsoever**. It also carries only `resource_digest` (32-byte), a good minimisation already implemented.

**Proposed value.** **180 days** for `security_audit_events` (external duty, jurisdiction-scoped); `audit_events` 24 months; `admin_sessions`/challenges: session expiry + 7 days.
**Status.** **PROPOSAL — no candidate exists in any canonical document.** This is a genuine gap in B-07's scope, not a value awaiting ratification.
**Exact enforcement mechanism.** Add `category='SECURITY_ICT_LOG'` and `'FAMILY_AUDIT'` to the registry, extend `purge_expired_privacy_audit()` with matching `DELETE … AND NOT EXISTS(hold)` blocks (copy the 0010 L285-299 pattern exactly), and gate `SECURITY_ICT_LOG` behind an explicit `jurisdiction='IN'` condition so the 180-day duty is not silently applied to rows outside its scope.

---

### R9 — Telemetry and aggregates

**Purpose.** Capacity, cost and reliability. Intended to be non-personal.

**Current implemented mechanism.**
| Table | Migration | Shape | Purge |
|---|---|---|---|
| `ap_m1.telemetry_aggregates` | 0011 L55-60 | `PRIMARY KEY(bucket_start, service, outcome)`, `event_count`, `duration_ms`, `updated_at` — **no `child_id`** | none |
| `ap_m1.cost_usage_snapshots` | 0011 L61-67 | `period_start`,`period_end`,`service`,`unit`,`quantity` | none |
| `ap_m1.parent_service_usage_events` | manifest → 0011 lineage | no clock column | none |

`telemetry_aggregates` is genuinely child-free by schema, which is the strongest structural anonymity evidence available — **but it is not "certified irreversibly anonymous"**: `service`+`outcome` buckets at 1,008-family scale, or a single-child outage, can re-identify by correlation. R-18 says anonymity must be demonstrable, *"cannot be deemed anonymous on assertion."*

**Proposed value.** **400 days** (covers year-over-year capacity planning); `cost_usage_snapshots` **7 years** if it must substantiate tax/GST (see R-09 payments, still unresolved with the accountant).
**Status.** **PROPOSAL — no candidate exists for telemetry in any canonical document.** R-18 declines to set a limit.
**Exact enforcement mechanism.** `category='TELEMETRY_AGGREGATE'`, `clock_basis='CREATED_AT'` on `bucket_start`; a `DELETE … WHERE bucket_start < statement_timestamp()-interval '400 days'` driven by `retention_deadline`, plus a `CHECK` that no future column named `child_id`/`device_id` is added to this table (a schema guard, since the current anonymity is structural and easy to break).

---

### R10 — Backups / WAL / PITR

**Purpose.** Disaster recovery. The category that most often silently defeats erasure.

**Current implemented mechanism.**
| Element | Location |
|---|---|
| `ap_m1.backup_inventory` | 0010 L41-46 — `completed_at`, `expires_at` **nullable**, `destroyed_at`, `retention_policy_id uuid REFERENCES retention_policy_versions(id)`, `CHECK(expires_at IS NULL OR expires_at>completed_at)` |
| `ap_m1.backup_erasure_manifests` | 0010 L47-53 — `state IN ('SUPPRESS_ON_RESTORE','PURGED','EXPIRED_VERIFIED')`, `purge_by`, `proof_sha256`; `CHECK(state='SUPPRESS_ON_RESTORE' OR (verified_at IS NOT NULL AND proof_sha256 IS NOT NULL))` |
| `ap_m1.restore_runs` | 0010 L54-59 — default `state='QUARANTINED'` |
| `ap_m1.restore_suppression_receipts` | 0010 L60-… — FK `child_id → child_erasure_tombstones` |
| `ap_m1.restore_can_open(t)` | 0010 L234-242 — refuses to open unless `state='READY'`, ledger matches, **every** tombstoned child has a receipt `suppressed_at>=t.erased_at`, **and** no restored child is un-deleted |
| `ma_recovery.erasure_ledger` | `0013_restore_quarantine_and_erasure_ledger.sql` L7-12 — `child_id` PK, **no FK by design** |
| Dump path | `tools/database/manage.py` L704 — `pg_dump -Fc --exclude-schema=ma_recovery` |

**Implemented honestly:** restore suppression is real and well-tested in design. **Not implemented:** any actual backup schedule, any WAL/PITR configuration (repo-wide grep for `wal_level`/`archive_mode`/`archive_command`/`pg_basebackup` returns **nothing**), and any enforcement of `backup_inventory.expires_at` — it is nullable, never computed, and its `retention_policy_id` points at an empty table. `--exclude-schema=ma_recovery` means the local dump omits the very ledger suppression depends on, so suppression after a restore requires a manual `import_restore_ledger()` step (0010 L354) — a documented operational hazard, not a bug.

**Proposed value.** **30 days** (LG-05) vs **35 days** (R-12) — unresolved.
**Status.** **PROPOSAL.** `R-12`: *"35 days proposed, not verified against RPO/RTO or deletion rights"*.
**Exact enforcement mechanism.** `category='BACKUP'`, `clock_basis='BACKUP_COMPLETED_AT'` (an existing enum value), `period_days`=<decided>, **and `backups_bound_days` must equal the same number** — the `CHECK` on 0003 L36-38 forces both, which is precisely the field that makes "primary purge ≠ backup erasure" auditable. Then: make `backup_inventory.expires_at` `NOT NULL` and `GENERATED`/triggered from `retention_deadline('BACKUP', completed_at)`, require `retention_policy_id` to reference an APPROVED row, and add a job that transitions manifests to `EXPIRED_VERIFIED` only with `proof_sha256`. WAL retention needs explicit `archive_timeout`/`recovery_target_time` config **in the deployment layer**, which does not exist yet — this must be decided with B-08, not B-07 alone.

---

### R11 — Erasure and deletion records

**Purpose.** Prove deletion happened, prevent re-ingestion and resurrect-on-restore, and satisfy a rights request. These records must **outlive the data** they attest to — the inverse of every other row.

**Current implemented mechanism.**
| Table | Migration | Clock | Retention wiring |
|---|---|---|---|
| `ap_m1.account_deletion_requests` | 0010 L9-18 | `received_at`, `deadline` **never assigned** (only L15 defines it; no writer in any migration) | none |
| `ap_m1.erasure_jobs` | 0010 L19-27 | `completed_at` | none |
| `ap_m1.erasure_job_targets` | 0010 L28-34 | `completed_at`, `proof_sha256` required when completed | none |
| `ap_m1.erasure_evidence` | 0010 L35-40 | `created_at`, `retention_policy_id` FK | **`'ERASURE_AUDIT'`** (0010 L297) — wired |
| `ap_m1.child_erasure_tombstones` | `0002_child_scoped_cross_family_guardians.sql` L50 | `erased_at` | none — **must be none** |
| `ma_recovery.erasure_ledger` | 0013 L7-12 | `erased_at`, `recorded_at` | none — **must be none** |
| `ap_m1.adult_erasure_requests` | `0014_account_erasure_requests.sql` L4-11 | `requested_at` | none |
| `ap_m1.adult_erasure_jobs` | 0014 L13-20 | `due_at`, `completed_at`, `retention_policy_id` FK | **default `state='BLOCKED_POLICY'`** (L16) |
| `ap_m1.erasure_store_inventory` | 0010 L81-84 | `purge_order` | n/a (configuration) |

**Implemented honestly:** `adult_erasure_jobs.state DEFAULT 'BLOCKED_POLICY'` is a correct fail-closed default — adult erasure cannot proceed without an approved policy. The child path (`_purge_child_data` 0010 L109-…, `_restore_ledger_matches`, `restore_can_open`) is implemented and does not depend on a retention number, which is right.

**Gaps.** `account_deletion_requests.deadline` is declared and **never written** — so no response SLA is actually computed; the 3-day/30-day targets remain unimplemented product commitments. Tombstones and the ledger have no TTL and correctly no FK, but there is also **no bound at all** — they grow forever, which is the intended behaviour and should be stated as such rather than left implicit.

**Proposed value.** `ERASURE_AUDIT` evidence and erasure job records: **13 months** (must strictly exceed R10's backup bound so evidence outlives restore-ability). Tombstones + `ma_recovery.erasure_ledger`: **indefinite, no TTL** — required for restore suppression to remain valid across the full backup history and beyond.
**Status.** **PROPOSAL — no candidate exists** for erasure-record retention in `DATA_RETENTION_SCHEDULE.md`, B-07, or R-01…R-18. The "13 months" above is derived from the backup bound, not from any source document; it is my construction and is labelled as such.
**Exact enforcement mechanism.** `category='ERASURE_AUDIT'` (already referenced — only the row is missing) with `period_days` > R10's; **no** `retention_policy_versions` row and **no** purge function for `child_erasure_tombstones` / `ma_recovery.erasure_ledger`, enforced by a negative test that no purge function names them. Separately: compute `account_deletion_requests.deadline` inside `_purge_child_data` from an approved `'DELETION_SLA'` row, so the declared column stops being dead.

---

## 4. Values that cannot be implemented until the owner decides

**Nothing in this matrix is implementable today.** Not one row has an approved value, and the blocking reason differs by row:

1. **R1 raw GPS, R3 derived (14/30/90 d) — hard-blocked.** The number is ambiguous in three places (14 vs 30 raw, 90 derived unverified, possibly shorter). Nothing can be inserted into `location_collection_policies.retain_for` because there is no defensible value, and the column's `CHECK (… <= 365 days)` is a ceiling, not an answer. Until decided, `enabled=false` keeps collection OFF — correct, and the reason no GPS exists anywhere.
2. **R4 SOS (12 mo), R6 media metadata (12 mo) — blocked on scope, not only duration.** B-07's question (*"raw GPS, trips, usage, audit and backups"*) **does not mention SOS or media at all**. The owner cannot approve what was never asked. Both need to be added to the question first.
3. **R7 audit — hard-blocked by a 4-way conflict.** 90 d / 24 mo / 365 d / 180 d cannot be reconciled without the owner picking a purpose (product audit vs CERT-In ICT log vs litigation evidence). Picking one number for all four tables would be wrong.
4. **R8 security logs, R9 telemetry, R11 erasure records — blocked by absence of any candidate.** No document proposes a value. An owner "yes" cannot be obtained for a blank.
5. **R10 backups (30 vs 35 d) — blocked on B-07 *and* B-08.** `backups_bound_days` is a `NOT NULL`-when-approved field; WAL/PITR retention is deployment configuration and the repo has zero `archive_mode`/`wal_level` settings. This value cannot be implemented before a hosting/DR decision exists.
6. **R2 visible window and R5 media content — not blocked, and correctly not part of B-07.** Both are already decided and already enforced. Conflating them with B-07 is the specific error this matrix exists to prevent.
7. **Cross-cutting: even a decided number is not sufficient.** Arming retention requires four code changes that B-07 does not authorise and that no PR currently proposes: (a) `APPROVED` rows in `retention_policy_versions`, (b) per-child `location_collection_policies` rows, (c) a scheduled runner for `purge_expired_location` / `purge_expired_privacy_audit` with `ap_privacy_worker` as a `LOGIN` role, (d) partitioning for `location_observations`. A verbal "14 days" changes nothing on its own.

## 5. Recommended owner question list

Ordered so each answer unblocks the next. Each is answerable in one line; the parenthetical is the exact schema consequence.

1. **Raw GPS: 14 or 30 days, clocked from `observed_at`?** The two prior documents conflict and neither is adopted. (Sets `location_collection_policies.retain_for` and `retention_policy_versions` `'LOCATION_RAW'`.)
2. **Does that number also bound derived trips/stops, or do you want a separate — possibly shorter — derived period (90 d candidate)?** Derived geometry re-exposes school/home after raw purging. (Sets `'LOCATION_DERIVED'` with `CLOSED_AT`.)
3. **Should `named_places` (home/school pins) ever expire automatically, or only on manual archive or child erasure?** Today they never expire by age. (Determines whether a sweep is added at all.)
4. **Is a 90-day audit figure, a 24-month admin-case figure, a 365-day figure, or the 180-day CERT-In ICT-log duty the one you mean — and which table does each apply to?** These are four different purposes currently sharing one undecided slot.
5. **Do you accept that the CERT-In 180-day obligation applies to `security_audit_events`, which currently has no retention wiring at all?** (Adds `'SECURITY_ICT_LOG'` and a jurisdiction condition.)
6. **SOS/alert records: 12 months from `observed_at`?** Note B-07's wording omits SOS entirely — please confirm it is in scope. (Adds `'SOS_ALERT'` + a new purge function.)
7. **Media metadata: 12 months, and is media content permanently excluded from server storage in writing?** Content exclusion is already enforced by DB constraint; metadata has no clock. (Adds `'MEDIA_METADATA'`; records content as an exclusion, not a 0-day row.)
8. **Backups: 30 or 35 days, and what is the accepted maximum time a deleted child can still exist in a backup?** This must equal `period_days` and `backups_bound_days`. (Both are `CHECK`-coupled on approval.)
9. **Is WAL/PITR retention in scope for B-07 or deferred to B-08 hosting?** The repo configures no `archive_mode`; the answer determines whether this is a policy or a deployment task.
10. **How long must erasure evidence and tombstones outlive backups?** My suggestion is evidence = backup bound + 1 month, tombstones and the restore ledger indefinite with no TTL. (Confirm the indefinite part explicitly — it is the one place "keep forever" is correct.)
11. **Telemetry/aggregates: is 400 days acceptable, and what evidence would you accept that `telemetry_aggregates` is non-reidentifiable?** It has no `child_id`, which is structural but not certified.
12. **App usage: 30 days (R-05) or 90 days (B-07 planning candidate)?** Still conflicting; the feature is OFF so this is currently cost-free to decide.
13. **May engineering begin the four arming changes (approved policy rows, per-child policies, a scheduled purge runner, `location_observations` partitioning) once you have answered 1–12 — and on which branch (`api` → `dev` → `main`)?** A retention value with no runner is inert; this is the question that converts your answers into working code.

## 6. Verification notes

- Canonical documents read with `git show origin/main:<path>`; no checkout, merge or tracked-file modification.
- Live DB state read read-only from `.local-db/connection.json` → `test` DSN under `SET TRANSACTION READ ONLY`; **`SELECT count(*)` only, no writes.**
- `retention-ownership-manifest.json` parsed programmatically: 144 tables, **0** with an approved value, **0** with a non-null `candidate_period`, **0** with a partition policy.
- Implemented-behaviour column derived by grepping `retain_for`, `retention_policy_versions`, `retention_holds`, `retention_deadline`, `purge_*`, `expires_at`, and `private`/`tombstone` symbols across `backend/persistence/migrations/*.sql`, then confirming caller existence across `backend/`, `tools/`, `infra/` and `backend/deploy/`.
- Claims labelled `PROPOSAL` are proposals. The `13 months` erasure-evidence figure in R11 is my own derivation, not a source value, and is flagged in place.
- This draft closes nothing. B-07 remains **OPEN/UNDECIDED**; `real_child_release` remains **OFF**.
