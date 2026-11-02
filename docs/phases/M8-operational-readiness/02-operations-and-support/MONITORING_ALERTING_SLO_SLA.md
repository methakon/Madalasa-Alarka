# Monitoring, Alerting and Service Objectives — Proposed

> **Document control:** M8 / 02-operations-and-support · Proposed owner: SRE + incident lead (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

**Status:** SLO planning, no production telemetry. Monitoring must avoid raw GPS/child identities, app package names, command media payloads and account secrets.

## Service boundaries
Measure **independently**: (a) parent auth/API availability, (b) child device enrollment and scope verification, (c) GPS durable inbox acceptance, (d) inbox-to-raw processing lag, (e) derived trip route freshness, (f) UsageStats aggregation completeness, (g) SOS request delivery receipts, (h) media and admin audit denial/availability, and (i) restore readiness. A single VM has a shared failure domain and no high-availability claim.

| SLI | Proposed initial SLO / alert | Caveat |
|---|---|---|
| Parent API synthetic successful authorized reads | candidate 99.5% monthly; page on prolonged 5xx or p95 regression | Not an actual SLA; excludes planned maintenance only after policy |
| Durable GPS intake receipt p95 | experiment target under 1 second with synthetic moderate load | 202 must follow Tx A PostgreSQL inbox COMMIT |
| GPS oldest pending inbox age | warn 5 minutes, critical 15 minutes when workers healthy | Initial thresholds, tune with load and normal legal data cadence |
| Raw/route reconstruction lag | warn 15 minutes, critical 1 hour, with delayed/48h replay separately measured | Don't mark backfilled data as live |
| Parent's last verified position age | show age per child and suppress false live indicator; aggregate alert on systemic regression | No blanket device-online guarantee (Doze/offline/GPS disabled) |
| Child local queue capacity | event count/bytes/oldest unacked age, warn before exceeding 48h capacity target | Device reporting itself may be offline |
| Auth/RLS denials | count sudden elevated wrong-family, sibling scope and admin case violations | Security paging but redact family/child |
| Admin detailed read audit | zero unaudited sensitive reads; fail closed on audit write loss | No root override |
| Backup age and restore-test status | page if backups overdue; scheduled quarterly synthetic restore | Proposed backup cadence after owner approval |
| Signing/secret rotation | track expiry and unexpected use | Actual keys not provisioned |

**Alerts:** SEV1 suspected unauthorized child location exposure, missing sensitive audit, signing key compromise, GPS ACKs without commits, disk full/backups lost. SEV2 prolonged batch ingestion lag, repeated worker crashes, parents showing stale as live. SEV3 individual OS device/permission issues. Include service, runbook, sanitized request ID, alert start UTC, last known severity and owner. Assign on-call coverage before activating paging.

## Telemetry design
OpenTelemetry-style trace IDs spanning authenticated batch_id/inbox row/worker/outbox, no raw payloads. Prometheus-compatible counters/histograms for in-progress batches, WAL MB/s, DB CPU/locks/IOPS, p95/p99 request latency, retry/quarantine counts, API 401/403/429/503, backup age and device cohort aggregate. Use low-cardinality labels (service, release, error code, region) rather than userId/childId/deviceId. Log sensitive forensic specifics only to restricted, India-compliant ICT security/audit storage as appropriate.

**SLA:** No customer-facing availability, real-time GPS, SOS delivery or response-time contractual SLA is approved. Do not publish speculative uptime as a product promise. Review when service is deployed, staffed, measured and risk-assessed.
