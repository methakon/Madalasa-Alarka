# X402 public acceptance — WAF, Android signing identities, OAuth and SOS (2026-11-07)

**Record ID:** X402-ACC-2026-11-07 · **Control state:** ENGINEERING_REPORTED / INDEPENDENT_REVIEW_PENDING · **Release state:** FREE_ONLY / adult-owned synthetic devices only / **NOT APPROVED FOR REAL-MINOR DEPLOYMENT**. **Document owner:** proposed engineering + Android + security; no independent or legal sign-off implied.

**Companion documents:** [x402 deployment runbook](../01-cloud-infrastructure/X402_FREE_FIRST_API_ADMIN_DEPLOYMENT_2026-11-05.md), [repository branch governance](../../M1-secure-platform-foundation/02-development-process/BRANCHING_VERSIONING_AND_RELEASE_PROCESS.md), [Google Play gate](../../M9-play-release/03-release-gates/DEPLOYMENT_RELEASE_READINESS_CHECKLIST.md). **Execution tracking:** [GitHub #46](https://github.com/methakon/Madalasa-Alarka/issues/46), [#48](https://github.com/methakon/Madalasa-Alarka/issues/48), [#52](https://github.com/methakon/Madalasa-Alarka/issues/52). This record supersedes older runbook **status bullets only**, not their source-of-truth installation instructions or historical dates.

## 1. Current verified-vs-reported evidence (do not overclaim)

| Area | Latest evidence | Classification | Outstanding condition |
|---|---|---|---|
| Source control | Backend + parent + child workstreams merged into dev; PR #47 x402 deployment checks, #50 trusted Cloudflare real-IP config, and #51 public synthetic HTTPS SOS test merged | GitHub state and committed code independently inspected by assistant in chat; operator must bind deployed ELF/APK to exact SHA | No automatic production acceptance from CI |
| x402 mail and API | Antigravity reported Nginx, OpenSMTPD, Dovecot healthy; Drogon listens only on 127.0.0.1:8080; Neon TLS verify-full; /healthz and /readyz HTTP 200; host RSS about 9.4 MiB; FREE_ONLY | Operator-reported host evidence in #46/#52 | Continue mail/resource monitoring and exact ELF checksum evidence |
| Public TLS | Let’s Encrypt certificate with explicit SANs for madalasa.berhampore.in and api.madalasa.berhampore.in, expiring 2027-02-04; certbot dry-run passed including mail cert | Operator-reported | Ongoing ACME renewal, mail continuity and strict TLS verification |
| Cloudflare edge | **Only** madalasa.berhampore.in orange-cloud proxied with Full (strict), Bot Fight Mode disabled; WAF admin auth rate limit at 10 requests/10 seconds/IP; /v1/ cache bypass | Operator-reported Cloudflare rule IDs/evidence in #48 | Validate false positives and preserve rollback; avoid zone-wide JS challenges |
| Native API | **api.madalasa.berhampore.in stays DNS-only**, because the existing Cloudflare Free Universal SSL single-level wildcard does not cover the deeper hostname. Native HTTPS terminates at origin | Operator-reported DNS and tested TLS | Cloudflare WAF **does not** protect this API; app/backend auth, RLS and Nginx are essential; do not orange-cloud without edge cert coverage |
| Genuine Google *web admin* sign-in | Later Antigravity report says genuine Google account authenticated, session issued and email verified | **Operator-reported PASS**, newer than prior 401 invalid_client | Verify scoped admin role/access and no token leakage; do not label full permission test passed from login alone |
| Child physical device SOS | Android 9 synthetic Alarka APK reported installed; native UI submitted one SOS to public API with **201 SERVER_ACCEPTED**, UUID 30258d32-af54-453a-b504-bd9f1b34e1e7 | **Operator-reported PASS** for submission only | Does **not** imply guardian notified, acknowledged, status converged, or queue cleared |
| Parent physical device OAuth | Android 11 synthetic Madalasa package sign-in got Google `UNREGISTERED_ON_API_CONSOLE [16]` | **BLOCKED** at Google OAuth project registration | Register exact synthetic package and APK signing SHA-1 in the existing project, then retest parent token/server session |
| Guardian retrieve/ACK and child queue | Parent GET `/v1/children/{childId}/signals`, ACK `/v1/children/{childId}/signals/{eventId}/ack`, child GET `/v1/devices/{deviceId}/signals/{eventId}/status`, outbox deletion | **NOT YET VERIFIED on physical apps** | Same event must reach GUARDIAN_ACKNOWLEDGED; encrypted outbox may clear only after verified status; repeat offline restart/replay and cross-family negatives |
| Public synthetic contract test | PR #51 adds `deploy/x402/api/public-synthetic-sos-acceptance.py`; explicitly opt-in, requires synthetic-only flags and operator-provided secrets, system-trust TLS, checks exact event/ACK | Implemented and CI-checked, NOT an executed live success on behalf of this assistant | Execute only with approved synthetic fixture, never with real children's credentials |

## 2. Controlled OAuth signing-identity matrix

**Google Cloud project:** `gen-lang-client-0212768379` · project number `207621418218`. Never substitute a separate Google project without verifying consent-screen configuration, server issuer/audience and intended ownership.

| Identity | Application ID / package | SHA-1 (certificate) | SHA-256 | Intended registration |
|---|---|---|---|---|
| **Synthetic Madalasa debug** | `in.berhampore.madalasa.synthetic` | `D1:35:08:5A:88:E6:B5:B8:27:F5:64:DE:57:D6:61:40:13:BB:56:61` | `16:42:F5:8E:AC:E8:E0:3F:81:2D:1C:1B:5F:F3:86:48:0F:BC:CA:36:60:9F:B2:BE:15:57:E3:EB:E2:73:A2:F7` | **Required separate Android OAuth client**; creation not yet evidenced |
| **Synthetic Alarka debug** | `in.berhampore.alarka.synthetic` | Same local debug SHA-1 as above, per worker | Same local debug SHA-256 as above, per worker | No Android OAuth client implied unless this package actually uses Google sign-in |
| **Madalasa Google Play app-signing** | `in.berhampore.madalasa` | `69:E6:EB:88:27:04:36:66:33:30:DF:56:4E:43:C9:85:67:4E:82:1A` | `4D:71:3B:5B:86:38:29:8C:48:03:E7:D6:95:FC:F6:B7:45:26:59:24:5C:B9:DA:BB:E7:BE:00:B9:FA:D8:B4:AD` | Production Play Android OAuth client only after confirmed console state; preserve existing registration |
| **Additional historical/classical cert** | `in.berhampore.madalasa` | `50:C9:18:FC:72:DF:1A:C9:91:1C:9C:34:39:54:22:0F:06:55:BB:84` | `A5:38:A5:4C:09:3C:48:58:0F:27:D0:5D:A8:58:D4:03:1E:E8:57:B0:64:CE:D2:E8:2F:1E:CA:9B:A9:34:52:3C` | Investigate actual installed signing variant / Google Play rotation before including in production registration |

**Web OAuth audience/client ID:** `207621418218-0bh5omf3aj4ita86kcjiorc387361o4k.apps.googleusercontent.com`, used by the backend admin web authentication flow (and where architecturally required as ID-token server audience). Android OAuth credentials are separate **package + signing SHA-1 registrations**; do not replace the web client ID in server-side ID-token verification with an Android client ID without revisiting auth contract.

**Existing local directory reported by owner:** `/home/swarna-sekhar-dhar/Downloads/ME/madalasa`. Antigravity may inspect local public signing certificates and keystore metadata but **must not commit, upload, transmit or log private keys, passwords, ZIPs, signing keystores or tokens**. Use `apksigner verify --print-certs` against the **installed build's APK** and `keytool -list -v -keystore ...` under a secure local shell to compare fingerprints; user must approve any changes to upload/release key identity. Google Play app-signing and local debug signatures are not interchangeable.

### Android OAuth action required

1. In Google Cloud Auth Platform → Clients for project `gen-lang-client-0212768379`, search for an Android OAuth client with **package `in.berhampore.madalasa.synthetic` and SHA-1 `D1:35:08:5A:88:E6:B5:B8:27:F5:64:DE:57:D6:61:40:13:BB:56:61`**. Do not rely on its display name; avoid duplicate registrations.
2. If missing, the authorized operator may use the authenticated **official Cloud Console UI** to create this Android client. A normal `gcloud` command does not provide an equivalent general-purpose Android OAuth client creation operation. Do not misuse IAP OAuth client tooling or bypass security challenges.
3. Preserve the existing production package/client, web client, signing keys, consent policy and WAF/DNS configuration. Confirm exact matching project and all consent-screen test-user requirements.
4. A signed-in Google account on the parent app must produce an actual `POST /v1/auth/parent/google` success and appropriately scoped session; app UI success alone is insufficient. A parent role may only see/ACK its authorized synthetic family.

### Digital Asset Links is separate — no synthetic production-domain privilege

The owner's Play Console screenshot lists production `assetlinks.json` with `delegate_permission/common.handle_all_urls` for `in.berhampore.madalasa` + its Play SHA-256 `4D:71:...`. This is a domain/app association, not a Google OAuth client and not a fix for `UNREGISTERED_ON_API_CONSOLE`. **Do not add `in.berhampore.madalasa.synthetic` to public production `/.well-known/assetlinks.json`** merely to make Google Sign-In work; do not add `common.get_login_creds` without a separately approved security review. Production app links and login credential delegation are distinct decisions.

## 3. Test sequence and fail-closed definition of done (Issue #52)

1. Record exact `dev` SHA and separately SHA-256 for both APKs; verify installed package, installed signing fingerprint, API base URL `https://api.madalasa.berhampore.in`, synthetic-only identities and no debug preview masquerading as native network success.
2. After OAuth registration, genuine Google auth on Android 11 → backend creates parent session → authenticated list contains **the exact child SOS UUID**, initially unacknowledged. Do not fabricate push notification delivery if the app fetched the event by polling.
3. Human taps ACK on real parent phone; backend returns 200 `GUARDIAN_ACKNOWLEDGED` for same event, verifies family authorization and atomic persistence.
4. Child device polls server; status of same event becomes `GUARDIAN_ACKNOWLEDGED`, `guardian_acknowledged=true`. Only then confirm encrypted outbox entry removed, including after process restart.
5. Trigger a **separate** synthetic offline event while device has no network, force-stop/relaunch and reconnect; ensure same event UUID is re-sent (not regenerated), no duplicate alerts, ACK converges, persisted pending entry clears at the correct stage. Cross-family access must fail and device revocation must prevent further submissions without destroying unacknowledged safety evidence.
6. Preserve x402 health, certbot renewal, mail delivery and resource evidence and keep Cloudflare admin-proxied/API-DNS-only configuration. Never weaken TLS or mark request 401/403/429 as successful SOS.
7. Only after evidence is provided may the issue mark **PUBLIC_STAGING_SYNTHETIC_E2E_VERIFIED**. This is **not** Play production approval, genuine child tracking authority, 24/7 emergency SLA or legal/DPDP clearance.

## 4. Source trail and change control

- Worker reports: Antigravity x402 deployment 2026-11-06; Cloudflare phase/PR #50 2026-11-07; 2026-11-07 Google web/Android SOS preflight; subsequent keystore/Play signing comparison.
- GitHub: [#46](https://github.com/methakon/Madalasa-Alarka/issues/46), [#48](https://github.com/methakon/Madalasa-Alarka/issues/48), [#52](https://github.com/methakon/Madalasa-Alarka/issues/52), [PR #51](https://github.com/methakon/Madalasa-Alarka/pull/51).
- Evidence semantics: **source implemented** ≠ **CI green** ≠ **worker reports PASS** ≠ **independently rerun** ≠ **production release granted**. If a later owner/worker report contradicts a prior status, append a dated correction rather than erasing history.
- Do not store identity emails, phone serials, device bearer tokens, session cookies, unredacted parental data or signing material in documentation or GitHub issues.
