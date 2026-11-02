# Madalasa–Alarka — M1 Executable Acceptance Cases (T-M1-01–14)

> **Current app roles:** **Madalasa** = parent/guardian Android app; **Alarka** = child device companion. Canonical GitHub repository: https://github.com/methakon/Madalasa-Alarka. Test IDs, synthetic family names and M1 API routes are unchanged by the brand rename.

**Scope:** canonical [M1 plan](../../docs/phases/M0-foundation-and-approvals/01-project-governance/MASTER_MILESTONE_IMPLEMENTATION_AND_RELEASE_PLAN.md) and [M1-only OpenAPI](../../docs/openapi-m1.yaml).
**Status:** TEST CASES WRITTEN, **NOT EXECUTED on Android or running C++ APIs**; SQL isolation test runs when PostgreSQL CI is available.
**Data safety:** fake guardian subjects, synthesized child aliases/UUIDs only. Never real child GPS, camera/mic/usage or ID documents.

## Common fixture, execution and evidence

- **Parents:** two *different* signed-in test principals A/B with distinct synthetic families A/B, each with one child. At least one second A child without grants tests intra-family scope. Backend low-privilege PG role and closed-world authorization enabled.
- **Devices:** STANDARD API29–36 candidate, second recent OEM, one separate backup-completed **owner-approved expendable factory-resettable device** for real DPC provisioning. Record Android version/manufacturer/model/build; absence is BLOCKED, not PASS.
- **Network:** HTTPS staging in designated OCI India region or explicitly labeled isolated local container with no real PII. Local/offline tests simulate expiring challenge and pairing replay.
- **Test record:** ID, build SHA, M1 OpenAPI SHA, PG migration SHA, environment/OS/OEM, setup fixture IDs, UTC date, executor, expected/actual JSON/HTTP and screenshot or redacted CI log, reviewer and status PASS/FAIL/BLOCKED/NOT_RUN.
- **Strong stop condition:** M1 cannot pass fully with just documentation/API spec and a SQL script. Real backend handlers, signed Android builds and device-owner test are necessary.
- **Commands:** validate spec using python3 backend/tests/lint_openapi_m1.py docs/openapi-m1.yaml. Provision disposable PostgreSQL 16 and execute psql -X -v ON_ERROR_STOP=1 -f backend/persistence/migrations/0001_m1_identity.sql followed by psql -X -v ON_ERROR_STOP=1 -f backend/tests/m1_tenant_isolation.sql.

## T-M1-01 — Authorized A pairing

**Status:** APIs/Android NOT_RUN | **Category:** API integration + two real Android apps

**Preconditions:** Parent A signed-in, A child, no device, one-use short-lived code, Keystore P-256 key

**Procedure:** POST child pairing code → redeem → sign one-use nonce → POST proof → capability → GET devices as parent A

**Pass criteria:** 201, 201, 201 and 202; one ACTIVE device bound to A child, no extra A/B devices; key never leaves Keystore

**Negative safety checks:** Reject unauthorized object/scope/role; ensure invalid input does not mutate another child's state; redact sensitive fields. Where OS permission/role is relevant, the real device's observed system authority is decisive.

**Evidence to capture:** exact source SHA, request IDs, UTC test time, environment/device model/API, status code/response, relevant redacted DB record/OS output, test executor/reviewer and PASS/FAIL.


## T-M1-02 — Cross-family guessed child

**Status:** SQL TEST READY, HTTP NOT_RUN | **Category:** SQL RLS + HTTP integration

**Preconditions:** Parent A family A, B child id and B device ID known only in synthetic fixture

**Procedure:** Using A parent token GET /children/Bchild, GET B child's devices; attempt own /families/Bfamily/children list; query PG as ap_m1_api with A context

**Pass criteria:** 404/403 without child B metadata; PG RLS test RLS_01–RLS_08 denies all B data

**Negative safety checks:** Reject unauthorized object/scope/role; ensure invalid input does not mutate another child's state; redact sensitive fields. Where OS permission/role is relevant, the real device's observed system authority is decisive.

**Evidence to capture:** exact source SHA, request IDs, UTC test time, environment/device model/API, status code/response, relevant redacted DB record/OS output, test executor/reviewer and PASS/FAIL.


## T-M1-03 — One-use and expired codes

**Status:** NOT_RUN | **Category:** Backend HTTP unit integration

