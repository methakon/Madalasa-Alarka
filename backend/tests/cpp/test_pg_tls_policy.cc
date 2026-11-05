#include <cassert>
#include <string_view>
#include "pg_tls_policy.h"

int main() {
  assert(ma::pg_host_is_loopback("127.0.0.1"));
  assert(ma::pg_host_is_loopback("localhost"));
  assert(ma::pg_host_is_loopback("::1"));
  assert(!ma::pg_host_is_loopback("db.example.com"));
  assert(!ma::pg_host_is_loopback("127.0.0.2"));
  assert(ma::remote_pg_sslmode_allowed(""));
  assert(ma::remote_pg_sslmode_allowed("verify-full"));
  for (const auto mode : {"disable", "allow", "prefer", "require",
                          "verify-ca", "VERIFY-FULL", "unknown", " "}) {
    assert(!ma::remote_pg_sslmode_allowed(mode));
  }
  return 0;
}
