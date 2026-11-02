// Positive bounded DB limits. Invalid runtime configuration fails startup closed.
#pragma once
#include <charconv>
#include <cstdlib>
#include <stdexcept>
#include <string_view>

namespace ma {
inline unsigned db_env_limit(const char* name, unsigned fallback, unsigned maximum) {
  const char* text = std::getenv(name);
  if (!text) return fallback;
  const std::string_view value(text);
  unsigned parsed = 0;
  const auto result = std::from_chars(value.data(), value.data() + value.size(), parsed);
  if (result.ec != std::errc{} || result.ptr != value.data() + value.size() || parsed == 0 || parsed > maximum)
    throw std::invalid_argument(name);  // name only, never echo configuration values
  return parsed;
}

struct DbLimits {
  unsigned client_ms;
  unsigned statement_ms;
  unsigned lock_ms;
  unsigned connections;
  unsigned port;
  double client_seconds() const { return static_cast<double>(client_ms) / 1000.0; }
};

inline const DbLimits& db_limits() {
  static const DbLimits limits = [] {
    DbLimits result{db_env_limit("MA_PG_TIMEOUT_MS", 6000, 60000),
                    db_env_limit("MA_PG_STATEMENT_TIMEOUT_MS", 5000, 60000),
                    db_env_limit("MA_PG_LOCK_TIMEOUT_MS", 1000, 60000),
                    db_env_limit("MA_PG_CONNECTIONS", 4, 64),
                    db_env_limit("MA_PG_PORT", 5432, 65535)};
    if (result.lock_ms >= result.statement_ms)
      throw std::invalid_argument("MA_PG_LOCK_TIMEOUT_MS must be below statement timeout");
    return result;
  }();
  return limits;
}
}  // namespace ma
