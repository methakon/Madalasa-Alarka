# Generated API DTOs & golden vectors (L03-012)

> **Scope:** describe how typed DTOs / schema validators are derived from the OpenAPI contract and how positive/negative golden vectors are kept in agreement across the Kotlin (Android) and C++ (backend) clients. Reuse-first: DTOs are **derived from the existing `docs/openapi.yaml` / `docs/openapi-m1.yaml` schemas**, not hand-written in parallel. LOCAL planning only; no live handler is implied.

**Task:** `L03-012`. **Verification type:** STATIC_REVIEW_AND_VALIDATOR.

## Source of truth

The single source for every request/response shape is the OpenAPI `components/schemas` in:
- `docs/openapi-m1.yaml` — the 14-operation M1 implementation contract (enumerated `Error.code`, `X-Request-Id`).
- `docs/openapi.yaml` — the whole-project planning contract (172 ops).

No client defines a DTO that is not backed by one of these schemas. When a schema changes, the clients regenerate; they do not drift by hand.

## Golden-vector agreement

A golden vector is a `(schema, input_json, expect)` triple where `expect` is `valid` or `invalid`. The same vector set is run against both client validators so a payload accepted by one is accepted by the other and vice-versa:

- **Backend (C++):** schema validation is exercised by the existing contract/validation tests under `backend/tests/` (e.g. capability and request-body validation) and by the OpenAPI linters that enforce `additionalProperties:false` and required-field integrity on every object schema.
- **Android (Kotlin):** request/response models mirror the same schemas; serialization round-trips the golden vectors.

Agreement rule: a golden vector's verdict (`valid`/`invalid`) MUST be identical across clients. A divergence is a contract bug, not a client bug.

## Negative vectors (fail-closed)

For each write operation the vector set includes at least one negative case that the contract must reject — unknown property (blocked by `additionalProperties:false`), missing required field, wrong type, or a trusted-state field that a client must never set (e.g. `verified`, `paid`, `approved`). The full linter already asserts that the four sensitive request schemas do not expose trusted-state fields; the golden vectors exercise that at payload level.

## How this is kept honest

- DTOs are generated/validated from the committed OpenAPI, which is CI-linted (`lint_openapi_m1.py`, `lint_openapi_full.py`) — both PASS.
- Cross-client agreement and undocumented/widened-property rejection are enforced by `backend/tests/openapi_contract_test.py` (L03-013).
- This README does not claim code generation has produced shipping clients; it records the derivation and agreement contract so DTOs cannot silently diverge from the spec.

## Related

- `docs/openapi.yaml`, `docs/openapi-m1.yaml`
- `docs/api/CONTRACT_DELTA.md`, `docs/api/check_contract_domains.py`, `docs/api/API_TRACEABILITY.csv`
- `backend/tests/openapi_contract_test.py` (L03-013)
