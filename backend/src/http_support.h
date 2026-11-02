// Shared HTTP behaviour: server-generated X-Request-Id on every response and the catalog error envelope.
#pragma once
#include <string>
#include <string_view>

#include <drogon/drogon.h>

#include "error_catalog.h"

namespace ma {

inline constexpr const char* kRequestIdHeader = "X-Request-Id";
inline constexpr const char* kRequestIdAttr = "ma.request_id";
inline constexpr std::size_t kMaxBodyBytes = 64 * 1024;

// Always server-generated: a client-supplied X-Request-Id is ignored so it cannot forge log correlation.
inline std::string new_request_id() { return drogon::utils::getUuid(true); }  // lower-case hyphenated

inline std::string request_id_of(const drogon::HttpRequestPtr& req) {
  auto attrs = req->getAttributes();
  if (attrs->find(kRequestIdAttr)) return attrs->get<std::string>(kRequestIdAttr);
  return new_request_id();
}

inline drogon::HttpResponsePtr error_response(std::string_view code, std::string_view message,
                                              const std::string& request_id,
                                              std::optional<bool> retryable_override = std::nullopt) {
  auto spec = find_error(code).value_or(*find_error("INTERNAL_ERROR"));
  Json::Value body;
  body["code"] = std::string(spec.code);
  body["message"] = std::string(message).substr(0, 300);
  body["request_id"] = request_id;
  body["retryable"] = retryable_override.value_or(spec.retryable);
  auto resp = drogon::HttpResponse::newHttpJsonResponse(body);
  resp->setStatusCode(static_cast<drogon::HttpStatusCode>(spec.http_status));
  resp->addHeader(kRequestIdHeader, request_id);
  return resp;
}

}  // namespace ma
