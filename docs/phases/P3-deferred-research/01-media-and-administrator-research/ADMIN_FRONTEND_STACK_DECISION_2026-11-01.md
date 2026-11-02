# ADR — Admin Panel frontend: HTMX + Alpine.js CSP

**Decision:** OWNER_APPROVED, 2026-11-01. **Implementation:** MIGRATION_PENDING. Applies only to the browser-based administrative back office, not the native Madalasa/Alarka Android apps. Replaces the earlier 'UI technology TBD' assumption. React/TypeScript/Vite on the admin-web branch is historical provisional implementation, **not** the approved destination.

## Approved stack and rationale

- Backend remains **C++20 Drogon** serving authenticated server-rendered HTML templates and narrow HTMX fragment responses; existing JSON endpoints may be retained for documented clients and tests.
- Browser: semantic **HTML/CSS**, **HTMX** for server-driven interactions (pagination, search, forms, modals) and **Alpine.js CSP-compatible distribution** for strictly local display state (dropdowns, disclosure, dialog toggles); avoid arbitrary dynamic JS expressions and inline event scripts.
- **No separate Node.js production server required.** Build-time tools are optional; pin packages and integrity, use locally hosted immutable production assets, not external CDN scripts.
- Figma BO-01..BO-09 variants remain the visual handoff; responsive, keyboard-accessible, progressive forms with no live child data in demos.
- Selected to minimize shipped JS and client authorization complexity. Security comes from the backend and deployment controls, **not automatically from library size**.

## Non-negotiable security architecture

1. Google OIDC verification occurs on the server (issuer, audience, signature, expiry, nonce, state and replay); applicant Google sign-in does not grant owner/staff privileges. Bind initial owner only to verified Google issuer+subject by controlled bootstrap, not user-supplied email.
2. Sessions: short-lived, rotated, revocable server-side sessions; Secure, HttpOnly, suitable SameSite cookies and anti-CSRF tokens for all mutations and sensitive HTMX endpoints; validate origin/fetch metadata as defense in depth. Owner role mutations need MFA/step-up, dual approval where required, and audited revision checks.
3. Enforce **every request** through Drogon admin audience, scoped RBAC and PostgreSQL RLS; no privileges from hidden buttons, browser props, role strings, or client-side Alpine state. A ROOT_OWNER is not automatically authorized to read child location, recordings or private media.
4. Output HTML-encode dynamic values; sanitize approved FAQ rich text with a strict allowlist at ingest AND render. Treat support tickets and email replies as hostile HTML; no untrusted HTML injection into HTMX swap targets or Alpine expressions. Set CSP prohibiting unsafe-inline and unsafe-eval wherever feasible, with approved nonces/hashes and locally hosted assets.
5. HTMX: disallow dangerous untrusted attributes, restrict permitted request origins and targets, reject user-controlled hx-* markup, disable automatic script evaluation for swapped fragments and sensitive history cache, and return 403/401/409 rather than fake-success HTML. Never use HTMX response headers for untrusted arbitrary navigation.
6. Staff-facing lists use server pagination, minimal authorized projections, rate-limited autocomplete, request-size limits and audited exports; avoid raw payment tokens, private child data, precise coordinates, audio/video, device activation.
7. Redact logs, secure form and upload endpoints, attachment scanning, anti-clickjacking/frame-ancestors, HSTS, referrer restrictions, dependency scanning, SRI for any permitted external resource, independent negative authorization tests.

## Migration plan and acceptance

- **ADM-STACK-01** Freeze current React branch as reference; inventory Figma components, routes, typed API adapter, security gates, all BO screens and error states. Do not delete old code before parity and CI.
- **ADM-STACK-02** Add server HTML templates and trusted partial renderer to Drogon, plus local vendored version-pinned HTMX and Alpine CSP assets, strict CSP and anti-CSRF foundation.
- **ADM-STACK-03** Recreate BO-01..BO-09 navigation/forms and keyboard interactions; compare Figma screenshots. Prefer server decisions for roles/visibility; Alpine only for harmless client display state.
- **ADM-STACK-04** Integrate Google verified admin sessions, owner approval, FAQ review/publish, tickets/replies, subscribers, usage metadata and audit/roles using existing or explicitly versioned APIs.
- **ADM-STACK-05** Test XSS in tickets/FAQ/search, CSRF (HTMX headers/forms), IDOR, RBAC/role revocation, login replay, injected hx-* attributes, SSRF/open redirects, audit-store failure, HTML cache leak, CSP violations, session fixation, tab concurrency, accessibility and safe offline/timeout states. Use synthetic data only.
- **ADM-STACK-06** Produce parity and migration evidence with exact SHAs and test output; reviewed PR admin-web→dev→main. Retire React/Vite runtime only after verified parity. No claim of production auth or regulatory readiness until independently demonstrated.

**Change control:** This is an OWNER-APPROVED TECH-STACK DECISION, not implementation completion or approval of any admin data access. Other prior requirements remain binding.
