# Madalasa–Alarka — Commercial Invariants Register

> **Document control:** roadmap / task-governance · **Proposed owner:** Project owner (not yet assigned) · **Registry:** DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master Document Control Register](../MASTER_DOCUMENT_CONTROL_REGISTER.md) · [Decision Ledger](DECISION_LEDGER.md).

**Task:** `L00-008` — Record base prepaid and 100-day add-on invariants.
**Established:** 2026-11-01 · **Version:** 1.0 · **State:** DOCUMENTED_REVIEW_PENDING · **Scope:** LOCAL governance only.

## Purpose

Freeze the commercial invariants for prepaid plans, founding pricing, the concurrent premium viewer, and the ₹100 / 100-day add-on, so implementations and tests behave consistently. Satisfies `L00-008` acceptance: *"Expired base suspends extra viewing but does not erase addon until own end."*

Actual Google Play catalog prices and offer configuration are authoritative at checkout; marketing/mock values never override the store. These invariants are business intent (owner-approved where noted), not provider-verified behavior.

## INV — invariants

- **INV-01 Trial:** 48 hours, once per eligible family, with privacy-respecting anti-repeat. No renewal charge.
- **INV-02 Free tier after trial:** live location at reduced, Android-allowed adaptive sampling, plus the last six hours of history *visible* (a query window, not retention — see [Retention Pending](RETENTION_PENDING.md)).
- **INV-03 Prepaid, manual:** per selected child, **no auto-renewal**. Public target ₹99/month, ₹999/year.
- **INV-04 Founding pricing:** first 1,008 distinct paying families count once; eligible paid children (including later additions) retain ₹50/month or ₹500/year. One count per family.
- **INV-05 Exact-child sharing:** co-parent access is granted per exact child via invitation; no automatic siblings, surname, or billing-family sharing.
- **INV-06 One premium viewer:** one concurrent PREMIUM viewer per active paid child, shared among that child's approved guardians.
- **INV-07 Add-on:** optional **₹100 one-time** adds **+1 viewer slot** lasting **100 calendar days** independently, plus **+30 total combined audio/video minutes** per eligible child, shared among approved guardians.

## INV-08 Base-lapse vs add-on lifecycle (the key invariant)

- When the **base prepaid plan lapses/expires**, the add-on's extra viewing is **SUSPENDED (dormant)** — the extra concurrent viewer and pooled A/V minutes cannot be used while the base is inactive.
- The lapse **does NOT erase, refund, or shorten** the add-on. The add-on continues toward its **own fixed 100-calendar-day expiry**, which is set at purchase and never extended or reset by base lapse/renewal.
- If the base plan is renewed **before** the add-on's day-100 expiry, the add-on's remaining validity and unused pooled minutes **resume** (within whatever remains of its fixed 100-day window).
- At the add-on's day-100 expiry the add-on ends regardless of base state. Base lapse pauses use; it does not delete the add-on before its own end.

This prevents two wrong behaviors: (a) silently deleting a paid add-on when the base lapses, and (b) extending the add-on's 100-day clock because of base lapse/renewal.

## Gate

- Billing provider behavior (Play one-time product, seat counting, founding eligibility, refund/fraud rules) is UNVERIFIED (B-14). Thirteen sandbox cases NOT_RUN.
- Implement with the local fake Play provider and fake clock; prove the day-100 fixed expiry and base-lapse suspension with time-travel tests before any real-provider claim.

## Figma design alignment

Matches SH-03 (one active premium viewer), SH-04 (₹100 once for 100 independent calendar days), and SH-06 (base child prepaid expired but separately purchased ₹100 add-on remains until its own end). The dormant-add-on screen SH-06 is the visual contract for INV-08.

## Related governance sources

- [Decision Ledger](DECISION_LEDGER.md) (C-04, C-05, C-06, B-14)
- [Subscription plans, pricing & rules](../phases/M7-commercial-integrations/01-commercial-plans-and-costing/SUBSCRIPTION_PLANS_PRICING_AND_RULES_2026.md)
- [Child-specific sharing & concurrent screen add-ons](../phases/M7-commercial-integrations/01-commercial-plans-and-costing/CHILD_SPECIFIC_GOOGLE_PARENT_SHARING_AND_CONCURRENT_SCREEN_ADDONS_2026.md)
- [Owner Approvals](OWNER_APPROVALS.md)
