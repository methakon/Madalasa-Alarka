// Production guard for the database test-mode switch.
// ap_m1.local_test_settings.enabled turns on LOCAL_TEST_APPROVED verification, synthetic purchase evidence and
// synthetic session minting inside the schema. It must never be on where real families can reach the API.
// The runtime role cannot read the table, only the boolean exposed by ap_m1.test_mode_enabled() (migration 0032).
// A deployable (non-synthetic) build therefore checks it at start-up and every 30 seconds and, if it is on,
// answers 503 to every route except /healthz until it is switched off. A database that cannot be read, or that
// has no such function (the frozen M1 schema), is not treated as "on": routes that need the database already fail
// closed on their own.
#pragma once
#include <atomic>
#include <cstdlib>
#include <regex>
#include <string>
#include <drogon/drogon.h>

#include "db_support.h"

namespace ma {

inline std::atomic<bool>& test_mode_tripped() {
  static std::atomic<bool> tripped{false};
  return tripped;
}

// Same predicate as migration 0032's trigger.
inline bool database_is_disposable(const std::string& name) {
  static const std::regex re("^(madalasa_alarka_(dev|test)|ma_synthetic_[a-z0-9_]+)$");
  return std::regex_match(name, re);
}

// Pure decision so it can be unit-tested without a database. Only a deployable build with the switch on trips.
// The single exception is the CI harness that exercises the production-auth binary against a disposable database
// whose fixtures need the switch: it must opt in with MA_TEST_MODE_ALLOWED_IN_DISPOSABLE_DB=1 AND the database name
// must be a disposable one, so a stray variable in production changes nothing.
inline bool test_mode_must_block(bool synthetic_build, bool switch_enabled, bool harness_opt_in = false,
                                 const std::string& database = "") {
  if (synthetic_build || !switch_enabled) return false;
  return !(harness_opt_in && database_is_disposable(database));
}

inline bool path_exempt_from_test_mode_block(const std::string& path) { return path == "/healthz"; }

#ifdef MA_SYNTHETIC_AUTH
inline constexpr bool kSyntheticBuild = true;
#else
inline constexpr bool kSyntheticBuild = false;
#endif

inline void check_test_mode_switch() {
  if (kSyntheticBuild || !drogon::app().hasDbClient(kDbClientName)) return;
  auto db = drogon::app().getDbClient(kDbClientName);
  if (!db) return;
  db->execSqlAsync(
      "SELECT ap_m1.test_mode_enabled() AS enabled, current_database() AS db",
      [](const drogon::orm::Result& rows) {
        const bool on = !rows.empty() && rows.at(0)["enabled"].as<bool>();
        const char* opt = std::getenv("MA_TEST_MODE_ALLOWED_IN_DISPOSABLE_DB");
        const bool block = test_mode_must_block(kSyntheticBuild, on, opt != nullptr && std::string(opt) == "1",
                                                rows.empty() ? std::string() : rows.at(0)["db"].as<std::string>());
        const bool was = test_mode_tripped().exchange(block);
        if (block && !was) LOG_FATAL << "database test mode is ON in a deployable build: refusing all routes except /healthz";
        if (!block && was) LOG_WARN << "database test mode is now off: routes re-enabled";
      },
      [](const drogon::orm::DrogonDbException&) {});
}

inline void start_test_mode_guard() {
  if (kSyntheticBuild) return;
  drogon::app().registerBeginningAdvice([] {
    check_test_mode_switch();
    drogon::app().getLoop()->runEvery(30.0, [] { check_test_mode_switch(); });
  });
}

}  // namespace ma
