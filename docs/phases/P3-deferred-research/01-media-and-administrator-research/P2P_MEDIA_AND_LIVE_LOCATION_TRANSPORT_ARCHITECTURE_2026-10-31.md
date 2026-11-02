# MA-P2P-ADR-004 — P2P-First Media and Live-Location Transport Architecture

> **Document control:** P3 / media and administrator research. Owner-selected engineering method, 2026-10-31. API/Android/security review pending. **DESIGN ONLY: NOT IMPLEMENTED, NO DEVICE/LOAD TESTS, NO LEGAL OR GOOGLE PLAY APPROVAL.** All real-child media and unapproved high-intensity location features remain **OFF**.

## Decision and scope

Adopt **WebRTC peer connections with ICE, STUN and TURN fallback** for *approved, visible, bounded* Android-to-Android media and interactive live-location sessions. Existing **C++20 Drogon** is the authenticated control/signaling API; PostgreSQL stores scoped session metadata and the authoritative location ingest/history. **Do not develop a full-device VPN** for these app-level features. Neither a custom VPN nor extra QUIC/libp2p/WireGuard fallback chain is needed for the initial P2P implementation. TURN cannot be removed: some mobile carrier/NAT/firewall combinations require the relay and will incur bandwidth/compute costs.

This selects a **transport design**, not permission to record a child, activate hidden mic/camera, take screens silently, or sidestep Android, Indian law or Play review. The [media feasibility/reason contract](MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md) and [media metadata-audit contract](MEDIA_ACTIVITY_AUDIT_LOGGING_AND_REPORTING_2026.md) remain binding. Research FR-009/FR-010 stays outside the approved first Play release.

This decision draws on the two owner-uploaded PDFs: *C++ VPS Control Server for Secure Direct Android-to-Android P2P Connectivity* (23 pages) and *C++ P2P Signaling Server Setup* (14 pages). They suggest async control/data-plane separation, ICE fallback and nonblocking PostgreSQL logging; they do **not** prove any direct-connect success rate, battery improvement, Android sensor exemption, zero-cost relay or production capacity. Do not adopt unconditional background reconnect/wakeup, fixed heartbeat intervals or blanket CGNAT impossibility claims.

## Selected transport per feature

| Feature | Android capture / initiation | Network | System of record and restrictions |
|---|---|---|---|
| Authorized one-way live microphone | Android RECORD_AUDIO/WebRTC audio in an OS-permitted, disclosed foreground-service session | WebRTC encrypted audio, direct or TURN | No VPS recordings; background permission alone does not permit unsolicited starts |
| Live front/rear camera | CameraX/Camera2, runtime CAMERA, eligible camera-type FGS, visible indicators | WebRTC video, direct or TURN | Real frame confirmation separate from command delivery |
| Snapshot or short camera/video recording | Only inside an authorized, eligible active capture session | Encrypted peer data transfer or active WebRTC | Verified receipt, finite duration; optional encrypted parent-local save separately gated |
| Screen viewing and snapshots | MediaProjection with **new device-user consent for each capture session**, corresponding FGS, Stop callback | WebRTC screen track / authorized still-image transfer | No reusable consent; `FLAG_SECURE` and financial/protected screens must not be bypassed; fail closed if exclusion cannot be trusted |
| Time-limited high-detail **live** GPS view | Android-permitted location workflow, child-specific authorized live lease, battery/thermal bounds | **Optional** WebRTC DataChannel | Never bypass lawful-purpose limits, offline queue, durable location dedup/history and erasure |
| Normal tracking, alerts, offline recovery, history | Alarka encrypted queue → Drogon durable inbox → independent C++ workers → Postgres/PostGIS | Existing HTTPS/API, optional parent SSE | Backend remains canonical and available when no P2P viewer is connected |

No arbitrary app-private file browsing, protected-screen capture, covert audio, “always instant” background device wakeup or generic network tunnel is justified by this architecture.

## Control plane, data plane and security

