# Coding evidence and safe Google Play sandbox setup

**Date:** 2026-10-28. **Status:** procedural checklist, not evidence that software or Google Play purchases have been tested.

## What implementation evidence means

| System | Required executable artifacts | Required evidence |
|---|---|---|
| C++20 Drogon service | CMakeLists, compiled executable, source handlers, auth middleware and unit tests | Clean `cmake -S backend -B build/backend`, build, `ctest --test-dir build/backend --output-on-failure` exit 0; start localhost service, send real HTTP contract requests, negative auth/tenant tests and redact logs |
| Madalasa Android | Gradle wrapper, parent module, manifest, actual Kotlin code and resources | Clean assembleDebug, testDebugUnitTest, emulator/physical device UI tests, approved Figma screen screenshots, OS permissions and denial tests |
| Alarka Android | Separate app Gradle module, visible notice, device enrollment, location queue | Clean APK build, offline/reconnect, reboot, permission/revocation and Android API/OEM matrix results |
| PostgreSQL/PostGIS | Executable versioned migrations, non-BYPASSRLS app roles, proper constraints | Apply to clean disposable DB, run `backend/tests/m1_tenant_isolation.sql` and new blended-family cross-household isolation test, include schema and privilege output |
| Admin web | Lockfile/package, web build, real server endpoints, role-guarded UI | npm ci/build/test and browser E2E: unknown Google login NO_ACCESS; verified profile; owner approval; FAQ XSS; support isolation; masked billing/usage data |
| OpenAPI | Versioned operation contracts + implemented backend routes | OpenAPI validator, typed responses/error vectors and HTTP contract tests against actual service |
| Play billing | Android Billing client and server purchase validator | First use LOCAL fake Play provider; later license tester purchase, pending/refund/top-up/replay, no real charge to normal users, token and app verified |

**Every completion claim requires:** git SHA, exact command, actual exit code, environment versions, redacted test output, positive and negative assertions, synthetic fixture and reviewer. Figma diagrams, specifications, SQL text, unrun test commands and Play account status are NOT execution evidence.

## Credential policy — no secrets needed for planning or local synthetic tests

**Never share in chat or GitHub:** Play Console password, Google 2FA/OTP, OAuth secret, service-account private JSON, Android signing keystore, real purchase token, real payment card or family records. Developer account ID is intentionally omitted.

Owner steps:
1. Go to https://play.google.com/console and create/select the Madalasa parent app (distinct package from Alarka). A package name, intended product ID, tester-track state and Console status are non-secret information useful for designing the integration.
2. For Madalasa, inspect **Monetize → Products → Subscriptions**: monthly/yearly *prepaid* base plans and founding offers. Verify availability and restrictions in Console before declaring a multi-child seat purchase feasible. Multi-child entitlements are our server's logic; one Play purchase token must not be expanded to multiple paid child seats unless actual purchased capacity is represented.
3. Inspect **Monetize → Products → In-app products**: a repeatable one-time Buy product candidate `extra_viewer_100d_plus30_av_100_inr`; our backend enforces its independent 100-day expiry and 1800 combined A/V seconds.
4. Open **Settings → License testing** and invite dedicated adult QA Google accounts (email list/Google Group). These account holders use Play test instruments. Regular testers may face real charges—do not mistake a test track for free license testing. **Testing → Internal testing** can distribute a synthetic-data test build to opted-in QA adults.
5. For **server Play Developer API**: in https://console.cloud.google.com create/select a dedicated test project and enable Google Play Developer API. Create service account under IAM & Admin → Service Accounts. In Play Console → **Users and permissions** invite its **service-account email** to the specific application(s) with the minimum Google Play purchase API permissions. Official documentation identifies “View financial data, orders, and cancellation survey responses” and “Manage orders and subscriptions”; don't add release/owner privileges solely for billing.
6. Prefer keyless environment-managed credentials; if private key needed, owner stores in a secure local secret manager outside repository/conversation and rotates it. Android does not receive service-account JSON.

**Information that can safely be supplied to the planning agent:** parent package name, candidate SKU IDs, whether prepaid offers exist, whether test track/license testers exist, whether API enabled and optional service-account email. Sanitized screenshots of configuration status are also useful. **No credential file is needed for now.**

References: https://developers.google.com/android-publisher/getting_started · https://developer.android.com/google/play/billing/test · https://support.google.com/googleplay/android-developer/answer/6062777 · https://developer.android.com/google/play/billing/subscriptions · https://developer.android.com/google/play/billing/lifecycle/subscriptions .
