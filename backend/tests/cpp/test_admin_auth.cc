// Admin login/CSRF layer: parsers, configuration and offline route negatives.
// No database, network or real identity. SYNTHETIC DATA ONLY.
#include <drogon/drogon.h>
#include <iostream>
#include <string>
#include "admin_backoffice.h"

static int failed = 0;
#define CHECK(p) do { if (!(p)) { std::cerr << "FAIL line " << __LINE__ << ": " #p "\n"; ++failed; } } while (0)

static const std::string kOrigin = "http://127.0.0.1:5173";
static const std::string kHex(64, 'a');

static drogon::HttpRequestPtr make(drogon::HttpMethod method, const std::string& path, const std::string& body = "",
                                   bool origin = true, bool csrf = true, bool cookie = true) {
  auto req = drogon::HttpRequest::newHttpRequest();
  req->setMethod(method);
  req->setPath(path);
  if (!body.empty()) { req->setContentTypeCode(drogon::CT_APPLICATION_JSON); req->setBody(body); }
  if (origin) req->addHeader("origin", kOrigin);
  if (csrf) req->addHeader("x-csrf-token", kHex);
  if (cookie) req->addHeader("cookie", "__Host-ma_admin_s=" + kHex + "; __Host-ma_admin_login=" + std::string(64, 'b'));
  return req;
}

static int status(const drogon::HttpResponsePtr& r) { return static_cast<int>(r->statusCode()); }
static std::string code(const drogon::HttpResponsePtr& r) {
  return r->getJsonObject() ? (*r->getJsonObject())["code"].asString() : std::string();
}

