// Pure remote PostgreSQL TLS policy; never downgrade libpq verification.
#pragma once
#include <string_view>

namespace ma {
inline bool remote_pg_sslmode_allowed(std::string_view value) {
  // An unset mode is accepted only because startup installs verify-full.
  return value.empty() || value == "verify-full";
}
inline bool pg_host_is_loopback(std::string_view host) {
  return host == "127.0.0.1" || host == "localhost" || host == "::1";
}
}  // namespace ma
