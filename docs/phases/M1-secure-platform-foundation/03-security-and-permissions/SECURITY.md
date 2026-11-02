# Security Reporting & Researcher Handoff — Madalasa–Alarka

> **Document control:** M1 / 03-security-and-permissions · Proposed owner: Security + Android/backend (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

**Document ID: MA-SEC-REPORT-002 · Reviewed 2026-10-27 · State: DRAFT operational companion / NOT an independent vulnerability reporting policy.**

**Authoritative external policy:** [repository root SECURITY.md](../../../../SECURITY.md). This file is a project documentation copy/reconciliation of the uploaded \`SECURITY.md\` intended for use by developers, reviewers and incident responders. If wording differs, the **root policy controls** and the owner must resolve the inconsistency before publication.

## 1. Current supported scope

- Repository: \`methakon/Madalasa-Alarka\`; supported design/CI branch: **\`main\`**, not a released Android application or live service.
- Current runnable evidence: Python standard-library M1 11-operation OpenAPI structural validation, PostgreSQL 16 synthetic SQL migration and two-family/child-scope isolation test. Future Drogon backend, Android Alarka/Madalasa, 48-hour GPS buffer, PostGIS durable inbox, media and case-scoped admin console are **design only**, not a production attack surface.
- **No real children's data** may be used to demonstrate a bug. India/Google Play legal and release gates remain NO-GO. An Android permission grant never allows secret microphone/camera use.

## 2. How to make a confidential report

**Do not** disclose an exploitable report, API secret, child location, identity, media or credentials in a public GitHub issue/PR/comment.

1. Preferred when available: GitHub repository **Security → Advisories → Report a vulnerability**; repository owner must verify that private reporting is enabled. No claim is made that the control is currently available.
2. A verified private security email/contact method must be published by the owner. The uploaded draft contained **[SECURITY CONTACT EMAIL]** and **[ADD PGP KEY IF USED]** placeholders; these are **not functioning endpoints**. Do **not** invent a contact address or email a guessed mailbox.
3. If no confidential intake exists, this is a **pre-pilot release blocker**; the owner must configure a protected channel before encouraging external researchers to share sensitive findings.

Recommended report structure: affected component and commit/build; prerequisites; proof using synthetic accounts only; expected vs actual behavior; confidentiality/integrity/availability impact; which child/family scopes could be affected; relevant non-sensitive request/correlation IDs; mitigation recommendation. Use sanitized proof, not raw customer data.

## 3. Response targets proposed in the uploaded draft (not current promises)

| Workflow | Uploaded draft's proposed target | Status |
|---|---|---|
| Acknowledge report | 3 business days | **Owner staffing and confidential channel not verified; proposal only** |
| Initial triage/severity | 7 days | Proposal only; immediate escalation required for suspected child harm |
| Researcher updates | Every 14 days | Proposal only |
| Critical remediation | Target 7 days | Case-specific risk and practical availability; no guarantee |
| High/Medium/Low | Draft 30/60/90 days | Proposal only, not contractual SLA |
| Coordinated disclosure | 90 days suggested | Requires agreement with reporter, legal/custody safety review and emergency exception |

**Important:** CERT-In-covered incident reporting **within six hours** and future applicable DPDP breach notice deadlines are separate, potentially much shorter legal obligations. Researcher disclosure timelines must **never override** incident response clocks; see [MA-IR-001](../../M8-operational-readiness/02-operations-and-support/INCIDENT_AND_BREACH_RESPONSE_PROCEDURE.md).

## 4. Research scope and safeguards

**In scope once implemented:** child/guardian authorization (including wrong-child and cross-family), tokens, PostgreSQL RLS, offline deleted-device re-ingestion, Postgres inbox WAL/backups, Android-grant status truthfulness, persistent monitoring notifications/indicators, code signing, parent-local-save metadata integrity, admin case scoped autocomplete and read-audit, CI/secret leaks and published documentation with unsafe permission guidance.

**Out of scope unless separately authorized:** volumetric denial-of-service/load tests, attacks on unrelated vendors, social engineering, physical intrusion, real family or child account probing, attempted covert capture, third-party private-app file extraction, and exploitation that could expose any actual child's GPS, media, identity or private files.

Safe-harbor intentions (from uploaded draft): good-faith reports using only your own synthetic accounts/devices; stop immediately if personal child data appears; do not download or reproduce it; no harm/degradation; privately notify through confirmed channel. **This companion cannot itself promise a binding legal safe harbor, compensation, or exemption from third-party law**—the root owner policy and qualified counsel must approve operative language.

## 5. Additional commitments required before real-data use

- [ ] Assign an accountable response/security contact and backup, enable tested private vulnerability intake and encrypted communication procedure.
- [ ] Confirm who owns incident leadership outside business hours and secure response evidence locations.
- [ ] Complete independent review of child IDOR, device/guardian pairing, admin case access, release/offline GPS intake and account deletion/replay risks.
- [ ] Complete signing and dependency/SBOM/secret scanning, physical Android permission/indicator tests and production recovery rehearsals.
- [ ] Establish reporter coordination/credit/non-retaliation language and realistic response targets with owner/counsel sign-off.
- [ ] Implement targeted tests: T-CAP-01…24, T-ING-01…24, T-AUD-01…22, T-ADM-01…14 and M1 tenant-isolation CI.
- [ ] Keep Play/India child-data restrictions, persistent Alarka identity and lawful guardian authority as independent release gates.

See [STRIDE model](THREAT_MODEL_STRIDE.md), [Incident Procedure](../../M8-operational-readiness/02-operations-and-support/INCIDENT_AND_BREACH_RESPONSE_PROCEDURE.md), [Root Security Policy](../../../../SECURITY.md), [Release Checklist](../../M9-play-release/03-release-gates/DEPLOYMENT_RELEASE_READINESS_CHECKLIST.md).

**No vulnerability triage team, email, PGP key, bug bounty or live service is verified by this document.**
