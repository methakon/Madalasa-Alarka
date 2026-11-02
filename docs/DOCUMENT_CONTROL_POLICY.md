# MA-DOC-CTRL-001 — Professional Document Control and Phase Gate Standard

**Issued for review:** 2026-10-27 · **Status:** WORKING_DRAFT / NOT OWNER-SIGNED. Applies to `docs/phases/`, the fixed API contracts, UI handoffs and release evidence.

## 1. Naming, category, phase and single source of truth

The canonical project milestone numbering is **M0–M9**, not separately invented business-unit phases. Each full-text document belongs to **one primary phase/category**; cross-phase dependencies are links, not additional uncontrolled copies. **P3** is research/deferred and **CROSS** is for shared architecture references. Existing filenames and existing in-document IDs/versions are retained. The root `docs/<old>.md` compatibility pointers contain no maintained substantive text.

## 2. Required controlled document metadata

At its next substantive review, each document must identify: document ID, exact title, purpose, project/company, primary milestone, content category, current edition/version, date, proposed author role, **named actual author**, reviewer role/name, approver role/name, status, revision log, requirement references, source evidence, decision constraints, next review date and superseded document paths. **Not known** must be written as **UNASSIGNED / NOT EVIDENCED / TBD**, never guessed. Repository commit history is change provenance, not legal or business sign-off.

## 3. Lifecycle statuses and gates

| Status | Meaning | May engineering work start? |
|---|---|---|
| WORKING_DRAFT | Text exists, not reviewed or signed | Synthetic planning/prototype with isolated controls only |
| REVIEW_REQUIRED | Coverage assembled, independent review is due | Only explicitly allowed synthetic scope |
| REVIEWED | Reviewer checked technical/internal consistency and recorded date | Depends on blocked M0/data-release controls |
| BASELINED | Version/commit and change-control owner formally adopted | Yes for approved bounded engineering scope, not child-data production |
| APPROVED | Named authorized owner signed document and known restrictions | May clear corresponding *document* gate, not all release gates |
| SUPERSEDED/RETIRED | Historic, explicitly points to replacement | Do not treat as current implementation contract |
| RESEARCH_ONLY/NO-GO | Deferred or legally blocked capability | Never activate in a real-child app until independent release decision |

The migration register's `DOCUMENTED_REVIEW_PENDING`, `DRAFT_LEGAL_REVIEW_REQUIRED`, etc. are **conservative tracking labels** from project context, not evidence of an enacted quality-management system or person signing a document.

## 4. Review and approval roles

Owner/product: product scope, roadmap, intended use and business acceptance. Engineering architect/backend/Android lead: HLD, LLD, API, code-bound compatibility and feasibility evidence. QA: traceability and test-case completeness. Security: threat model, permissions and cryptography. Privacy/qualified India counsel: child data purposes, lawful processing, parent authority, DPIA/retention, DPAs and consumer disclosures. Operations: OCI, monitoring, incident, backup/recovery. Play release owner: Play policy, reviewer pack and developer account. Nobody is treated as appointed merely because their role appears in a table.

## 5. Change-control procedure

Propose issue/ADR → determine affected phase and consumer/requirement → update canonical doc and traceability → evaluate legal/Play/Android/child impacts → version/date the controlled document → seek named reviewer and approver → attach signed record in approved secure location → merge with CI link tests → update this register, and mark earlier content SUPERSEDED only when genuinely replaced. Never put actual child data, identities, secrets, private counsel files or signed personal data in the public repo.

## 6. Proof versus plans

Documentation phase exit means **the necessary documents are inventoried, consistent enough for review, and owner decisions are explicitly enumerated**. Software code/testing deployment are **different milestones**. No OpenAPI/Figma diagram implies executable features. The base M1 SQL tenant-isolation CI is only narrow evidence, not an overall child-safety app clearance. Any approved real-child pilot needs independent India law/guardian/Google Play and device security evidence.

## 7. Machine-readable traceability

[Master register](MASTER_DOCUMENT_CONTROL_REGISTER.md) is the human index; [relocation manifest](DOCUMENT_RELOCATION_MANIFEST.json) retains old/new paths, phase/category and source blob SHA. [Phase coverage](PHASE_DOCUMENTATION_COVERAGE_MATRIX.md) shows M0–M9 readiness gaps. GitHub file URLs that pointed at `docs/<old>.md` continue through the compatibility pointer; root OpenAPI/CI paths remain stable.
