# Evidence — Canonical FAQ seed content (authored + loaded + verified)

- **Scope:** create FAQ entries from the project documents/decisions and make them version-controlled, schema-valid, and loadable through the enforced admin path. Supports the admin back-office FAQ workstream (BO-05) and the public `/v1/faqs` read path.
- **Branch:** `api` (backend/SQL worktree Amar-Pola)
- **UTC run timestamp:** 2026-11-01T20:05Z
- **Environment:** Linux x86_64; Python venv (psycopg 3.3.6); RAM-backed Postgres on 127.0.0.1:15433 (v2 lineage through 0022)
- **Privacy class:** SYNTHETIC_DATA_ONLY (disposable DB; no real data)
- **Release gate:** CONDITIONAL_HUMAN_SIGNOFF
- **Verification type:** AUTOMATED_TEST_REQUIRED

## What was created

- `backend/persistence/seeds/faqs.json` — 20 canonical FAQ entries grounded in the project documents, each matching the `FaqDraftInput` contract and the `ap_m1.faq_entries`/`faq_revisions` schema constraints (slug `^[a-z0-9][a-z0-9-]{1,149}$`, category ≤100, language `en`, title 3–220 without `<>`, `safe_markdown` 1–10000 without `< > [ ]`, plain-text Markdown only).
- `backend/tests/database/test_faq_seed_content.py` — loads the JSON through the real stored procedures and verifies the lifecycle.

## FAQ topics (grounded in sources)

Categories: Getting started, Plans and billing, Guardians and sharing, Privacy and data, Features and permissions, Safety features, Support. Content reflects:
- Commercial invariants (COMMERCE_INVARIANTS.md): 48h one-time trial, free live location + last 6h visibility, prepaid no-auto-renew, ₹99/₹999 vs founding ₹50/₹500 for first 1,008 families, one premium viewer, ₹100/100-day add-on with base-lapse-suspends-not-erases semantics.
- Exact-child sharing / no Family Link dependency (DECISION_LEDGER.md, ADR 2026-10-28): invitation per exact child, no automatic siblings, co-parent has no billing control, revoke semantics.
- India DPDP gate: feature-by-feature lawfulness, no blanket exemption, gated features OFF until cleared; six-hour window is viewing not retention.
- Admin least-privilege (ADMIN_OWNER_...2026): owner/support cannot see raw child location/history/media.
- Android/Play reality (X-02 review, compatibility matrix): no covert capture, honest unavailable/permission states, standard install (Device Owner deferred), SOS best-effort.

## Verification — executed

`tools/database/manage.py test --database test --pattern test_faq_seed_content.py` → exit `0`, `Ran 3 tests ... OK`:
- `test_01_content_obeys_schema_constraints` — all 20 entries pass slug/category/language/title/body constraints and slugs are unique.
- `test_02_draft_publish_and_public_visibility` — each entry drafts via `ap_m1.faq_draft` (FAQ_EDIT), is confirmed NOT publicly visible while DRAFT, then publishes via `ap_m1.faq_transition` under an MFA admin session (FAQ_PUBLISH); the public read path then returns exactly the published title/body.
- `test_03_unprivileged_runtime_cannot_draft` — a runtime connection with no admin session is denied FAQ_EDIT (SQLSTATE 42501 / InsufficientPrivilege).

Full-suite regression: `tools/database/manage.py test --database test` → exit `0`, `Ran 257 tests ... OK (skipped=10)` (was 254; +3 FAQ tests; 0 failures).

## Iterations (genuine fixes)

- Corrected the expected exception for the denial test (42501 surfaces as `InsufficientPrivilege`, not `RaiseException`).
- Made teardown/cleanup FK-safe for the circular `faq_entries`<->`faq_revisions` references and the PUBLISHED CHECK, and robust against leftover rows (set DRAFT + null pointers before delete; also clear the immutable audit rows for the synthetic actor/targets).

## Figma design alignment

Content and categories map to the BO-05 admin FAQ screen (search + categories, editor, publication controls) and the public FAQ view; the draft→publish/MFA/RBAC behaviour matches the admin back-office spec. No HTML/links in bodies, consistent with the sanitized plain-text rendering contract.

## Result

- **State: PASS** (3 FAQ tests + 257-test full suite, exit 0). Disposable DB torn down.
- The 20 entries are canonical, version-controlled, and load through the enforced path; actual runtime publication on a deployed admin panel remains a separate owner/admin action, and gated features' FAQ text truthfully states they are not yet available.
- Reviewer: NOT YET ASSIGNED. Status-ledger update deferred to `main`.
