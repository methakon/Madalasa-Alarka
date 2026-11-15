#include <cassert>
#include <array>
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
  // Every non-empty, non-"verify-full" mode must be rejected.
  assert(!ma::remote_pg_sslmode_allowed("disable"));
  assert(!ma::remote_pg_sslmode_allowed("allow"));
  assert(!ma::remote_pg_sslmode_allowed("prefer"));
  assert(!ma::remote_pg_sslmode_allowed("require"));
  assert(!ma::remote_pg_sslmode_allowed("verify-ca"));
  assert(!ma::remote_pg_sslmode_allowed("VERIFY-FULL"));
  assert(!ma::remote_pg_sslmode_allowed("unknown"));
  assert(!ma::remote_pg_sslmode_allowed(" "));
  return 0;
}
