# Responsible Vulnerability Disclosure — Madalasa–Alarka

**Status:** Reviewed draft (2026-10-27), contact/feature setup not verified.  
**Current implemented scope:** M1 contract, SQL migration, synthetic tenant-isolation test and docs; **no deployed production app/service or active bug bounty**. Child monitoring/media features are proposed and legal/Play gated.

## Confidential reporting (do NOT create a public security issue)

**Preferred channel if enabled:** Use GitHub repository **Security → Advisories → Report a vulnerability**:
https://github.com/methakon/Madalasa-Alarka/security/advisories

**Repository owner action REQUIRED:** Enable GitHub **Private vulnerability reporting** and verify a researcher can submit a private advisory. This has **not** been checked or enabled by creating this file. Until a working confidential channel is confirmed, do not put detailed exploit evidence, live tokens, child IDs, GPS or access logs into public issues or discussions. The publisher must publish a verified fallback security contact before a real-child pilot. **No security email or PGP key is invented here.**

Include affected file/component/commit, reproduction against **synthetic accounts only**, why it matters (child location exposure, guardian grant/tenant bypass, key compromise, media misuse, command forgery), minimal sanitized logs, and suggested mitigation. Do not test against real children, unrelated families, real production vendors, Android devices you do not own, or unauthorized services.

## Scope and handling

In scope after implementation: C++ Drogon controllers and workers, Android Alarka/Madalasa, PostgreSQL RLS/data deletion, batch ingress and GPS inbox/48h replay, pairing/authentication, admin case scope, signing/CI and release misconfigurations. At present only documents and M1 artifacts are available for reproducible tests.

Out of scope without prior written coordination: service interruption/DDoS or mass load, accessing other people's data, physical stalking/surveillance, social engineering, bypass of Android monitoring indicators, vendor products unrelated to project configuration. If accidentally encountering child data **stop access immediately** and report minimally without copying it.

**Targets not promises:** initial acknowledgment within 3 business days; first triage within 7 days; updates every 14 days if active. Critical incidents are escalated immediately to the incident owner under [MA-IR-001](docs/phases/M8-operational-readiness/02-operations-and-support/INCIDENT_AND_BREACH_RESPONSE_PROCEDURE.md). A 90-day coordinated disclosure period is a suggested starting point; negotiate exceptions when user safety demands faster action. The publisher must verify staffing and a monitored reporting channel first.

## Safe-harbor intent

We welcome authorized, good-faith research on self-owned synthetic test assets, without privacy invasion, persistence, covert surveillance or degradation. This policy is not permission to attack other infrastructure and cannot bind third-party services. No bounty is offered. Attribution by consent, protected identity by request.

## Owner security-release gate

- [ ] Enable and test GitHub private vulnerability reporting.
- [ ] Register an authenticated monitored backup security contact in repo About/privacy policy (no guessed address).
- [ ] Assign response owner/deputy and confidential evidence retention.
- [ ] Implement least-privilege code review, automated dependency/static/secret checks and tests.
- [ ] Conduct incident tabletop, RLS/child-scope and audit/recovery negative tests.
- [ ] Do not use real-minor data until India/Play and technical release gates close.

Security operations: [STRIDE](docs/phases/M1-secure-platform-foundation/03-security-and-permissions/THREAT_MODEL_STRIDE.md), [Incident Procedure](docs/phases/M8-operational-readiness/02-operations-and-support/INCIDENT_AND_BREACH_RESPONSE_PROCEDURE.md), [Signing/Keys](docs/phases/M1-secure-platform-foundation/03-security-and-permissions/APP_SIGNING_AND_KEY_MANAGEMENT_POLICY.md).
