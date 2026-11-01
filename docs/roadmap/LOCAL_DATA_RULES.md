# Madalasa–Alarka — Local Synthetic-Only Data Classification & Rules

> **Document control:** roadmap / task-governance · **Proposed owner:** Project owner (not yet assigned) · **Registry:** DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master Document Control Register](../MASTER_DOCUMENT_CONTROL_REGISTER.md) · [Decision Ledger](DECISION_LEDGER.md).

**Task:** `L00-003` — Define synthetic-only local data classification.
**Established:** 2026-11-01 · **Version:** 1.0 · **State:** DOCUMENTED_REVIEW_PENDING · **Scope:** LOCAL development only.

## Purpose

Local development, tests, fixtures and evidence use **synthetic data only**. This document classifies every data category the product touches and states exactly what a coding agent may and may not place into the repository, fixtures, logs, or evidence files. It satisfies `L00-003` acceptance: *"No real child, payment token, government ID or home address used."*

Binding rule: **No real minors' data, and no real identity/payment/credential data of any person, may exist in any build, test, fixture, log, or committed file.** This holds until India DPDP purpose-by-purpose lawful authority, Google Play eligibility, and owner authorization are independently verified (see [India DPDP gate](../phases/M0-foundation-and-approvals/03-legal-and-privacy/INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md), [DPIA](../phases/M0-foundation-and-approvals/03-legal-and-privacy/DPIA.md)).

## A. Data categories and local handling

| Category | Examples | Real data in repo? | Synthetic substitute required |
|---|---|---|---|
| Child identity | Child name, DOB, photo, school | **FORBIDDEN** | Invented alias (e.g. `child_demo_01`), fixed fictional DOB, no face image |
| Child location (GPS) | lat/lon, accuracy, speed, timestamps | **FORBIDDEN** (real minor) | Generated coordinates in a public test bounding box, synthetic timestamps |
| App usage / behavioral | Per-app foreground intervals | **FORBIDDEN** (real minor) | Generated usage fixtures with fictional package names |
| Health / SOS | SOS events, device health | **FORBIDDEN** (real) | Synthetic event fixtures |
| Adult / guardian identity | Real name, email, phone | **FORBIDDEN** | Synthetic aliases; the only real operational addresses permitted are the project's own published support/no-reply mailboxes, never a household's |
| Government ID | PAN, Aadhaar, passport, driving licence | **FORBIDDEN** | Never represented; use opaque synthetic account IDs |
| Home / residential address | Street address, pincode of a real home | **FORBIDDEN** | Fictional place labels only |
| Payment tokens | Play purchase tokens, card/UPI data, bank details | **FORBIDDEN** | Fake Play provider tokens from the local testkit adapter |
| Secrets / credentials | API keys, OIDC client secrets, dev-account ID, JWT signing keys | **FORBIDDEN** | `.env.example` placeholders; real secrets never committed |
| Device identifiers | Real IMEI/Android ID/FCM token | **FORBIDDEN** | Synthetic device IDs and fake FCM adapter tokens |

## B. Forbidden real-data patterns (scanner-enforced)

The checker `tools/check-local-data-rules.py` statically scans committed text for patterns that indicate real sensitive data and fails closed if any appear outside an explicit allowlist:

- **PAN:** `[A-Z]{5}[0-9]{4}[A-Z]` (Indian Permanent Account Number shape)
- **Aadhaar:** a 12-digit group `\b[0-9]{4}\s?[0-9]{4}\s?[0-9]{4}\b`
- **Credit/debit card:** 13–16 contiguous digits passing a Luhn-like length check
- **Google Play purchase token:** long opaque token patterns labelled `purchaseToken`/`purchase_token`
- **Private keys:** `BEGIN (RSA|EC|OPENSSH|PRIVATE) KEY`
- **Real residential address markers** paired with a 6-digit Indian PIN in fixtures

Allowlisted, non-sensitive strings (explicitly permitted): the project's own published support/no-reply mailboxes, documentation that merely *names* these categories (such as this file), and synthetic identifiers prefixed `demo_`, `synthetic_`, `test_`, `fake_`.

## C. Required synthetic fixture conventions

- Child/adult/device records use `demo_`/`synthetic_` prefixes and fixed fictional values.
- Coordinates come from a declared public test bounding box; never a real child route.
- Payments go through the local fake Play provider; never a real charge, payout, or token.
- OIDC/FCM/maps use local fake adapters; no live third-party calls in local tests.
- Evidence files redact any value that could resemble a real identifier.

## D. Enforcement and relationship to other gates

- This classification is enforced by `tools/check-local-data-rules.py` (exit non-zero on any match). It complements the fail-closed [feature-gate matrix](../../config/feature-gates.example.json) (L00-002) and the [Decision Ledger](DECISION_LEDGER.md) (L00-001).
- Passing this scan is **not** legal or Play approval; it only proves the repository contains no real sensitive-data patterns at scan time.

## F. Figma design alignment

Cross-checked against the [Figma functional handoff](../ui/figma-functional-handoff/README.md) and [Theme C UI contract](../ui/MADALASA_ALARKA_THEME_C_STORY_AND_UI_CONTRACT_2026.md): billing/checkout screens (P-47/P-48/P-49, SH-03/SH-04) route payment through Google Play and present no raw card/UPI/bank entry fields; child-profile and history screens display only child-scoped data; and the designs explicitly treat six-hour history *visibility* as distinct from stored retention. The synthetic-only categories above therefore match what the designs actually render — no screen requires real PAN, Aadhaar, card number, or residential address. These classifications must stay consistent with the Figma source if screens change.

## Related governance sources

- [Decision Ledger](DECISION_LEDGER.md)
- [DPIA](../phases/M0-foundation-and-approvals/03-legal-and-privacy/DPIA.md)
- [India DPDP child privacy gate](../phases/M0-foundation-and-approvals/03-legal-and-privacy/INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md)
- [Data Retention Schedule](../phases/M0-foundation-and-approvals/03-legal-and-privacy/DATA_RETENTION_SCHEDULE.md)
- [Agent Execution & Test Evidence Contract](AGENT_EXECUTION_AND_TEST_EVIDENCE.md)
