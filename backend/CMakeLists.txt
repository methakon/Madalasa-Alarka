cmake_minimum_required(VERSION 3.16)
project(madalasa_backend LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
add_compile_options(-Wall -Wextra -Wpedantic -Werror)

# Opt-in synthetic local read harness. CFamily: separate executable, never sources into ma_backend.
option(MA_LOCAL_DB_READ_PROBE "Build the loopback-only synthetic V2 read probe" OFF)

# Dependencies are built by backend/scripts/build_deps.sh; point CMAKE_PREFIX_PATH at its $PREFIX.
find_package(Drogon CONFIG REQUIRED)
find_package(OpenSSL 3.0 REQUIRED COMPONENTS Crypto)
if(EXISTS "${OPENSSL_INCLUDE_DIR}/x86_64-linux-gnu")
  include_directories("${OPENSSL_INCLUDE_DIR}/x86_64-linux-gnu")
endif()
find_package(CURL REQUIRED)
find_package(Threads REQUIRED)
enable_testing()

# Test-only header authentication. NEVER enable for a deployable build (see src/auth.h).
option(MA_SYNTHETIC_AUTH "Compile the synthetic test authenticator" OFF)

add_library(ma_admin_state STATIC src/admin/access_state.cc)
target_include_directories(ma_admin_state PUBLIC src)
target_link_libraries(ma_admin_state PUBLIC Drogon::Drogon)

add_library(ma_privacy_tombstones STATIC src/privacy/tombstones.cc)
target_include_directories(ma_privacy_tombstones PUBLIC src)

add_library(ma_core INTERFACE)
target_include_directories(ma_core INTERFACE src)
target_link_libraries(ma_core INTERFACE Drogon::Drogon ma_admin_state ma_privacy_tombstones)

add_executable(ma_backend src/main.cc)
add_library(ma_oidc src/google_oidc.cc src/google_jwks.cc)
target_include_directories(ma_oidc PUBLIC src)
target_link_libraries(ma_oidc PUBLIC Drogon::Drogon OpenSSL::Crypto PRIVATE CURL::libcurl Threads::Threads)
target_link_libraries(ma_backend PRIVATE ma_core ma_oidc)
if(MA_SYNTHETIC_AUTH)
  target_compile_definitions(ma_backend PRIVATE MA_SYNTHETIC_AUTH=1)
endif()

# x402 free-first deploy contract: loopback listener, FREE_ONLY, DB-aware readiness.
# Static source tests; never a substitute for live VM/TLS/DB checks.
add_test(NAME x402_deployment_contract
         COMMAND python3 -m unittest backend.tests.test_x402_deployment_contract -v)
set_tests_properties(x402_deployment_contract PROPERTIES WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/..)

# Frozen 14-operation OpenAPI surface must match real route registration.
# Static coverage alone cannot prove handlers are integrated or authorized.
add_test(NAME privacy_route_contract
         COMMAND python3 ${CMAKE_CURRENT_SOURCE_DIR}/tests/test_privacy_route_contract.py)

add_test(NAME m1_route_registration
         COMMAND python3 ${CMAKE_CURRENT_SOURCE_DIR}/tests/check_m1_route_coverage.py)

# Swagger UI is a separate LOCAL dev server, never linked into ma_backend.
add_test(NAME swagger_ui_local_security
         COMMAND python3 ${CMAKE_CURRENT_SOURCE_DIR}/tests/test_swagger_dev.py)

add_executable(test_pg_tls_policy tests/cpp/test_pg_tls_policy.cc)
target_include_directories(test_pg_tls_policy PRIVATE src)
add_test(NAME pg_tls_policy COMMAND test_pg_tls_policy)

add_executable(test_core tests/cpp/test_core.cc)
target_link_libraries(test_core PRIVATE ma_core)
add_test(NAME core COMMAND test_core)

add_executable(test_oidc tests/cpp/test_oidc.cc)
target_link_libraries(test_oidc PRIVATE ma_oidc)
add_test(NAME oidc COMMAND test_oidc)
add_executable(test_jwks tests/cpp/test_jwks.cc)
target_link_libraries(test_jwks PRIVATE ma_oidc)
add_test(NAME jwks COMMAND test_jwks)
add_executable(test_jwks_fetch tests/cpp/test_jwks_fetch.cc)
target_link_libraries(test_jwks_fetch PRIVATE ma_oidc)
add_test(NAME jwks_fetch COMMAND test_jwks_fetch)
add_executable(test_crypto tests/cpp/test_crypto.cc)
target_link_libraries(test_crypto PRIVATE ma_core OpenSSL::Crypto)
add_test(NAME crypto COMMAND test_crypto)

add_executable(test_capabilities_validation tests/cpp/test_capabilities_validation.cc)
target_link_libraries(test_capabilities_validation PRIVATE ma_core)
add_test(NAME capabilities_validation COMMAND test_capabilities_validation)

add_executable(test_device_endpoints tests/cpp/test_device_endpoints.cc)
target_link_libraries(test_device_endpoints PRIVATE ma_core OpenSSL::Crypto)
add_test(NAME device_endpoints COMMAND test_device_endpoints)

add_executable(test_mode_guard_test tests/cpp/test_mode_guard_test.cc)
target_link_libraries(test_mode_guard_test PRIVATE ma_core ma_oidc)
add_test(NAME test_mode_guard COMMAND test_mode_guard_test)

add_executable(billing_catalog_test tests/cpp/billing_catalog_test.cc)
target_link_libraries(billing_catalog_test PRIVATE ma_core ma_oidc)
add_test(NAME billing_catalog COMMAND billing_catalog_test)

add_executable(trial_policy_test tests/cpp/trial_policy_test.cc)
target_link_libraries(trial_policy_test PRIVATE ma_core ma_oidc)
add_test(NAME trial_policy_handler COMMAND trial_policy_test)

add_executable(test_children_read tests/cpp/test_children_read.cc)
target_link_libraries(test_children_read PRIVATE ma_core ma_oidc)
add_test(NAME children_read_negative COMMAND test_children_read)

add_executable(blended_family_test tests/blended_family_test.cc)
target_link_libraries(blended_family_test PRIVATE ma_core ma_oidc)
add_test(NAME blended_family_no_leak COMMAND blended_family_test)

add_executable(test_admin_faq tests/cpp/test_admin_faq.cc)
target_link_libraries(test_admin_faq PRIVATE ma_core ma_oidc)
add_test(NAME admin_faq_negative COMMAND test_admin_faq)

add_executable(test_admin_owner tests/cpp/test_admin_owner.cc)
target_link_libraries(test_admin_owner PRIVATE ma_core ma_oidc)
add_test(NAME admin_owner_negative COMMAND test_admin_owner)

add_executable(test_admin_applicant tests/cpp/test_admin_applicant.cc)
target_link_libraries(test_admin_applicant PRIVATE ma_core ma_oidc)
add_test(NAME admin_applicant_negative COMMAND test_admin_applicant)

add_executable(test_admin_session tests/cpp/test_admin_session.cc)
target_link_libraries(test_admin_session PRIVATE ma_core ma_oidc)
add_test(NAME admin_session_negative COMMAND test_admin_session)

add_executable(test_admin_access_state tests/cpp/test_admin_access_state.cc)
target_link_libraries(test_admin_access_state PRIVATE ma_core ma_oidc)
add_test(NAME admin_access_state_negative COMMAND test_admin_access_state)

add_executable(test_admin_auth tests/cpp/test_admin_auth.cc)
target_link_libraries(test_admin_auth PRIVATE ma_core ma_oidc)
add_test(NAME admin_auth_backoffice_negative COMMAND test_admin_auth)

add_executable(test_admin_oidc tests/cpp/test_admin_oidc.cc)
target_link_libraries(test_admin_oidc PRIVATE ma_core ma_oidc)
add_test(NAME admin_oidc_negative COMMAND test_admin_oidc)

add_executable(test_parent_session tests/cpp/test_parent_session.cc)
target_link_libraries(test_parent_session PRIVATE ma_core ma_oidc)
add_test(NAME parent_session_bridge_negative COMMAND test_parent_session)

add_executable(test_oidc_http tests/cpp/test_oidc_http.cc)
target_link_libraries(test_oidc_http PRIVATE ma_core ma_oidc)
add_test(NAME oidc_http COMMAND test_oidc_http)

if(MA_LOCAL_DB_READ_PROBE)
  add_library(ma_local_database src/Database.cc)
  # Probe-local: links the V2 read adapter; ma_backend never sees these sources.
  target_include_directories(ma_local_database PUBLIC include)
  target_link_libraries(ma_local_database PUBLIC Drogon::Drogon)
  add_executable(ma_local_db_read_probe src/local_db_read_probe.cc)
  target_link_libraries(ma_local_db_read_probe PRIVATE ma_local_database)
  add_executable(database_config_test tests/database_config_test.cc)
  target_link_libraries(database_config_test PRIVATE ma_local_database)
  add_test(NAME database_config COMMAND database_config_test)
endif()

# Phase 15: pure erasure state/fence tests (no database or credentials required).
add_executable(privacy_lifecycle_policy_test tests/cpp/privacy_lifecycle_policy_test.cc)
add_test(NAME privacy_lifecycle_policy COMMAND privacy_lifecycle_policy_test)

# Phase 15: authenticated deletion workflow and notices (202 Accepted, completed=false).
add_executable(test_deletion_workflow tests/cpp/test_deletion_workflow.cc)
target_link_libraries(test_deletion_workflow PRIVATE ma_core)
add_test(NAME deletion_workflow COMMAND test_deletion_workflow)

# Phase 15: parent/child device revocation before erasure and offline replay guard.
add_executable(test_device_revocation_before_erasure tests/cpp/test_device_revocation_before_erasure.cc)
target_link_libraries(test_device_revocation_before_erasure PRIVATE ma_core)
add_test(NAME device_revocation_before_erasure COMMAND test_device_revocation_before_erasure)

# Phase 10: founding family 1008 distinct paid counter & child inheritance.
add_executable(test_founding_family_counter tests/cpp/test_founding_family_counter.cc)
target_include_directories(test_founding_family_counter PRIVATE src)
add_test(NAME founding_family_counter COMMAND test_founding_family_counter)

# Free-first release must default to no payment or trial.
add_executable(test_free_release_profile tests/cpp/test_free_release_profile.cc)
add_test(NAME free_release_profile COMMAND test_free_release_profile)

# Phase 15: per-category retention stays fail-closed until an exact period is
# approved; the six-hour free window is a query bound, never a storage lifetime.
add_executable(test_retention_policy tests/cpp/test_retention_policy.cc)
add_test(NAME retention_policy COMMAND test_retention_policy)

# Phase 10: an expired prepaid balance or trial reverts to the free capability set
# with the documented reduced cadence, and no unspecified figure is invented.
add_executable(test_free_tier tests/cpp/test_free_tier.cc)
add_test(NAME free_tier COMMAND test_free_tier)

# Phase 15: the six-hour free visibility window is an access bound and stays
# independent of any storage/retention decision.
add_test(NAME history_visibility_contract
         COMMAND python3 -m unittest backend.tests.test_history_visibility_contract -v)
set_tests_properties(history_visibility_contract PROPERTIES WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/..)
