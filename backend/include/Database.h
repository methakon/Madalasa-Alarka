#pragma once
#include <drogon/orm/DbClient.h>
#include <json/json.h>
#include <stdexcept>
#include <string>

namespace madalasa {
struct ApiError : std::runtime_error {
    int status;
    std::string code;
    ApiError(int status_, std::string code_, const std::string &message)
        : std::runtime_error(message), status(status_), code(std::move(code_)) {}
};

// Configuration values are escaped as libpq values; secrets never enter logs.
std::string connectionInfoFromEnvironment();
bool validUuid(const std::string &value);

class Database {
 public:
    explicit Database(const std::string &connectionInfo);
    // Optional harness pin: when set, an opaque session that resolves to any
    // other principal is rejected. Requests still cannot select an identity.
    void expectPrincipal(std::string principalId);
    Json::Value profile(const std::string &token);
    Json::Value child(const std::string &token, const std::string &childId);
    Json::Value children(const std::string &token, const std::string &familyId,
                         const std::string &cursor, int limit);
    Json::Value consents(const std::string &token, const std::string &childId,
                         const std::string &cursor, int limit);
 private:
    std::string expected_principal_;
    std::shared_ptr<drogon::orm::DbClient> client_;
    std::shared_ptr<drogon::orm::Transaction> authenticated(const std::string &token);
};
}
