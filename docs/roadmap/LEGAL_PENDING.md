# Madalasa–Alarka — India Controller & Legal Pending Register

> **Document control:** roadmap / task-governance · **Proposed owner:** Project owner (not yet assigned) · **Registry:** DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master Document Control Register](../MASTER_DOCUMENT_CONTROL_REGISTER.md) · [Decision Ledger](DECISION_LEDGER.md).

**Task:** `L00-005` — Register India controller and age-band UNKNOWN.
**Established:** 2026-11-01 · **Version:** 1.0 · **State:** DOCUMENTED_REVIEW_PENDING · **Scope:** LOCAL governance only.

## Purpose

Record the India data-controller determination and child age-band treatment as **PENDING** so that **no real-data pilot is permitted until a verifiable lawful approval exists.** Satisfies `L00-005` acceptance: *"No real-data pilot allowed until verifiable approval."*

## Binding rule

**No real minors' data, and no real-data pilot of any child-monitoring feature, is permitted** until the India DPDP purpose-by-purpose lawful authority, guardian consent/authority, retention/deletion basis, and cross-border processing basis are documented and verifiable. Synthetic fixtures and non-production tests continue. Selecting a market or age band is product scope, not legal approval.

## Pending legal registrations

| Item | State | Note |
|---|---|---|
| India data controller identity | PENDING | Owner is the accountable controller; formal controller/processor mapping not finalized |
| Child age band | DECIDED (scope) / PENDING (lawfulness) | B-02: India, ages 0–17 inclusive. Legal treatment of under-18 processing remains gated |
| DPDP s.9 verifiable parental consent basis | PENDING | Feature-by-feature; see India DPDP gate |
| DPDP real-time safety exemption scope | PENDING | Narrow; does NOT automatically cover history, usage, media |
| Cross-border processing basis | PENDING | Depends on deployment region (B-08, deferred) |
| Tele-Law / MeitY guidance | EXTERNAL_PENDING | Owner-reported requests sent; responses pending; not a government approval process |

## No-real-data-pilot gate

Until the items above are verifiably resolved:

- No real child location, usage, health, media, or identity in any build, test, fixture, or deployment.
- No pilot with real families, even opt-in, even internal.
- All sensitive feature flags remain disabled per the [feature-gate matrix](../../config/feature-gates.example.json).
- Data handling follows the [Local Data Rules](LOCAL_DATA_RULES.md) synthetic-only classification.

A verifiable approval means a documented, dated, feature-specific lawful basis an auditor could check — not an assumption, not a product preference, not passing local tests.

## Related governance sources

- [India DPDP child privacy & cross-border gate](../phases/M0-foundation-and-approvals/03-legal-and-privacy/INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md)
- [India government/legal/Play risk assessment](../phases/M0-foundation-and-approvals/03-legal-and-privacy/INDIA_GOVERNMENT_LEGAL_GOOGLE_PLAY_PROJECT_RISK_ASSESSMENT_2026.md)
- [DPIA](../phases/M0-foundation-and-approvals/03-legal-and-privacy/DPIA.md)
- [Decision Ledger](DECISION_LEDGER.md) · [Owner Approvals](OWNER_APPROVALS.md)
