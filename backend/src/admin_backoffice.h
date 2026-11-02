// Admin back-office routes for the admin-web panel. Every route goes through
// with_admin_session (admin_auth.h): opaque session cookie, and for mutations the
// exact Origin plus a session-bound CSRF token. Authorization, revisions and audit
// are enforced by the SECURITY DEFINER SQL functions (migrations 0008/0022), never
// by the browser. SYNTHETIC DATA ONLY.
#pragma once
#include <initializer_list>
#include <optional>
#include <string>
#include <string_view>

#include <drogon/drogon.h>

#include "admin_auth.h"
#include "idempotency_key.h"
#include "validation.h"

namespace ma {

inline bool json_only_keys(const Json::Value& body, std::initializer_list<std::string_view> allowed) {
  if (!body.isObject()) return false;
  for (const auto& name : body.getMemberNames()) {
    bool ok = false;
    for (auto a : allowed) ok = ok || name == a;
    if (!ok) return false;
  }
  return true;
}

inline bool json_text(const Json::Value& v, std::size_t min_cp, std::size_t max_cp) {
  if (!v.isString()) return false;
  const auto s = v.asString();
  const auto cp = utf8_codepoints(s);
  return cp && *cp >= min_cp && *cp <= max_cp && s.find('\0') == std::string::npos;
}

inline std::optional<std::int64_t> json_revision(const Json::Value& v, std::int64_t min) {
  if (!v.isIntegral() || !v.isInt64()) return std::nullopt;
  const auto value = v.asInt64();
  if (value < min || value > (std::int64_t{1} << 53)) return std::nullopt;
  return value;
}

inline std::optional<Json::Value> admin_json_body(const drogon::HttpRequestPtr& req) {
  if (req->body().size() > kMaxBodyBytes || req->contentType() != drogon::CT_APPLICATION_JSON) return std::nullopt;
  Json::Value body;
  if (!parse_json_strict(req->body(), body) || !body.isObject()) return std::nullopt;
  return body;
}

struct PageQuery { std::optional<std::string> after; int limit; };

inline std::optional<PageQuery> admin_page_query(const drogon::HttpRequestPtr& req, int default_limit) {
  PageQuery page{std::nullopt, default_limit};
  const auto& after = req->getParameter("after");
  if (!after.empty()) {
    page.after = normalize_uuid(after);
    if (!page.after) return std::nullopt;
  }
  const auto& limit = req->getParameter("limit");
  if (!limit.empty()) {
    if (limit.size() > 3) return std::nullopt;
    int value = 0;
    for (char c : limit) {
      if (c < '0' || c > '9') return std::nullopt;
      value = value * 10 + (c - '0');
    }
    if (value < 1 || value > 100) return std::nullopt;
    page.limit = value;
  }
  return page;
}

inline Json::Value nullable_text(const drogon::orm::Field& f) {
  return f.isNull() ? Json::Value(Json::nullValue) : Json::Value(f.as<std::string>());
}

#define MA_ADMIN_BAD_REQUEST(msg) \
  co_return admin_no_store(error_response("INVALID_REQUEST", msg, request_id_of(req)))

// PUT /v1/admin/access/profile — DOB/gender/address are not collected (data minimisation).
inline drogon::Task<drogon::HttpResponsePtr> admin_save_profile(drogon::HttpRequestPtr req) {
  using namespace drogon;
  auto body = admin_json_body(req);
  if (!body || !json_only_keys(*body, {"full_name", "contact_email", "privacy_notice_version", "expected_revision",
                                       "postal_address", "date_of_birth", "gender"}))
    MA_ADMIN_BAD_REQUEST("body must be a JSON profile object");
  const auto& b = *body;
  for (const char* minimised : {"postal_address", "date_of_birth", "gender"})
    if (b.isMember(minimised) && !b[minimised].isNull())
      co_return admin_no_store(error_response("VALIDATION_FAILED", "this field is not collected", request_id_of(req)));
  const auto expected = json_revision(b["expected_revision"], 0);
  if (!json_text(b["full_name"], 1, 150) || !b["contact_email"].isString() ||
      !valid_verified_email(b["contact_email"].asString()) || !json_text(b["privacy_notice_version"], 1, 100) ||
      !expected)
    co_return admin_no_store(error_response("VALIDATION_FAILED", "invalid profile fields", request_id_of(req)));
  const auto name = b["full_name"].asString(), email = b["contact_email"].asString(),
             notice = b["privacy_notice_version"].asString();
  const auto expected_revision = std::to_string(*expected);
  co_return co_await with_admin_session(req, true,
      [name, email, notice, expected_revision](std::shared_ptr<orm::Transaction> tx, std::string rid)
          -> Task<HttpResponsePtr> {
        auto rows = co_await tx->execSqlCoro(
            "SELECT ap_m1.save_admin_profile($1,$2,$3,$4::bigint) AS revision", name, email, notice, expected_revision);
        auto verified = co_await tx->execSqlCoro(
            "SELECT contact_verified_at IS NOT NULL AS v FROM ap_m1.admin_profiles WHERE admin_id=ap_m1.ctx_admin()");
        Json::Value out(Json::objectValue);
        out["profile_revision"] = Json::Int64(rows.at(0)["revision"].as<std::int64_t>());
        out["email_verified"] = !verified.empty() && verified.at(0)["v"].as<bool>();
        co_return admin_json(out, k200OK, rid);
      });
}

// POST /v1/admin/access/requests — idempotent per pending request.
inline drogon::Task<drogon::HttpResponsePtr> admin_submit_request(drogon::HttpRequestPtr req) {
  using namespace drogon;
  auto body = admin_json_body(req);
  if (!body || !json_only_keys(*body, {"profile_revision", "privacy_notice_version", "request_id"}))
    MA_ADMIN_BAD_REQUEST("body must be {profile_revision}");
  const auto revision = json_revision((*body)["profile_revision"], 1);
  if (!revision) co_return admin_no_store(error_response("VALIDATION_FAILED", "profile_revision required", request_id_of(req)));
  const auto expected = std::to_string(*revision);
  co_return co_await with_admin_session(req, true,
      [expected](std::shared_ptr<orm::Transaction> tx, std::string rid) -> Task<HttpResponsePtr> {
        auto rows = co_await tx->execSqlCoro("SELECT ap_m1.submit_admin_request($1::bigint)::text AS id", expected);
        auto state = co_await tx->execSqlCoro(
            "SELECT state, revision FROM ap_m1.admin_access_requests WHERE id=$1::uuid", rows.at(0)["id"].as<std::string>());
        Json::Value out(Json::objectValue);
        out["id"] = rows.at(0)["id"].as<std::string>();
        out["state"] = state.empty() ? "PENDING_REVIEW" : state.at(0)["state"].as<std::string>();
        out["revision"] = state.empty() ? Json::Value(Json::nullValue)
                                        : Json::Value(Json::Int64(state.at(0)["revision"].as<std::int64_t>()));
        co_return admin_json(out, k201Created, rid);
      });
}

// POST /v1/admin/owner/access-requests/{requestId}/decision — owner + MFA step-up in SQL.
inline drogon::Task<drogon::HttpResponsePtr> admin_decide_request(drogon::HttpRequestPtr req, std::string request_param) {
  using namespace drogon;
  const auto target = normalize_uuid(request_param);
  if (!target) MA_ADMIN_BAD_REQUEST("requestId must be a UUID");
  auto body = admin_json_body(req);
  if (!body || !json_only_keys(*body, {"decision", "role_codes", "reason", "expected_revision"}))
    MA_ADMIN_BAD_REQUEST("body must be {decision, role_codes, reason, expected_revision}");
  const auto& b = *body;
  const auto decision = b["decision"].isString() ? b["decision"].asString() : std::string();
  const auto expected = json_revision(b["expected_revision"], 1);
  std::string roles = "{";
  bool roles_ok = b["role_codes"].isArray() && b["role_codes"].size() <= 4;
  for (Json::ArrayIndex i = 0; roles_ok && i < b["role_codes"].size(); ++i) {
    const auto& r = b["role_codes"][i];
    roles_ok = r.isString() && !r.asString().empty() && r.asString().size() <= 40;
    for (char c : roles_ok ? r.asString() : std::string()) roles_ok = roles_ok && ((c >= 'A' && c <= 'Z') || c == '_');
    if (roles_ok) roles += (i ? "," : "") + r.asString();
  }
  roles += "}";
  if ((decision != "APPROVE" && decision != "REJECT") || !roles_ok || !json_text(b["reason"], 1, 500) || !expected)
    co_return admin_no_store(error_response("VALIDATION_FAILED", "invalid decision fields", request_id_of(req)));
  const bool approve = decision == "APPROVE";
  const auto reason = b["reason"].asString();
  const auto expected_revision = std::to_string(*expected);
  const auto id = *target;
  co_return co_await with_admin_session(req, true,
      [id, approve, roles, reason, expected_revision](std::shared_ptr<orm::Transaction> tx, std::string rid)
          -> Task<HttpResponsePtr> {
        co_await tx->execSqlCoro("SELECT ap_m1.decide_admin_request($1::uuid,$2::bigint,$3::boolean,$4::text[],$5)",
                                 id, expected_revision, std::string(approve ? "true" : "false"), roles, reason);
        auto rows = co_await tx->execSqlCoro(
            "SELECT id::text AS id,state,revision FROM ap_m1.admin_access_requests WHERE id=$1::uuid", id);
        Json::Value out(Json::objectValue);
        out["id"] = id;
        out["state"] = rows.empty() ? Json::Value(Json::nullValue) : Json::Value(rows.at(0)["state"].as<std::string>());
        out["revision"] = rows.empty() ? Json::Value(Json::nullValue)
                                       : Json::Value(Json::Int64(rows.at(0)["revision"].as<std::int64_t>()));
        co_return admin_json(out, k200OK, rid);
      });
}

inline bool valid_faq_slug(const Json::Value& v) {
  if (!v.isString()) return false;
  const auto s = v.asString();
  if (s.size() < 2 || s.size() > 150) return false;
  for (std::size_t i = 0; i < s.size(); ++i) {
    const char c = s[i];
    const bool alnum = (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9');
    if (!(alnum || (i > 0 && c == '-'))) return false;
  }
  return true;
}

// Plain-text Markdown subset: no HTML, links or images (also enforced by SQL CHECKs).
inline bool safe_faq_text(const Json::Value& v, std::size_t min_cp, std::size_t max_cp, bool body) {
  if (!json_text(v, min_cp, max_cp)) return false;
  for (char c : v.asString())
    if (c == '<' || c == '>' || (body && (c == '[' || c == ']'))) return false;
  return true;
}

// POST /v1/admin/faqs (create) and PUT /v1/admin/faqs/{faqId} (new draft revision).
inline drogon::Task<drogon::HttpResponsePtr> admin_faq_draft(drogon::HttpRequestPtr req,
                                                             std::optional<std::string> faq_param) {
  using namespace drogon;
  std::optional<std::string> target;
  if (faq_param) {
    target = normalize_uuid(*faq_param);
    if (!target) MA_ADMIN_BAD_REQUEST("faqId must be a UUID");
  }
  auto body = admin_json_body(req);
  const bool create = !target;
  if (!body || (create ? !json_only_keys(*body, {"slug", "category", "title", "safe_markdown", "language"})
                       : !json_only_keys(*body, {"title", "safe_markdown", "language", "expected_revision"})))
    MA_ADMIN_BAD_REQUEST("unexpected FAQ fields");
  const auto& b = *body;
  if (b.isMember("language") && b["language"] != "en")
    co_return admin_no_store(error_response("VALIDATION_FAILED", "only language en is supported", request_id_of(req)));
  const auto expected = create ? std::optional<std::int64_t>(0) : json_revision(b["expected_revision"], 1);
  if (!safe_faq_text(b["title"], 3, 220, false) || !safe_faq_text(b["safe_markdown"], 1, 10000, true) || !expected ||
      (create && (!valid_faq_slug(b["slug"]) || !json_text(b["category"], 1, 100))))
    co_return admin_no_store(error_response("VALIDATION_FAILED", "invalid FAQ fields", request_id_of(req)));
  const auto id = create ? drogon::utils::getUuid(true) : *target;
  const auto slug = create ? b["slug"].asString() : std::string("unchanged-on-update");
  const auto category = create ? b["category"].asString() : std::string("unchanged-on-update");
  const auto title = b["title"].asString(), text = b["safe_markdown"].asString();
  const auto expected_revision = std::to_string(*expected);
  co_return co_await with_admin_session(req, true,
      [id, slug, category, title, text, expected_revision, create](std::shared_ptr<orm::Transaction> tx,
                                                                   std::string rid) -> Task<HttpResponsePtr> {
        auto rows = co_await tx->execSqlCoro(
            "SELECT ap_m1.faq_draft($1::uuid,$2,$3,$4,$5,$6::bigint)::text AS revision_id",
            id, slug, category, title, text, expected_revision);
        auto entry = co_await tx->execSqlCoro(
            "SELECT state,revision FROM ap_m1.faq_entries WHERE id=$1::uuid", id);
        Json::Value out(Json::objectValue);
        out["id"] = id;
        out["current_revision_id"] = rows.at(0)["revision_id"].as<std::string>();
        out["status"] = entry.empty() ? "DRAFT" : entry.at(0)["state"].as<std::string>();
        out["revision"] = entry.empty() ? Json::Value(Json::nullValue)
                                        : Json::Value(Json::Int64(entry.at(0)["revision"].as<std::int64_t>()));
        co_return admin_json(out, create ? k201Created : k200OK, rid);
      });
}

// POST /v1/admin/faqs/{faqId}/publish {revision_id, expected_revision} — FAQ_PUBLISH (MFA step-up).
inline drogon::Task<drogon::HttpResponsePtr> admin_faq_publish(drogon::HttpRequestPtr req, std::string faq_param) {
  using namespace drogon;
  const auto target = normalize_uuid(faq_param);
  if (!target) MA_ADMIN_BAD_REQUEST("faqId must be a UUID");
  auto body = admin_json_body(req);
  if (!body || !json_only_keys(*body, {"revision_id", "expected_revision", "request_id"}))
    MA_ADMIN_BAD_REQUEST("body must be {revision_id, expected_revision}");
  const auto revision_id = (*body)["revision_id"].isString() ? normalize_uuid((*body)["revision_id"].asString())
                                                             : std::nullopt;
  const auto expected = json_revision((*body)["expected_revision"], 1);
  if (!revision_id || !expected)
    co_return admin_no_store(error_response("VALIDATION_FAILED", "revision_id and expected_revision required", request_id_of(req)));
  const auto id = *target, rev = *revision_id, expected_revision = std::to_string(*expected);
  co_return co_await with_admin_session(req, true,
      [id, rev, expected_revision](std::shared_ptr<orm::Transaction> tx, std::string rid) -> Task<HttpResponsePtr> {
        auto rows = co_await tx->execSqlCoro(
            "SELECT ap_m1.faq_transition($1::uuid,$2::uuid,$3::bigint,'PUBLISHED') AS revision", id, rev, expected_revision);
        Json::Value out(Json::objectValue);
        out["id"] = id;
        out["status"] = "PUBLISHED";
        out["published_revision_id"] = rev;
        out["revision"] = Json::Int64(rows.at(0)["revision"].as<std::int64_t>());
        co_return admin_json(out, k200OK, rid);
      });
}

// GET /v1/admin/support/tickets?after=&limit= — owner: all; agent: assigned only.
inline drogon::Task<drogon::HttpResponsePtr> admin_list_tickets(drogon::HttpRequestPtr req) {
  using namespace drogon;
  const auto page = admin_page_query(req, 25);
  if (!page) MA_ADMIN_BAD_REQUEST("invalid after/limit");
  const auto after = page->after.value_or(""), limit = std::to_string(page->limit);
  const int size = page->limit;
  co_return co_await with_admin_session(req, false,
      [after, limit, size](std::shared_ptr<orm::Transaction> tx, std::string rid) -> Task<HttpResponsePtr> {
        auto rows = co_await tx->execSqlCoro(
            "SELECT id::text AS id,subject,state,priority,assigned_to_me,revision," + pg_utc("created_at") +
            " AS created_at," + pg_utc("updated_at") +
            " AS updated_at FROM ap_m1.admin_list_support_tickets(NULLIF($1,'')::uuid,$2::integer)", after, limit);
        Json::Value out(Json::objectValue);
        out["items"] = Json::Value(Json::arrayValue);
        for (const auto& r : rows) {
          Json::Value t(Json::objectValue);
          t["id"] = r["id"].as<std::string>();
          t["subject"] = r["subject"].as<std::string>();
          t["status"] = r["state"].as<std::string>();
          t["priority"] = r["priority"].as<std::string>();
          t["assigned_to_me"] = r["assigned_to_me"].as<bool>();
          t["revision"] = Json::Int64(r["revision"].as<std::int64_t>());
          t["created_at"] = r["created_at"].as<std::string>();
          t["updated_at"] = r["updated_at"].as<std::string>();
          out["items"].append(t);
        }
        out["next_cursor"] = static_cast<int>(rows.size()) == size && !rows.empty()
                                 ? Json::Value(rows[rows.size() - 1]["id"].as<std::string>()) : Json::Value(Json::nullValue);
        co_return admin_json(out, k200OK, rid);
      });
}

// GET /v1/admin/support/tickets/{ticketId}/messages?after=&limit= — read is audited in SQL.
inline drogon::Task<drogon::HttpResponsePtr> admin_ticket_messages(drogon::HttpRequestPtr req, std::string ticket_param) {
  using namespace drogon;
  const auto ticket = normalize_uuid(ticket_param);
  if (!ticket) MA_ADMIN_BAD_REQUEST("ticketId must be a UUID");
  const auto page = admin_page_query(req, 25);
  if (!page) MA_ADMIN_BAD_REQUEST("invalid after/limit");
  const auto id = *ticket, after = page->after.value_or(""), limit = std::to_string(page->limit);
  const int size = page->limit;
  co_return co_await with_admin_session(req, false,
      [id, after, limit, size](std::shared_ptr<orm::Transaction> tx, std::string rid) -> Task<HttpResponsePtr> {
        auto rows = co_await tx->execSqlCoro(
            "SELECT id::text AS id,body,author_kind," + pg_utc("created_at") +
            " AS created_at FROM ap_m1.read_support_messages($1::uuid,NULLIF($2,'')::uuid,$3::integer)", id, after, limit);
        Json::Value out(Json::objectValue);
        out["items"] = Json::Value(Json::arrayValue);
        for (const auto& r : rows) {
          Json::Value m(Json::objectValue);
          m["id"] = r["id"].as<std::string>();
          m["body"] = r["body"].as<std::string>();
          m["author_kind"] = r["author_kind"].as<std::string>();
          m["created_at"] = r["created_at"].as<std::string>();
          out["items"].append(m);
        }
        out["next_cursor"] = static_cast<int>(rows.size()) == size && !rows.empty()
                                 ? Json::Value(rows[rows.size() - 1]["id"].as<std::string>()) : Json::Value(Json::nullValue);
        co_return admin_json(out, k200OK, rid);
      });
}

// POST /v1/admin/support/tickets/{ticketId}/reply {body, request_id} — idempotent on request_id.
inline drogon::Task<drogon::HttpResponsePtr> admin_ticket_reply(drogon::HttpRequestPtr req, std::string ticket_param) {
  using namespace drogon;
  const auto ticket = normalize_uuid(ticket_param);
  if (!ticket) MA_ADMIN_BAD_REQUEST("ticketId must be a UUID");
  auto body = admin_json_body(req);
  if (!body || !json_only_keys(*body, {"body", "request_id"})) MA_ADMIN_BAD_REQUEST("body must be {body, request_id}");
  const auto request_id = (*body)["request_id"].isString() ? normalize_uuid((*body)["request_id"].asString())
                                                           : std::nullopt;
  if (!safe_faq_text((*body)["body"], 1, 5000, false) || !request_id)
    co_return admin_no_store(error_response("VALIDATION_FAILED", "body (no < >) and request_id UUID required", request_id_of(req)));
  const auto id = *ticket, text = (*body)["body"].asString(), key = *request_id;
  co_return co_await with_admin_session(req, true,
      [id, text, key](std::shared_ptr<orm::Transaction> tx, std::string rid) -> Task<HttpResponsePtr> {
        auto rows = co_await tx->execSqlCoro("SELECT ap_m1.support_reply($1::uuid,$2,$3::uuid)::text AS id", id, text, key);
        Json::Value out(Json::objectValue);
        out["id"] = rows.at(0)["id"].as<std::string>();
        out["ticket_id"] = id;
        co_return admin_json(out, k201Created, rid);
      });
}

// Shared read for permission-gated views. 403 when the permission is missing
// (the views alone would silently return zero rows).
inline drogon::Task<drogon::HttpResponsePtr> admin_permission_read(
    drogon::HttpRequestPtr req, std::string permission, std::string sql,
    std::function<Json::Value(const drogon::orm::Row&)> map_row) {
  using namespace drogon;
  co_return co_await with_admin_session(req, false,
      [permission, sql, map_row](std::shared_ptr<orm::Transaction> tx, std::string rid) -> Task<HttpResponsePtr> {
        auto allowed = co_await tx->execSqlCoro("SELECT ap_m1.has_admin_permission($1) AS ok", permission);
        if (allowed.empty() || !allowed.at(0)["ok"].as<bool>())
          co_return admin_no_store(error_response("FORBIDDEN", "administrator permission denied", rid));
        auto rows = co_await tx->execSqlCoro(sql);
        Json::Value out(Json::objectValue);
        out["items"] = Json::Value(Json::arrayValue);
        for (const auto& r : rows) out["items"].append(map_row(r));
        out["next_cursor"] = Json::nullValue;  // bounded to 100 newest rows; cursor pending
        co_return admin_json(out, k200OK, rid);
      });
}

// GET /v1/admin/subscribers — restricted billing projection (no payer identity, no token).
inline drogon::Task<drogon::HttpResponsePtr> admin_subscribers(drogon::HttpRequestPtr req) {
  co_return co_await admin_permission_read(req, "BILLING_READ",
      "SELECT family_id::text AS family_id,sku_id::text AS sku_id,state::text AS state,amount_paise::text AS amount_paise,"
      + pg_utc("purchased_at") + " AS purchased_at,assigned_seats::text AS assigned_seats "
      "FROM ap_m1.admin_subscription_support ORDER BY purchased_at DESC NULLS LAST LIMIT 100",
      [](const drogon::orm::Row& r) {
        Json::Value s(Json::objectValue);
        s["family_id"] = r["family_id"].as<std::string>();
        s["sku_id"] = nullable_text(r["sku_id"]);
        s["state"] = nullable_text(r["state"]);
        s["amount_paise"] = nullable_text(r["amount_paise"]);
        s["purchased_at"] = nullable_text(r["purchased_at"]);
        s["assigned_seats"] = nullable_text(r["assigned_seats"]);
        return s;
      });
}

// GET /v1/admin/usage/parents — daily service aggregates; pseudonymous parent id only.
inline drogon::Task<drogon::HttpResponsePtr> admin_parent_usage(drogon::HttpRequestPtr req) {
  co_return co_await admin_permission_read(req, "USAGE_READ",
      "SELECT parent_id::text AS parent_id," + pg_utc("day") + " AS day,service_code,outcome,"
      "event_count::text AS event_count,duration_seconds::text AS duration_seconds,quota_seconds::text AS quota_seconds "
      "FROM ap_m1.parent_service_usage_aggregates ORDER BY day DESC,parent_id,service_code,outcome LIMIT 100",
      [](const drogon::orm::Row& r) {
        Json::Value u(Json::objectValue);
        u["parent_id"] = r["parent_id"].as<std::string>();
        u["day"] = r["day"].as<std::string>();
        u["service_code"] = r["service_code"].as<std::string>();
        u["outcome"] = r["outcome"].as<std::string>();
        u["event_count"] = nullable_text(r["event_count"]);
        u["duration_seconds"] = nullable_text(r["duration_seconds"]);
        u["quota_seconds"] = nullable_text(r["quota_seconds"]);
        return u;
      });
}

// GET /v1/admin/security/audit?after=&limit= — owner with active MFA (enforced in SQL).
inline drogon::Task<drogon::HttpResponsePtr> admin_security_audit(drogon::HttpRequestPtr req) {
  using namespace drogon;
  const auto page = admin_page_query(req, 50);
  if (!page) MA_ADMIN_BAD_REQUEST("invalid after/limit");
  const auto after = page->after.value_or(""), limit = std::to_string(page->limit);
  const int size = page->limit;
  co_return co_await with_admin_session(req, false,
      [after, limit, size](std::shared_ptr<orm::Transaction> tx, std::string rid) -> Task<HttpResponsePtr> {
        auto rows = co_await tx->execSqlCoro(
            "SELECT id::text AS id,actor_admin_id::text AS actor,target_ref::text AS target,action,outcome," +
            pg_utc("occurred_at") + " AS occurred_at FROM ap_m1.admin_read_action_audit(NULLIF($1,'')::uuid,$2::integer)",
            after, limit);
        Json::Value out(Json::objectValue);
        out["items"] = Json::Value(Json::arrayValue);
        for (const auto& r : rows) {
          Json::Value a(Json::objectValue);
          a["id"] = r["id"].as<std::string>();
          a["actor_admin_id"] = nullable_text(r["actor"]);
          a["target_ref"] = nullable_text(r["target"]);
          a["action"] = r["action"].as<std::string>();
          a["outcome"] = r["outcome"].as<std::string>();
          a["occurred_at"] = r["occurred_at"].as<std::string>();
          out["items"].append(a);
        }
        out["next_cursor"] = static_cast<int>(rows.size()) == size && !rows.empty()
                                 ? Json::Value(rows[rows.size() - 1]["id"].as<std::string>()) : Json::Value(Json::nullValue);
        co_return admin_json(out, k200OK, rid);
      });
}

#undef MA_ADMIN_BAD_REQUEST

}  // namespace ma
