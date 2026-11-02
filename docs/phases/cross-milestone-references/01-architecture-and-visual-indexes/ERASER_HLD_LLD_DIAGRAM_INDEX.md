# Madalasa–Alarka — Eraser.io HLD & LLD Diagram Registry

> **Document control:** CROSS / 01-architecture-and-visual-indexes · Proposed owner: Engineering lead (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

> **Current product:** **Madalasa** (parent app) + **Alarka** (child app); the GitHub repository is now **[Madalasa-Alarka](https://github.com/methakon/Madalasa-Alarka)**. [English mythological inspiration](../../M0-foundation-and-approvals/02-market-and-feasibility/BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md).

**Date:** 2026-10-26 · **Status:** 8 diagrams created and verified in connected Eraser team workspace, design diagrams only (not implemented).\n
**Eraser project file:** https://app.eraser.io/workspace/dP8nMbuaxaFXBkBzUHCv

| Diagram | Eraser link | Coverage |
|---|---|---|
| HLD — System Context & Trust Boundaries | [Open live diagram](https://app.eraser.io/workspace/dP8nMbuaxaFXBkBzUHCv?diagram=jQyWLWJX9S69ShFULHE3&layout=canvas) | Full ecosystem, Android, C++ backend, data stores, trust boundaries and India DPDP gating |
| HLD — OCI Mumbai Deployment & Disaster Recovery | [Open live diagram](https://app.eraser.io/workspace/dP8nMbuaxaFXBkBzUHCv?diagram=omtR3y1WBROQklllz6Hq&layout=canvas) | Single VM risk, backup/WAL, RPO/RTO targets and third-party transfer caveats |
| LLD — M1 Secure Enrollment & Key Proof | [Open live diagram](https://app.eraser.io/workspace/dP8nMbuaxaFXBkBzUHCv?diagram=QeyVOP0EH8QoyQ3BNQE2&layout=canvas) | Kotlin + Android Keystore PoP, pairing-code replay rejection and device revocation |
| LLD — M1 PostgreSQL Tenant-Isolation ERD | [Open live diagram](https://app.eraser.io/workspace/dP8nMbuaxaFXBkBzUHCv?diagram=k9ZQ2ixfKvGhhPO78e9f&layout=canvas) | M1 family/child/guardian grants, devices and forced RLS relationships |
| LLD — GPS Ingestion & Event-Time Reconstruction | [Open live diagram](https://app.eraser.io/workspace/dP8nMbuaxaFXBkBzUHCv?diagram=ghgtwzh38ovFtivtUg6h&layout=canvas) | Encrypted queue, durable ACK, C++ geo worker, uncertain route rendering, deletion |
| LLD — Guardian Authorization & Revocation | [Open live diagram](https://app.eraser.io/workspace/dP8nMbuaxaFXBkBzUHCv?diagram=Besc1tErcBahsMebk29v&layout=canvas) | Child-specific ACL, cross-family negative cases, pickup TTL, active stream invalidation |
| LLD — SOS Alert & Independent Fallback | [Open live diagram](https://app.eraser.io/workspace/dP8nMbuaxaFXBkBzUHCv?diagram=os70bsdV1d49u7CF93xd&layout=canvas) | FCM provider vs human acknowledgement, conditional SMS, offline limitations |
| LLD — Family Billing & Entitlements | [Open live diagram](https://app.eraser.io/workspace/dP8nMbuaxaFXBkBzUHCv?diagram=6ZY6KKV8Af9b2q27v3Q1&layout=canvas) | Proposed 50/500 family child-seat plans, Play verification, RTDN and refunds |

## Design caveats

- M1 design/migration exists; backend and Android runtime have not passed live implementation tests. No OCI account/VM or high availability service is provisioned.
- Preferred primary hosting OCI Mumbai ap-mumbai-1, alternate Hyderabad; legacy Chicago report is historical cost planning.
- India DPDP legal child-purpose, ages, publisher identity, guardian approvals and app-usage/history lawful processing remain **OPEN**; no real minor data authorized.
- SOS is at most a best-effort child-initiated check-in until funded independent fallback and tested guardian human acknowledgement.
- ₹50 monthly / ₹500 annual per child are **proposed**, not settled Play Console prices nor demonstrated fully-loaded profitable prices.
- M1 ERD is a logical visual of migration table relationships and authorizations, not proof that Postgres CI has passed. Diagram DSL remains editable in Eraser; source SQL and OpenAPI in repository are authoritative.

## Cross-reference

- [Single master milestone roadmap](../../M0-foundation-and-approvals/01-project-governance/MASTER_MILESTONE_IMPLEMENTATION_AND_RELEASE_PLAN.md)
- [M1-only API](../../../openapi-m1.yaml)
- [M1 PostgreSQL schema](../../../../backend/persistence/migrations/0001_m1_identity.sql)
- [Legal gate](../../M0-foundation-and-approvals/03-legal-and-privacy/INDIA_DPDP_CHILD_PRIVACY_AND_CROSS_BORDER_GATE.md)
- [OCI India selection](../../M0-foundation-and-approvals/03-legal-and-privacy/INDIA_REGION_AND_M0_OWNER_DECISION_GATE.md)
- [SOS fallback](../../M4-usage-health-sos/01-usage-health-and-sos/SOS_ESCALATION_AND_INDEPENDENT_DELIVERY_DESIGN.md)


## Live branding vs existing editable drawings

Architecture responsibilities are unchanged, but labels should be rebranded to **Madalasa** on parent clients and **Alarka** on child clients. The existing Eraser diagrams may retain older headings until visually edited; the new [product naming contract](../../M0-foundation-and-approvals/02-market-and-feasibility/BRAND_NAME_MADALASA_ALARKA_AND_MYTHOLOGY_CONCEPT.md) is authoritative. New GitHub repository is [Madalasa-Alarka](https://github.com/methakon/Madalasa-Alarka).

## Media HLD/LLD addition hosted in native editable Figma — 2026-10-26

The linked original **eight Eraser diagrams are unchanged**: Eraser returned "free AI credits used" when editing was attempted; the Eraser originals have **not** been silently replaced. To keep the architecture synchronized with [MA-MEDIA-ADR-001](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_CAPABILITY_PARENT_REASON_AND_RUNTIME_DECISION_2026.md), two **native editable Figma diagrams** were created instead: [Conditional media HLD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=21-3) (P2P, TURN, no VPS media storage, standard/managed Android trust boundaries) and [Conditional media LLD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=21-41) (guardian grant, runtime checks, session status/reason codes, Android screen-share consent). Eight additional parent/child research UX screens are indexed in [Figma UI handoff](../../../ui/figma-functional-handoff/README.md). All media functionality remains RESEARCH P3 / not implemented / no commercial approval.

## 2026-10-27 capability scan and permission-sync HLD/LLD in Figma

The original eight Eraser diagrams remain **unchanged** (Eraser AI editing credits unavailable). The verified new architecture additions are native editable Figma frames on the existing file: [HLD — Alarka device hardware/permission discovery, authenticated Drogon reporting, post-ACK Madalasa child-scoped compatibility dashboard](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=27-2); [LLD — stepwise Android grants, OS readback, monotonic revision, durable server ACK, parent stale/offline/revoked/reapproved UI, Android process-kill edge cases](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=27-40). Complementary [46 editable parent/child capability screens](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=23-2) are inventoried in [06-capability-onboarding.json](../../../ui/figma-functional-handoff/06-capability-onboarding.json). **Design only, not implemented or Play/India legally approved.** Source: [MA-CAP-ADR-002](../../M1-secure-platform-foundation/03-security-and-permissions/CAPABILITY_DISCOVERY_PERMISSION_SYNC_ADR_2026-10-27.md).

## 2026-10-27 metadata-only media audit HLD/LLD and new admin-panel Figma designs

The original **eight Eraser diagrams remain unchanged**; earlier connected Eraser AI editing credits were exhausted and no Eraser update is claimed. To maintain new editable system design alongside related Figma UI, added [Media Activity Auditing HLD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=35-2) and [Media Activity Admin/Parent Query LLD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=35-56) as native Figma frames. Coverage: Alarka/parent signed start/stop/playback/local-save events, C++ Drogon authorization and idempotent append, PostgreSQL metadata-only projection, VIEWED_ONLY vs SAVED_PARENT_LOCAL, file_size_bytes NULL for live-only, evidence-grounded errors, secured parent child dropdown and case-gated admin autocomplete/filter/pagination with separate access-audit fail-closed write. No binary media storage, no admin access to parent-local files. [28 parent/admin editable screens](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=32-2) and [node index](../../../ui/figma-functional-handoff/07-media-activity-audit.json). Canonical docs: [media audit](../../P3-deferred-research/01-media-and-administrator-research/MEDIA_ACTIVITY_AUDIT_LOGGING_AND_REPORTING_2026.md), [admin console](../../P3-deferred-research/01-media-and-administrator-research/ADMIN_PANEL_SPECIFICATION_2026.md). **NOT IMPLEMENTED / NOT TESTED**.

## 2026-10-27 GPS intake, 48h offline buffer and PostgreSQL bulk-insert HLD/LLD

**Actual editable diagrams saved in Figma (not Eraser):** [GPS ingestion HLD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=41-2), [durable inbox + C++ bulk insert LLD](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=41-60) and [direct bulk vs inbox benchmark/tradeoff](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=41-126). Source [MA-INGEST-ADR-004](../../M2-location-collection/01-location-collection-and-ingestion/POSTGRES_DURABLE_INBOX_BULK_GPS_USAGE_INGESTION_ADR_2026-10-27.md), exact [Figma node index](../../../ui/figma-functional-handoff/08-postgres-gps-batch-system-design.json). These show Alarka encrypted 48h offline capacity, 1–2min eligible JSON upload target, PostgreSQL per-batch durable inbox 202, SKIP LOCKED C++ worker combining many GPS records for multirow/COPY staging bulk insert, atomic raw/dedup/outbox Tx B and crash recovery. Redis not required initially; direct bulk insert retains a benchmark path because inbox consumes additional WAL/storage. **Original eight Eraser HLD/LLD diagrams remain unchanged**; Figma frames supply the new editable system design. No code, migration or device proof implied.
