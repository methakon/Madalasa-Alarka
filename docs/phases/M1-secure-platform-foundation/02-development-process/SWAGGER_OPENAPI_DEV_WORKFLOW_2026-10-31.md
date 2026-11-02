# Swagger UI and OpenAPI tooling — implemented 2026-10-31

**Status:** SOURCE COMMITTED and **CI VERIFIED** at [api SHA b1348c6](https://github.com/methakon/Madalasa-Alarka/commit/b1348c677986e48e3ab8f01b0c0e844ec07c351d) — [all three M1 workflow jobs SUCCESS](https://github.com/methakon/Madalasa-Alarka/actions/runs/41168787562); code is on the persistent [api workstream branch](https://github.com/methakon/Madalasa-Alarka/tree/api), **not merged to dev/main**; this documentation is maintained on main. **Scope:** local developer-only API visualization and synthetic contract testing. **Not:** a production URL, 171 implemented APIs, child-data release approval, or a V2 trusted-session completion claim.

## Existing specification, now visualized

The codebase already used **OpenAPI 3.1.0** before this change (the \`.yaml\` files contain JSON, which is a valid YAML subset):

- [Frozen M1 OpenAPI](../../../openapi-m1.yaml): **14 registered operations** under \`/v1\`. This is the implemented **route** baseline, not full feature/authorization release acceptance.
- [Whole-product OpenAPI design](../../../openapi.yaml): **171 planned operations** at this snapshot, mapped to [Figma screen/API/DB audit](../../../audits/FIGMA_SCREEN_API_DB_AUDIT_2026-10-28.json). Many are not coded and may require further legal/Play/Android clearance.

Swagger UI was **not previously installed or served**. To apply Swagger without confusing planned designs with deployed functionality, it now has two separate local views and **no routes in the production Drogon process**.

## One-time local install

The [Swagger UI distribution](https://www.npmjs.com/package/swagger-ui-dist) is pinned to **5.34.1** under [backend/swagger/package.json](https://github.com/methakon/Madalasa-Alarka/blob/api/backend/swagger/package.json). Use Python 3.10+ and Node/npm locally:

~~~sh
git checkout api
cd backend/swagger
SCARF_ANALYTICS=false npm install --ignore-scripts --no-audit --no-fund
cd ../..
python3 backend/scripts/swagger_dev.py
~~~

Open **http://127.0.0.1:8765/swagger/m1** for the frozen M1 contract, and **http://127.0.0.1:8765/swagger/planned** for the Figma-aligned design-only contract. External users and ChatGPT cannot directly visit a developer's loopback browser URL. Run the commands on the developer machine.

The server reads the existing two specification files, overlays their invalid placeholder server address with **local** \`/v1\` in memory, and serves Swagger's JavaScript/CSS from **ignored local node_modules**. It requires no external JS/CDN or remote Swagger validator during runtime. No real API credentials are supplied or written to source.

## Optional developer API execution (synthetic data only)

When a test Drogon backend is running on local port 8080:

~~~sh
python3 backend/scripts/swagger_dev.py --backend-port 8080 --enable-try-it-out
~~~

**Safety guardrails:**

- UI and API proxy are **read-only by default**, with no Try it out/execute capability until this explicit flag.
- Even with the flag, only the exact **14 frozen M1 method+path combinations** may reach the fixed \`127.0.0.1:8080\` upstream. Planned location/media/billing routes stay blocked; planned UI remains read-only.
- The local UI binds **only 127.0.0.1**; do not deploy or expose it publicly, set up a DNS record for it, or put Swagger paths into production Drogon.
- Local proxy denies arbitrary upstream URLs; enforces ≤64 KiB request bodies; forwards only the minimal authorization/accept/content-type/idempotency headers, never cookies; suppresses request logging; sets restrictive CSP and no-store headers.
- All generated docs carry contract-auth scheme information but **Swagger does not create parent verification, guardian authority, device key proofs, enrollment permissions, or production sessions**. Use invented fixtures/tokens exclusively, never actual children, live Google credentials or merchant secrets.
- Showing the 171-operation design in Swagger does **not** mean those endpoints exist. Changes to beyond-M1 APIs still follow frozen contract/versioning, security reviews and independent product/Play gates.

## Validation and evidence

~~~sh
python3 -m unittest backend.tests.test_swagger_dev -v
python3 backend/tests/check_m1_route_coverage.py
~~~

The [Swagger dev regression suite](https://github.com/methakon/Madalasa-Alarka/blob/api/backend/tests/test_swagger_dev.py) is wired into M1 contract CI **and CTest**. It checks OAS 3.1 parsing, M1 counts, in-memory server selection, local assets/CSP, read-only planned view, forbidden non-M1 routes, explicit opt-in, no cookie forwarding, request size cap, and fixture-only proxy round-trip. Existing structural M1/full OpenAPI linters continue to run.

**Verification evidence:** [CI run 41168787562](https://github.com/methakon/Madalasa-Alarka/actions/runs/41168787562): contracts-and-isolation (including Swagger tests), database-v2-lineage and backend-build all passed on the final code SHA. **Limitations:** A source/CI pass does not verify a real browser's Swagger rendering until npm assets are installed and the UI is opened; nor does it prove that all M1 operations pass V2 verified session/guardian cross-tenant positive tests. E-02 remains open for those separate tests and dev integration. Source docs are authoritative; Swagger is a local renderer of them, not a substitute.
