# Madalasa–Alarka admin web

Responsive React + TypeScript administration UI, designed from the BO-01 to BO-09 Figma back-office frames. Uses the source colors: navy #223952, cream #fbf7ee, pale green and peach.

## Local synthetic-only preview

    cd admin-web
    npm install --no-audit --no-fund
    VITE_ADMIN_SYNTHETIC_PREVIEW=true npm run dev

Open http://127.0.0.1:5173. This preview uses invented examples only, prominently discloses synthetic mode and disables mutations. Never enable preview on a public service.

## Live integration constraints

Without preview mode, the UI calls same-origin /v1/admin/access/me. The backend admin APIs remain **design-only** in docs/openapi.yaml; Drogon M1 does not implement them. The UI therefore fails closed rather than granting an owner role or inventing live data.

The typed API adapter uses same-origin credentials, no localStorage, admin path allowlisting, response error checks and a server-supplied CSRF token gate for mutations. It calls the planned owner access-review, FAQ, support, subscriber and audit paths only after authorized server sessions exist.

**Not yet implemented:** real Google OAuth callback, verified owner issuer/subject bootstrap, MFA/step-up, secure admin cookie/session, authoritative roles, profile/email verification, admin business handlers and database queries. Real activity, successful mutations, payments and staff privileges must not be inferred from UI mockups. The source schemas currently return single access-request objects where the UI needs lists and omit a trusted revision for access decisions, so full live integration is blocked pending versioned backend contract alignment. Media and child private records remain excluded.

## Tests

    npm test
    npm run build

Code is on the admin-web workstream branch and must be reviewed and merged into dev before main. Source changes must not claim production readiness.