1. **Parent request** from Madalasa over TLS to Drogon: authenticate the adult, exact guardian-to-child grant, device enrollment, release flag, feature purpose, bounded TTL/quotas and current device capability. Family billing membership and Google Sign-In alone never confer child access.
2. **Child response**: send scoped command/notification (FCM delivery is not guaranteed), show the user what is requested; when OS/user interaction is required, Alarka obtains it on the child device. Alarka rechecks permissions, capture context, expiry, guardian authorization and explicit stop prior to starting any sensor. A delivered message or permission granted at installation is **not** proof of active capture.
3. **Signaling**: Drogon HTTPS/WSS carries bounded, authenticated SDP offer/answer and trickled ICE candidates with opaque session IDs, sequence/replay defense, timeouts, backpressure and rate limits; no blocking SQL on I/O loop. Do not log full SDP, raw ICE candidate addresses, passwords, child content, raw tokens or private keys. No separate uWebSockets/Boost.Asio daemon until profiling shows a need.
4. **Peer path**: ICE tests LAN/IPv6/host and STUN-derived UDP candidates as applicable. Successful **DIRECT** peer traffic never traverses VPS API workers. On unsuitable networks, use short-lived quota-limited **coturn TURN** relay. WebRTC encrypts media; TURN forwards encrypted packets in memory, but TURN **does** transport payload bandwidth. Validate peer DTLS certificate fingerprints against the authenticated, session-bound signaling identity and guard signaling key substitution.
5. **Lifecycle**: proposed `REQUESTED → AUTHORIZED → CHILD_ACTION_PENDING → NEGOTIATING → CONNECTED_DIRECT/CONNECTED_RELAY → STREAMING/DEGRADED → STOPPED/FAILED/REVOKED/EXPIRED`. Keep command delivery, peer connection and actual streamed frame/recording receipt as distinct states. Support visible child-side Stop, parent Stop, expiry, revoke, network handover and bounded ICE restart.
6. **Android restrictions**: microphone/camera while-in-use FGS cannot be started from arbitrary ordinary background states; supported notification interaction and other documented platform exceptions must be tested per OS/OEM, never presumed from FCM. MediaProjection requires a fresh system prompt for every session. On a denied action report `USER_ACTION_REQUIRED`/`OS_REJECTED`/`FEATURE_NOT_RELEASED`, not STREAMING. Permanent idle sockets, wake locks or indefinite recording services to evade restrictions are excluded.
7. **Logs**: bounded, retention-classified metadata only: actor/child/device/session IDs, verified states/duration, path type, bytes, bounded error code and timestamp. Do not store audio, video, screen frames, thumbnails, transcripts or protected IP/SDP payloads on the VPS. Optional saved recordings stay encrypted on the parent device only if later approved. Log asynchronously without starving signaling; admission and authorization failures must fail closed if security state is unavailable.
8. **Alternative stacks**: do not layer QUIC, libp2p, ICE-TCP and WireGuard by default. Evaluate a specific alternative only after real measurements demonstrate a gap and a separate security decision supports it. P2P is not a guarantee of connectivity; when TURN is blocked or over quota return a truthful failure.

## High-intensity location rules

The regular pipeline remains **Android fix → encrypted durable child queue → authenticated Drogon inbox/commit receipt → PostGIS → parent authorized reads**. Optional WebRTC DataChannel is a transient live-view optimization, not a location source of truth, history replacement or retention exemption. A guardian may request a short, revocable detail-mode lease; the child runtime enforces legal purpose, Android location permissions, current battery/thermal budget, accuracy and maximum duration. Proposed 5–15 second intervals are **measurement candidates only**, not guaranteed background behavior. Shared fixes need stable dedup event IDs for approved durable history. When direct/relay paths fail, show the age/accuracy of the last verified server fix, never an invented live point.

## Cost / scaling hypothesis and evidence

**Potential saving:** no VPS media egress on direct sessions. **Residual cost:** STUN/signaling/TLS, TURN-relayed media, database/GPS history, monitoring, authentication, recovery, cloud and staff. Benchmark media by active-stream minutes and relay fraction, not registered child count alone:

`stream one-way GB ≈ Mbps × minutes × 60 ÷ 8000` (before overhead).
`relay GB ≈ stream GB × measured relayed share × provider-specific egress accounting factor`.

Measure direct/relayed/failed fractions on LAN, two separate Wi-Fi NATs, mobile CGNAT and IPv6; setup time p50/p95/p99, Wi-Fi/mobile handover, ICE restarts, TURN peak Mbps/GB, CPU/RAM/fds per concurrent WSS client, signaling backpressure, and Android power/thermal behavior. Test 100/500/1000 simulated signaling sessions separately from 10/50/100 active media sessions. **These are test sizes, not capacity claims.** No guaranteed per-child savings or elimination of relay cost is approved. Reuse current Drogon infrastructure unless a comparative load test establishes a bottleneck.

## Three separately required release gates — all currently OPEN

| Gate | Evidence required | Stop condition |
|---|---|---|
| **A — Android compatibility** | Actual signed adult-test builds on OS/OEM matrix; microphone/camera FGS permission/start context; visible app icon, monitoring notification, Android sensor indicators, explicit Stop; fresh MediaProjection prompt/session + callback; denied starts, protected/financial screens, lock/revoke and network tests | Ordinary background or protected capture fails closed; a passed unit test alone does not prove device behavior |
| **B — Indian legal compliance** | Documented, cited feature-by-feature lawfulness determination with accountable owner review: purposes, guardian authority/custody, bystander privacy, DPDP/other Indian law and commencement, notices/consent, relay data, retention/deletion and recordings. **Qualified lawyer email/review is recommended for contested/high-risk features; no blanket signed-opinion mandate established.** | No real-child feature operation without documented applicable legal basis and safeguards. The real-time-location exception is not a blanket media/history exemption |
| **C — Google Play eligibility/review** | Truthful separate Madalasa/Alarka target audience, Families location/mic/camera rules, monitoring disclosure and `isMonitoringTool` where required, FGS type declarations/video, Data Safety, public privacy/account-deletion pages, actual review outcome | No child media feature exposed or enabled solely on the basis of developer permissions, internal review or support AI responses |

