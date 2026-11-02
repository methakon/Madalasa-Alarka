# Formal STRIDE Threat Model — Madalasa–Alarka

> **Document control:** M1 / 03-security-and-permissions · Proposed owner: Security + Android/backend (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

**Document:** MA-SEC-STRIDE-001; **status:** DOCUMENTED_REVIEW_PENDING threat model, updated 2026-10-30; not a penetration-test or legal approval. PR9 source/CI and fresh local M1 SQL evidence now exist, but no production child data is permitted. The [pending-identity acceptance queue](../../M8-operational-readiness/03-quality-and-evidence/TEST_STRATEGY_UNIT_INTEGRATION_LOAD_SECURITY.md#pending-identity-security-acceptance-queue--2026-10-30) identifies what is actually tested versus merely planned.

## Scope and data-flow trust boundaries

1. **Alarka child Android/Wear OS**: public hardware checks, Android granted permission states, location/app usage, encrypted local 48h-capacity queue; possible parent-device pairing. Boundary: OS runtime permission and physically accessible device, can be rooted/stolen/force-stopped.
2. **Madalasa parent Android**: authenticated guardian and child-specific scopes, map/history, device actions; cannot grant Android permissions remotely. Parent device also subject to theft/insecure local media handling.
3. **Network/FCM**: untrusted networks, queued/offline delivery, no guarantee of notification receipt.
4. **Drogon API**: device and parent tokens, family/child authorization, rate/size limits, idempotent command and GPS event handling.
5. **PostgreSQL**: forced M1 RLS, future geospatial inbox (Tx A), event dedup, raw GPS, reconstruction outbox (Tx B), derived routes/usage and retention/tombstones.
6. **Admin console**: independent audience+MFA, case-bound purposes and time-limited named-child grants; admin searches/autocomplete audited, general support aggregated only.
7. **Media pathways**: P3 research OFF; if released under law, WebRTC/TURN transient encrypted transport and optional parent-local media; no VPS media archive.
8. **OCI/Google/CI/vendors**: code signing, provisioning and external processors; backups/WAL/restore and incident logs.

## STRIDE table

| STRIDE | Threat example | Consequence | Proposed defenses / negative tests |
|---|---|---|---|
| **S**poofing | Parent forges Alarka OS permission or GPS signed event | False status/location; stalking | Keystore device-bound PoP, enrollment generation, stable event ID, authenticated source, replay test |
| **S**poofing | Attacker registers as unrelated guardian/abusive ex-partner | Unauthorized monitoring | Verifiable guardian authority, revocation/dispute freeze, no SMS-only trust |
| **T**ampering | Same GPS batch ID resent with altered bytes | History corruption | device+batch unique key/digest; 409 conflicting digest; quarantine |
| **T**ampering | Worker reuses stale SKIP LOCKED lease | Lost/duplicate location, false 202 | atomic durable inbox ACK, lease epoch fencing, Tx B dedup/outbox/inbox processed |
| **R**epudiation | Guardian claims not to have requested camera/usage | Dispute/lack of audit | Minimized signed command metadata, actor/scoped audit; no media files; no false success receipt |
| **R**epudiation | Admin exports child activity without trace | Insider stalking | Separate fail-closed detailed-read audit, step-up MFA and case expiry |
| **I**nformation disclosure | Wrong family or sibling scope can read child GPS | Child physical safety danger | API scope + RLS, cross-family and same-family ungranted-child tests, cache isolation |
| **I**nformation disclosure | Android local queue, inbox, backup or metrics leak GPS | Routes/home/school exposed | Actual local encryption, TLS, encrypted backups, minimal HTTP/ops logs, DB least privilege, shortened TTL |
| **D**enial of service | 100k phones reconnect after 48h outage | Queue/disk full, parent stale map | Bounded 100–500 point batches, per-tenant quotas, 429/503 Retry-After, jitter, worker pressure thresholds |
| **D**enial of service | Force-stop/OS throttling blocks Alarka | No live location, stale data | Visible freshness and offline action; do not promise invisible persistent monitoring |
| **E**levation of privilege | Superuser/root operator queries children's media metadata | Insider access abuse | Admin role alone insufficient, case-purpose/MFA and audit, no direct inbox browser |
| **E**levation of privilege | Legacy Android device admin mistaken for Device Owner | Unexpected camera/mic controls | Genuine DPC provisioning check, typed FGS, Play review, Android indicators and OS session consent |
| **I/T** supply chain | Poisoned Gradle/C++ transitive dep or signing secret leak | Malicious APK/backend | Pinned deps, SBOM, SAST, secret scan, signing key separation, CI provenance |

## Abuse-case escalation
Consider separated/custodial disputes, coercive parent, abusive admin, child in immediate physical danger, phone/watch disagreeing about child location, false "live" map pins and abusive use of precision/history. Human review must be safe and not automatically reveal reports to an accused guardian.

## Mandatory controls/test traceability
- M1 synthetic tenant RLS and limited createFamily HTTP tests exist on PR9; real ParentOIDC validation, the full API, mobile runtime and penetration-test evidence **do not**. `ap_m1_api` is NOBYPASSRLS; the NOLOGIN `ap_m1_auth` definer role intentionally BYPASSRLS and its grants/ownership/search paths must be reviewed, not described as an ordinary runtime role.
- T-ING-01…24 for offline replay, inbox ACK, leases and deletion resurrection; T-CAP-01…24 for permission/report integrity; T-AUD-01…22/T-ADM-01…14 for media/admin audit; independent Android device/FGS tests.
- No raw child payloads in CI, GitHub issues, crash reports or general telemetry.
- Regular scenario re-review on new permissions, vendor/location region, child-age transitions and third-party media changes.
- Stop conditions: cross-family access, undisclosed data collection, unapproved child behavioural tracking, no breach notification owner, missing signing recovery or restore test.

### Review and decisions
Threat owners, risk acceptance, pen tester and final deployment region **UNASSIGNED**. Unmitigated child GPS and usage risks remain CRITICAL; design documents are not evidence that controls work.

## 2026-10-30 review additions

- **Spoofing:** payment/publisher identity verification is not parent authentication, adult age verification, or lawful guardian authority. Test each boundary separately. ParentOIDC is a known release blocker even while its default-deny seam is safe for local development.
- **Tampering/privilege:** historical M1 and local V2 use overlapping migration numbers and incompatible grant models. Do not concatenate SQL alphabetically; use the existing namespaced lineage solution and separately reconcile new family-provisioning migration before integration.
- **Disclosure:** screen capture must stop on banking/payment/financial apps and when foreground classification is unknown; honoring FLAG_SECURE alone is insufficient. No privileged API bypass is an approved mitigation. Backend OS/capability/consent freshness gates precede command acceptance; unproven device status stays unknown.
- **Availability:** high-latency OIDC/JWKS, DB pool starvation, unlimited new principal/family requests and expired credential checks after lock waits require bounded failure tests. Synthetic eight-request idempotency concurrency is not production rate limiting or load certification.
- **Recovery:** a local encrypted backup and separately stored secret on the same host do not establish offsite disaster recovery. Keep restore quarantine and deletion-suppression checks separate from a simple backup-file checksum.
