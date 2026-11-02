# Third-Party Dependencies, Licensing and SBOM Register

> **Document control:** M1 / 02-development-process · Proposed owner: Engineering lead (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

**Status:** Preliminary inventory of **planned or discussed** dependencies, not a generated SBOM or proof a runtime dependency is installed. The only currently verified CI runtime dependencies are Python stdlib tooling, PostgreSQL 16 service and GitHub Actions checkout workflow.

| Component | Proposed purpose | License/commercial review | Status and evidence needed |
|---|---|---|---|
| Android SDK / AndroidX / Kotlin / Jetpack Compose | Alarka and Madalasa apps | Android SDK terms; Kotlin/AndroidX mostly Apache-2.0 components; audit exact versions | PLANNED, no Gradle lockfiles |
| Android Google Play services Location / Maps SDK / FCM | GPS, parent map, notifications | Google API/Maps Platform/FCM terms, telemetry and map asset restrictions | PLANNED; processor/data transfer review |
| C++20 toolchain, CMake/Ninja | Backend builds | GNU/LLVM/CMake licenses by actual distribution | PLANNED; no CMakeLists |
| Drogon | C++ async HTTP/backend framework | Verify pinned release LICENSE (commonly MIT) and transitive components | PLANNED |
| PostgreSQL | Identity, child scopes, GPS inbox/raw | PostgreSQL License | M1 PostgreSQL 16 CI only |
| PostGIS | Spatial types/query | GPL-2.0-or-later components and library boundaries; verify exact distribution and notices | PLANNED for location schema |
| libpq, OpenSSL | PostgreSQL/TLS | PostgreSQL/OpenSSL license notices; build variants | PLANNED |
| WebRTC and TURN (e.g. coturn) | Parent direct/relay media when lawful | WebRTC BSD-style; coturn BSD-style; transitive dependency review | RESEARCH OFF |
| SQLCipher or approved encryption library | Encrypted Alarka 48h local queue | Verify actual variant/license and Android distribution integration | PLANNED, plaintext SQLite insufficient |
| Google Play Billing | Paid child seats/subscriptions | Play Billing APIs/merchant/refund policy | DRAFT pricing, not released |
| OCI compute/network/storage | Backend, Postgres backups and monitoring | Oracle contract/DPA, regions, costs | CHICAGO/MUMBAI DECISION OPEN |
| Google OIDC / Drive | Adult guardian login, optional scoped backup | Google OAuth verification, sensitive/restricted scopes | PLANNED |
| Third-party SMS or email provider | SOS fallback/notifications | Vendor DPA and real deliverability | UNSELECTED |

**Never copy this list into a shipping BOM as though packages already exist.** For each actual dependency capture package coordinates, exact version, source/repo, SHA/signature, SPDX license, notice/patent obligations, source/binary distribution effect, CVE severity and mitigation, child-data flow, transitive dependencies, update EOL and approving owner.

### When sources exist
Generate machine-readable **CycloneDX JSON** and/or **SPDX JSON** for Kotlin Gradle resolved runtime+build graph, C++ package manager/CMake linked binary tree, container layers and OCI images. Version these in private release artifacts with hashes/signatures and link to release record; don't commit secrets/private customer data. Pin/review GitHub Actions and transitive supply chain. Run automated dependency vulnerability+license checks on each PR and before release; triage exploitability rather than suppress CVEs blindly.

### Licensing gate
Repository root LICENSE is an interim all-rights-reserved holding notice and is **not** an approved open-source license. The project needs an explicit publisher/IP-owner decision, separate from third-party licenses. See [Licensing decision](../../M0-foundation-and-approvals/03-legal-and-privacy/LICENSING_DECISION_AND_IP_REGISTER.md).

**Owner assignments, exact dependency versions, SBOM generation and acceptance: OPEN.**