**Preconditions:** One code redeemed once, another aged beyond expires_at with clock controlled at server

**Procedure:** Redeem valid code twice; redeem expired; replay same proof after consumption

**Pass criteria:** Second/expired returns 409/410; no second device; rate limit repeated guessing; no code in logs

**DB-level coverage:** m1_enrollment.sql (EN_01–EN_05): one-use, expired, used, exhausted and unknown codes redeem nothing; malformed input does not burn a valid code.

**Negative safety checks:** Reject unauthorized object/scope/role; ensure invalid input does not mutate another child's state; redact sensitive fields. Where OS permission/role is relevant, the real device's observed system authority is decisive.

**Evidence to capture:** exact source SHA, request IDs, UTC test time, environment/device model/API, status code/response, relevant redacted DB record/OS output, test executor/reviewer and PASS/FAIL.


## T-M1-04 — Missing/spoofed key or challenge

**Status:** NOT_RUN | **Category:** Kotlin instrumentation + cryptographic API test

**Preconditions:** Valid redeemed code with enrolled SPKI of keyA, spoof keyB and wrong nonce

**Procedure:** Sign challenge with keyB, sign stale/altered nonce, reuse nonce, uninstall/reinstall keyA and retry

**Pass criteria:** Proof denied 401/409/410, no ACTIVE device; explicit re-enroll after lost key; no credential minted

**Enrollment sub-step:** a challenge whose proof failed must stay spent (a corrected signature on the same enrollment id fails), and a lost or reinstalled key means revoke plus a new pairing code, never key rotation (decision C-06). DB-level coverage: m1_enrollment.sql (EN_06–EN_15).

**Renewal sub-steps (credential lifecycle, see docs/M1_DEVICE_CREDENTIAL_LIFECYCLE.md):** on an ACTIVE device with an expired token, request POST /devices/{id}/credential/challenge, then POST .../renew with (a) a signature by keyB, (b) a stale or altered nonce, (c) a signature over the enrollment context string instead of `amar-pola-m1-device-renew-v1`, (d) a replay of an already-used challenge. Each must fail with 401/404/410/422, mint no credential, and burn the challenge (a following correct signature on the same challenge also fails). Control: keyA with a fresh challenge returns a new token and the previous token stops working. DB-level coverage: backend/tests/m1_credential_lifecycle.sql (CL_14–CL_24).

**Negative safety checks:** Reject unauthorized object/scope/role; ensure invalid input does not mutate another child's state; redact sensitive fields. Where OS permission/role is relevant, the real device's observed system authority is decisive.

**Evidence to capture:** exact source SHA, request IDs, UTC test time, environment/device model/API, status code/response, relevant redacted DB record/OS output, test executor/reviewer and PASS/FAIL.


## T-M1-05 — Device revoke and heartbeat

**Status:** NOT_RUN | **Category:** API+DB integration, device reconnect

**Preconditions:** Completed A enrollment with active key; A owner grant REVOKE_CHILD_DEVICE

**Procedure:** A calls DELETE /devices/deviceA/pairing, then A device POST /devices/deviceA/health; try B revoke

**Pass criteria:** 204 owner; revoked device 401/403 on next use; B operation 404/403; revocation reflected in audit/epochs

**Renewal sub-step:** after revoke, the revoked device's still-unexpired token is refused, POST .../credential/challenge gives no challenge, and a challenge issued before revoke cannot be completed. DB-level coverage: m1_credential_lifecycle.sql (CL_25–CL_27).

**Negative safety checks:** Reject unauthorized object/scope/role; ensure invalid input does not mutate another child's state; redact sensitive fields. Where OS permission/role is relevant, the real device's observed system authority is decisive.

**Evidence to capture:** exact source SHA, request IDs, UTC test time, environment/device model/API, status code/response, relevant redacted DB record/OS output, test executor/reviewer and PASS/FAIL.


## T-M1-06 — STANDARD reports truth

**Status:** BLOCKED DEVICE | **Category:** Android physical STANDARD test

**Preconditions:** Standard install without provisioning; app permission states known

**Procedure:** Open child capability screen and POST capabilities; inspect isDeviceOwnerApp and API-side enum

**Pass criteria:** device_mode STANDARD, is_device_owner false, managed_package_suspend UNSUPPORTED; never pretend suspension

