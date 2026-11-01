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

add_library(ma_core INTERFACE)
target_include_directories(ma_core INTERFACE src)
target_link_libraries(ma_core INTERFACE Drogon::Drogon)

add_executable(ma_backend src/main.cc)
add_library(ma_oidc src/google_oidc.cc src/google_jwks.cc)
target_include_directories(ma_oidc PUBLIC src)
target_link_libraries(ma_oidc PUBLIC Drogon::Drogon OpenSSL::Crypto PRIVATE CURL::libcurl Threads::Threads)
target_link_libraries(ma_backend PRIVATE ma_core ma_oidc)
if(MA_SYNTHETIC_AUTH)
  target_compile_definitions(ma_backend PRIVATE MA_SYNTHETIC_AUTH=1)
endif()

# Frozen 14-operation OpenAPI surface must match real route registration.
# Static coverage alone cannot prove handlers are integrated or authorized.
add_test(NAME m1_route_registration
         COMMAND python3 ${CMAKE_CURRENT_SOURCE_DIR}/tests/check_m1_route_coverage.py)

# Swagger UI is a separate LOCAL dev server, never linked into ma_backend.
add_test(NAME swagger_ui_local_security
         COMMAND python3 ${CMAKE_CURRENT_SOURCE_DIR}/tests/test_swagger_dev.py)

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

add_executable(test_children_read tests/cpp/test_children_read.cc)
target_link_libraries(test_children_read PRIVATE ma_core ma_oidc)
add_test(NAME children_read_negative COMMAND test_children_read)

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
