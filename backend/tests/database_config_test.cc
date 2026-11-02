#include "Database.h"
#include <cstdlib>
#include <iostream>

int main() {
    using madalasa::validUuid;
    if (!validUuid("a0000000-0000-4000-8000-000000000001") || validUuid("';DROP TABLE x;--")) return 1;
    setenv("DB_HOST", "db.production.invalid", 1);
    setenv("DB_PASSWORD", "synthetic-password", 1);
    try { (void)madalasa::connectionInfoFromEnvironment(); return 2; }
    catch (const std::runtime_error &) {}
    setenv("DB_HOST", "127.0.0.1", 1);
    setenv("DB_NAME", "production", 1);
    try { (void)madalasa::connectionInfoFromEnvironment(); return 3; }
    catch (const std::runtime_error &) {}
    setenv("DB_NAME", "madalasa_alarka_test", 1);
    setenv("DB_USER", "postgres", 1);
    try { (void)madalasa::connectionInfoFromEnvironment(); return 4; }
    catch (const std::runtime_error &) {}
    setenv("DB_USER", "madalasa_dev", 1);
    setenv("DB_PASSWORD", "synthetic'\\password", 1);
    const auto config = madalasa::connectionInfoFromEnvironment();
    if (config.find("password='synthetic\\'\\\\password'") == std::string::npos) return 5;
    setenv("DB_PORT", "15433", 1);
    if (madalasa::connectionInfoFromEnvironment().find("port='15433'")==std::string::npos) return 6;
    setenv("DB_NAME", "madalasa_alarka_dev", 1);
    try { (void)madalasa::connectionInfoFromEnvironment(); return 7; }
    catch (const std::runtime_error &) {}
    std::cout << "Database configuration boundaries and libpq escaping PASS\n";
}
