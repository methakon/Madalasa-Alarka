// Error catalog from docs/API_CONVENTIONS_AND_ERROR_CATALOG.md section 5.2 (12 codes).
// tests/test_error_catalog_sync.py keeps this table equal to the OpenAPI Error.code enum and the document table.
#pragma once
#include <array>
#include <optional>
#include <string_view>

namespace ma {

struct ErrorSpec {
  std::string_view code;
  int http_status;
  bool retryable;  // default; CONFLICT may be raised with retryable=true by the caller (lock_timeout case)
};

// SYNC-BEGIN
inline constexpr std::array<ErrorSpec, 12> kErrors{{
    {"INVALID_REQUEST", 400, false},
    {"UNAUTHENTICATED", 401, false},
    {"FORBIDDEN", 403, false},
    {"NOT_FOUND", 404, false},
    {"CONFLICT", 409, false},
    {"IDEMPOTENCY_KEY_REUSED", 409, false},
    {"CODE_EXPIRED_OR_USED", 410, false},
    {"PAYLOAD_TOO_LARGE", 413, false},
    {"VALIDATION_FAILED", 422, false},
    {"RATE_LIMITED", 429, true},
    {"INTERNAL_ERROR", 500, false},
    {"SERVICE_UNAVAILABLE", 503, true},
}};
// SYNC-END

constexpr std::optional<ErrorSpec> find_error(std::string_view code) {
  for (const auto& e : kErrors)
    if (e.code == code) return e;
  return std::nullopt;
}

}  // namespace ma
