# Madalasa–Alarka — Release Approval Authority & Responsibilities (RACI)

> **Document control:** roadmap / task-governance · **Proposed owner:** Project owner (not yet assigned) · **Registry:** DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master Document Control Register](../MASTER_DOCUMENT_CONTROL_REGISTER.md) · [Decision Ledger](DECISION_LEDGER.md).

**Task:** `L00-010` — Define release approval authority and RACI.
**Established:** 2026-11-01 · **Version:** 1.0 · **State:** DOCUMENTED_REVIEW_PENDING · **Scope:** LOCAL governance only.

## Purpose

Define who is accountable for each class of decision, so that **no automated process self-approves legal/counsel, platform (Google Play/Android), or owner business decisions.** Satisfies `L00-010` acceptance: *"No agent self-approves counsel/platform/owner decisions."*

## Core rule

Implementation and local verification may be performed and recorded under the responsible human owner identity, but **approval of counsel/legal, Google Play/Android platform, and owner business decisions is reserved to the accountable humans/authorities below. No automated process, script, or contributor self-approves these.** A passing local test or merged PR is never release, legal, or platform approval.

## RACI by decision class

| Decision class | Responsible (does the work) | Accountable (approves) | Consulted | Informed |
|---|---|---|---|---|
| Local implementation & synthetic tests | Contributor (human-owned) | Project owner | Security reviewer | — |
| Security review of a change | Security reviewer | Project owner | Contributor | — |
| Owner business decisions (pricing, scope, market) | Project owner | Project owner | — | Contributors |
| Legal/counsel (India DPDP, child-data lawfulness) | Qualified India counsel / owner due diligence | Project owner (accountable) + counsel where required | Privacy specialist | Contributors |
| Google Play eligibility & declarations | Owner (Play Console actions) | Google Play (external) | Release lead | Contributors |
| Android OS feasibility (device/OEM evidence) | QA with physical devices | Project owner | Android dev | Contributors |
| Deployment / hosting region | Owner + ops | Project owner | Ops/SRE | Contributors |
| Payment/merchant activation | Owner + provider | Payment provider (external) + owner | Finance | Contributors |

## What an automated process / contributor may NOT do

- May **not** self-approve or fabricate: legal signoff, counsel opinions, Google Play approval, Android device certification, owner business decisions, or payment/merchant activation.
- May **not** mark a task PASS without executed commands, real exit codes, and redacted evidence.
- May **not** enable a sensitive feature flag whose gates are not independently CLEARED (see [feature-gate matrix](../../config/feature-gates.example.json)).
- May **not** perform deployment, Play Console submission, real billing, or device provisioning (see the [separate deployment plan](DEPLOYMENT_AND_PLAY_RELEASE_PLAN_SEPARATE_2026-10-28.md)).

## What may proceed without external approval

- Local synthetic-data implementation, tests, static analysis, and evidence capture.
- Documentation and planning on `main`.
- Preparing (not submitting) reviewer packs, declarations, and legal-question packs.

## Related governance sources

- [Owner Approvals](OWNER_APPROVALS.md) · [Legal Pending](LEGAL_PENDING.md) · [Decision Ledger](DECISION_LEDGER.md)
- [Agent Execution & Test Evidence Contract](AGENT_EXECUTION_AND_TEST_EVIDENCE.md)
- [Separate Deployment & Play Release Plan](DEPLOYMENT_AND_PLAY_RELEASE_PLAN_SEPARATE_2026-10-28.md)
