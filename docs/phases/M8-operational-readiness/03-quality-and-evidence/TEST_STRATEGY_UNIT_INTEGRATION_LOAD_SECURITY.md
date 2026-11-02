# Test Strategy — Unit, Integration, Android, Load, Security and Recovery

> **Document control:** M8 / 03-quality-and-evidence · Proposed owner: QA + security (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

**Status (2026-10-30):** DOCUMENTED_REVIEW_PENDING QA strategy, not whole-product acceptance. PR #9 at `c693899e4b411cbadd1639f0bcb642844af50ea9` has verified hosted C++ build/CTest, synthetic HTTP family provisioning and PostgreSQL 16 contract/isolation/purge checks. Its SQL gates were independently reproduced locally on PostgreSQL 16.15. ParentOIDC and Android/device tests remain unimplemented or unverified. See the [detailed PR review](../../M1-secure-platform-foundation/02-development-process/M1_STACK_PR9_REVIEW_2026-10-30.md). Google Payments verification does not block this work.

## Test pyramid
| Level | Coverage and tooling (planned) | Mandatory release evidence |
|---|---|---|
| Unit: Kotlin | Permission state reducer, location queue/TTL, media reason mapping, UsageStats interval reconstruction, date/cursor logic | Deterministic synthetic tests, Android fake OS boundaries |
| Unit: C++20 | Batch parsing, time/lat/lon normalization, child scope, digest/replay, statuses, lease fencing, trip simplification | CTest/gtest or approved C++ harness, sanitizers |
| DB/integration | M1 forced RLS; ungranted sibling, revoke; Tx A inbox ACK, Tx B bulk insert/rollback/outbox; retention/tombstones | Real disposable Postgres 16/PostGIS when relevant, seeded synthetic families |
| Android device/OEM | API29–36+ Pixel/Samsung/OEM, separate foreground/background location, Android 11+ one-time permissions, FGS/notifications, managed vs ordinary install; watch phone-proxied GPS | Build/version and screenshots/logs without child data |
| API/E2E | Signed Android enrollment, child-scoped reads, parent UI stale/offline, app usage quality, SOS status, admin case/search auditing | Reproducible synthetic fixture/signed build/test account |
| Load/soak | 1k/10k/100k simulated devices, 48h backlog reconnection, GPS 1–2min upload target when eligible, query p95, WAL/IOPS, direct bulk vs inbox | Measured environment sizing, dashboards, reproducible seed |
| Security | STRIDE, SAST/SCA/SBOM, fuzz malformed JSON, BOLA/IDOR, mobile MASVS, key handling, scoped admin tests and penetration tests | Independent reviewed findings and remediations |
| Operations | Worker restart, disk-full, postgres failover, backup restore RPO/RTO, inbox 202 receipt/Tx B loss/dedup, deletion after restore | Dated evidence file, SQL counts, RPO/RTO result and responsible signature |
| Legal/policy | Explicit features-off tests for under-18 India/Play blocked functions; reviewer material validity | Counsel and Play decision, release signoff |

## Quality gates
Security blocker when cross-family child data leaks, precise GPS revealed to ungranted sibling, unsupported covert capture, admin case bypass, invalid 202 before durable commit, deleted child data resurrected from 48h local queue, insecure keys, missing visible monitoring. Don't treat flaky tests as passed. Pin OS emulator snapshots and record real device OS/OEM.

**Evidence format:** test ID, requirement ID, commit SHA, environment build OS/device, synthetic data seed, exact commands, expected and actual, pass/fail/blocked, screenshots/logs (no PII), issue link, reviewer. Rate-limit and fuzz test in isolated env only.

## CI growth
Existing `.github/workflows/m1-contract-and-tenant.yml` stays intact. Add per-PR C++20 formatting/ASAN, Kotlin lint/test, full OpenAPI validator, secret scanning, vulnerability and SBOM checks **after corresponding projects/manifests exist**. Add dedicated staging workflow for migrations/backups and nightly synthetic load; no prod secret in fork PRs. All new T-ING/T-CAP/T-ADM/T-AUD test IDs are **planned NOT_TESTED**; never infer implementation from test-case files.

## Release evidence
Publish per-release test summary and explicitly enumerate not run tests, risk exceptions approved by owner/security/legal (none auto-approved), Play declarations, signed artifact hash, backup restore evidence, rollout and rollback proof. No real-minor pilot before gates.

## Pending-identity security acceptance queue — 2026-10-30

Source: owner instruction of 2026-10-30, PR #9 source/CI and the existing T-CAP/T-ING/T-AUD/T-ADM catalogs. Decision owner: project owner; test implementation/release approval remains separate. These IDs add cross-cutting evidence requirements, not features or passing test counts. No real reviewer accounts, OAuth registrations or credentials are created by this queue.

| ID | Threat/control and required negative cases | Current evidence / state | Next executable gate |
|---|---|---|---|
| T-PEND-01 | Forced RLS, restricted runtime role, no PUBLIC function/table access, fixed definer search path; prove detector rejects deliberate drift | VERIFIED locally against PR9 M1 schema: [catalog acceptance SQL](../../../../backend/tests/m1_security_catalog_acceptance.sql), with three rollback-only negative controls; refuses non-review database | Re-run after any migration/ACL change; not transferable to V2 by assumption |
| T-PEND-02 | ParentOIDC signature, allowed algorithm, issuer, audience/authorized party, expiry/not-before, subject, nonce flow, malformed/duplicate claims, unknown/rotated JWKS, cache outage; never trust a synthetic header in deployable build | PROPOSED; real validator absent. Hosted build excludes synthetic authenticator; default denies authentication | Implement validator behind existing narrow interface, mocked provider/JWKS tests, then separately authorized real-provider acceptance |
| T-PEND-03 | Child-specific guardian authority: wrong-family and ungranted sibling, expired/revoked invite, custody dispute, revocation epoch/cache/worker race | M1 local tenant SQL passes; blended-family V2 remains separate branch evidence, not PR9 coverage | Compare M1 membership-linked grants with approved V2 ADR before real access |
| T-PEND-04 | Device renewal/revocation: expired token/challenge, transaction-start versus real elapsed deadline, waits on row locks, proof replay, stale key, rollback/commit and issuance-window edges | Existing M1 credential/enrollment SQL VERIFIED locally; wall-clock/lock expiry requires additional targeted review, not presumed covered | Add actual elapsed-time regressions without rewriting published migrations |
| T-PEND-05 | Account deletion: revoke sessions/commands before erase, delete raw/derived/inbox/cache, retained billing/legal holds minimized, deterministic repeated request, old offline replay | PR9 has no complete deletion implementation; V2 local historical evidence is distinct | Synthetic deletion pipeline and tombstone tests before integration; owner/counsel approve category retention |
| T-PEND-06 | Retention/purge: expired versus recent, per-category TTL, batch FK ordering, concurrent worker, bounded lock wait, restricted purge role, nonzero failure and retry | PR9 credential/idempotency purge and concurrency scripts VERIFIED locally; does not cover location/usage/account purge | Link each physical category to an approved TTL and executable job; no TTL invented from six-hour free visibility |
| T-PEND-07 | Backup/recovery: corrupt/incomplete backup, wrong key, restore quarantine, replay erasure ledger and revocation before runtime opens, RPO/RTO, independently stored copy | PR9 CI does not test backup/recovery. Earlier local V2 and upload-key drills are scoped historical results, not offsite/production acceptance | Authorized synthetic restore on separate destination; custody and measured recovery review |
| T-PEND-08 | Audit: actor/request/child binding, append-only metadata, no raw tokens/GPS/media, duplicate/failed write, case expiry, fail-closed privileged reads | PROPOSED; no production audit assurance or admin runtime coverage | Narrow test doubles and real disposable DB negative tests; no unrestricted owner/admin child access |
| T-PEND-09 | API abuse: malformed/duplicate JSON, oversized body, idempotency mismatch/replay, simultaneous requests, per-actor/IP rate limits, exhausted DB pool/lock wait, retry envelope | Hosted synthetic createFamily covers parser/idempotency/concurrency; production rate limiting and parser-level >1MiB envelope are gaps | Rate-limit implementation tests plus isolated resource-bound load; test denied auth cannot create principals/families |
| T-PEND-10 | Offline/revocation: Settings revoke, force-stop, process death, stale capability, lost ACK, reboot restrictions, app uninstall | DOCUMENTED_REVIEW_PENDING; no signed Android build/device evidence | Synthetic status reducer cases can be prepared now; physical OS/OEM tests only after separate Android coding authorization |
| T-PEND-11 | Remote-media gate: backend rejects unsupported OS/capability before acceptance, denial/timeout truthful, MediaProjection each session, stop financial/unknown foreground screen, no indicator bypass | DOCUMENTED_REVIEW_PENDING; media release OFF | Versioned capability/permission freshness/consent test matrix; no real media capture in this task |
| T-PEND-12 | Incident response: operator escalation, six-hour CERT-In applicability, evidence clock, containment, minimize child exposure, controller/counsel notice decisions, no secret in public report | DOCUMENTED_REVIEW_PENDING tabletop; not legal signoff or an incident exercise | Synthetic tabletop with named incident lead and counsel; distinguish current law from phased DPDP duties |

Execution records must distinguish LOCAL_EXECUTED, HOSTED_CI, SIMULATED, NOT_EXECUTED and PRODUCTION evidence. A compiled synthetic authenticator never satisfies T-PEND-02. A successful payments identity check would satisfy none of these engineering controls by itself.

The [documentation-inventory verifier](../../../../backend/tests/test_pending_identity_documentation.py) executes eight stdlib tests: all source SRS IDs represented exactly once, 40 supplemental rows, nine required fields, separate 20-item Parent/Child checklists, 18 Data Safety IDs, 13 billing cases and fail-sensitive missing/duplicate/unexpected-row controls. It runs in the documentation workflow. **These are coverage/control tests, not proof that the documented Android APIs, legal interpretations or provider behavior work.**


## 2026-10-31 WebRTC P2P acceptance inventory — design-only / NOT RUN

[MA-P2P-ADR-004](../../P3-deferred-research/01-media-and-administrator-research/P2P_MEDIA_AND_LIVE_LOCATION_TRANSPORT_ARCHITECTURE_2026-10-31.md) defines planned cases **T-P2P-01…12**: cross-child ACL/offer/TURN denial, LAN/STUN/NAT/relay path selection, short-lived TURN security, handover/ICE restart, Android foreground/Doze denial, real mic/camera and MediaProjection/device indicators, protected financial screens, no VPS content storage, high-detail GPS durable-history invariants, and measured 100/500/1000 signaling vs 10/50/100 active stream scenarios. **None has executed**. Each gets exact build SHA, synthetic test identities, Android/OEM/network, observed output, failure reason, measured resources and reviewer evidence. These supplement T-MEDIA-01…18, not replace Android legal/Play release gates. Require cumulative `dev` tests and final actual-`main` commit verification.
