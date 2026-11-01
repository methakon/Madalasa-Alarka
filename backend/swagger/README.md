# Swagger UI — developer-only, never part of production Drogon

Madalasa–Alarka already has two OpenAPI 3.1 contracts (JSON encoded in .yaml files).
Swagger UI shows the 14 **frozen M1** endpoints and the broader **design-only**
Figma/OpenAPI document separately. It does **not** generate handlers or change
the frozen API. The pinned Swagger UI distribution is 5.34.1 (Apache-2.0).

## Install assets and open read-only API documentation

~~~sh
cd backend/swagger
SCARF_ANALYTICS=false npm install --ignore-scripts --no-audit --no-fund
cd ../..
python3 backend/scripts/swagger_dev.py
~~~

Open http://127.0.0.1:8765/swagger/m1 (frozen M1).
Open http://127.0.0.1:8765/swagger/planned (Figma-wide design; NOT implemented).

Assets stay in ignored node_modules, not a remote CDN. Node is needed only
for installation; the runtime serves assets locally using Python 3.10+.
The source spec's invalid production placeholder is replaced with local /v1
**in memory only**, never committed to the canonical OpenAPI document.

## Explicit synthetic-only Try it out

First start a local Drogon backend on port 8080 with appropriate synthetic
fixtures. Then:

~~~sh
python3 backend/scripts/swagger_dev.py --backend-port 8080 --enable-try-it-out
~~~

- WITHOUT the flag, no method can be executed by the proxy.
- WITH the flag, only the exact 14 frozen M1 method+path combinations can
  be forwarded to 127.0.0.1. The broader planned APIs, including location
  ingestion/media/billing, remain blocked and the planned UI is read-only.
- The docs and API proxy are same-origin; do not change Drogon CORS settings.
- No real children's data, real guardian identities, production Google tokens,
  real merchant credentials or real Android devices. Swagger can show bearer
  auth in its local browser session; use synthetic credentials only.
- The tool forwards a limited header allowlist and does not log requests.
- Do not expose this utility on 0.0.0.0, install it on public VPS hosts, or
  add Swagger routes into the production C++ Drogon process.
- The wider Figma/OpenAPI design does **not** imply all its operations exist.
- Real V2 trusted-session/guardian authorization remains an independent gate.

## Verification

~~~sh
python3 -m unittest backend.tests.test_swagger_dev -v
python3 backend/tests/check_m1_route_coverage.py
~~~

CI additionally runs existing M1/full OpenAPI structure linters and the new
local Swagger regression tests. Those verify parsing, endpoint counts,
read-only defaults, same-origin path routing, fixed loopback backend, and
negative authorization/path/size cases. A real browser rendering check still
requires local npm assets and a developer browser.
