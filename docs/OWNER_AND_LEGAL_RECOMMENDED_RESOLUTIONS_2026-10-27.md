# Owner and legal items: recommended resolutions (2026-10-27)

**Status: PROPOSALS. Not approvals, not legal advice.** Engineering cannot close these. Each row gives a concrete recommended
answer so the owner can reply "approved" or edit it, plus what evidence closes it. Nothing here authorizes real child data.
Statements about Indian law and Google Play policy come from earlier research in this repo
([risk assessment](phases/M0-foundation-and-approvals/03-legal-and-privacy/INDIA_GOVERNMENT_LEGAL_GOOGLE_PLAY_PROJECT_RISK_ASSESSMENT_2026.md)) and were **not verified against primary
text**; counsel and Google must confirm them.

## 1. Decisions the owner can make now

| ID | Recommended answer | Closes when |
|---|---|---|
| **B-01** Publisher | Register an Indian company or LLP before creating the Play developer account, and publish under it (a private person as publisher makes DPDP data-fiduciary duties, Play organization verification and contracts with Oracle awkward). Use a role email for support and privacy, not a personal one. | Owner supplies legal name, entity type, registration number, support and privacy email. Do not put identity documents in GitHub. |
| **B-02** Launch scope | India only. Parent or guardian users must be 18 or older. Supported child age: **8 to 17** (below 8 is out of scope for the first release). Languages: English first. | Owner signs; counsel confirms the age policy under DPDP rules for children. |
| **B-07** Retention | Raw GPS 14 days. Trip history 90 days but **disabled** until counsel approves the purpose. App usage **off**. Audit log 365 days. Backups 30 days, so deleted data leaves backups within 30 days. Credential artifacts: see [C-05](M1_DEVICE_CREDENTIAL_LIFECYCLE.md). | Owner and counsel approve the table; then update the privacy policy and Data Safety worksheet. |
| **B-09 / B-18** Guardians | Only the verified family owner invites or revokes guardians. Access is per child. History is opt-in. Pickup access is current location only, 45 minutes. Disputes between guardians: handled by support with identity checks, out of scope for M1 software. | Owner approves; M1 database already implements the owner and per-child grant model. |
| **OCI-06** Login | Google Sign-In through Android Credential Manager, ID token verified by the backend. This proves an account, **not** that the person is an adult or a legal guardian, so add an in-app guardian declaration and ask counsel what consent method the DPDP rules require. | Owner approves vendor; counsel names the consent method. |
| **HW-01** Devices | Buy or assign at least: one recent Pixel or Samsung phone for the parent app, one older Android 10 to 12 phone for the child app, and one low-cost spare handset the owner agrees may be factory-reset for the managed-device proof. | Owner lists models. M1 physical acceptance cannot pass without them. |
| **B-21** Team and budget | Decide a funded runway number first. The break-even document says the proposed ₹50 per month and ₹500 per year pricing does not cover staffing. Recommendation: limit the first funded scope to M1 to M3, run a small free pilot only after the legal gates, and make **no price promise** until Play fees, tax, churn and support cost are recalculated. | Owner names people, budget and months of runway. |
| **SOS** | Ship best-effort **check-in only**. Public emergency SOS stays off. The app must say it is not an emergency service. | Owner confirms. A funded independent delivery path (SMS or vendor) is needed before any emergency claim. |
| **RPO / RTO** | Pilot targets: RPO 24 hours, RTO 48 hours. Before any real pilot, run one restore drill: restore the latest backup, taken to storage in the other Indian region, onto a fresh VM and pass the M1 SQL tests against it. Record the elapsed time. | Drill report committed, with times. |
| **Deletion SLA** | Complete deletion requests in 30 days. Backups roll off within the 30-day backup window. List legal holds on the public deletion page. | Counsel confirms the exceptions. |

## 2. Questions to send to counsel and to Google (written answers needed)

**Counsel (LEG-01, LEG-02, G02, G03):**
1. Does a parental child-safety location service fall within the DPDP rule exemption for real-time location, and does that cover stored history, app usage or inferred behavior?
2. What is acceptable verifiable consent from a parent or guardian, and how do we handle separated parents and disputed guardianship?
3. Which logs must be kept, for how long, and where (CERT-In 180 days India, DPDP rule log period)? What is the 6-hour incident reporting process?
4. Cross-border: is Mumbai hosting enough, and which processors (Google sign-in, FCM, Play Billing) transfer data outside India?
5. What does the privacy notice for a child need to say, in which languages?

**Google Play Support (G01), in writing, before any child GPS release:**
1. Alarka is installed on a child's phone by a parent. How must the target audience be declared?
2. Policy says apps that solely target children may not request location. Is there an exception for parental-control apps that are openly disclosed, show a persistent notification and carry the monitoring-tool flag?
3. Does the answer change for a separate parent app (Madalasa)?

Keep the replies as dated files in a private location and cite them in the blocker register. Do not publish counsel's advice.

## 3. Still not decided by anyone

Package names and application IDs are **permanent on Google Play** and must be chosen after B-01 (publisher and domain).
A software licence cannot be chosen by engineering: until the owner picks one, keep the repository private and add no licence file.
