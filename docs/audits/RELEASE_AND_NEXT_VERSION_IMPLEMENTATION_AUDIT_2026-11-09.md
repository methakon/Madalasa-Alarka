# Madalasa–Alarka: release and next-full-version implementation audit

**Audit date:** 2026-11-09 (Asia/Kolkata)  
**Evidence state:** GITHUB_SOURCE_VERIFIED + OWNER/ANTIGRAVITY_REPORTED; **not** an independent SSH, Play Console or device replay.  
**Decision:** Free V1 synthetic/adult-owned Internal Testing MAY continue under the previously granted owner authorization. **No real-minor collection, public production release, monitoring activation or payments are approved by this audit.**

## 1. Method, authority and snapshot

This is a source-to-evidence reconciliation, not a blanket certification. Read live GitHub `main` and `dev`, PR #60, Issues #32/#33/#42/#46/#48/#52/#54/#57, Android application/DI/manifest and release profile sources, the 2026-10-28 Figma/API/DB audit, the 108-child free-first roadmap, M9 release gates, and the canonical branch policy. Compared owner-provided signing/Play screenshots and Antigravity reports with committed source. No local device, local AAB, Play account, running service or signing file was accessed from this session.

**GitHub snapshot (before this document commit):**
- Repo: https://github.com/methakon/Madalasa-Alarka
- `main`: `b9a704162b19d64dd9db192e4fb5d5ff9ebc0f4c`
- `dev` / PR #60 head: `470fc3e1ecd01f2d9c2eafee4329224737990f48`
- `main...dev`: **396 commits ahead, 0 behind, 187 changed files** at inspection; numbers change with later commits.
- [PR #60](https://github.com/methakon/Madalasa-Alarka/pull/60) is **OPEN, NOT MERGED**, `dev → main`. Its 393-commit/185-file prose is a historical snapshot, not the current difference.
- Code/governance: `api`, `parent`, `child`, `admin-web` → reviewed `dev` → reviewed `main`; canonical `docs/**` only on `main`. Follow `AGENTS.md` and `docs/phases/M1-secure-platform-foundation/02-development-process/BRANCHING_VERSIONING_AND_RELEASE_PROCESS.md`. No automatic merge/force push.

**Evidence tags** used below: **S** = source inspected in GitHub; **R** = worker/owner-reported executed evidence, not independently replayed; **D** = draft specification/design only; **B** = blocked or missing evidence. Source presence, CI success, staging success and Play-delivered verification are different gates.

## 2. Audited capability and release matrix

| Area | Source or evidence | Current classification | Missing acceptance |
|---|---|---|---|
| Android launcher icons and distinct Queen/Prince artwork | Manifests and `mipmap-anydpi-v26` adaptive XML source S; icon audit and device captures R | S/R — configured and reported correct | Confirm store-listing icon/feature graphics in *both* actual Play listings; source assets alone are insufficient |
| Madalasa Parent identity | `android/madalasa/build.gradle.kts` on `dev` specifies `in.berhampore.madalasa`, v0.1.0, versionCode 2; `parent` workstream branch was older and still declared `.synthetic` at inspection | S — integrated configuration; signed artifact R | Sync workstream; inspect actual signed AAB and Play-delivered APK; confirm Android OAuth package + Google Play app-signing SHA-1; real login/session on Play build |
| Alarka Child identity | `android/alarka/build.gradle.kts` on `dev` specifies `in.berhampore.alarka`, v0.1.0, versionCode 1; `child` workstream branch older | S; signed artifact R | Verify uploaded AAB and Play-installed package/signature/version; do not reuse an accepted version code |
| Android build/lint/signing | Antigravity reports unit/lint success, Madalasa `madalasa-upload.p12`, Alarka dedicated `alarka-upload.p12` and `jarsigner` PASS | R — plausible but exact signed binaries not inspected here | Artifact source SHA, build arguments, SHA256, signing and installed build manifest captured together |
| Play Internal Testing | Alarka user-provided opt-in URL and Play Console screenshots show internal testing progression; parent signed AAB reported | Owner-supplied Play evidence; parent distribution unverified | Record Play Console final release statuses, parent opt-in link, adult tester access and Play-installed phone tests |
| Parent Google OAuth/session | `GoogleParentHandoff.kt` uses Android Credential Manager, fresh nonce, server exchange; staging hardware E2E reported at Issue #52 | S/R | Re-test production package and Play signing certificate; build must contain *correct public Web client ID and HTTPS API origin* |
| Child pairing | `PairingScreen.kt` supports 10-character one-time code, backend enrollment/Keystore service source present; backend V2 issuer migrated | S/R for prior testing; QR is D | QR issuance/claim/scan/poll is **not** proven live; negative duplicate, expiry, revocation and consent checks |
| Manual SOS | `ChildSosService.kt`, encrypted `PersistentSosOutbox`, guardian API/ACK code; physical two-handset same-event, offline manual retry and revoke R in Issue #52 | S/R for tested debug/synthetic hardware | Repeat same-event acceptance with both **Play-delivered** production packages; document best-effort delivery and manual retry limitations |
| FREE_ONLY & price preview | `backend/src/release_profile.h`, parent premium preview and contract; future ₹99/₹999 shown, checkout disabled | S/R limited | Runtime negative purchase/entitlement proofs for exact release builds; no live gateway or premium trial |
| 108 child admission / FIFO queue | `0023_free_first_108_child_admission.sql`, DB tests and rollout roadmap | S; synthetic tests reported | Confirm 108/109 concurrency on actual deployed stack and waitlisted no-pair/no-tracking behavior; not a scale or SLA certification |
| Location/history | `free_location_reads.h` and parent read client; child location release flag defaults false and release manifest has no location grants | S + D — **release-gated** | No live child monitoring authorization. Separate Android/Play/legal approval, permissions, observable disclosure, backend durable ingestion, battery/OEM and retention/restore tests |
| Privacy/erasure/custody | Migrations `0028_child_erasure_dependency_order.sql`, `0029_guardian_revocation_and_invite_validation.sql`, gateway logic | S — partial controls | Signed category TTL, guardian/custody authority rules, external-store/backup erasure propagation, no resurrection after restore |
| Database/security | `0023`–`0031`, forced RLS and limited roles; worker reports 136/136 forced RLS, Neon verify-full, two-family denied tests | S/R | Independently repeat scope/role/RLS/expiry on release candidate plus backup/restore failure modes |
| x402 admin/API | Nginx templates, CSP/HSTS PRs #58/#59, bounded 14/14 baseline and mail continuity reported | S/R | Incident/on-call capacity, backups/recovery and operational alerts for real pilot; keep DB off 954 MiB mail VM |
| Admin web / support | OIDC/CSRF/RBAC/logout implementation and tests | S/R | Live end-to-end support/owner roles, governance, audit logging, privacy/contact obligations |
| Figma ↔ implementation | 187 Figma screen/state records, 171 draft OpenAPI operations, 120 conceptual table rows in post-remediation audit | D + some S; **not** 187 shipped screens | Per-screen UI route → code → API → policy → tests evidence mapping, especially QR, consent, location, privacy, onboarding and admin |
| Billing, media, usage, DPC | Specifications and selective scaffolding | D/B — not release-cleared | Independent legal/OS/Play/security/merchant gates; feature flags OFF until authorized |

## 3. P0 release-candidate discrepancies requiring resolution

**P0-A — Built-time public configuration cannot be inferred from successful signing.** The current parent Gradle file obtains `madalasaGoogleWebClientId` / `madalasaApiOrigin` from flags or environment with **empty-string defaults**. `DefaultAppContainer` uses an `UnavailableMadalasaApiClient` for a non-debuggable build with no valid origin; `GoogleParentConfiguration.isConfigured()` also requires a Web client ID. Child Gradle `alarkaApiOrigin` likewise defaults to empty; `DefaultChildAppContainer` switches to unavailable enrollment and unauthenticated privacy; its SOS fallback is synthetic/local when no origin is set. **This is intentional fail-closed behavior, not proven broken binary behavior**, but there is no verified manifest/resource dump from the uploaded Play AAB documenting those exact values. The risk is signed, Play-installable but nonfunctional two-app connectivity. **Action:** [Issue #61](https://github.com/methakon/Madalasa-Alarka/issues/61) verifies actual AAB and Play-installed resources, public audience/URL and E2E without publishing tokens.

**P0-B — Developer branch synchronization.** At review, `dev` contained production package settings for both Android apps; the permanent `parent` and `child` workstream branch copies of their Gradle files remained at older `.synthetic` defaults. Future implementation on an unsynchronized branch can accidentally regress release identity, icons or signing. Execute clean preflight `bash docs/tools/sync_work_branch.sh parent` / `child` with branch-owner coordination, inspect merges, test and submit reviewed PRs. This audit cannot run that local preflight.

**P0-C — PR #60 is not an approval artifact.** An open 187-file/396-commit code change requires review by scope, source-test provenance and merged-source rebuild. Some text in its description (393 commits / 185 files, HSTS durations) predates current source; reviewers must compare actual head. Do **not** merge automatically or mark older implementation tests as executed on a newly merged main.

**P0-D — Play-distributed adult synthetic acceptance.** Earlier E2E on Android 9 and 11 was conducted with synthetic/debug packages. Production-signing SHA, OAuth Android client registration, actual Play-installed app build and cross-app negative cases remain separate acceptance. Alarka user-supplied internal opt-in link is not proof that the parent release was distributed.

**P0-E — Operating/legal gates.** Separate signed verification of data purposes, parental authority, grievance/support, retention and Play declarations required for any real-minor monitoring. Do not interpret an internal testing release or an owner upload key as a real-child deployment waiver.

## 4. Documentation drift and corrections

- `docs/roadmap/LOCAL_TASK_EXECUTION_STATUS.json` is dated **2026-11-02** and lists **128 PASS / 134 NOT_STARTED**. It should not be blindly advanced: the statuses reflect their historical execution task graph, while later 2026-11-08 evidence belongs to separately scoped tests. Refresh only task IDs with commands/exit codes, commit SHA and reproducible evidence; use a dated addendum for cross-cutting releases.
- `docs/phases/M9-play-release/03-release-gates/DEPLOYMENT_RELEASE_READINESS_CHECKLIST.md` mixes historic 2026-10-30 PR #9 statements with newer feature evidence. Keep old snapshots as history, add a current dated note, and **do not** mark legal/Play/real-child gates signed.
- `docs/audits/POST_REMEDIATION_SCREEN_API_DB_REPORT_2026-10-28.md` intentionally records documentation/API design rather than code. Its 171 proposed operations and 187 screen records **must not** be represented as implemented route counts.
- Correct SQL migration citations: `0028_child_erasure_dependency_order.sql` and `0029_guardian_revocation_and_invite_validation.sql` are the actual names. Avoid the two inaccurate titles in prior Antigravity release-candidate prose.
- [Issue #57](https://github.com/methakon/Madalasa-Alarka/issues/57) is closed; [#52](https://github.com/methakon/Madalasa-Alarka/issues/52) and [#54](https://github.com/methakon/Madalasa-Alarka/issues/54) are still open at inspection despite worker-reported evidence. Respect each issue's acceptance/close criteria; don't close automatically.
- Old research assumptions about availability of QR, GPS monitoring and full media cannot override `FREE_ONLY`, current release manifests or policy gates.

## 5. Recommended staged exit decisions

1. **Free V1 Internal Testing:** continue with synthetic adult fixtures; resolve Issue #61 and capture parent/child Play-installed acceptance. This is a test track, not a public launch.
2. **Next full-version implementation:** execute the dependency-ordered [implementation and acceptance plan](../roadmap/NEXT_FULL_VERSION_IMPLEMENTATION_AND_ACCEPTANCE_2026-11-09.md) through the existing workstreams, not all 171 draft routes at once.
3. **M8/M9:** update release evidence, backup/restore incident process, on-call, legal/Play and data retention. Actual external signoff remains blocked until obtained.
4. **Promotion:** PR #60 requires owner review, exact-head CI and integrated tests before a controlled `dev → main` merge. No automatic production deployment.

## 6. References

- [PR #60 — integrated release candidate](https://github.com/methakon/Madalasa-Alarka/pull/60), [Issue #61 — build proof](https://github.com/methakon/Madalasa-Alarka/issues/61), [Issues #32](https://github.com/methakon/Madalasa-Alarka/issues/32), [#33](https://github.com/methakon/Madalasa-Alarka/issues/33), [#42](https://github.com/methakon/Madalasa-Alarka/issues/42), [#52](https://github.com/methakon/Madalasa-Alarka/issues/52), [#54](https://github.com/methakon/Madalasa-Alarka/issues/54), [#57](https://github.com/methakon/Madalasa-Alarka/issues/57).
- [Free-first roadmap](../roadmap/FREE_FIRST_108_CHILD_RELEASE_AND_WAITLIST_2026-11-03.md), [M9 gate](../phases/M9-play-release/03-release-gates/DEPLOYMENT_RELEASE_READINESS_CHECKLIST.md), [Figma/API/DB audit](POST_REMEDIATION_SCREEN_API_DB_REPORT_2026-10-28.md), [branch governance](../phases/M1-secure-platform-foundation/02-development-process/BRANCHING_VERSIONING_AND_RELEASE_PROCESS.md).
- Operator evidence: Issue #52 comment 6712011065, Issue #57 comment 6712692976, Issue #42 comment 6713465168 and owner-provided Alarka/Madalasa AAB signing statements. Their precise binary/runtime observations remain **R**, not independently replayed by this audit.
