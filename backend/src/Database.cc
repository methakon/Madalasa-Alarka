#include "Database.h"

#include <algorithm>
#include <cctype>
#include <cstdlib>
#include <sstream>

namespace madalasa {
namespace {
std::string environment(const char *key, const std::string &fallback) {
    const char *value = std::getenv(key);
    return value ? value : fallback;
}
std::string quote(const std::string &value) {
    std::string result = "'";
    for (const char c : value) {
        if (c == '\'' || c == '\\') result += '\\';
        result += c;
    }
    return result + "'";
}
Json::Value jsonResult(const drogon::orm::Result &result) {
    if (result.empty() || result[0][0].isNull()) throw ApiError(404, "NOT_FOUND", "Object not found");
    Json::Value value;
    Json::CharReaderBuilder builder;
    std::string errors;
    std::istringstream input(result[0][0].as<std::string>());
    if (!Json::parseFromStream(builder, input, &value, &errors)) throw ApiError(503, "DATABASE_UNAVAILABLE", "Database response unavailable");
    return value;
}
void validateId(const std::string &id) {
    if (!validUuid(id)) throw ApiError(400, "INVALID_REQUEST", "Invalid object identifier");
}
void validatePage(const std::string &cursor, const int limit) {
    if ((!cursor.empty() && !validUuid(cursor)) || limit < 1 || limit > 100) throw ApiError(400, "INVALID_REQUEST", "Invalid pagination");
}
}

bool validUuid(const std::string &value) {
    if (value.size() != 36) return false;
    for (std::size_t i = 0; i < value.size(); ++i) {
        if (i == 8 || i == 13 || i == 18 || i == 23) { if (value[i] != '-') return false; }
        else if (!std::isxdigit(static_cast<unsigned char>(value[i]))) return false;
    }
    return true;
}

std::string connectionInfoFromEnvironment() {
    const auto host = environment("DB_HOST", "127.0.0.1");
    const auto database = environment("DB_NAME", "madalasa_alarka_dev");
    const auto user = environment("DB_USER", "madalasa_dev");
    const auto password = environment("DB_PASSWORD", "");
    const auto port = environment("DB_PORT", "15432");
    if (host != "127.0.0.1" ||
        !(port == "15432" || (database == "madalasa_alarka_test" && (port == "15433" || port == "15434"))) ||
        (database != "madalasa_alarka_dev" && database != "madalasa_alarka_test") ||
        user != "madalasa_dev" || password.empty())
        throw std::runtime_error("Local backend requires named loopback database and restricted runtime role");
    return "host=" + quote(host) + " port=" + quote(port) + " dbname=" + quote(database) +
           " user=" + quote(user) + " password=" + quote(password) +
           " sslmode=disable connect_timeout=5 application_name=madalasa-backend";
}

Database::Database(const std::string &connectionInfo)
    : client_(drogon::orm::DbClient::newPgClient(connectionInfo, 2)) {
    client_->setTimeout(5.0);
    const auto result = client_->execSqlSync("SELECT current_user, rolsuper, rolbypassrls FROM pg_roles WHERE rolname=current_user");
    if (result.empty() || result[0][0].as<std::string>() != "madalasa_dev" ||
        result[0][1].as<bool>() || result[0][2].as<bool>())
        throw std::runtime_error("Backend database role is not restricted");
}

void Database::expectPrincipal(std::string principalId) {
    if (!validUuid(principalId)) throw std::runtime_error("Expected principal must be a UUID");
    expected_principal_ = std::move(principalId);
}

std::shared_ptr<drogon::orm::Transaction> Database::authenticated(const std::string &token) {
    if (token.size() < 32 || token.size() > 2048 || token.find_first_of("\r\n\0", 0, 3) != std::string::npos)
        throw ApiError(401, "AUTHENTICATION_REQUIRED", "Valid server-issued session required");
    auto tx = client_->newTransaction();
    if (!tx->execSqlSync("SELECT ma_recovery.database_open()")[0][0].as<bool>()) {
        tx->rollback(); throw ApiError(503,"RESTORE_QUARANTINED","Database recovery is incomplete");
    }
    // The token is opaque and hash-checked against issuer-only session storage.
    // Neither URL nor request body can select an adult, family or device identity.
    tx->execSqlSync("SELECT set_config('ap.session_token',$1,true)", token);
    // Identity is the opaque session row only; the caller never supplies it.
    // An optional harness pin narrows acceptance further and can never widen it.
    const auto actor = tx->execSqlSync("SELECT ap_m1.ctx_principal()::text, ap_m1.ctx_device()");
    if (actor.empty() || actor[0][0].isNull() || !actor[0][1].isNull() ||
        (!expected_principal_.empty() && actor[0][0].as<std::string>() != expected_principal_)) {
        tx->rollback(); throw ApiError(401, "AUTHENTICATION_REQUIRED", "Valid parent session required");
    }
    return tx;
}

Json::Value Database::profile(const std::string &token) {
    auto tx = authenticated(token);
    return jsonResult(tx->execSqlSync(R"SQL(
      SELECT jsonb_build_object('adult_id',p.id,'family_ids',
        COALESCE((SELECT jsonb_agg(m.family_id ORDER BY m.family_id)
          FROM ap_m1.guardian_memberships m WHERE m.principal_id=p.id AND m.revoked_at IS NULL),'[]'::jsonb))::text
      FROM ap_m1.parent_principals p WHERE p.id=ap_m1.ctx_principal()
    )SQL"));
}

Json::Value Database::child(const std::string &token, const std::string &childId) {
    validateId(childId);
    auto tx = authenticated(token);
    return jsonResult(tx->execSqlSync(R"SQL(
      SELECT jsonb_build_object('id',id,'family_id',family_id,'alias',alias)::text
      FROM ap_m1.children WHERE id=$1::uuid
    )SQL", childId));
}

Json::Value Database::children(const std::string &token, const std::string &familyId,
                               const std::string &cursor, const int limit) {
    validateId(familyId); validatePage(cursor,limit);
    auto tx = authenticated(token);
    const auto membership = tx->execSqlSync("SELECT EXISTS(SELECT 1 FROM ap_m1.guardian_memberships WHERE family_id=$1::uuid AND principal_id=ap_m1.ctx_principal() AND revoked_at IS NULL)", familyId);
    if (!membership[0][0].as<bool>()) throw ApiError(404,"NOT_FOUND","Object not found");
    auto value = jsonResult(tx->execSqlSync(R"SQL(
      SELECT jsonb_build_object('items',COALESCE(jsonb_agg(jsonb_build_object('id',id,'family_id',family_id,'alias',alias) ORDER BY id),'[]'::jsonb), 'as_of',statement_timestamp())::text
      FROM (SELECT id,family_id,alias FROM ap_m1.children WHERE family_id=$1::uuid
        AND (NULLIF($2,'') IS NULL OR id>NULLIF($2,'')::uuid) ORDER BY id LIMIT $3::integer) q
    )SQL", familyId,cursor,limit+1));
    auto &items = value["items"];
    value["next_cursor"] = Json::nullValue;
    if (items.size() > static_cast<Json::ArrayIndex>(limit)) {
        value["next_cursor"] = items[limit-1]["id"];
        Json::Value discarded; items.removeIndex(static_cast<Json::ArrayIndex>(limit), &discarded);
    }
    return value;
}

Json::Value Database::consents(const std::string &token, const std::string &childId,
                               const std::string &cursor, const int limit) {
    validateId(childId); validatePage(cursor,limit);
    auto tx = authenticated(token);
    if (tx->execSqlSync("SELECT 1 FROM ap_m1.children WHERE id=$1::uuid",childId).empty()) throw ApiError(404,"NOT_FOUND","Object not found");
    auto value = jsonResult(tx->execSqlSync(R"SQL(
      SELECT jsonb_build_object('items',COALESCE(jsonb_agg(value ORDER BY id),'[]'::jsonb),'as_of',statement_timestamp())::text
      FROM (SELECT c.id,jsonb_build_object('id',c.id,'child_id',c.child_id,'purpose',c.purpose,
        'notice_version',COALESCE(to_jsonb(c)->>'notice_version',''),
        'status',c.status,
        'updated_at',COALESCE(to_jsonb(c)->>'updated_at',to_jsonb(c)->>'accepted_at',to_jsonb(c)->>'created_at')) AS value
      FROM ap_m1.consent_records c WHERE c.child_id=$1::uuid
        AND (NULLIF($2,'') IS NULL OR c.id>NULLIF($2,'')::uuid) ORDER BY c.id LIMIT $3::integer) q
    )SQL",childId,cursor,limit+1));
    auto &items = value["items"];
    value["next_cursor"] = Json::nullValue;
    if (items.size() > static_cast<Json::ArrayIndex>(limit)) {
        value["next_cursor"] = items[limit-1]["id"];
        Json::Value discarded; items.removeIndex(static_cast<Json::ArrayIndex>(limit),&discarded);
    }
    return value;
}
}
