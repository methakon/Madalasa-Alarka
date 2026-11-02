# Developer Onboarding and Coding Standards — Android Kotlin / C++20

> **Document control:** M1 / 02-development-process · Proposed owner: Engineering lead (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

**Status:** Engineering standard proposal, October 27, 2026. **Codebase reality:** M1 structural OpenAPI linter, PostgreSQL migration, tenant-isolation tests and docs exist; Android Gradle modules and C++ Drogon build do not yet exist.

## First hour
Read SRS, blocked owner decisions, DPIA, STRIDE, GitHub SECURITY.md and docs/phases/M1-secure-platform-foundation/02-development-process/BUILD_AND_RUN.md. Clone https://github.com/methakon/Madalasa-Alarka. With Python 3.10+ run `python3 backend/tests/lint_openapi_m1.py docs/openapi-m1.yaml`. Optional disposable PostgreSQL 16 runs migration `0001_m1_identity.sql` and `m1_tenant_isolation.sql` through psql. **No current backend server, APK, health endpoint or localhost UI is runnable.**

## Architecture boundaries
- Alarka Kotlin handles OS lifecycle, WorkManager, Location/UsageStats permission flows, Keystore and encrypted local storage. Main Activity may close after setup, but Android foreground service notices and OS indicators remain.
- Madalasa Kotlin displays only child-scoped verified results; last-observed location and last observed foreground app are not continuous live proof.
- C++20 Drogon API authenticates tenant/device/guardian before collecting data, returning precise statuses. Postgres RLS is defense in depth, never a substitute for controller scopes.
- GPS pipeline: encrypted Alarka up-to-48h **capacity target** → conditional 1–2 min JSON batches → durable PostgreSQL inbox Tx A/202 receipt → leased C++ bulk workers → raw PostGIS, outbox Tx B → separate trip processing; benchmark direct bulk insertion. No Redis required in MVP.
- Never include covert mic/camera, private app files, unauthorized MediaProjection or restricted child-data processing.

## Kotlin / Android style
Kotlin official style, 4-space indent, immutable `val` by default, sealed states for permission/result/reason, explicit nullable return types at boundaries, coroutines/structured concurrency tied to lifecycle, bounded dispatcher and timeout. Avoid `GlobalScope`, background busy loops, unrestricted locks, mutable static family data, hidden permissions. Expose normalized domain interfaces through dependency injection; Android platform and permissions tested in instrumented device tests, reducers in unit tests. Keep Compose semantics, content labels, high contrast and safe empty/offline/stale UI. Every sensitive permission has scoped purpose and OS readback; never label green operational ready merely because a grant exists.

## C++20 / Drogon style
Follow an agreed clang-format profile; use RAII, value semantics, `unique_ptr` when ownership unique, std::chrono monotonic clocks for durations and ISO 8601 UTC for durable instants. Sanitize JSON with explicit schema bounds, reject unknown privileged fields, use prepared/parameterized SQL, structured privacy-safe logs, request IDs and bounded thread pools. Never run GPS trip reconstruction or slow synchronous I/O on Drogon event loop. Prefer explicit typed `Result<T,Error>` or equivalent, consistent error code mappings to parent UI, robust cancellation/shutdown, exception-safe transactional boundaries, finite backoff and jitter.

## SQL and migration rules
Every migration forward-only, reviewed, synthetically tested from empty and previous schema, rollback/data safety described. Child-scoped composite indexes and forced RLS tested as runtime role; superuser bypass is not app authorization. PostGIS geometry source and device provenance preserved; UTC `observed_at` independent of `received_at`. Reprocessing event IDs idempotent; avoid duplicate GPS turns or fabricated inferred roads.

## PR quality gates
- SRS/ADR/OpenAPI/implementation/tests/Figma synchronized.
- All permissions/feature flags fail closed; cross-family and ungranted-sibling negative tests.
- New dependencies entered into THIRD_PARTY_DEPENDENCY_AND_SBOM_REGISTER.md with SPDX licenses/security lifecycle.
- Tests run listed with real results; missing tests openly reported.
- No child identifiers/coordinates/media, signing keys, secrets or private safety incident logs in repo/CI.
- Android version matrix plus release/Play legal gates before even a pilot.

**Owner sign-off still required** for final lint settings, package IDs, publisher domain, Kotlin/NDK tool versions and code review assignments.
