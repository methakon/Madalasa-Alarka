# Evidence — security review findings 1 and 2 (2026-11-08)

Branch `api`. SYNTHETIC DATA ONLY. Pre-work sync: `bash docs/tools/sync_work_branch.sh api` → `PREWORK_SYNC_OK`.

## Finding 1 — no rate limiting
**Change:** `deploy/x402/nginx/madalasa-api.conf.template` and `madalasa-admin.conf.template` now declare `limit_req_zone` and `limit_conn_zone` (keyed on `$binary_remote_addr`, which `cloudflare-realip.conf` sets from `CF-Connecting-IP` only for Cloudflare ranges), refuse with 429, and apply a stricter zone to pre-authentication routes.
- API general 20 r/s burst 60, 30 connections; pre-auth (`/v1/auth/*`, `/v1/enrollment*`, `/v1/devices/{id}/credential/*`) 30 r/min burst 10.
- Admin general 10 r/s burst 30, 15 connections; `/v1/admin/auth/` 12 r/min burst 6.
- SOS and location-upload routes are on the general zone only, so an alert is never starved by the strict zone.
**Verification (executed):** `node --test deploy/x402/admin/test-deploy.mjs` 7/7. Four mutants (strict regex widened to all device paths, general zone dropped from the strict location, zone keyed on a header, undeclared zone referenced) are each caught.
**Not verified:** `nginx -t` (no nginx in the sandbox) and live behaviour behind Cloudflare. Run `nginx -t` and a burst test on the VM before relying on it. Limits are starting values; carrier NAT can put many users behind one address.

## Finding 2 — test-mode switch in the production schema
**Change (two independent layers):**
1. Migration `0032_test_mode_production_guard.sql` (V2 lineage): a trigger refuses `enabled = true` unless the database is named `madalasa_alarka_dev`, `madalasa_alarka_test` or `ma_synthetic_*`; `ap_m1.test_mode_enabled()` (definer, runtime-executable) exposes one boolean, because the runtime role has no SELECT on the table.
2. `backend/src/test_mode_guard.h`: a deployable (non-`MA_SYNTHETIC_AUTH`) binary checks the probe at start-up and every 30 s and answers 503 to everything except `/healthz` while the switch is on.
3. Release gate: `deploy/x402/api/check-test-mode-off.sh`, called by `preflight.sh` (explicit `MA_PREFLIGHT_SKIP_TEST_MODE_CHECK=1` to skip, with a warning), fails when the switch is on, the probe is missing, or the database has a disposable name.
**Verification (executed, PostgreSQL 16 and the deployable binary):**
- `m1_test_mode_guard.sql` PASS (probe on/off, runtime role cannot read or write the table, not executable by PUBLIC, name predicate and trigger present).
- `m1_test_mode_guard_prod_name.sh` PASS (a copy named `madalasa_prod_guard_probe` refuses to enable).
- `integration_test_mode_guard.sh` PASS: blocked at start-up, recovered within one poll after switching off, blocked again after switching on. Mutant (guard always false) → `FAIL: route not blocked`.
- `test-check-test-mode-off.sh` PASS; 3 of 4 mutants caught; the survivor (swallowing the psql error) is equivalent because an empty answer still fails the `*)` branch.
- ctest 27/27; migration manifest verified with checksums (41 entries); lineage unit tests 21/21 (driver stubbed locally; full suite runs in CI).
**Not verified locally:** the CI wiring itself (new steps in `m1-contract-and-tenant.yml` and `local-checks.yml`) until the pushed run finishes; migration replay of 0005–0031 (PostGIS unavailable here).
**Residual risk:** a superuser can drop the trigger on purpose, and the guard reads the flag every 30 s, so up to 30 s of exposure after an out-of-band enable. The backend does not stop the synthetic *SQL* functions themselves; the trigger and gate are what keep the flag off.

## Update: disposable-database opt-in for the CI pairing harness
The deployable binary refuses traffic (503, /healthz exempt) whenever `ap_m1.local_test_settings.enabled` is true. The
CI pairing/ingestion e2e runs the deployable binary against `madalasa_alarka_test`, whose fixtures leave the switch on.
It now sets `MA_TEST_MODE_ALLOWED_IN_DISPOSABLE_DB=1`; the guard honours this only when `current_database()` matches the
same disposable-name predicate as the DB trigger (`madalasa_alarka_(dev|test)` or `ma_synthetic_*`). A stray variable in
production, or any other database name, still blocks. Unit tests cover opt-in with disposable, production and near-miss
names and without the opt-in. `integration_test_mode_guard.sh` deliberately does not set the variable.

## Findings 3-6 (2026-11-09)
- **Workflow hardening:** every workflow now has a top-level `permissions: contents: read`; all third-party actions are pinned to commit SHAs (tag kept in a trailing comment).
- **Dependency pinning:** `backend/scripts/build_deps.sh` verifies the cloned jsoncpp and Drogon commits against fixed SHAs (both checked against upstream tags in this session); `dependencies.lock` records them.
- **Android (low):** explicit `data_extraction_rules.xml` excluding all backup/transfer domains; release builds enable R8 shrinking, and CI now builds `assembleRelease` so a shrinker break is caught.
- **Branch protection / doc redaction:** see commit notes on `main`.
