#include <drogon/drogon.h>
#include "admin_owner.h"
#include "admin_backoffice.h"
#include <iostream>

static int failures=0;
#define CHECK(x) do {if(!(x)){std::cerr<<"FAIL line "<<__LINE__<<": " #x "\n";++failures;}}while(0)

int main(){
  using namespace ma;
  const std::string kOrigin = "http://127.0.0.1:5173";
  const std::string kHex(64, 'a');
  const std::string kValidUuid = "00000000-0000-4000-8000-000000000001";

  admin_web_config() = AdminWebConfig{kOrigin, 1800, nullptr};

  // 1. Owner queue: unauthenticated caller is denied
  auto req = drogon::HttpRequest::newHttpRequest();
  req->setMethod(drogon::Get);
  req->setPath("/v1/admin/owner/access-requests");
  auto anon = drogon::sync_wait(admin_owner_access_requests(req));
  CHECK(anon->statusCode() == drogon::k401Unauthorized);

  // 2. Owner queue: session without DB is gracefully handled (service unavailable)
  req->addHeader("cookie", "__Host-ma_admin_s=" + kHex);
  auto offline = drogon::sync_wait(admin_owner_access_requests(req));
  CHECK(offline->statusCode() == drogon::k503ServiceUnavailable);
  CHECK(offline->getJsonObject() && (*offline->getJsonObject())["code"] == "SERVICE_UNAVAILABLE");

  // 3. Decision endpoint: unauthenticated caller denied before DB
  auto dec_req = drogon::HttpRequest::newHttpRequest();
  dec_req->setMethod(drogon::Post);
  dec_req->setPath("/v1/admin/owner/access-requests/" + kValidUuid + "/decision");
  dec_req->setContentTypeCode(drogon::CT_APPLICATION_JSON);
  dec_req->setBody(R"({"decision":"APPROVE","role_codes":["SUPPORT_AGENT"],"reason":"Verified","expected_revision":1})");
  auto dec_anon = drogon::sync_wait(admin_decide_request(dec_req, kValidUuid));
  CHECK(dec_anon->statusCode() == drogon::k401Unauthorized || dec_anon->statusCode() == drogon::k403Forbidden);

  // 4. Decision endpoint: malformed target UUID rejected
  auto bad_target = drogon::sync_wait(admin_decide_request(dec_req, "not-a-valid-uuid"));
  CHECK(bad_target->statusCode() == drogon::k400BadRequest);

  // 5. Decision endpoint: payload validation without CSRF or Origin fails closed
  dec_req->addHeader("cookie", "__Host-ma_admin_s=" + kHex);
  auto dec_nocsrf = drogon::sync_wait(admin_decide_request(dec_req, kValidUuid));
  CHECK(dec_nocsrf->statusCode() == drogon::k403Forbidden);

  // 6. Decision endpoint: invalid decisions and roles fail validation
  dec_req->addHeader("origin", kOrigin);
  dec_req->addHeader("x-csrf-token", kHex);
  dec_req->setBody(R"({"decision":"GRANT_EVERYTHING","role_codes":[],"reason":"hacked","expected_revision":1})");
  auto dec_bad_action = drogon::sync_wait(admin_decide_request(dec_req, kValidUuid));
  CHECK(dec_bad_action->statusCode() == drogon::k422UnprocessableEntity);

  dec_req->setBody(R"({"decision":"APPROVE","role_codes":["invalid_lowercase_role"],"reason":"test","expected_revision":1})");
  auto dec_bad_role = drogon::sync_wait(admin_decide_request(dec_req, kValidUuid));
  CHECK(dec_bad_role->statusCode() == drogon::k422UnprocessableEntity);

  dec_req->setBody(R"({"decision":"APPROVE","role_codes":["SUPPORT_AGENT"],"reason":"","expected_revision":1})");
  auto dec_empty_reason = drogon::sync_wait(admin_decide_request(dec_req, kValidUuid));
  CHECK(dec_empty_reason->statusCode() == drogon::k422UnprocessableEntity);

  // 7. Decision endpoint: valid payload with CSRF reaches offline DB guard
  dec_req->setBody(R"({"decision":"APPROVE","role_codes":["SUPPORT_AGENT"],"reason":"Owner approved","expected_revision":1})");
  auto dec_offline = drogon::sync_wait(admin_decide_request(dec_req, kValidUuid));
  CHECK(dec_offline->statusCode() == drogon::k503ServiceUnavailable);

  if(failures) return 1;
  std::cout << "admin owner access queue and decision boundary tests PASS\n";
  return 0;
}

