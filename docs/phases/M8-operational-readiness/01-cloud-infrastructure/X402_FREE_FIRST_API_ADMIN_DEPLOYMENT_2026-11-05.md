# X402 Free-First API + Admin deployment — implementation runbook
**Record:** X402-DEPLOY-001 · **Date:** 2026-11-05 · **Stage:** deployment candidate / controlled adult-device lab, **NOT public child-monitoring approval**.

## 2026-11-05 owner hostname selection

**Owner supplied:** `madalasa.berhampore.in`. This is the **admin-panel hostname** `https://madalasa.berhampore.in`, and the separate **proposed** API hostname is `https://api.madalasa.berhampore.in`. Both should resolve to the VM public IPv4 `161.33.146.238` only after DNS changes are confirmed. An existing DNS record or Nginx virtual host may already own the first hostname: **inspect and preserve current content before changing it**. No DNS, TLS certificate, or VM state was changed by recording this decision.

| DNS host | Proposed record | Purpose |
|---|---|---|
| `madalasa.berhampore.in` | A → `161.33.146.238` | Admin UI, same-origin `/v1/admin/*` only |
| `api.madalasa.berhampore.in` | A → `161.33.146.238` (new subdomain, owner DNS control pending) | Parent/child free-service API, deny admin routes |

API env `MA_ADMIN_ORIGIN=https://madalasa.berhampore.in`; backend remains local `127.0.0.1:8080`. Admin and API Nginx templates on `admin-web` use the hostnames and expected separate LetsEncrypt live certificate paths. **They will fail `nginx -t` until valid certificates exist.** Use a non-invasive HTTP-01 DNS/ACME procedure that keeps current port-80 websites, Nginx and mail services operational; do not assume Certbot is installed or replace existing certificates. Verify `dig +short A` for both hosts, detect public A/AAAA mismatches, check `sudo nginx -T` for duplicate `server_name`, and confirm ports 80/443 firewall rules before issuance. No automatic redirect, HSTS, or public publishing until the verified admin/auth flows pass.

## 1. Owner-provided host baseline (unverified by this assistant)
- Host label: `x402-endpoint`; public IPv4 **161.33.146.238**, private **10.0.0.89**.
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
1. Two DNS hostnames and DNS A records to 161.33.146.238, then issue legitimate TLS certificates for the actual names. Confirm the existing Nginx `80` vhost, ACME and all mail services remain working. Enable 443 at the provider/network firewall; do **not** close existing mail ports, widen 22, expose 8080/5432 or change MX.
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