**Negative safety checks:** Reject unauthorized object/scope/role; ensure invalid input does not mutate another child's state; redact sensitive fields. Where OS permission/role is relevant, the real device's observed system authority is decisive.

**Evidence to capture:** exact source SHA, request IDs, UTC test time, environment/device model/API, status code/response, relevant redacted DB record/OS output, test executor/reviewer and PASS/FAIL.


## T-M1-07 — Real fully managed owner

**Status:** BLOCKED DEVICE | **Category:** Real DPC Android instrumentation and safe-reset log

**Preconditions:** Owner explicitly approves wiping expendable test phone after backup and provisions real DPC

**Procedure:** Provision via supported factory/QR/managed route; inspect DevicePolicyManager.isDeviceOwnerApp; submit capabilities

**Pass criteria:** MANAGED_DEVICE_OWNER only with OS proof and reproducible log; no spoofed flag acceptance to privileged command

**Negative safety checks:** Reject unauthorized object/scope/role; ensure invalid input does not mutate another child's state; redact sensitive fields. Where OS permission/role is relevant, the real device's observed system authority is decisive.

**Evidence to capture:** exact source SHA, request IDs, UTC test time, environment/device model/API, status code/response, relevant redacted DB record/OS output, test executor/reviewer and PASS/FAIL.


## T-M1-08 — Suspend/restore harmless app

**Status:** BLOCKED DEVICE | **Category:** Real device owner instrumentation

**Preconditions:** M1 DPC verified on physical test device; harmless test target installed

**Procedure:** Call setPackagesSuspended(test) and verify block, then unsuspend; inspect returned per-package failures

**Pass criteria:** Only target blocked then restored; clear audit; no permanent lockout; no protected system package touched

**Negative safety checks:** Reject unauthorized object/scope/role; ensure invalid input does not mutate another child's state; redact sensitive fields. Where OS permission/role is relevant, the real device's observed system authority is decisive.

**Evidence to capture:** exact source SHA, request IDs, UTC test time, environment/device model/API, status code/response, relevant redacted DB record/OS output, test executor/reviewer and PASS/FAIL.


## T-M1-09 — Refuse protected/nonmanaged app

**Status:** BLOCKED DEVICE | **Category:** Instrumentation guarded safety test

**Preconditions:** STANDARD phone and managed spare; protected package allowlist

**Procedure:** Try policy adapter on STANDARD; on managed device request protected dialer/launcher or disallowed package (dry-run where possible)

**Pass criteria:** UNSUPPORTED_MODE/OS_REJECTED, protected packages not altered, no success false-positive

**Negative safety checks:** Reject unauthorized object/scope/role; ensure invalid input does not mutate another child's state; redact sensitive fields. Where OS permission/role is relevant, the real device's observed system authority is decisive.

**Evidence to capture:** exact source SHA, request IDs, UTC test time, environment/device model/API, status code/response, relevant redacted DB record/OS output, test executor/reviewer and PASS/FAIL.


## T-M1-10 — Onboarding Activity closes

**Status:** BLOCKED DEVICE | **Category:** Physical Android lifecycle

**Preconditions:** Child setup permissions/grants and visible app notification test; user closes setup screen

**Procedure:** Press home/back, lock/unlock phone, observe launcher icon, monitoring identity, lifecycle callbacks

**Pass criteria:** Setup Activity not kept active; no covert background mic/camera; no fabricated location service-start capability

**Negative safety checks:** Reject unauthorized object/scope/role; ensure invalid input does not mutate another child's state; redact sensitive fields. Where OS permission/role is relevant, the real device's observed system authority is decisive.

**Evidence to capture:** exact source SHA, request IDs, UTC test time, environment/device model/API, status code/response, relevant redacted DB record/OS output, test executor/reviewer and PASS/FAIL.


## T-M1-11 — Huge/invalid or abusive API requests

**Status:** NOT_RUN | **Category:** API fuzz+load integration

**Preconditions:** Isolated test API with request-size cap, rate limits, staging secrets

**Procedure:** POST invalid JSON, missing required fields, oversized SPKI/capability, repeated unauthorized pairing attempts

**Pass criteria:** 400/413/422/429 with Error schema; no crash, bounded memory/time, redacted request logs

