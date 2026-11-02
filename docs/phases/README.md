# Phase Documentation Index (M0–M9, P3, CROSS)

This directory organizes all canonical technical architecture, engineering specifications, legal analyses, and operational runbooks by project milestone phase.

## Phase Indexes

| Phase | Milestone Name | Focus & Scope | Category Directories |
|---|---|---|---|
| [**M0**](M0-foundation-and-approvals/README.md) | Foundation & Approvals | Project governance, market feasibility, DPDP legal consent, and risk registers | `01-project-governance`, `02-market-and-feasibility`, `03-legal-and-privacy` |
| [**M1**](M1-secure-platform-foundation/README.md) | Secure Platform Foundation | C++ Drogon API, Android baseline, permissions, Keystore auth, and developer standards | `01-requirements-and-architecture`, `02-development-process`, `03-security-and-permissions` |
| [**M2**](M2-location-collection/README.md) | Location Collection | Compliant GPS collection, 48h encrypted offline queue, and durable PostgreSQL inbox | `01-location-collection-and-ingestion` |
| [**M3**](M3-trips-and-places/README.md) | Trips & Places | PostGIS route geometries, trip reconstruction, and geofence state machines | `01-trips-and-places` |
| [**M4**](M4-usage-health-sos/README.md) | Usage, Health & SOS | Android UsageStats adapters, low-power health telemetry, and prioritized SOS escalation | `01-usage-health-and-sos` |
| [**M5**](M5-managed-android-controls/README.md) | Managed Android Controls | Eligible Device Owner policies, app suspensions, and managed profile enforcement | Phase status and policy notes |
| [**M6**](M6-guardian-erasure-security/README.md) | Guardian Erasure & Security | Per-child access grants, cryptographic erasure hooks, and account deletion workflows | `01-data-erasure-and-access` |
| [**M7**](M7-commercial-integrations/README.md) | Commercial Integrations | Child-seat subscription pricing, payment ledgers, and unit economics break-even | `01-commercial-plans-and-costing` |
| [**M8**](M8-operational-readiness/README.md) | Operational Readiness | OCI cloud infrastructure, incident response SOPs, backup/restore, and test matrices | `01-cloud-infrastructure`, `02-operations-and-support`, `03-quality-and-evidence` |
| [**M9**](M9-play-release/README.md) | Play Release | Google Play publishing criteria, Data Safety declarations, and public terms drafts | `01-play-and-data-safety`, `02-public-legal-drafts`, `03-release-gates` |
| [**P3**](P3-deferred-research/README.md) | Deferred Research | Deferred remote media experiments, activity audit telemetry, and back-office research | `01-media-and-administrator-research` |
| [**CROSS**](cross-milestone-references/README.md) | Cross-Milestone References | High-level system architecture diagrams and cross-milestone visual indexes | `01-architecture-and-visual-indexes` |
