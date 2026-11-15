// The production guard for the database test-mode switch: decision table, path exemption, and the
// pre-routing advice that enforces it. No database needed.
#include <drogon/drogon.h>
#include <iostream>
#include "test_mode_guard.h"

int main() {
  int failed = 0;
  auto check = [&](bool ok, const char* label) { if (!ok) { std::cerr << "FAIL " << label << '\n'; ++failed; } };
  check(ma::test_mode_must_block(false, true), "deployable build with switch ON is blocked");
  check(!ma::test_mode_must_block(false, false), "deployable build with switch off is served");
  check(!ma::test_mode_must_block(true, true), "synthetic test build may run with the switch on");
  check(!ma::test_mode_must_block(true, false), "synthetic build with switch off is served");
  // Harness opt-in only counts for a disposable database name.
  check(!ma::test_mode_must_block(false, true, true, "madalasa_alarka_test"), "opt-in honoured in the CI database");
  check(!ma::test_mode_must_block(false, true, true, "ma_synthetic_guard"), "opt-in honoured in ma_synthetic_*");
  check(ma::test_mode_must_block(false, true, true, "madalasa_alarka"), "opt-in ignored for a production name");
  check(ma::test_mode_must_block(false, true, true, "madalasa_alarka_test2"), "opt-in ignored for a near-miss name");
  check(ma::test_mode_must_block(false, true, true, ""), "opt-in ignored when the name is unknown");
  check(ma::test_mode_must_block(false, true, false, "madalasa_alarka_test"), "no opt-in: disposable name is still blocked");
  check(ma::database_is_disposable("madalasa_alarka_dev") && !ma::database_is_disposable("MADALASA_ALARKA_DEV") &&
        !ma::database_is_disposable("ma_synthetic_") && !ma::database_is_disposable("xma_synthetic_a"), "name predicate");
  check(ma::path_exempt_from_test_mode_block("/healthz"), "healthz stays reachable");
  for (const char* p : {"/v1/families", "/healthz/", "/healthz/x", "/v1/release/capabilities", "/", ""})
    check(!ma::path_exempt_from_test_mode_block(p), p);
  check(!ma::test_mode_tripped().load(), "guard starts untripped");
#ifndef MA_SYNTHETIC_AUTH
  check(!ma::kSyntheticBuild, "this binary is a deployable build");
#endif
  // Without a configured database the check must neither trip nor throw.
  ma::check_test_mode_switch();
  check(!ma::test_mode_tripped().load(), "no database configured does not trip");
  if (failed) return 1;
  std::cout << "test mode guard tests PASS\n";
  return 0;
}