**Starting rate limits to verify (decision C-02, docs/M1_DEVICE_CREDENTIAL_LIFECYCLE.md):** POST /enrollment 10/min/IP; credential challenge 10/min/IP and 20/hour/device; credential renew 10/min/IP and 10/hour/device; each over-limit call returns 429 with Retry-After and creates no database row.

**Negative safety checks:** Reject unauthorized object/scope/role; ensure invalid input does not mutate another child's state; redact sensitive fields. Where OS permission/role is relevant, the real device's observed system authority is decisive.

**Evidence to capture:** exact source SHA, request IDs, UTC test time, environment/device model/API, status code/response, relevant redacted DB record/OS output, test executor/reviewer and PASS/FAIL.


## T-M1-12 — Old/new Android capability branches

**Status:** BLOCKED DEVICE | **Category:** Android instrumentation matrix

**Preconditions:** One API29/30 phone and one API34–36 phone (minimum), deny/approximate/notification states

**Procedure:** Toggle permission and FGS eligibility; report snapshots; test unsupported starts only in permitted contexts

**Pass criteria:** Truthful permission states and OS rejections, exact API/model evidence, no forged MANAGED

**Negative safety checks:** Reject unauthorized object/scope/role; ensure invalid input does not mutate another child's state; redact sensitive fields. Where OS permission/role is relevant, the real device's observed system authority is decisive.

**Evidence to capture:** exact source SHA, request IDs, UTC test time, environment/device model/API, status code/response, relevant redacted DB record/OS output, test executor/reviewer and PASS/FAIL.


## T-M1-13 — 16 KB native packaging

**Status:** NOT_RUN | **Category:** CI artifact scan + emulator

**Preconditions:** Child debug/release AAB/APK with pinned NDK and arm64 library

**Procedure:** Analyze ZIP/APK alignment/ELF LOAD alignment and smoke JNI on 16KB page-size emulator/device

**Pass criteria:** 4K/16KB native support correctly reported; no dlopen crashes, builds reproducible

**Negative safety checks:** Reject unauthorized object/scope/role; ensure invalid input does not mutate another child's state; redact sensitive fields. Where OS permission/role is relevant, the real device's observed system authority is decisive.

**Evidence to capture:** exact source SHA, request IDs, UTC test time, environment/device model/API, status code/response, relevant redacted DB record/OS output, test executor/reviewer and PASS/FAIL.


## T-M1-14 — Secrets/child data absent in logs

**Status:** NOT_RUN | **Category:** Log scan, redaction review

**Preconditions:** Synthetic sensitive-looking sentinel pairing code, fake token/private key marker, fake location field

**Procedure:** Complete happy and error tests; scan logcat, Drogon logs, CI traces, crash logs, HTTP middleware

**Pass criteria:** No raw token, code, key or GPS in default logs; audit event IDs/status remain; reversible leaks fail release

**Negative safety checks:** Reject unauthorized object/scope/role; ensure invalid input does not mutate another child's state; redact sensitive fields. Where OS permission/role is relevant, the real device's observed system authority is decisive.

**Evidence to capture:** exact source SHA, request IDs, UTC test time, environment/device model/API, status code/response, relevant redacted DB record/OS output, test executor/reviewer and PASS/FAIL.

## Exit decision checklist

| Gate | Status on 2026-10-26 | What proves closure |
|---|---|---|
| Strict M1-only OpenAPI syntax and structural lint | SPEC/LINTER READY; run lint job | Exit 0 with trace and full external OpenAPI validator when available |
| PostgreSQL migration syntax and two-family RLS | SQL FILE READY; real PostgreSQL test pending | CI PostgreSQL 16 migration + isolation script PASS |
| M1 backend handlers | NOT IMPLEMENTED | Every endpoint meets expected HTTP/security cases |
| Parent/child Android setup and Keystore | NOT IMPLEMENTED | Auth and proof pass real device suite |
| Managed DPC suspend/restore | NO APPROVED RESETTABLE PHONE | T-M1-07/08/09 completed on owned spare |
| 16KB native library validation | NOT BUILT | Actual linked ELF and device emulator evidence |
| India child-data legal approval | OWNER + LAWYER OPEN | No real child data until legal gates pass |
| Independent security reviewer | UNASSIGNED | Signed cross-family and log/privacy review |

**M1 Go/No-Go:** NO-GO for physical acceptance and NO-GO for real minors' data. Synthetic implementation can proceed. A test case's existence is **not a passing test**.
