# Session handoff — 2026-11-13 (IST)

Branch `api`. Nothing pushed: the reviewed `api → dev` PR is still the owner's call.

## Commits made this session

| Repo | Commit | What |
|---|---|---|
| `api` | `15f1303` | guarded renewal-challenge expiry reader (`v2:0033`) + release-build test integrity |
| `api` | `165fd6c` | restore execute bits on `gradlew` and the documented script entry points |
| `api` | `dd8f2fb` | fail-closed retention policy (L15-001) + trial identifier minimisation (L10-001) |
| `api` | `ed51619` | evidence for L15-001 and L10-001 |
| `api` | `3490542` | Theme C tokens, launcher branding, English-only resources (L12-001, L13-001) |
| `api` | `1d91176` | enforce the committed Android 10 floor found by physical-device testing |
| `api` | `453e99a` | evidence: L14-002 Google ID-token claim denials |
| `api` | `000f03b` | free-tier revert on expiry (L10-003) + distinct six-hour visibility gate (L15-002) |
| `api` | `523457b` | reject the third handset (spoofing clone) as a second child |
| `api` | `49c1b91` | API 29 emulator row in the device matrix |
| `admin-web` | `c619dcb` | evidence: L14-001 admin dev shell |
| `main` | `45d823e`, `01a2a0f`, `680c539`, `7335f73`, `6fb2532`, `8a255a1` | execution-ledger reconciliation |

## Tasks closed (ledger 128 PASS → 138 PASS)

L15-001 retention policy · L10-001 trial fixture · L10-002, L10-005 reconciled ·
L12-001 Theme C tokens · L13-001 child launcher · L14-001 admin shell ·
L10-003 free-tier revert · L15-002 visibility gate · L14-002 ID-token verifier.
L18-012 is IN_PROGRESS (device matrix).

## Verified (executed, not assumed)

- ctest **30/30 PASS**; disposable-PostgreSQL suite **368 tests OK, 10 skipped**.
- Android JVM: madalasa 92, alarka 147, ui-common 6 tests — 0 failures.
- admin-web `npm test` 11/11.
- Instrumented on hardware: parent 3/3 on Mi A3 (API 30) and Eluga I7 (API 28);
  child 7/7 on Mi A3. Emulator API 29: child 7/7, parent 3/3.
- documentation checker exit 0.

## Defects found and fixed

1. **`minSdk 28` vs committed Android 10 floor** — the instrumented suite failed on the
   Android 9 handset; the build file was wrong, not the test. Raised `alarka` `minSdk` to 29;
   the Android 9 handset now refuses the build with `INSTALL_FAILED_OLDER_SDK`.
2. **`assert()`-only C++ tests** — `privacy_lifecycle_policy_test`, `test_pg_tls_policy` and
   `test_free_release_profile` did nothing under `-DNDEBUG`; one had a stale Nov-5 binary.
   All three now evaluate expectations explicitly.
3. **`device_credentials.h` did not compile** (`kAuthDbClientName` undeclared).
4. **Execute bits cleared** on `android/gradlew` and the backend/tools scripts.
5. **Out-of-gate work removed**: migration `0034` inbox flip (ADR MA-INGEST-ADR-004 requires
   benchmark evidence before that mode change), Neon CLI scaffolding, and a `manage.py`
   change that let any `neon.tech` host bypass the loopback/DB-name guards.

## Left running

API 31–36 emulator sweep (`proc_d0727a042fef`). It gates on a complete image install, boots
one emulator per level, runs both suites, copies each level's result XML out, then kills the
emulator. Safe to let finish; it self-cleans.

## Needs the owner (nothing here is blocked on more effort)

1. **Push / PR `api → dev`** — `api` is 28 commits ahead of `origin/api`. Local only because
   AGENTS.md requires a reviewed `dev` PR; I will not push unreviewed.
2. **Rebuild `alarka-release.aab`** — the bundle in `Downloads/ME/Alarka` was built at
   `minSdk 28` and is now stale.
3. **Second child device** — the clone (API 27, spoofing MT6580) is rejected. A genuine second
   child needs an Android 10+ handset, or the API 29 emulator.
4. **Legal/insurance** — nothing about insurance, indemnity or liability is recorded anywhere
   in `docs/`. DPDP substantive obligations become enforceable 13 May 2027; DPDP fines are
   generally uninsurable as a matter of public policy, so controls are the mitigation.
5. **The 121 dependency-blocked tasks** need counsel/Play/device decisions, not engineering.
