# Build, Run and Verify — Current M1 / Future Android & Drogon

> **Document control:** M1 / 02-development-process · Proposed owner: Engineering lead (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

**Reviewed 2026-10-27 against the repository CI and files.** There is **no runnable Android Gradle project or C++20 Drogon server yet**. The only executable project baseline is M1 API structural lint + PostgreSQL identity/child-scope synthetic test. These commands are for **synthetic test data**, not a live child-monitoring app.

## Available tools
- Python 3.10+ with standard library. `backend/tests/lint_openapi_m1.py` uses `json.loads` and requires **no pip/PyYAML**. The `docs/openapi-m1.yaml` file is JSON formatted in a YAML filename.
- PostgreSQL **16** for parity with `.github/workflows/m1-contract-and-tenant.yml` (M1 migration targets PostgreSQL 15+). PostGIS is NOT required for `0001_m1_identity.sql`. Future GPS schema will need PostGIS.
- Docker optional; `psql` and `pg_isready` required for SQL test.

## Developer quick-start

```bash
git clone https://github.com/methakon/Madalasa-Alarka.git
cd Madalasa-Alarka
python3 backend/tests/lint_openapi_m1.py docs/openapi-m1.yaml
```

Expected beginning: `M1 OpenAPI structural lint PASS`. This verifies 11 designated API operations and reference consistency, **not endpoint implementation or full OpenAPI validation**.

## Disposable PostgreSQL M1 isolation tests

```bash
docker run -d --name ma-m1-pg \
  -e POSTGRES_PASSWORD=synthetic_test_only_password \
  -e POSTGRES_DB=amar_pola_m1 \
  -p 127.0.0.1:5432:5432 postgres:16

export PGHOST=127.0.0.1 PGPORT=5432 PGUSER=postgres
export PGPASSWORD=synthetic_test_only_password
export PGDATABASE=amar_pola_m1
pg_isready -h "$PGHOST" -U "$PGUSER" -d "$PGDATABASE"
psql -v ON_ERROR_STOP=1 -f backend/persistence/migrations/0001_m1_identity.sql
psql -v ON_ERROR_STOP=1 -f backend/tests/m1_tenant_isolation.sql

docker rm -f ma-m1-pg
unset PGPASSWORD
```

Use only a local disposable DB; avoid port collision or public network binding. Test SQL must execute as migration/test administrator, **not the app's runtime PostgreSQL superuser**. CI service uses `postgres:16`, `amar_pola_m1` and same psql migrations and tenant test. Failures require investigation, never relax RLS to make CI green.

## Planned, NOT runnable commands

No `backend/CMakeLists.txt`, Gradle wrapper, `android/alarka` or `android/madalasa` actual compiled projects exist as of review. When implemented, proposed build steps will be:

```bash
# FUTURE ONLY; these will fail today:
cmake -S backend -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
ctest --test-dir build --output-on-failure
# In android/ AFTER creating a real Gradle wrapper and modules:
./gradlew :alarka:assembleDebug
./gradlew :madalasa:assembleDebug
```

The `android/` directory currently contains scoping README files, not runnable source. Android OS permission and identity must not be fabricated to satisfy a test. C++20 Drogon, PostGIS location inbox, lease workers, media command endpoints, dashboard and admin portal are design only.

## Server GPS ingestion future contract
Alarka's encrypted up-to-48h offline capacity queue + adaptive GPS captures original event timestamps separately from conditional 1–2min JSON upload. Drogon must ACK HTTP 202 only **after** durable PostgreSQL inbox Tx A commit; C++ leased workers combine GPS points into multirow/COPY-staged bulk Tx B committing dedup+PostGIS raw+trip outbox+processed inbox. No Redis mandatory. This is [MA-INGEST-ADR-004](../../M2-location-collection/01-location-collection-and-ingestion/POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md), not implemented code.

## CI coverage and security
Current workflow `.github/workflows/m1-contract-and-tenant.yml` runs structural API lint, synthetic SQL migration and family/sibling grants. It does **not** run Android OEM instrumentation, C++ builds, SAST, penetration tests, release signing, backup tests or real DPDP/Play approval. Do not put real child data, credentials, GPS or recordings in GitHub; `.env.example` contains placeholders only.

**Legal and operational go/no-go:** [DPIA](../../M0-foundation-and-approvals/03-legal-and-privacy/DPIA.md), [Retention](../../M0-foundation-and-approvals/03-legal-and-privacy/DATA_RETENTION_SCHEDULE.md), [Incident Response](../../M8-operational-readiness/02-operations-and-support/INCIDENT_AND_BREACH_RESPONSE_PROCEDURE.md), [Security](../../../../SECURITY.md), [Signoff](../../M9-play-release/03-release-gates/DEPLOYMENT_RELEASE_READINESS_CHECKLIST.md). Verify exact Android/Play target API and India phased DPDP law at actual release.

## Uploaded developer guide reconciliation — 2026-10-27

The accompanying uploaded \`BUILD_AND_RUN.md\` was reviewed against the **actual repository CI**, M1 SQL files and current scaffolds rather than copied over this reviewed guide. The following corrections are intentional:

| Uploaded draft instruction | Verified repository state and change |
|---|---|
| \`pip install pyyaml\` may be needed | **Not needed** for the current linter: \`backend/tests/lint_openapi_m1.py\` uses Python's \`json.loads\`; \`openapi-m1.yaml\` contains JSON-formatted OpenAPI. |
| Local Docker uses \`postgis/postgis:16-3.4\` | The **existing CI uses \`postgres:16\`**, not PostGIS, and the M1 identity migration does not require PostGIS. Use PostGIS for **future** spatial migrations. |
| Database in example is \`madalasa_test\` | Current CI environment names it **\`amar_pola_m1\`** despite the repository's Madalasa–Alarka branding. Renaming test DB is optional and is **not** an app rename or a change to the M1 identity contract. |
| Run \`./gradlew :alarka...\` from repository root | **Not yet runnable.** The Android directory contains scaffolds; the eventual wrapper location/module names must be verified after implementation. |
| CMake command assumes a \`backend/CMakeLists.txt\` | **Not present**. Commands under "Planned" are illustrative only. |
| Failure of tenant SQL test | Treat as **blocking high-severity security regression** and investigate; never paper over with broad superuser/RLS bypass. |

### Current CI-equivalent quick verification

Run after clone with only synthetic records:

~~~bash
python3 backend/tests/lint_openapi_m1.py docs/openapi-m1.yaml
docker run -d --name ma-m1-pg \
  -e POSTGRES_PASSWORD=synthetic_test_only_password \
  -e POSTGRES_DB=amar_pola_m1 \
  -p 127.0.0.1:5432:5432 postgres:16
export PGHOST=127.0.0.1 PGPORT=5432 PGUSER=postgres
export PGPASSWORD=synthetic_test_only_password PGDATABASE=amar_pola_m1
# Wait for readiness; do not assume container boot has finished.
until pg_isready -h "$PGHOST" -U "$PGUSER" -d "$PGDATABASE"; do sleep 1; done
psql -v ON_ERROR_STOP=1 -f backend/persistence/migrations/0001_m1_identity.sql
psql -v ON_ERROR_STOP=1 -f backend/tests/m1_tenant_isolation.sql
docker rm -f ma-m1-pg
unset PGPASSWORD
~~~

The password is for a disposable local-only container; do not reuse or commit real secrets. Avoid a localhost port collision and remove container on test failures as well. In CI, source of truth is \`.github/workflows/m1-contract-and-tenant.yml\`. **No command above builds a runnable location tracker, C++ Drogon API, Android app, PostGIS GPS worker or admin console.**

### Deferred build/run acceptance checklist

- [ ] Actual Android module source, Gradle wrapper, Android SDK/NDK and permissions/visible-notification tests created.
- [ ] Actual C++20 Drogon CMake source and tests with synthetic device tokens.
- [ ] M2+ PostGIS \`location_ingest_inbox\` migration and two-transaction durable \`202 QUEUED\` receipt implemented and tested.
- [ ] C++ \`SKIP LOCKED\` lease/fencing, dedup and multi-row/\`COPY\` staging bulk-insert tests built; direct-bulk comparison measured.
- [ ] 48-hour offline **capacity** queue, not always-on location-capture guarantee, tested on physical Android/Wear devices.
- [ ] Evidence filed for T-ING-01…24, T-CAP-01…24, T-AUD-01…22 and T-ADM-01…14; no real-minor test fixtures before India/Play gates.

Further references: [Deployment Readiness](../../M9-play-release/03-release-gates/DEPLOYMENT_RELEASE_READINESS_CHECKLIST.md), [M1 Scope](../01-requirements-and-architecture/M1_ANDROID_CPP_ARCHITECTURE_AND_IMPLEMENTATION.md), [GPS Ingest ADR](../../M2-location-collection/01-location-collection-and-ingestion/POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md).

