# BillDesk onboarding — application submission and verification tracker

**Recorded:** 2026-11-03 IST · **Owner-evidence classification:** OWNER-PROVIDED PORTAL CONFIRMATION TEXT · **Status:** APPLICATION_SUBMITTED; PROVIDER_RESPONSE_AWAITED · **Release status:** NOT_APPROVED.

## Verified from the owner's supplied portal confirmation

The owner supplied BillDesk Connect portal text stating **"Your application is successfully submitted"** and assigning an **Application ID for future correspondence/reference**. The page instructs the applicant to write to **onboarding@billdesk.com** and put the Application ID in the **email subject**. The portal says BillDesk will email an update shortly. **The application number is deliberately not reproduced in this public repository.** The owner holds the exact value in their private portal receipt/email and can use it in direct correspondence. A BillDesk Partner ID beginning with `BD` is **not required** if the application-specific numeric ID is supplied.

Source classification: applicant-provided portal confirmation in project chat, not an independently authenticated account-side API or receipt. No additional approval, settlement, payout, merchant ID, product catalog, payment activation or KYC completion follows from submission alone.

| Gate | Current state | Next verification / owner action |
|---|---|---|
| X-01A — Google Play publisher identity | OWNER_CONFIRMED_COMPLETE (prior status) | Preserve private Play Console evidence; separate from BillDesk |
| X-01B1 — BillDesk application creation | OWNER_CONFIRMED_SUBMITTED | Keep screenshot/receipt and numeric Application ID privately; no duplicate application solely to obtain `BD` number |
| X-01B2 — BillDesk KYC / Video KYC | NOT_CONFIRMED_COMPLETE | Check portal and provider response; if required, finish VKYC with official workflow |
| X-01B3 — BillDesk onboarding review/approval | PROVIDER_RESPONSE_AWAITED | Ask BillDesk for application status and remaining steps; do not equate portal submission with approval |
| X-01B4 — Unpublished Google Play listing link | PROVIDER_CLARIFICATION_AWAITED | Ask whether a Play Console/internal-test link is accepted before app publication, or whether a public listing is mandatory |
| X-01C — Google Payments merchant, payout, tax and billing activation | NOT_VERIFIED | Check actual Play Console/Payments/processor account states and approved test purchases separately |
| Play release and child-data legal gates | STILL OPEN | Play policy/declarations, eligible release, India-specific feature legality and technical/reviewer evidence are independent |

## Communication workflow

- To: **onboarding@billdesk.com**.
- Subject: **Status update request — BillDesk Application ID [OWNER_PRIVATE_APPLICATION_ID]**.
- Include: portal confirms successful submission; ask for current review/KYC status, any pending VKYC/documents, anticipated next action, and unpublished Google Play listing/link requirements.
- Send **from the Gmail account actually used for this particular BillDesk registration**. Prior email correspondence in another Gmail account is not independent proof of the account used for this application.
- Do not send government ID photos, PAN images, payment details or account passwords unless requested through a verified secure official process. Store identity/financial evidence outside GitHub/Figma/CI.

## Development implications

The portal's submission confirmation is an **external onboarding progress event** and does **not** block local C++/Android/SQL implementation, sandbox fixtures, documentation or Figma. Do not mark merchant payments, BillDesk KYC, Google Play billing products, real purchase verification or public release as PASS until explicit provider/Console evidence arrives.

**Status transition rule:** `SUBMITTED` → `UNDER_REVIEW` (provider confirmed) → `APPROVED` or `ACTION_REQUIRED` / `REJECTED`; record UTC/IST time, source and non-sensitive evidence reference for every transition. No silent `SUBMITTED` → `APPROVED` shortcut.
