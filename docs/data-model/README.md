# Data Model & Relational Schema Library

This directory maintains the logical and physical data models, foreign key relationships, and schema audit records for the Madalasa–Alarka platform.

## Artifacts

| Document / Asset | Description | Format |
|---|---|---|
| [Logical ERD Specification](MADALASA_ALARKA_FIGMA_LOGICAL_ERD_V1_2026.md) | Authoritative logical entity-relationship diagrams across all 11 domains with Mermaid visualizations | Markdown |
| [Logical ERD Definition](MADALASA_ALARKA_FIGMA_LOGICAL_ERD_V1_2026.json) | Machine-readable entity, column, foreign key, and domain catalog extracted from design sources | JSON |
| [Figma Screen-to-Physical Review](FIGMA_SCREEN_GAP_PHYSICAL_SCHEMA_REVIEW_2026-10-28.md) | Gap analysis connecting Figma screens to physical PostgreSQL storage tables | Markdown |
| [Physical Schema Deep Audit](PHYSICAL_SCHEMA_DEEP_AUDIT_AND_REMEDIATION_2026-10-29.md) | Relational integrity verification, dangling reference resolutions, and migration execution plan | Markdown |

## Domains Covered
1. **Domain 01:** Family identity, child-scoped V2 cross-family grants, and lawful authority
2. **Domain 02:** Device identity, hardware capabilities, and key rotations
3. **Domain 03:** Geofences, named places, and location observations
4. **Domain 04:** Trips, route geometries, and commute plans
5. **Domain 05:** Screen time rules, app limits, and category suspensions
6. **Domain 06:** Notifications, dispatch logs, and read receipts
7. **Domain 07:** Commercial plans, subscriptions, and billing ledgers
8. **Domain 08:** Audit logging, security events, and compliance exports
9. **Domain 09:** SOS signals, emergency escalations, and incident receipts
10. **Domain 10:** Remote media controls, device consent, and session audit
11. **Domain 11:** Support tickets, FAQ topics, and admin portal roles
