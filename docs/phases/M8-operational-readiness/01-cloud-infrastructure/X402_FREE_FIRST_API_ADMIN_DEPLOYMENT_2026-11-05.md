# X402 Free-First API + Admin deployment — implementation runbook
**Record:** X402-DEPLOY-001 · **Date:** 2026-11-05 · **Stage:** deployment candidate / controlled adult-device lab, **NOT public child-monitoring approval**.

## 2026-11-08 newer acceptance supersession — synthetic handset end-to-end PASS reported

Antigravity's [Issue #52 acceptance evidence](https://github.com/methakon/Madalasa-Alarka/issues/52#issuecomment-6712011065) now reports actual Android 11 parent Google sign-in, child-scoped guardian SOS retrieval, user-initiated ACK, Android 9 child status convergence and encrypted outbox removal; offline force-stop/manual retry, credential revocation and cross-family denied operations also passed. **Supersedes the 2026-11-07 parent OAuth and guardian-ACK blockers below for the tested synthetic builds only.** Definitive statuses, APK SHA-256s, evidence class and open gates are in the [M8 public acceptance record](../03-quality-and-evidence/X402_PUBLIC_ACCEPTANCE_OAUTH_SIGNING_AND_WAF_2026-11-07.md). Live admin Cloudflare WAF and API DNS-only mode remain unchanged; the shared mail VM and real-child release are not approved for unlimited production traffic. Pentest [Issue #54](https://github.com/methakon/Madalasa-Alarka/issues/54) remains separate.

## 2026-11-07 status supersession — HTTPS/WAF live; Android OAuth still blocks full SOS round trip

**Read the newer [controlled x402 public acceptance, signing and OAuth record](../03-quality-and-evidence/X402_PUBLIC_ACCEPTANCE_OAUTH_SIGNING_AND_WAF_2026-11-07.md) before interpreting earlier `NOT RUN` lines below.** The 2026-11-05/06 bullets are **historical snapshots**. Antigravity subsequently reports x402 public TLS, free-only Drogon service, Nginx/admin static delivery, Neon TLS verification and mail preservation, plus Cloudflare-proxied **admin** website; the deeper API hostname deliberately remains **DNS-only**, not Cloudflare WAF-protected. Admin genuine Google web sign-in and native Alarka SOS 201 are subsequently worker-reported PASS; parent Android OAuth remains blocked pending its separately registered `.synthetic` package+SHA-1 client in project 207621418218. Parent same-event ACK, child's confirmed ACK status, encrypted outbox clearance and offline/revocation tests remain NOT YET VERIFIED. See [GitHub #52](https://github.com/methakon/Madalasa-Alarka/issues/52). None of these authorize real-minor data or public Play release.

## 2026-11-06 self-implemented deployment code and Antigravity-only environment steps

**Direct GitHub implementation on `api`, PR #47:** corrected previously inconsistent `deploy/x402/api/validate-env.sh` to require actual managed-Neon LOGIN roles `ap_m1_api_user`, `ap_auth_issuer_user` (not `ap_m1_api` group), `PGSSLMODE=verify-full`, absolute trust-bundle path, external database DNS hostname, exact admin HTTPS origin and FREE_ONLY. Template uses placeholders for real Neon hostname/database/passwords. Added `deploy/x402/api/test-validate-env.sh` synthetic positive/negative role/TLS/origin tests and CI invocation in `.github/workflows/local-checks.yml`. Added **read-only** `deploy/x402/api/staging-acceptance.sh` to check existing mail units, Nginx syntax, loopback listener, free-only/readiness, verified public TLS, vhost separation and bounded resource evidence. These are committed but are **not x402 deployment proof**; only merge after new-head CI, branch sync and review.

