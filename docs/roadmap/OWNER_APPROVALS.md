# Madalasa–Alarka — Owner Decision & Approval Template

> **Document control:** roadmap / task-governance · **Proposed owner:** Project owner (not yet assigned) · **Registry:** DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master Document Control Register](../MASTER_DOCUMENT_CONTROL_REGISTER.md) · [Decision Ledger](DECISION_LEDGER.md).

**Task:** `L00-004` — Define owner decision template and approval signatures.
**Established:** 2026-11-01 · **Version:** 1.0 · **State:** DOCUMENTED_REVIEW_PENDING · **Scope:** LOCAL governance only.

## Purpose

Provide a uniform record for owner decisions and approvals so that **unresolved blocking decisions are explicitly recorded as BLOCKED, never guessed or silently assumed resolved.** Satisfies `L00-004` acceptance: *"Unresolved blocking decisions recorded as BLOCKED not guessed."*

Rule: a decision is binding only when it carries an owner approval record with a date. Until then its state is `OPEN` or `BLOCKED`, and dependent work must fail closed. Selecting a suggested default is a design assumption, not an owner approval.

## Approval record fields

Each decision record uses these fields:

| Field | Meaning |
|---|---|
| `decision_id` | Stable ID (e.g. B-07, X-03) cross-referenced in the [Decision Ledger](DECISION_LEDGER.md) and [Blockers register](../phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md) |
| `question` | The exact decision required |
| `state` | `OPEN` · `BLOCKED` · `DECIDED` · `DEFERRED` · `EXTERNAL_PENDING` |
| `decision` | The recorded owner decision text, or `NONE — NOT YET DECIDED` |
| `decided_by` | Owner identity (human); blank until recorded |
| `decided_date` | UTC date of the recorded decision; blank until recorded |
| `evidence` | Reference to where the decision is recorded; `NONE` if unrecorded |
| `blocks` | What stays fail-closed while unresolved |

A record with `state` in {`OPEN`, `BLOCKED`, `DEFERRED`, `EXTERNAL_PENDING`} must have `decision = NONE…` and blank `decided_by`/`decided_date`. Never populate an approval that the owner has not given.

## Current decision records (snapshot — authoritative source is the Blockers register)

| decision_id | question | state | decision | decided_by | decided_date | blocks |
|---|---|---|---|---|---|---|
| B-01 | Publisher identity | DECIDED | SWARNA SEKHAR DHAR, individual, India; Play identity completed | owner | 2026-10-31 | — |
| B-02 | Launch market & age band | DECIDED | India-only; ages 0–17 | owner | 2026-10-30 | legal/Play classification |
| B-03 | Background operation transparency | DECIDED | Transparent, no stealth | owner | 2026-10-30 | Android/Play/India evidence |
| B-04 | First-release feature inventory | DECIDED | Evaluate full inventory; per-feature gates apply | owner | 2026-10-30 | per-feature gates |
| B-05 | Provisioning model | DECIDED | Standard install first; Device Owner deferred | owner | 2026-10-30 | future managed edition |
| B-06 | Child SOS / capture / alarm UX | BLOCKED | NONE — design requested; legal/Play/Android open | | | child SOS/media/alarm |
| B-07 | Retention per category | BLOCKED | NONE — NOT YET DECIDED | | | retention/schema/cost |
| B-08 | Hosting provider/region | DEFERRED | NONE — reserved for deployment planning | owner | 2026-10-28 | deployment only |
| B-09 / B-18 | Guardian authority/scope/TTL; history visibility | BLOCKED | NONE — NOT YET DECIDED | | | ACL/sharing tables |
| B-14 | Founding pricing | DECIDED | First 1,008 families ₹50/mo or ₹500/yr | owner | 2026-10-28 | provider verification |
| B-16 | Media in launch | BLOCKED | NONE — conditional/OFF | | | sensitive permissions |
| X-01B | Payment/BillDesk verification | EXTERNAL_PENDING | NONE — provider response awaited | | | billing activation |
| X-01C | Merchant/payment activation | EXTERNAL_PENDING | NONE — not confirmed | | | billing/store |
| X-02 | Play Families location (G01) + background (G04) | EXTERNAL_PENDING | NONE — support case pending; G04 not submitted | | | location features release |
| X-03 | India DPDP child-data lawfulness | BLOCKED | NONE — due diligence in progress | | | real-child data features |

Remaining B-items (B-10–B-13, B-15, B-17, B-19–B-22) stay `OPEN` with suggested defaults as design assumptions only; see the Blockers register.

## Usage

1. When the owner records a decision, update the matching row here and in the [Decision Ledger](DECISION_LEDGER.md), setting `state=DECIDED`, the decision text, `decided_by`, `decided_date`, and `evidence`.
2. Never set `DECIDED` without a dated owner record. No automated process self-approves owner/legal/platform decisions.
3. Dependent tasks must treat any non-`DECIDED` record as fail-closed.

## Related governance sources

- [Decision Ledger](DECISION_LEDGER.md)
- [Blockers & Owner Decisions](../phases/M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md)
- [Local Data Rules](LOCAL_DATA_RULES.md)
- [Agent Execution & Test Evidence Contract](AGENT_EXECUTION_AND_TEST_EVIDENCE.md)
