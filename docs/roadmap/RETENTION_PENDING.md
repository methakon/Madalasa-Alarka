# Madalasa–Alarka — Retention Contradiction Pending Register

> **Document control:** roadmap / task-governance · **Proposed owner:** Project owner (not yet assigned) · **Registry:** DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master Document Control Register](../MASTER_DOCUMENT_CONTROL_REGISTER.md) · [Decision Ledger](DECISION_LEDGER.md).

**Task:** `L00-006` — Record retention contradiction as unresolved gate.
**Established:** 2026-11-01 · **Version:** 1.0 · **State:** DOCUMENTED_REVIEW_PENDING · **Scope:** LOCAL governance only.

## Purpose

Record the unresolved retention decision (conflict C-02) and make explicit that the **free six-hour history visibility is an access/query window, not a storage lifetime.** Satisfies `L00-006` acceptance: *"Six-hour access window not conflated with storage lifetime."*

## The distinction (binding)

- **Six-hour free visibility** = a read/query access limit: a free parent may *view* at most the last six hours of history. It constrains what is *shown*, not how long data is *stored*.
- **Storage lifetime / retention** = how long raw GPS, derived trips, usage, audit records, and backups are *kept*. This is a separate, per-category policy and is **NOT YET DECIDED** (B-07, conflict C-02).

Conflating the two is forbidden. Showing six hours does not imply deleting older data at six hours, and it does not imply retaining data indefinitely either. Neither storage duration nor deletion timing is approved by the visibility window.

## Pending retention decisions (per category — all UNRESOLVED)

| Category | Planning candidate (NOT approved) | State |
|---|---|---|
| Raw GPS observations | 14 days (candidate) | BLOCKED (B-07) |
| Derived trips/routes/places | 90 days (candidate) | BLOCKED (B-07) |
| App usage summaries | 90 days (candidate) | BLOCKED (B-07) |
| Audit/access logs | 90 days (candidate) | BLOCKED (B-07) |
| Backups / WAL | undecided | BLOCKED (B-07) |
| Free parent visibility window | **six hours (product decision, C-14)** | distinct from retention |

Candidate values are design assumptions for synthetic benchmarking only; they are not an owner- or counsel-approved retention schedule.

## Gate

- No real-data retention schedule is operative until B-07 is DECIDED with a dated owner/legal record (see [Owner Approvals](OWNER_APPROVALS.md)).
- Implementations must model retention as a configurable per-category policy abstraction, defaulting to fail-closed (no silent indefinite retention, no premature deletion of lawfully retained data).
- The six-hour visibility window is implemented as a query bound, independent of the retention policy.

## Related governance sources

- [Decision Ledger](DECISION_LEDGER.md) (C-02, C-14, B-07)
- [Data Retention Schedule](../phases/M0-foundation-and-approvals/03-legal-and-privacy/DATA_RETENTION_SCHEDULE.md)
- [Local Data Rules](LOCAL_DATA_RULES.md) · [Legal Pending](LEGAL_PENDING.md)
