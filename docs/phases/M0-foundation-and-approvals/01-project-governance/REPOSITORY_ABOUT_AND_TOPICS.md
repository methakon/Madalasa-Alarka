# GitHub About / Description and Topics — Owner Update Checklist

> **Document control:** M0 / 01-project-governance · Proposed owner: Project owner (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

**Verified:** Repository methakon/Madalasa-Alarka currently has an empty About description/topics section as reported. GitHub connector in this session exposes repository READ and Git WRITE for files, but **no repository metadata edit method**. This document provides ready-to-apply values; it does not imply About was updated.

**Suggested description:**
`Madalasa–Alarka: privacy- and safety-first Android parental device companion and guardian app (design/M1 tests; not production-ready).`

**Suggested topics:** `android`, `kotlin`, `cpp20`, `drogon`, `postgresql`, `postgis`, `parental-controls`, `privacy-by-design`, `device-management`, `documentation`.

**Suggested website:** Leave blank until an approved, hosted privacy/terms page exists. Do not set a dead placeholder URL.

**Owner actions:** Open GitHub repo → About gear icon → paste description/topics → save. Enable Discussions/Issues only after confidential vulnerability reporting, Code of Conduct enforcement contact, support workflow and user-data handling are ready. Enable branch protection and require owners/tests. Review public visibility because this is a child-safety project, even if the application is not released.

**Avoid terms implying verified deployed capabilities:** "live child tracking", "stealth mic", "automatic hidden video", "Play-approved", "DPDP-compliant", "production SaaS"; none are proven. Update only after implementation and audits.

## 2026-10-27 verified capability and exact owner UI action

The connected GitHub repository metadata for `methakon/Madalasa-Alarka` returns `permissions.admin=false`, `permissions.maintain=false`, `permissions.push=true`. The available GitHub integration can update repository **files**, not repository About description/topics or repository rulesets. The About state was not modified during this project checklist work; owner must inspect the live UI and apply the earlier suggested description/topics. In GitHub open `https://github.com/methakon/Madalasa-Alarka`, click the **About** gear, enter the non-production description and topics shown above, and save. In Settings → Security, verify private vulnerability reporting; in Settings → Rules → Rulesets (or Branches), require appropriate PR reviews/status checks for `main`. These settings need owner/admin access. The documentation files alone do not activate them.
