## Pre-work synchronization evidence (MANDATORY for all workstreams)

- [ ] Before starting/resuming this segment, executed `bash docs/tools/sync_work_branch.sh <current-branch>` (safely fetched and synchronized **both** origin/main and origin/dev; current branch fast-forward-pulled).
- [ ] Repeated the same sync immediately before proposing/updating this code PR; `dev` already includes latest `main`.
- [ ] Source `origin/main` SHA: **[record]**; `origin/dev` SHA: **[record]**; work branch SHA: **[record]**; UTC run time: **[record]**.
- [ ] Conflicts resolved without force/discard; all affected tests rerun. Note commands, exits and CI URLs; if blocked, stop the PR.

## Mandatory branch-route checkpoint

- [ ] Source is `api`, `parent`, `child` or `admin-web`; base is `dev`; OR this is the cleared promotion `dev` → `main`.
- [ ] Owner-approved temporary branch has recorded authorization and `owner-approved-temporary` label; or is the preserved legacy PostgreSQL reconciliation branch.
- [ ] **No canonical documentation changes** (`docs/**`, `AGENTS.md`, root governance Markdown) in code PR; docs/plans are updated separately on `main`.
- [ ] `dev` validation included integrated tests on the cumulative candidate tree, then final `main` verification is tracked as a separate gate.
- [ ] Explicit merge and branch-retirement decision: permanent five work branches survive; temporary branches deleted after unique work is proven on `main`.
- [ ] Read the [current owner branch policy](../docs/phases/M1-secure-platform-foundation/02-development-process/BRANCHING_VERSIONING_AND_RELEASE_PROCESS.md) (older ad-hoc branch instructions superseded).

## Summary
Describe the change, target requirement/ADR ID and expected safe user outcome.

## Scope and reality
- [ ] Feature implementation / bug fix / docs only clearly identified
- [ ] Does not imply unimplemented Android, C++ or media capability exists
- [ ] No real child/family identifiers, GPS or media in code, tests, logs or screenshots

## Verification
- [ ] Existing M1 OpenAPI structural lint checked when relevant
- [ ] Synthetic PostgreSQL family/child RLS tests checked when relevant
- [ ] Android/C++ unit/integration tests run if projects exist
- [ ] Explicitly note tests NOT RUN and why
- [ ] Figma and documentation/API/SQL traceability updated as needed

## Security, privacy, compatibility
- [ ] Scope and permission gates maintained; cross-family/same-family-negative tests included
- [ ] Indian DPDP / Google Play/Families release gates considered
- [ ] Signing keys and credentials not committed
- [ ] New external dependencies and licenses entered into dependency/SBOM register
- [ ] Backup, incident response and retention/deletion implications noted

## Approval
Identify backend, Android, security/privacy and owner review as required by CODEOWNERS and branch rules. No automatic claim of signoff.