While any feature's applicable gates remain open, **Play release builds must exclude that unapproved media capture functionality and unnecessary sensitive permissions; server release flags default OFF and child code must fail closed.** Internal explicit **adult-owned, synthetic-identity** research builds may exercise lawful, visible sessions for engineering tests. No production deployment, Play upload, real-child GPS/media or covert collection is authorized here.

## Worker routing and proposed tests (NOT RUN)

All technical documentation/planning stays on `main`. Workers pre-sync both `main` and `dev`. `api` owns Drogon/WebSocket signaling, auth/session/leases, coturn integration and backend RLS/metadata; `parent` owns receiving UI/stop; `child` owns OS permission/FGS/capture/stop adapters. Code goes from workstreams → tested cumulative `dev` → reviewed `main` → independent main-commit verification. **DB-01 schema reconciliation remains required before new database migrations.**

| Test | Proposed proof |
|---|---|
| T-P2P-01 | Authorized parent/child succeeds; other family/sibling/revoked guardian cannot obtain signaling/candidates/TURN credentials |
| T-P2P-02 | Same Wi-Fi connects directly and reports true first frame/Stop |
| T-P2P-03 | Separate NATs, CGNAT and IPv6 record *actual* direct/relayed/fail outcomes |
| T-P2P-04 | Short-lived scoped TURN credentials, quotas, expiry and misuse controls |
| T-P2P-05 | ICE restart, handover, network loss and revoke stop securely with bounded retries |
| T-P2P-06 | Force-stop/Doze/FCM delay and OS denial never masquerade as capture success |
| T-P2P-07 | Microphone/camera permissions, typed FGS, visible notification and Android sensor indicators on selected OEM devices |
| T-P2P-08 | MediaProjection fresh single-use session consent, Stop, device lock and `FLAG_SECURE`/financial-screen negative cases |
| T-P2P-09 | No media content on server, no raw SDP/IP/keys/tokens in logs, limited metadata and retention |
| T-P2P-10 | Optional high-detail live GPS session expires, downgrades gracefully, preserves durable history and correct freshness |
| T-P2P-11 | Load/soak: 100/500/1000 signaling and 10/50/100 media sessions; measure CPU, memory, FD, relay bandwidth and cost |
| T-P2P-12 | Test explicit feature OFF for each A/B/C gate; no policy-disabled captures in public/production builds |

Every acceptance result needs pinned commit/build, device+OS/network, command and exit, actual output, synthetic fixture and independent reviewer. A document, old DB test count or green structural CI is **not** a PASS.

## Sources and cross-references

- Owner-provided PDFs (technical proposals only): *C++ VPS Control Server for Secure Direct Android-to-Android P2P Connectivity* (23 pages); *C++ P2P Signaling Server Setup* (14 pages).
- [WebRTC peer connections](https://webrtc.org/getting-started/peer-connections), [ICE RFC 8445](https://www.rfc-editor.org/rfc/rfc8445.html), [STUN RFC 8489](https://www.rfc-editor.org/rfc/rfc8489.html), [TURN RFC 8656](https://www.rfc-editor.org/rfc/rfc8656.html).
- [Android background/while-in-use FGS](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start), [typed FGS](https://developer.android.com/develop/background-work/services/fgs/service-types), [MediaProjection](https://developer.android.com/media/grow/media-projection), [Doze](https://developer.android.com/training/monitoring-device-state/doze-standby).
- [Google Play monitoring tools](https://support.google.com/googleplay/android-developer/answer/12955211), [Families](https://support.google.com/googleplay/android-developer/answer/9893335), [FGS declarations](https://support.google.com/googleplay/android-developer/answer/13392821).
- [Conditional media capabilities](MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md), [media metadata logging](MEDIA_ACTIVITY_AUDIT_LOGGING_AND_REPORTING_2026.md), [technical specification](../../M1-secure-platform-foundation/01-requirements-and-architecture/TECHNICAL_SPECIFICATION.md), [QA plan](../../M8-operational-readiness/03-quality-and-evidence/TEST_STRATEGY_UNIT_INTEGRATION_LOAD_SECURITY.md), [blockers](../../M0-foundation-and-approvals/01-project-governance/BLOCKERS_AND_OWNER_DECISIONS.md).