int main() {
  using namespace ma;
  // Origin and lifetime configuration.
  for (const char* good : {"http://127.0.0.1:5173", "https://admin.example.invalid", "https://a.b-c.example:8443"})
    CHECK(valid_admin_origin(good));
  for (const char* bad : {"", "*", "127.0.0.1:5173", "https://admin.example.invalid/", "https://x/y",
                          "https://u:p@host", "javascript:alert(1)", "https://host:123456", "https://-bad.example"})
    CHECK(!valid_admin_origin(bad));
  CHECK(parse_admin_session_ttl(nullptr) == kAdminSessionDefaultTtlSeconds);
  CHECK(parse_admin_session_ttl("300") == 300 && parse_admin_session_ttl("3600") == 3600);
  for (const char* bad : {"299", "3601", "abc", "-5", "30000"}) CHECK(!parse_admin_session_ttl(bad));

  // Cookies: one exact name, 64 lowercase hex.
  CHECK(named_hex_cookie("__Host-ma_admin_login=" + kHex, kAdminLoginCookie) == kHex);
  CHECK(named_hex_cookie("x=1; __Host-ma_admin_login=" + kHex, kAdminLoginCookie) == kHex);
  CHECK(!named_hex_cookie("__Host-ma_admin_login=" + kHex + "; __Host-ma_admin_login=" + kHex, kAdminLoginCookie));
  CHECK(!named_hex_cookie("__Host-ma_admin_login=" + std::string(64, 'A'), kAdminLoginCookie));
  CHECK(!named_hex_cookie("__Host-ma_admin_login=" + kHex + "0", kAdminLoginCookie));
  CHECK(!named_hex_cookie("x__Host-ma_admin_login=" + kHex, kAdminLoginCookie));
  CHECK(!named_hex_cookie("", kAdminLoginCookie));
  auto cookie = admin_cookie(kAdminSessionCookie, kHex, 1800);
  CHECK(cookie.isSecure() && cookie.isHttpOnly() && cookie.path() == "/" &&
        cookie.sameSite() == drogon::Cookie::SameSite::kStrict && cookie.maxAge() == 1800);
  CHECK(admin_text_array("{FAQ_EDITOR,ROOT_OWNER}").size() == 2);
  CHECK(admin_text_array("{}").empty() && admin_text_array("{x}").empty() && admin_text_array("FAQ").empty());

  // With no configured origin every admin login and mutation is closed.
  admin_web_config() = AdminWebConfig{};
  CHECK(status(drogon::sync_wait(admin_login_challenge(make(drogon::Post, "/v1/admin/auth/challenge")))) == 503);
  CHECK(status(drogon::sync_wait(admin_login_google(make(drogon::Post, "/v1/admin/auth/google",
        R"({"id_token":"x","nonce":")" + kHex + "\"}")))) == 503);
  CHECK(code(drogon::sync_wait(admin_logout(make(drogon::Delete, "/v1/admin/auth/session")))) == "FORBIDDEN");

  int verifier_calls = 0;
  admin_web_config() = AdminWebConfig{kOrigin, 1800,
      [&verifier_calls](const drogon::HttpRequestPtr&, std::string_view, std::string_view)
          -> std::optional<AdminGoogleIdentity> {
        ++verifier_calls;
        return AdminGoogleIdentity{"https://synthetic.invalid", "unit-admin", "unit@example.invalid"};
      }};
  // Challenge: origin required; reaches the issuer DB stage only with the exact origin.
  CHECK(code(drogon::sync_wait(admin_login_challenge(make(drogon::Post, "/x", "", false)))) == "FORBIDDEN");
  auto foreign = make(drogon::Post, "/x", "", false);
  foreign->addHeader("origin", "http://127.0.0.1:5174");
  CHECK(code(drogon::sync_wait(admin_login_challenge(foreign))) == "FORBIDDEN");
  CHECK(status(drogon::sync_wait(admin_login_challenge(make(drogon::Post, "/x", "{}")))) == 400);
  CHECK(status(drogon::sync_wait(admin_login_challenge(make(drogon::Post, "/x")))) == 503);

  // Login: strict body, server nonce shape, state cookie, verifier, then issuer DB.
  const std::string good = R"({"id_token":"t","nonce":")" + kHex + "\"}";
  CHECK(code(drogon::sync_wait(admin_login_google(make(drogon::Post, "/x", good, false)))) == "FORBIDDEN");
  for (const std::string& bad : {std::string(R"({"id_token":"t"})"), std::string(R"({"id_token":"t","nonce":"short"})"),
                                 R"({"id_token":"t","nonce":")" + kHex + R"(","csrf_state":"x"})", std::string("[]")})
    CHECK(status(drogon::sync_wait(admin_login_google(make(drogon::Post, "/x", bad)))) == 400);
  CHECK(verifier_calls == 0);
  CHECK(status(drogon::sync_wait(admin_login_google(make(drogon::Post, "/x", good, true, true, false)))) == 401);
  CHECK(verifier_calls == 0);  // no state cookie => identity never verified
  CHECK(status(drogon::sync_wait(admin_login_google(make(drogon::Post, "/x", good)))) == 503);
  CHECK(verifier_calls == 1);
  admin_web_config().verifier = reject_all_admin_verifier();
  CHECK(status(drogon::sync_wait(admin_login_google(make(drogon::Post, "/x", good)))) == 401);

  // Mutations: origin, CSRF and cookie are required before any database access.
  const std::string profile = R"({"full_name":"Synthetic","contact_email":"s@example.invalid",)"
                              R"("privacy_notice_version":"v1","expected_revision":0})";
  CHECK(code(drogon::sync_wait(admin_save_profile(make(drogon::Put, "/x", profile, false)))) == "FORBIDDEN");
  CHECK(code(drogon::sync_wait(admin_save_profile(make(drogon::Put, "/x", profile, true, false)))) == "FORBIDDEN");
  CHECK(code(drogon::sync_wait(admin_save_profile(make(drogon::Put, "/x", profile, true, true, false)))) == "UNAUTHENTICATED");
  CHECK(status(drogon::sync_wait(admin_save_profile(make(drogon::Put, "/x", profile)))) == 503);
  auto bad_csrf = make(drogon::Put, "/x", profile, true, false);
  bad_csrf->addHeader("x-csrf-token", std::string(64, 'A'));
  CHECK(code(drogon::sync_wait(admin_save_profile(bad_csrf))) == "FORBIDDEN");
  // Data minimisation and validation happen before the database.
  CHECK(status(drogon::sync_wait(admin_save_profile(make(drogon::Put, "/x",
        R"({"full_name":"S","contact_email":"s@example.invalid","privacy_notice_version":"v1","expected_revision":0,"date_of_birth":"2000-01-01"})")))) == 422);
  CHECK(status(drogon::sync_wait(admin_save_profile(make(drogon::Put, "/x", R"({"full_name":"S","role":"ROOT_OWNER"})")))) == 400);
  CHECK(status(drogon::sync_wait(admin_submit_request(make(drogon::Post, "/x", R"({"profile_revision":0})")))) == 422);
  const std::string decision = R"({"decision":"APPROVE","role_codes":["FAQ_EDITOR"],"reason":"ok","expected_revision":1})";
  CHECK(status(drogon::sync_wait(admin_decide_request(make(drogon::Post, "/x", decision), "nope"))) == 400);
  const std::string uuid = "00000000-0000-4000-8000-000000000001";
  CHECK(status(drogon::sync_wait(admin_decide_request(make(drogon::Post, "/x",
        R"({"decision":"MAYBE","role_codes":[],"reason":"ok","expected_revision":1})"), uuid))) == 422);
  CHECK(status(drogon::sync_wait(admin_decide_request(make(drogon::Post, "/x",
        R"({"decision":"APPROVE","role_codes":["faq_editor"],"reason":"ok","expected_revision":1})"), uuid))) == 422);
  CHECK(status(drogon::sync_wait(admin_decide_request(make(drogon::Post, "/x", decision), uuid))) == 503);
  CHECK(status(drogon::sync_wait(admin_faq_draft(make(drogon::Post, "/x",
        R"({"slug":"Bad Slug","category":"c","title":"Title","safe_markdown":"x"})"), std::nullopt))) == 422);
  CHECK(status(drogon::sync_wait(admin_faq_draft(make(drogon::Post, "/x",
        R"({"slug":"ok-slug","category":"c","title":"Title","safe_markdown":"<script>"})"), std::nullopt))) == 422);
  CHECK(status(drogon::sync_wait(admin_faq_draft(make(drogon::Post, "/x",
        R"J({"slug":"ok-slug","category":"c","title":"Title","safe_markdown":"[link](x)"})J"), std::nullopt))) == 422);
  CHECK(status(drogon::sync_wait(admin_faq_draft(make(drogon::Put, "/x",
        R"({"title":"Title","safe_markdown":"x","expected_revision":0})"), uuid))) == 422);
  CHECK(status(drogon::sync_wait(admin_faq_draft(make(drogon::Post, "/x",
        R"({"slug":"ok-slug","category":"c","title":"Title","safe_markdown":"Plain text"})"), std::nullopt))) == 503);
  CHECK(status(drogon::sync_wait(admin_faq_publish(make(drogon::Post, "/x", R"({"revision_id":"x","expected_revision":1})"), uuid))) == 422);
  CHECK(status(drogon::sync_wait(admin_ticket_reply(make(drogon::Post, "/x", R"({"body":"<b>","request_id":")" + uuid + "\"}"), uuid))) == 422);

  // Reads need only the session cookie; bad paging is rejected first.
  CHECK(code(drogon::sync_wait(admin_list_tickets(make(drogon::Get, "/x", "", false, false, false)))) == "UNAUTHENTICATED");
  CHECK(status(drogon::sync_wait(admin_list_tickets(make(drogon::Get, "/x", "", false, false)))) == 503);
  auto bad_page = make(drogon::Get, "/x", "", false, false);
  bad_page->setParameter("limit", "101");
  CHECK(status(drogon::sync_wait(admin_list_tickets(bad_page))) == 400);
  bad_page->setParameter("limit", "5");
  bad_page->setParameter("after", "not-a-uuid");
  CHECK(status(drogon::sync_wait(admin_security_audit(bad_page))) == 400);
  for (auto r : {drogon::sync_wait(admin_subscribers(make(drogon::Get, "/x", "", false, false, false))),
                 drogon::sync_wait(admin_parent_usage(make(drogon::Get, "/x", "", false, false, false))),
                 drogon::sync_wait(admin_security_audit(make(drogon::Get, "/x", "", false, false, false)))})
    CHECK(status(r) == 401 && r->getHeader("cache-control") == "no-store");

  if (failed) return 1;
  std::cout << "admin auth/back-office offline tests PASS\n";
  return 0;
}
