// L15-003 — Authenticated deletion workflow & notices.
// Delete request is never mistaken for immediate completion (returns 202 Accepted, completed: false).
#include <drogon/drogon.h>
#include <iostream>
#include "privacy_request_endpoints.h"

static int failures = 0;
#define CHECK(x) do { if (!(x)) { std::cerr << "FAIL line " << __LINE__ << ": " #x "\n"; ++failures; } } while (0)

int main() {
  using namespace ma;
  const std::string kValidChildId = "00000000-0000-4000-8000-000000000001";
  const std::string kValidKey = "00000000-0000-4000-8000-000000000002";
  const std::string kValidSessionToken(64, 'a');

  ParentAuth auth{ParentAuthMode::V2Session, nullptr};

  // 1. Malformed childId rejected before auth or DB
  auto req1 = drogon::HttpRequest::newHttpRequest();
  req1->setMethod(drogon::Post);
  req1->setPath("/v1/children/not-a-uuid/erasure-requests");
  auto res1 = drogon::sync_wait(child_privacy_job(req1, "not-a-uuid", auth, true, true));
  CHECK(res1->statusCode() == drogon::k400BadRequest);
  CHECK(res1->getJsonObject() && (*res1->getJsonObject())["code"] == "INVALID_REQUEST");

  // 2. Unauthenticated caller rejected
  auto req2 = drogon::HttpRequest::newHttpRequest();
  req2->setMethod(drogon::Post);
  req2->setPath("/v1/children/" + kValidChildId + "/erasure-requests");
  req2->setContentTypeCode(drogon::CT_APPLICATION_JSON);
  req2->setBody(R"({"confirm_child_erasure":true})");
  req2->addHeader("idempotency-key", kValidKey);
  auto res2 = drogon::sync_wait(child_privacy_job(req2, kValidChildId, auth, true, true));
  CHECK(res2->statusCode() == drogon::k401Unauthorized);

  // 3. Authenticated request with payload > 1024 bytes rejected
  auto req3 = drogon::HttpRequest::newHttpRequest();
  req3->setMethod(drogon::Post);
  req3->setPath("/v1/children/" + kValidChildId + "/erasure-requests");
  req3->addHeader("authorization", "Bearer " + kValidSessionToken);
  req3->setBody(std::string(1025, 'x'));
  auto res3 = drogon::sync_wait(child_privacy_job(req3, kValidChildId, auth, true, true));
  CHECK(res3->statusCode() == drogon::k413RequestEntityTooLarge);

  // 4. Missing confirm_child_erasure or boolean false rejected
  auto req4 = drogon::HttpRequest::newHttpRequest();
  req4->setMethod(drogon::Post);
  req4->setPath("/v1/children/" + kValidChildId + "/erasure-requests");
  req4->addHeader("authorization", "Bearer " + kValidSessionToken);
  req4->setContentTypeCode(drogon::CT_APPLICATION_JSON);
  req4->setBody(R"({"confirm_child_erasure":false})");
  req4->addHeader("idempotency-key", kValidKey);
  auto res4 = drogon::sync_wait(child_privacy_job(req4, kValidChildId, auth, true, true));
  CHECK(res4->statusCode() == drogon::k422UnprocessableEntity);

  // 5. Missing Idempotency-Key rejected
  auto req5 = drogon::HttpRequest::newHttpRequest();
  req5->setMethod(drogon::Post);
  req5->setPath("/v1/children/" + kValidChildId + "/erasure-requests");
  req5->addHeader("authorization", "Bearer " + kValidSessionToken);
  req5->setContentTypeCode(drogon::CT_APPLICATION_JSON);
  req5->setBody(R"({"confirm_child_erasure":true})");
  auto res5 = drogon::sync_wait(child_privacy_job(req5, kValidChildId, auth, true, true));
  CHECK(res5->statusCode() == drogon::k400BadRequest);

  // 6. Extraneous fields rejected
  auto req6 = drogon::HttpRequest::newHttpRequest();
  req6->setMethod(drogon::Post);
  req6->setPath("/v1/children/" + kValidChildId + "/erasure-requests");
  req6->addHeader("authorization", "Bearer " + kValidSessionToken);
  req6->setContentTypeCode(drogon::CT_APPLICATION_JSON);
  req6->setBody(R"({"confirm_child_erasure":true,"extra":"malicious"})");
  req6->addHeader("idempotency-key", kValidKey);
  auto res6 = drogon::sync_wait(child_privacy_job(req6, kValidChildId, auth, true, true));
  CHECK(res6->statusCode() == drogon::k400BadRequest);

  // 7. Non-empty body on GET status rejected
  auto req7 = drogon::HttpRequest::newHttpRequest();
  req7->setMethod(drogon::Get);
  req7->setPath("/v1/children/" + kValidChildId + "/erasure-requests");
  req7->addHeader("authorization", "Bearer " + kValidSessionToken);
  req7->setBody("not empty");
  auto res7 = drogon::sync_wait(child_privacy_job(req7, kValidChildId, auth, true, false));
  CHECK(res7->statusCode() == drogon::k400BadRequest);

  // 8. Offline database guard on valid erasure creation
  auto req8 = drogon::HttpRequest::newHttpRequest();
  req8->setMethod(drogon::Post);
  req8->setPath("/v1/children/" + kValidChildId + "/erasure-requests");
  req8->addHeader("authorization", "Bearer " + kValidSessionToken);
  req8->setContentTypeCode(drogon::CT_APPLICATION_JSON);
  req8->setBody(R"({"confirm_child_erasure":true})");
  req8->addHeader("idempotency-key", kValidKey);
  auto res8 = drogon::sync_wait(child_privacy_job(req8, kValidChildId, auth, true, true));
  CHECK(res8->statusCode() == drogon::k503ServiceUnavailable);

  // 9. Offline database guard on valid erasure GET status
  auto req9 = drogon::HttpRequest::newHttpRequest();
  req9->setMethod(drogon::Get);
  req9->setPath("/v1/children/" + kValidChildId + "/erasure-requests");
  req9->addHeader("authorization", "Bearer " + kValidSessionToken);
  auto res9 = drogon::sync_wait(child_privacy_job(req9, kValidChildId, auth, true, false));
  CHECK(res9->statusCode() == drogon::k503ServiceUnavailable);

  // 10. Verify privacy_pending helper formats 202 Accepted with completed=false
  Json::Value sample(Json::objectValue);
  sample["request_id"] = kValidKey;
  sample["child_id"] = kValidChildId;
  sample["kind"] = "ERASURE";
  sample["completed"] = false;
  sample["message"] = "Request recorded; primary deletion and external/backup verification are separate.";
  auto pendingResp = privacy_pending(sample, "req-123");
  CHECK(pendingResp->statusCode() == drogon::k202Accepted);
  CHECK(pendingResp->getHeader("cache-control") == "no-store");
  auto obj = pendingResp->getJsonObject();
  CHECK(obj != nullptr);
  CHECK((*obj)["completed"].asBool() == false);
  CHECK((*obj)["kind"].asString() == "ERASURE");
  CHECK((*obj)["message"].asString().find("primary deletion and external/backup verification are separate") != std::string::npos);

  if (failures) return 1;
  std::cout << "deletion workflow & notices tests PASS\n";
  return 0;
}