**Admin build blocker remains:** `admin-web/package-lock.json` is absent from `admin-web` branch, while `deploy/x402/admin/build.sh` correctly requires reproducible `npm ci`. Do not disable this precondition; Antigravity must generate and commit reviewed lockfile with network/Node/npm tooling. PR #29 is draft/stale relative to `dev` and requires clean main/dev sync, exact-head CI and scope review.

**Antigravity environment handoff** in [Issue #46](https://github.com/methakon/Madalasa-Alarka/issues/46): after source merge, SSH read-only resource + mail preflight, off-host C++/admin builds, real Neon TLS/least-privilege and OIDC config outside repository, DNS/ACME and Nginx isolation, restricted systemd install, controlled static publish, mail continuity proof and rollback. **No PostgreSQL on x402, no production child-data processing and no live payments**. If resource or mail preflight fails, NO-GO; never disable existing mail to force staging.

## 2026-11-06 deployment execution decision — controlled staging only

**Owner asks to perform x402 deployment.** Staging API/admin is technically permitted under strict no-real-minor, FREE_ONLY controls, but no SSH, DNS, HTTPS, Nginx reload, systemd install, or end-to-end admin login has been executed by the assistant. Do **not** label this as a functioning production deployment or authorise public child monitoring.

**Latest source:** Neon/TLS/role-boundary and SOS API PR #41 merged to `dev` (`862c040f2ec702131ac329ec668e949c38d2a98f`); parent premium-preview PR #43 and guardian PR #45 also merged. Admin source PR #29 is **open, behind `dev`**. It requires reconciliation and exact-head checks before a deployment build. The admin's reproducible `deploy/x402/admin/build.sh` requires `admin-web/package-lock.json`, which is **not present** in the admin-workstream tree; generate, review and commit the lockfile under a connected build environment before `npm ci`. API staging env example on `api` commit `18543a6` now identifies the exact restricted login roles `ap_m1_api_user` and `ap_auth_issuer_user`, external Neon hostname and `PGSSLMODE=verify-full`; it must be reviewed and merged via `api → dev`.

**Execution handoff:** [Issue #46](https://github.com/methakon/Madalasa-Alarka/issues/46) contains SSH-only operator preflight, external binary/admin build, DNS/certbot/Nginx safe publish, actual OIDC and Neon checks, mail availability and rollback evidence. x402 RAM is ~954 MiB; **never install Postgres locally** and do not run heavyweight builds on this mail host. Passwords, Neon tokens, OAuth secrets and private keys must remain outside GitHub. No app ingestion, paid checkout, camera/mic/screen or sensor SOS in controlled staging.

**Deployment GO/NO-GO:** code staging preparation GO; publicly operating child-safety production service remains NO-GO pending Play/DPDP, category retention, guardian and Android gates, 108-client capacity testing, backup/restore and operational evidence. Completion requires genuine x402 runtime test results, not merely passing GitHub CI.

## 2026-11-05 LIVE SSH PREFLIGHT — POSTGRESQL CO-LOCATION NO-GO (owner accepted)

**Decision: do not install PostgreSQL/PostGIS on x402-endpoint.** A worker performed read-only SSH inspection and reported 954 MiB RAM, ~540 MiB available, 57 MiB swap already used at idle, 40 GB free disk, healthy mail services (OpenSMTPD ~61 MiB, Dovecot ~16 MiB, Nginx ~11 MiB). Oracle Cloud Agent ~86 MiB, journald ~53 MiB, fail2ban ~48 MiB, fwupd ~43 MiB and snapd ~25 MiB were observed. No PostgreSQL server installed and no 5432/443/8080 listener. Minimal PostgreSQL 16 + PostGIS estimated ~85–105 MiB additional idle memory **without peak-query/autovacuum/mail-spike headroom**. Measurements and risk estimate were supplied by the worker; independent operator rerun and evidence preservation remain required.

**Approved disposition: NO-GO / INSUFFICIENT_RESOURCES.** Do not override this decision by tuning shared_buffers, setting two connections, increasing swap, disabling mail, disabling security/Oracle agents or accepting bounded-lab risk. Previous optional `deploy/x402/api/postgresql-lowmem.conf.example` is **obsolete for this host; reference only, NEVER apply to x402**. Existing installation instructions for local PostgreSQL are superseded by this explicit refusal. Do not bind, install, start or migrate a database here. Existing Nginx, SMTP, IMAP, firewall and mail configuration are outside this project's change scope.

**Revised topology:** x402 remains a candidate API + static admin edge on loopback Drogon `127.0.0.1:8080` (API memory itself must still be measured); PostgreSQL 16/PostGIS must run on a **separate approved VM or managed database**, or x402 must be resized to **at least 2 GiB (preferably 4 GiB)** and re-benchmarked before reopening the co-location decision. No provider has been selected or provisioned. All eight reviewed GCP billing accounts were reported closed; GCP Always Free Compute Engine therefore remains blocked until an open billing account is authorized. Never silently provision on GCP or OCI without cost/placement approval.

**Off-host DB security implementation blocker:** current Drogon DB connector settings do **not** evidence verified TLS transport to remote PostgreSQL. Before configuring remote `MA_PG_HOST`, implement and test encrypted authenticated DB transport with server certificate validation (or a reviewed authenticated private tunnel), a default-deny DB firewall bound only to the API host, least-privilege runtime and issuer roles, backups and isolated restore. No public port 5432. Recheck systemd sandbox's network families and service start, then measure API RSS/swap/mail continuity separately from DB testing.

**Evidence source (worker-local, not attached here):** `/home/swarna-sekhar-dhar/projects/mypola/gcp-postgres-free-01/X402_POSTGRES_COLOCATION_PREFLIGHT.md`. Worker should add a redacted, non-secret and repeatable evidence summary through normal documentation governance. Do not claim this private path is a committed repository artifact.

**No public deployment or real-minor collection is authorized by this decision.**

## 2026-11-05 Neon Free PostgreSQL provisioning and E-01 managed-provider blocker

**Reported by Hermes; not independently connected from this session:** Neon org `mamata` project `madalasa-alarka-dev` (project ID `solitary-hat-06678539`), default branch `main` (`br-winter-sky-b3kv36g8`), PostgreSQL 16.15, PostGIS 3.3.10, `aws-ap-southeast-1` Singapore, 1 GiB logical branch storage, 6-hour history, 0.25 CU autosuspend. Managed database only for disposable synthetic development data; never interpret free-tier project provisioning as always-on capacity or real-child-data clearance.

**Partial migration:** V2 0001–0024 reported committed; V2 0025 blocked at its unqualified cluster-global `pg_roles` assertion `rolcanlogin AND rolname <> 'postgres' AND (rolsuper OR rolbypassrls)`. Neon-managed `cloud_admin`, `neon_service` and project owner login have privileged attributes; the assertion was designed around a localhost Docker `postgres` administrative identity. The failure is **not** evidence that `ap_m1_api_user` is privileged; Hermes reports API/issuer logins NOSUPERUSER/NOBYPASSRLS/NOCREATEROLE/NOCREATEDB, 143 application tables with ENABLE+FORCE RLS, direct unauthorized insert rejected. 0025+ remains **NOT APPLIED**, and full managed-Neon migration/authorization acceptance is NOT READY.

**Security decision:** reject an indiscriminate `NOT IN ('postgres','cloud_admin','neon_service',current_user)` patch. `current_user` is untrusted for authorization exemptions and role names alone do not prove provider identity. Adapt the boundary to protect all project-owned application/runtime login roles and their privileged membership graph while treating provider/project administrator accounts as a separate documented trusted administrative layer. Query/assert runtime roles, login roles they can assume, `rolsuper`, `rolbypassrls`, `rolcreaterole`, `rolcreatedb`, `rolreplication` and membership to `ap_m1_owner`, `ap_db_executor`, `ap_m1_auth` or equivalent definer bridges. Preserve bridge roles NOLOGIN and required definer attributes. Keep negative tests for elevation of `ap_m1_api_user` / `ap_auth_issuer_user` and dynamic role membership. Do not silently exempt an application principal because it is named like a provider role.

**Versioned migration rule:** migration 0025 and its SHA-256 are already pinned in the repo's `migration-lineages.json` and used by earlier merged/tested work. **Do not silently rewrite 0025 or its pinned checksum** to unblock Neon; first prove which ledgers have applied the original 0025, then design a version-aware adaptation using a reviewer-approved migration lineage/replay procedure with new additive repair where possible. A later migration alone cannot fix an earlier assertion that prevents execution; the worker must design and test a compatible clean-install path that preserves old applied checksums without bypassing negative tests. Do not edit Neon migration ledger manually, manually weaken a security-definer function, or use production data for the replay.

**Remote DB gate unchanged:** TLS was reported active from a Neon CLI client, but this **does not establish TLS peer/hostname verification from the actual C++ Drogon runtime on x402**. Require verified encrypted connection, hostname/certificate checking or approved private tunnel, least-privilege API and distinct issuer pool, credential renewal wrong-pool/expiry fix, limited connection counts, backup/restore and no public child data. 6-hour Neon history does not satisfy long-term approved category-specific backup/retention policy.

## 2026-11-05 owner hostname selection

**Owner supplied:** `madalasa.berhampore.in`. This is the **admin-panel hostname** `https://madalasa.berhampore.in`, and the separate **proposed** API hostname is `https://api.madalasa.berhampore.in`. Both should resolve to the VM public IPv4 `<VM_PUBLIC_IP>` only after DNS changes are confirmed. An existing DNS record or Nginx virtual host may already own the first hostname: **inspect and preserve current content before changing it**. No DNS, TLS certificate, or VM state was changed by recording this decision.

| DNS host | Proposed record | Purpose |
|---|---|---|
| `madalasa.berhampore.in` | A → `<VM_PUBLIC_IP>` | Admin UI, same-origin `/v1/admin/*` only |
| `api.madalasa.berhampore.in` | A → `<VM_PUBLIC_IP>` (new subdomain, owner DNS control pending) | Parent/child free-service API, deny admin routes |

API env `MA_ADMIN_ORIGIN=https://madalasa.berhampore.in`; backend remains local `127.0.0.1:8080`. Admin and API Nginx templates on `admin-web` use the hostnames and expected separate LetsEncrypt live certificate paths. **They will fail `nginx -t` until valid certificates exist.** Use a non-invasive HTTP-01 DNS/ACME procedure that keeps current port-80 websites, Nginx and mail services operational; do not assume Certbot is installed or replace existing certificates. Verify `dig +short A` for both hosts, detect public A/AAAA mismatches, check `sudo nginx -T` for duplicate `server_name`, and confirm ports 80/443 firewall rules before issuance. No automatic redirect, HSTS, or public publishing until the verified admin/auth flows pass.

## 1. Owner-provided host baseline (unverified by this assistant)
- Host label: `x402-endpoint`; public IPv4 **<VM_PUBLIC_IP>**, private **<VM_PRIVATE_IP>**.
- Ubuntu 24.04.5 LTS, Linux 6.17.0-1020-oracle, **x86_64**, KVM/AMD EPYC 7551, **2 vCPU**.
- **954 MiB RAM**, **1 GiB swap**, 45 GiB root disk (reported ~40 GiB free), 533 MiB available RAM, ~420 MiB used, swap 86 MiB used.
- Existing **nginx, dovecot, opensmtpd** must remain active. Public TCP listeners 22,25,80,465,587,993,995. No public 443 at report time; 5432 and 8080 must remain closed externally.
- Owner checked at 2026-11-05 01:20 IST. These metrics are a snapshot, **not** a remotely reproduced benchmark.

**Decision:** use this VM as an **interim low-resource deployment target**. Do not reconfigure the mail stack or run a resource-intensive build on the VM. No public child monitoring, 108-client availability guarantee, or production retention decision is authorized by host selection.

## 2. Proposed deployment topology

```text
Parent Madalasa / Alarka adult lab     Staff browser
        |                                  |
    HTTPS api.madalasa.berhampore.in    HTTPS madalasa.berhampore.in
        |                                  |
        +-------- existing NGINX on 443 --+
                            |
             127.0.0.1:8080 Drogon API
                  ma_backend (FREE_ONLY)
                      |          |
           ap_m1_api Postgres  ap_auth_issuer (separate role)
                      \          /
                PostgreSQL 16/PostGIS
                 localhost ONLY
       static admin Vite dist served directly by Nginx
       existing nginx/mail services remain undisturbed
```

**Two DNS FQDNs required:** `api.madalasa.berhampore.in` for API and `madalasa.berhampore.in` for admin, each with valid HTTPS TLS certificate, independent from mail subdomains. Admin client requires **exact** `MA_ADMIN_ORIGIN=https://madalasa.berhampore.in` because login and mutations enforce Origin and SameSite/secure Host-only cookies. **Do not claim a working public HTTPS endpoint using the bare IP.** The nginx templates have placeholders and intentionally cannot be installed unchanged.

**Memory:** systemd API `MemoryHigh=180M`, `MemoryMax=240M`, `MA_PG_CONNECTIONS=2` plus separately configured auth issuer connections. Memory limits are starting guardrails **not measurements**. Co-locating even a minimally configured PostgreSQL service on this 954 MiB VM with active mail can cause swapping/OOM; make a measured co-location decision. Prefer VM resize (at least 2–4 GiB) or separate database with verified encrypted transport before nontrivial sustained workload. **The current C++ database connector config does not establish remote PostgreSQL TLS; don't use an unencrypted off-host PostgreSQL socket.** If local Postgres is used for the controlled lab, it binds 127.0.0.1 only, with low-memory overrides as optional benchmark starting values. Never assume 108 active child capacity from synthetic DB-only tests.

**Free first:** `MA_RELEASE_PROFILE=FREE_ONLY`, monitoring/collection and billing remain independently gated. Premium catalog preview in Madalasa shows ₹99/month and ₹999/year and Pay now opens Coming Soon; no provider checkout or paid entitlement.

## 3. Changes prepared in source

| Branch | Implementation artifact | Purpose |
|---|---|---|
| `api` | `deploy/x402/api/madalasa-api.service` | Unprivileged, systemd-sandboxed loopback API, memory control |
| `api` | `deploy/x402/api/api.env.example`, `validate-env.sh` | Fail-closed FREE_ONLY, separate DB roles, explicit Google audiences, exact admin HTTPS Origin |
| `api` | `deploy/x402/api/preflight.sh`, `smoke.sh` | Non-destructive resource/port and API health/free-only checks |
| `api` | `deploy/x402/api/postgresql-lowmem.conf.example` | Optional lab-only PostgreSQL tuning, not approved production sizing |
| `api` | `backend/src/main.cc` (`GET /readyz`) | Database-aware readiness distinct from public liveness; not routed externally |
| `api` | `backend/tests/test_x402_deployment_contract.py` | Static release/host hardening assertions |
| `admin-web` | `deploy/x402/nginx/madalasa-{admin,api}.conf.template` | Separate HTTPS vhosts, admin-route isolation, 127.0.0.1 reverse proxy |
| `admin-web` | `deploy/x402/admin/build.sh`, `verify-static.sh` | Off-VM reproducible admin build and artifact validation |
| `admin-web` | `deploy/x402/admin/publish.sh`, `rollback.sh` | Atomic immutable release directories and static rollback |
| `admin-web` | `deploy/x402/admin/test-deploy.mjs` | Static Nginx and release-rule tests |

**Governance:** implementation changes remain on workstream branches pending code PRs to `dev`; documentation remains on `main`. No direct workstream deployment as a public release. The previous Chicago/A1 architecture is historical planning; this new target is a **temporary smaller VM decision**, not an authorization for sensitive data collection.

## 4. Operator prerequisites (never put secrets in GitHub)
1. Two DNS hostnames and DNS A records to <VM_PUBLIC_IP>, then issue legitimate TLS certificates for the actual names. Confirm the existing Nginx `80` vhost, ACME and all mail services remain working. Enable 443 at the provider/network firewall; do **not** close existing mail ports, widen 22, expose 8080/5432 or change MX.
2. Root/sudo shell access through existing secured SSH, and enough disk/RAM headroom. Run `bash deploy/x402/api/preflight.sh` and store **redacted** output. Check `nginx -t`, `systemctl --failed`, `free -m`, `ss -lntup`, `df -h`.
3. Decide verified PostgreSQL deployment location. For a localhost lab choose PostgreSQL 16 + compatible PostGIS, bind localhost, tune/monitor conservatively, create a **dedicated disposable test database** and separate `ap_m1_api` versus issuer roles using the documented DB migration/bootstrap process. Never run `manage.py reset` against production. Capture migrations through v2:0029 (or later approved SHA), SQL role/RLS tests, backup and an **isolated restore drill** first. For remote DB, implement/test TLS verification and private networking; never use plaintext external DB.
4. Configure approved Google OIDC audience/client IDs for guardian and admin separately; verify issuer/keys and actual Google ID-token flow. Do not enable synthetic header authentication or use test credentials as administrator production identity. Ensure intended root admin provisioning uses verified backend owner controls, not client-manufactured roles.
5. Build C++ binary/deps on a compatible **x86_64** builder from a reviewed SHA (CMake `MA_SYNTHETIC_AUTH=OFF`, Drogon/PostgreSQL enabled). Run backend C++ CTest, PostgreSQL and HTTP integration/security suites. Deploy binary plus all required pinned shared libraries to `/opt/madalasa/backend`; use `ldd` and test dynamic loader on VM. Compile React/Vite admin on a separate build runner: `VITE_ADMIN_SYNTHETIC_PREVIEW=false`, `npm ci`, `npm test`, `npm run build`; transfer only `dist`.

## 5. Example non-destructive installation sequence (operator/worker)
Use exact source artifact SHA and reviewed PRs; adapt usernames/paths only after verifying them. Commands assume administrator rights and downloaded, verified build artifacts.

```bash
# Inspect first. This changes nothing about mail services.
sudo bash deploy/x402/api/preflight.sh
sudo systemctl is-active nginx dovecot opensmtpd
sudo nginx -t
ss -lntup | grep -E '(:443|:5432|:8080)' || true

# Dedicated non-login account and directories; no root API process.
sudo useradd --system --user-group --home-dir /nonexistent --shell /usr/sbin/nologin madalasa-api  # only if absent
sudo install -d -m 0750 -o root -g madalasa-api /etc/madalasa
sudo install -d -m 0750 -o madalasa-api -g madalasa-api /opt/madalasa/backend
sudo install -d -m 0755 /usr/local/libexec/madalasa

# Copy verified API executable and its reviewed runtime shared-library dependencies.
# Provision /etc/madalasa/api.env securely OUTSIDE source control;
# chmod 0640 root:madalasa-api. Never paste contents into tickets/logs.
sudo install -m 0755 deploy/x402/api/validate-env.sh /usr/local/libexec/madalasa/validate-env.sh
sudo /usr/local/libexec/madalasa/validate-env.sh /etc/madalasa/api.env
sudo install -m 0644 deploy/x402/api/madalasa-api.service /etc/systemd/system/madalasa-api.service
sudo systemctl daemon-reload
# Only after readiness prerequisites: sudo systemctl enable --now madalasa-api
# curl -fsS http://127.0.0.1:8080/readyz
# bash deploy/x402/api/smoke.sh
```

For admin, install the **built** `dist` through `sudo bash deploy/x402/admin/publish.sh /path/to/dist FULL_GIT_SHA`. Resolve placeholders in new Nginx templates to actual FQDN, certificate paths and `WEB_ROOT=/srv/madalasa/admin/current`. Use separate new vhost files; **never replace existing nginx.conf, mail config or mail virtual hosts**. Then `sudo nginx -t && sudo systemctl reload nginx`. Keep static releases for rollback: `sudo bash deploy/x402/admin/rollback.sh PREVIOUS_FULL_SHA`.

**Network:** Nginx terminates HTTPS and proxies API/admin traffic to loopback 8080. `/v1/admin/` is available **only** from admin FQDN; non-admin `/v1/` is **not** reachable from admin FQDN. `/readyz` is intentionally absent from either public vhost. Store logs securely, avoid request-body/credential logging, do not log location coordinates.

## 6. Strict acceptance gates
- **Host continuity:** pre/post service list and Nginx config diff; check existing mail ports 25,465,587,993,995 and SMTP/IMAP tests. No outages from API install; capture nginx -t and journal of newly installed service only.
- **OS/resource:** report 5m/30m/2h memory RSS, swap-in, CPU, disk, OOM count and nginx/mail availability under controlled adult-lab traffic. Stop rollout on persistent swapping, OOM, mail latency or error-rate increase.
- **API:** `/healthz` liveness and `/readyz` DB/schema readiness are distinct; wrong DB credentials/schema → `503`. Admin/parent auth fails closed. `/v1/release/capabilities` says FREE_ONLY and billing/trial/media false. Cross-family RLS and request replay negatives pass.
- **Admin:** HTTPS only, production build with synthetic preview false, real Google OIDC nonce flow, HttpOnly/Secure/SameSite session cookie, CSRF rotation and mutating-action origin check. Unapproved login sees no role/access; owner and support roles see only scoped data. Nginx admin/API isolation tested.
- **Data:** no real minor's GPS, no hidden camera/microphone, no indefinite child retention, no unapproved capture. Adult-device lab may use genuine own GPS with explicit consent and private short-TTL test data once configured. Do not run 108-child synthetic load against the mail VM without resource review.
- **Restore:** backup both data and release artifacts, prove isolated restoration, rollback admin symlink and API service/binary using exact artifact SHA. Never roll SQL migrations backwards destructively to satisfy an app rollback.
- **Release:** Play G01/G04, DPDP feature-by-feature legality, category retention, live Android permissions and actual physical devices remain separate public-availability blockers.

## 7. Information owner should provide for real deployment
**Do not request any SSH password, private key or payment credentials in chat.** Provide:
- Proposed **two DNS hostnames** (or an existing domain the owner controls) and whether DNS/443 can be configured without touching mail.
- Whether an **existing private PostgreSQL 16/PostGIS database** is available, or the owner approves **lab-only** localhost installation with memory monitoring (no public child traffic).
- Access method for Hermes/authorized operator (existing SSH agent/credential manager, not pasted secrets).
- If production OTP/email notifications are needed, their approved mail pathway; **do not reuse existing SMTP credentials without explicit authorization**.

## 8. Status and evidence semantics
- **Prepared in GitHub workstreams:** deployment templates, script contracts, readiness handler, admin assets publication tools.
- **NOT RUN:** Ubuntu commands, actual host access, PostgreSQL provisioning, DNS/TLS, admin Google login on x402, off-host binary build and Nginx/TLS smoke, backup/restore, 108 authenticated HTTP sessions, Android battery matrix.
- **NO-GO for public minor tracking** until separately approved feature/legal/Play/data security requirements. Do not market a 1GB single VM as guaranteed SOS/emergency uptime.
