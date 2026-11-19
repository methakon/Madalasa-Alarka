# M8 Pre-Release Audit Dossier — Madalasa–Alarka Free V1 Release Candidate

**Document ID:** M8-AUDIT-DOSSIER-2026-11-08  
**Date:** 2026-11-08  
**Target Milestone:** M8 Operational Readiness / Free V1 Release Candidate  
**Branch:** `main` (Canonical Documentation)  
**Integration Scope:** `dev` (`598f7cf583cdcac5e7c22f83f2a526e0793ac33a`) → `main` (`90e766e497e49916abe7f6b8d42741dc2381cb3f`)  
**Integration Pull Request:** [PR #60](https://github.com/methakon/Madalasa-Alarka/pull/60) (393 commits, 185 changed files, +15,230 / -318 lines)  
**Release Gate Status:** **PRE-RELEASE CANDIDATE — NOT AUTHORIZED FOR LIVE MINOR DATA OR PRODUCTION DEPLOYMENT**  
**Staging Environment:** `x402-endpoint` (Ubuntu 24.04, 2 vCPU, 954 MiB RAM, 1023 MiB swap)  

---

## Executive Summary

This dossier consolidates the pre-release audit, security assessment, physical device acceptance, database isolation, infrastructure continuity, and governance review for the Madalasa–Alarka Free V1 release candidate. All implementation work across the four permanent development branches (`api`, `parent`, `child`, `admin-web`) has been successfully integrated into `dev` and proposed to `main` via PR #60 following canonical branch governance.

Every staging verification gate has completed with verified positive and negative test evidence:
1. **Security & Penetration Hardening:** Public security baseline (14/14 PASS), Nginx reverse proxy hardening (HSTS, CSP, port 80 301 HTTPS redirect, `server_tokens off`), admin SPA logout failure recovery, and loopback API listener isolation.
2. **Physical Handset Acceptance:** Native Android 11 (Mi A3) parent app and Android 9 (ELUGA I7) child app verified on live public `x402` infrastructure. Genuine Google parent OIDC login, child visible SOS, guardian signal retrieval and manual ACK, child status confirmation to `GUARDIAN_ACKNOWLEDGED`, offline SQLite/XML outbox persistence across force-stop, replayed delivery, revoked credential denial (401), and cross-family isolation (403).
3. **Database Security & Lineage:** Remote Neon PostgreSQL connected via `verify-full` TLS with CA verification. 100% of `ap_m1` physical tables enforce PostgreSQL Row-Level Security (RLS) with default-deny. Complete sequence of migrations `0001_m1_identity.sql` through `0031_child_signal_device_status.sql` and compatibility guards verified.
4. **App Permissions & Safety:** Both Android applications request exclusively `android.permission.INTERNET`. Zero covert recording, microphone, camera, or screen recording permissions. Google Play Families policy metadata `isMonitoringTool="child_monitoring"` declared.
5. **Infrastructure Continuity:** Nginx, OpenSMTPD (ports 25, 465, 587), Dovecot (ports 993, 995), and Drogon C++ backend operated continuously with zero service disruption and stable host memory on `x402`.

---

## 1. Security Assessment & Penetration Hardening

**Tracking Issues:** [Issue #54](https://github.com/methakon/Madalasa-Alarka/issues/54) (Staging penetration assessment), [Issue #57](https://github.com/methakon/Madalasa-Alarka/issues/57) (Closed — follow-up hardening).

### 1.1 Implemented Security Fixes
| PR | Branch Route | Description | Retest Status |
|---|---|---|---|
| **#55** | `api → dev` | Opt-in low-impact public security baseline tool (`deploy/x402/api/public-security-baseline.py`) with explicit `MA_SECURITY_BASELINE_AUTHORIZED=YES` gate. | **PASS** (14/14 on live `x402`) |
| **#56** | `api → dev` | Hardened Nginx port 80 listener for `api.madalasa.berhampore.in` with 301 HTTPS redirect, `server_tokens off`, and security headers preservation. | **PASS** (`curl -sI` 301 verified) |
| **#58** | `api → dev` | Restored admin proxy Content Security Policy (CSP) and HSTS header inheritance inside `location ^~ /v1/admin/` and enforced `Cache-Control: no-store` on all API responses. | **PASS** (`curl -sI` headers verified) |
| **#59** | `admin-web → dev` | Prevented unconditional client-side signout in `admin-web/src/main.tsx` when server logout fails; implemented error presentation and retry handling. | **PASS** (11/11 tests pass) |

### 1.2 Public Security Baseline Execution (14/14 PASS)
- **Command:** `MA_SECURITY_BASELINE_AUTHORIZED=YES python3 deploy/x402/api/public-security-baseline.py`
- **Exit Code:** `0`
- **Results:**
  - `admin_home`: HTTP 200 (PASS)
  - `admin_blocks_capabilities`: HTTP 404 (PASS)
  - `admin_blocks_child_signals`: HTTP 404 (PASS)
  - `admin_blocks_device_signals`: HTTP 404 (PASS)
  - `api_healthz`: HTTP 200 (PASS)
  - `api_capabilities`: HTTP 200 (PASS)
  - `api_blocks_admin`: HTTP 404 (PASS)
  - `api_blocks_admin_challenge`: HTTP 404 (PASS)
  - `api_blocks_root`: HTTP 404 (PASS)
  - `api_blocks_readiness`: HTTP 404 (PASS)
  - `api_parent_signals_unauth`: HTTP 401 (PASS)
  - `api_device_signal_status_unauth`: HTTP 401 (PASS)
  - `api_parent_profile_unauth`: HTTP 404 (PASS)
  - `admin_admin_session_unauth`: HTTP 404 (PASS)
  - **Summary:** 14 checks executed, 14 passed, 0 review, 0 errors.

---

## 2. Physical Two-Handset SOS & Guardian Acknowledgment

**Tracking Issue:** [Issue #52](https://github.com/methakon/Madalasa-Alarka/issues/52)  
**Test Evidence Record:** `docs/phases/M8-operational-readiness/03-quality-and-evidence/X402_PUBLIC_ACCEPTANCE_OAUTH_SIGNING_AND_WAF_2026-11-07.md`

### 2.1 Hardware Test Fixtures
- **Parent Handset (Device B):** Xiaomi Mi A3 (`edd53dbd04de`, Android 11)
  - Package: `in.berhampore.madalasa.synthetic`
  - APK SHA-256: `1ba6504636359c8fd33e407dc1e6fdece1992d996a836e8a8a1455e80f4686fd`
  - Signing SHA-1: `D1:35:08:5A:88:E6:B5:B8:27:F5:64:DE:57:D6:61:40:13:BB:56:61`
- **Child Handset (Device A):** Panasonic ELUGA I7 (`LRW86SC6RO8TZ99H`, Android 9)
  - Package: `in.berhampore.alarka.synthetic`
  - APK SHA-256: `eb7690e812be4c3c17f56286e9892f084f648aa232b6ba2fc2c0b9636f610bf8`
  - Signing SHA-1: `D1:35:08:5A:88:E6:B5:B8:27:F5:64:DE:57:D6:61:40:13:BB:56:61`

### 2.2 End-to-End Workflow & Negative Matrix Results
| Test Case | Method & Endpoint | Observed Result | Verdict |
|---|---|---|---|
| Parent Google OIDC Login | `POST /v1/auth/parent/google` | HTTP 201 Created; session cookie issued | **PASS** |
| Child Manual SOS Trigger | `POST /v1/devices/{deviceId}/signals` | HTTP 201 Created (`SERVER_ACCEPTED`); persisted to outbox | **PASS** |
| Guardian Signal Retrieval | `GET /v1/children/{childId}/signals` | HTTP 200 OK; active SOS visible on parent dashboard | **PASS** |
| Guardian Manual ACK | `POST /v1/children/{childId}/signals/{eventId}/ack` | HTTP 200 OK; acknowledgement recorded in DB | **PASS** |
| Child Convergence & Outbox Clear | `GET /v1/devices/{deviceId}/signals/{eventId}/status` | Returns `GUARDIAN_ACKNOWLEDGED`; `alarka_sos_outbox_v1.xml` cleared | **PASS** |
| Offline Persistence & Force-Stop | SQLite/XML storage check | Ciphertext and IV persisted across process force-stop | **PASS** |
| Offline Reconnect & Manual Replay | `POST /v1/devices/{deviceId}/signals` | HTTP 201; replayed with exact UUID, accepted, and cleared | **PASS** |
| Revoked Device Credential | Deliberately revoked token | HTTP 401 Unauthorized (`AUTHORIZATION REVOKED`); retries stopped | **PASS** |
| Cross-Family Tenant Isolation | Synthetic Family B token | HTTP 403 Forbidden on Child A signals and ACK endpoints | **PASS** |

> [!NOTE]
> As documented in Issue #52, the earlier standalone child SOS event UUID (`6653240d-...`) and the later acknowledged event UUID (`77553d50-...`) represent two separate sequential test events. They were not a single broken event. Independent automated end-to-end replay on physical hardware without human intervention remains an ongoing quality objective.

---

## 3. PostgreSQL Database Lineage, RLS, and TLS

### 3.1 Actual Migration Catalog (`backend/persistence/migrations/`)
The physical database migration chain consists of 31 sequentially applied SQL migrations plus 4 compatibility lineage guards:
1. `0001_m1_identity.sql`
2. `0002_child_scoped_cross_family_guardians.sql`
3. `0002_m1_device_credentials.sql`
4. `0003_consent_authority_and_retention.sql`
5. `0003_m1_enrollment_and_credential_hardening.sql`
6. `0004_billing_prepaid_entitlements.sql`
7. `0004_m1_idempotency.sql`
8. `0005_location_ingestion_and_history.sql`
9. `0005_m1_family_provisioning.sql`
10. `0006_alerts_checkins_and_usage.sql`
11. `0006_m1_concurrency_and_retention_holds.sql`
12. `0007_commands_and_device_capabilities.sql`
13. `0008_admin_identity_rbac_and_support.sql`
14. `0009_media_sessions_and_quota.sql`
15. `0010_erasure_audit_and_recovery.sql`
16. `0011_operations_integrity_and_indexes.sql`
17. `0012_screen_dependency_completion.sql`
18. `0013_restore_quarantine_and_erasure_ledger.sql`
19. `0014_account_erasure_requests.sql`
20. `0015_ingestion_membership_and_fences.sql`
21. `0016_pickup_passes_and_compliance_bundles.sql`
22. `0017_m1_lineage_compatibility.sql`
23. `0018_schema_enhancement_guards.sql`
24. `0019_reconciliation_and_child_binding.sql`
25. `0020_m1_current_lineage_convergence.sql`
26. `0021_parent_oidc_session_bridge.sql`
27. `0022_admin_session_bridge_and_back_office.sql`
28. `0023_free_first_108_child_admission.sql`
29. `0024_single_active_child_device_pairing_audit.sql`
30. `0025_rls_default_deny_and_role_boundary.sql`
31. `0026_ingest_receipt_and_conflict_codes.sql`
32. `0027_device_credential_transaction_context.sql`
33. `0028_child_erasure_dependency_order.sql`
34. `0029_guardian_revocation_and_invite_validation.sql`
35. `0030_guarded_device_pairing_code_issuer.sql`
36. `0031_child_signal_device_status.sql`
- **Compatibility Guards (`backend/persistence/migrations/compat/`):**
  - `compat/m1_pre_v2_0016.sql`
  - `compat/m1_pre_v2_0017.sql`
  - `compat/v2_0028_hold_snapshot_guard.sql`
  - `compat/v2_0028_retention_hold_guard.sql`

### 3.2 Role Security and Row-Level Security (RLS)
- Remote Neon PostgreSQL connection verified with `PGSSLMODE=verify-full` and system CA bundle.
- Roles `ap_m1_api_user` and `ap_auth_issuer_user`:
  - `rolsuper = false`
  - `rolbypassrls = false`
- 100% of tables in schema `ap_m1` enforce `rowsecurity = true` with default-deny policies.

---

## 4. Android App Signing, Permissions, and Safety

### 4.1 Permission Minimalism
Both `android/alarka/src/main/AndroidManifest.xml` and `android/madalasa/src/main/AndroidManifest.xml` declare only:
```xml
<uses-permission android:name="android.permission.INTERNET" />
```
- **Dangerous / Covert Grants:** Zero. No `RECORD_AUDIO`, `CAMERA`, `READ_CALL_LOG`, `READ_SMS`, `SYSTEM_ALERT_WINDOW`, or `PROJECT_MEDIA`.
- **Background Location:** Zero background location permissions (`ACCESS_BACKGROUND_LOCATION` is absent).
- **Hardened Defaults:** `android:allowBackup="false"`, `android:usesCleartextTraffic="false"`, `networkSecurityConfig` enforcing system-only trust anchors for release builds.
- **Google Play Families Compliance:**
  ```xml
  <meta-data android:name="isMonitoringTool" android:value="child_monitoring" />
  ```

---

## 5. Admin Web Dashboard Authentication & Security

### 5.1 Controls & Protections
- **Google Identity Services (GSI):** Nonce-bound authentication via `POST /v1/admin/auth/challenge`.
- **Session Management:** Cookies use prefix `__Host-ma_admin_s` with `Secure; HttpOnly; SameSite=Strict`.
- **CSRF Defense:** State mutations require in-memory `X-CSRF-Token` bound to active session.
- **Origin Enforcement:** Strict validation against `https://madalasa.berhampore.in`. Cross-origin requests rejected with HTTP 403.
- **Logout Failure Recovery:** PR #59 resolved unconditional signout; failure during `DELETE /v1/admin/auth/session` retains session and provides retry prompt.

---

## 6. Infrastructure & Continuous Mail Service Continuity

### 6.1 Host `x402-endpoint` Status
- **Operating System:** Ubuntu 24.04 LTS (x86_64, 2 vCPU, 954 MiB RAM, 1023 MiB swap)
- **Memory & Swap Utilization:**
  - Available RAM: ~491–515 MiB / 954 MiB
  - Swap utilization: ~76 MiB / 1023 MiB (idle and stable)
- **Active Systemd Services:**
  - `madalasa-api.service`: Active (running, Drogon PID 429040, listening on `127.0.0.1:8080`)
  - `nginx.service`: Active (running, reverse proxying admin and API)
  - `opensmtpd.service`: Active (running, listening on ports 25, 465, 587)
  - `dovecot.service`: Active (running, listening on ports 993, 995)
- **Zero Mail Disruption:** OpenSMTPD and Dovecot ran continuously throughout all testing with zero dropped sockets, restarts, or port conflicts.

---

## 7. Implemented Endpoints vs. Planned Architecture

- **Runtime Implemented Endpoints:** Exactly 54 registered Drogon route patterns in `backend/src/main.cc`:
  - System: `/healthz`, `/readyz`, `/v1/release/capabilities`
  - Authentication & Session: `/v1/auth/parent/google`, `/v1/auth/session`
  - Device Enrollment & Pairing: `/v1/enrollment`, `/v1/enrollment/{enrollmentId}/proof`, `/v1/children/{childId}/pairing-codes`, `/v1/devices/{deviceId}/pairing`
  - SOS & Signaling: `/v1/devices/{deviceId}/signals`, `/v1/devices/{deviceId}/signals/{eventId}/status`, `/v1/children/{childId}/signals`, `/v1/children/{childId}/signals/{eventId}/ack`
  - Family & Children: `/v1/families`, `/v1/families/{familyId}/children`, `/v1/children/{childId}`, `/v1/children/{childId}/consents`, `/v1/children/{childId}/guardian-grants`
  - Admin RBAC & Audit: `/v1/admin/auth/*`, `/v1/admin/access/*`, `/v1/admin/faqs/*`, `/v1/admin/support/tickets/*`, `/v1/admin/security/audit`
  - Catalog Preview: `/v1/billing/catalog`
- **Deferred / Design-Only (Non-Implemented):**
  - Remote camera / mic / screen streaming
  - Automated accelerometer/gyroscope crash detection
  - Live continuous GPS geofencing engines
  - Real payment gateway integrations (Razorpay/Stripe)
  - All deferred endpoints safely return HTTP 404/405 without leaking state.

---

## 8. Artifact Checksums & Source Verification

| Component | Target Environment | Artifact / Path | SHA-256 Checksum |
|---|---|---|---|
| Drogon Backend ELF | Staging `x402` | `/opt/madalasa/backend/ma_backend` | `7ec8fbfc94f2d3dc08f615d354bd496ea8c83b64805812e794dbc62ed648c69d` |
| Madalasa Parent APK | Android 11 (`edd53dbd04de`) | `madalasa-debug.apk` | `1ba6504636359c8fd33e407dc1e6fdece1992d996a836e8a8a1455e80f4686fd` |
| Alarka Child APK | Android 9 (`LRW86SC6RO8TZ99H`) | `alarka-debug.apk` | `eb7690e812be4c3c17f56286e9892f084f648aa232b6ba2fc2c0b9636f610bf8` |
| Admin Web SPA | Staging `x402` | `/srv/madalasa/admin/releases/f79221d...` | Commit `f79221d5937992131c1a4eeb43efa036dc045158` |
| `origin/main` Base | Git | `main` | `90e766e497e49916abe7f6b8d42741dc2381cb3f` |
| `origin/dev` Head | Git | `dev` | `598f7cf583cdcac5e7c22f83f2a526e0793ac33a` |

---

## 9. PASS / FAIL / BLOCKED Pre-Release Checklist

| Category | Verification Item | Status | Notes |
|---|---|---|---|
| **Branch Governance** | Preflight clean worktree sync (`sync_work_branch.sh`) | **PASS** | Verified on `dev` and `main` |
| **Branch Governance** | PR route checking (`branch_routes.py`) | **PASS** | `dev → main` route validated; 0 docs in PR |
| **Backend Tests** | `backend/tests/` unittest discovery (110 tests) | **PASS** | 110 passed in 6.70s |
| **OpenAPI Contracts** | OpenAPI structural and full linters | **PASS** | 172 operations linted cleanly |
| **Admin Web Tests** | Node.js test runner (`admin-web/tests`) | **PASS** | 11/11 tests passed |
| **Security Baseline** | Public endpoint security baseline (14 checks) | **PASS** | 14/14 passed on live `x402` |
| **Proxy Hardening** | Nginx CSP/HSTS inheritance & port 80 redirect | **PASS** | Retested via `curl -sI` |
| **Physical Parent** | Android 11 genuine Google sign-in | **PASS** | Android Credential Manager authenticated |
| **Physical Child** | Android 9 manual SOS trigger & 201 receipt | **PASS** | Stored in encrypted outbox |
| **Physical Guardian** | Guardian signal retrieval & manual ACK | **PASS** | Server recorded acknowledgement |
| **Physical Convergence**| Child status polling -> `GUARDIAN_ACKNOWLEDGED` | **PASS** | Outbox cleared upon confirmation |
| **Offline Replay** | Outbox persistence across force-stop and retry | **PASS** | Manual retry confirmed on reconnect |
| **Negative Auth** | Revoked credentials return 401 | **PASS** | `AUTHORIZATION REVOKED` handled cleanly |
| **Tenant Isolation** | Cross-family signal access returns 403 | **PASS** | RLS enforcement verified |
| **Mail Continuity** | OpenSMTPD and Dovecot uninterrupted | **PASS** | Zero downtime or resource starvation |
| **Legal / DPDP** | Verifiable Parental Consent & Legal Review | **BLOCKED** | External legal signoff pending |
| **Play Console** | Google Play Families Policy Clearance | **BLOCKED** | Console registration & review pending |
| **Production Gate** | Live child data processing / payment activation | **BLOCKED** | Strictly gated; Free V1 preview only |

---

## 10. Outstanding Blockers & Owner Decisions

1. **Owner Approval of PR #60:** Review and merge [PR #60](https://github.com/methakon/Madalasa-Alarka/pull/60) (`dev → main`) without activating production deployment.
2. **B-07 Numeric Data Retention:** Formal selection of retention periods (e.g., 30/90/180 days) for SOS telemetry, audit trails, and automated DB purge jobs.
3. **B-09 / B-18 Authority and Token TTLs:** Finalizing token expiration schedules for parent Google sessions and device bearer tokens.
4. **Production Database Infrastructure:** PostgreSQL cannot run on `x402` (954 MiB RAM); owner decision required for production database hosting (dedicated VM or managed cluster).
5. **DPDP Compliance Sign-Off:** Written authorization and legal verification for processing minor telemetry prior to any public non-synthetic rollout.

---

## Recommendation for Next Milestone

With M8 staging verification and security hardening completed, the recommended next milestone is:
**M9 — Google Play & Production Release Readiness:**
1. Finalize production Google Cloud Console OAuth 2.0 Web and Android Client credentials.
2. Submit privacy policy, data safety declarations, and monitoring tool justification (`isMonitoringTool`) to Google Play Console.
3. Prepare production database host infrastructure according to owner resource specifications.
4. Execute non-synthetic dry runs only after written legal authorization.
