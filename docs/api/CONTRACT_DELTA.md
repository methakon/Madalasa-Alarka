# API Contract Delta — M1 vs whole-project OpenAPI (L03-001)

> **Scope:** reconcile the narrow M1 contract and the whole-project contract **without claiming live handlers**. Both specifications already exist and are CI-linted; this document records how they relate and the deliberate differences, so a reader never mistakes a drafted operation for an implemented one. LOCAL planning only.

**Task:** `L03-001`. **Reuse-first:** this reconciles the two **existing** flat specs; it does not fragment or regenerate them.

## The two authoritative contracts

| Spec | Purpose | Ops / paths | Auth schemes | Error model | Lint |
|---|---|---|---|---|---|
| `docs/openapi-m1.yaml` | M1 secure-foundation milestone subset | 14 ops / 12 paths | `ParentOIDC`, `DeviceBearer` | `Error.code` **enumerated** (12-code catalog); `X-Request-Id` on every response; `Retry-After` on 429; componentized `IdempotencyKey` parameter | `backend/tests/lint_openapi_m1.py` PASS |
| `docs/openapi.yaml` | Whole-project planning contract | 172 ops / 156 paths | `ParentBearer`, `DeviceBearer`, `AdminBearer`, `AdminApplicantBearer` | `Error` envelope requires `code`,`message`,`request_id` (code is free string, no enum); correlation via body `request_id`; `Idempotency-Key` inlined per op | `backend/tests/lint_openapi_full.py` PASS |

Both are OpenAPI 3.1.0, JSON-encoded (valid YAML 1.2), single `https://api.example.invalid/v1` server.

## Reconciliation decision (C-10)

Per the conflict register C-10 and owner direction: **implement the M1 contract first, then domain extensions; the full spec is the planning superset, not a set of live handlers.** The authoritative implementation contract today is M1 (14 operations). The full spec's 172 operations are drafted with explicit `x-implementation-status` gating — only **2** are `VERIFIED_IMPLEMENTED`; the rest are PROPOSED/DRAFT/RESEARCH/BLOCKED. No path in either spec is a guarantee of a working handler.

## Deliberate differences (not defects)

1. **operationId naming:** the 14 M1 operationIds (`createFamily`, `recordCapabilities`, …) do **not** literally appear in the full spec, which uses auto-generated style (`post_devices_deviceId_capabilities`, `get__admin_faqs`). They are the **same capabilities under different ids** — M1 is a conceptual, not mechanically-sliced, subset. A future codegen/versioning ADR should converge the naming; until then, treat M1 operationIds as the stable contract names.
2. **Auth scheme names:** M1 `ParentOIDC` vs full `ParentBearer`. The full spec's `ParentBearer` describes the V2 opaque-session default (`POST /auth/parent/google`) with historical direct-OIDC behind `MA_PARENT_AUTH_MODE=m1_direct_oidc`. Same principal, evolved mechanism.
3. **Error catalog:** M1 enumerates the 12 error codes and declares `X-Request-Id`/`Retry-After` headers; the full spec carries `request_id` in the body but does not yet enumerate `code` or declare the header. **Gap recorded** (see Open items) — the full spec should adopt the enumerated catalog and header when its operations are implemented; it is not a blocker for the draft.

## Issuer isolation (verified)

The full spec partitions every operation to exactly one issuer (no operation mixes parent/device/admin bearers): ParentBearer 106, AdminBearer 39, DeviceBearer 13, AdminApplicantBearer 8, and 6 explicitly public/anonymous (auth bootstrap, `/service/status`, published `/faqs`). Verified by `docs/api/check_contract_domains.py` (L03-002).

## Open items (recorded, not resolved here)

- Converge operationId naming and auth-scheme names between M1 and full spec via a versioning ADR before codegen.
- Adopt the enumerated `Error.code` catalog and `X-Request-Id` header into the full spec as operations move from PROPOSED to implemented.
- The "47 paths" figure in historical notes is superseded: the live full spec is 156 paths / 172 ops.

## Related

- `docs/openapi.yaml`, `docs/openapi-m1.yaml`
- `backend/tests/lint_openapi_m1.py`, `backend/tests/lint_openapi_full.py`
- `docs/api/check_contract_domains.py` (domain acceptance verifier, L03-002..010)
- `docs/api/API_TRACEABILITY.csv` (L03-014) · `generated/api/README.md` (L03-012)
- `docs/roadmap/SOURCE_REFERENCE_AND_CONFLICT_REGISTER_2026-10-28.md` (C-10)
