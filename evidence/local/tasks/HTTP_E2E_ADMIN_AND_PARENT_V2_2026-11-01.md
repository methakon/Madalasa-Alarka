# Evidence — V2 HTTP end-to-end: admin back-office + parent session bridge

- **Scope:** real HTTP → Drogon (`ma_backend`) → restricted PostgreSQL, synthetic auth build. Validates E-01 (authorization/RLS), E-02 (M1 routes), E-09 (parent OIDC session bridge) and the admin P0/P1 workstream at the HTTP level.
- **Branch:** `api` (Amar-Pola @ 18a5f90)
- **UTC run timestamp:** 2026-11-01T14:50Z
- **Environment:** Linux x86_64; C++20 Drogon `ma_backend` built with `-DMA_SYNTHETIC_AUTH=ON`; Python venv (psycopg 3.3.6); RAM-backed Postgres on 127.0.0.1:15433 (v2 lineage through 0022)
- **Privacy class:** SYNTHETIC_DATA_ONLY (synthetic identities via test-only auth; disposable DB; no real data/secrets)
- **Release gate:** CONDITIONAL_HUMAN_SIGNOFF
- **Verification type:** AUTOMATED_TEST_REQUIRED

## Build note

`ma_backend` was built in a separate dir `build/backend-synth` with `-DMA_SYNTHETIC_AUTH=ON` (test-only header authenticator; NEVER enabled for a deployable build, per src/auth.h). The default production build (build/backend) has synthetic auth OFF.

## Verification — executed

### Admin back-office V2 — `integration_admin_v2.py ma_backend` → exit `0`
`V2 admin back-office HTTP end-to-end PASS`. Covered (all PASS):
- FAQ: draft not public, publish requires MFA step-up, published FAQ hides editor fields, revision ids exposed.
- RBAC: editor denied `/v1/admin/subscribers`, `/v1/admin/usage/parents`, `/v1/admin/security/audit`; owner permitted (audit read behind MFA).
- Support: owner lists/reads tickets; reply idempotent on request_id; same request_id + different body → conflict; markup/XSS in reply rejected; editor has no support access.
- Session/CSRF: cross-session CSRF refused; CSRF rotates per reload; rotated-out token refused; logout 204 + cookie cleared; logged-out session refused.
- "backend survived every request."

### Parent session bridge V2 — `integration_parent_session_v2.py ma_backend` → exit `0`
`V2 parent session bridge HTTP end-to-end PASS`. Covered (all PASS):
- `listFamilies` shows exactly the owned family; owner creates a child.
- **Ownership does NOT imply exact-child access** (no grant/consent); child listing requires per-child `VIEW_CHILD_PROFILE`; pairing requires `PAIR_DEVICE` on the exact child.
- Cross-family denial: other parent cannot list a foreign family, create a child in it, read a foreign child, or revoke a foreign device.
- Granted guardian reads the exact child but not an ungranted child.
- Session lifecycle: logout 204; revoked session refused; double-logout refused; parent logout cannot end a non-parent-OIDC session; expired session refused.

## Acceptance mapping

Demonstrates, end-to-end over HTTP with a restricted DB, the exact-child authorization model (no automatic sibling/family sharing), admin least-privilege RBAC, MFA-gated owner actions, CSRF protection, and session revocation — all on synthetic data. Does not grant legal/Play/release permission.

## Figma design alignment

Admin flows map to BO-01..BO-09 (owner review, FAQ, support, subscribers/usage/audit) with owner having no child-private data access; parent flows map to the exact-child sharing screens (SH-01/SH-02/SH-05) where unverified/ungranted parents are blocked.

## Result

- **State: PASS** (both HTTP E2E suites exit 0). Disposable DB torn down after the run.
- Strengthens E-01/E-02/E-09 from unit-level to HTTP↔PostgreSQL level under synthetic auth.
- Reviewer: NOT YET ASSIGNED. Status-ledger update deferred to `main`.
