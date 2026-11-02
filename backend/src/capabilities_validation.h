// Frozen M1 Capabilities schema validation. Pure and synthetic-testable.
#pragma once
#include <algorithm>
#include <regex>
#include <string>
#include <string_view>
#include <json/json.h>
#include "validation.h"

namespace ma {

enum class CapabilityCheck { Ok, Malformed, OutOfRange };

inline bool capability_text(const Json::Value& v, std::size_t max) {
  if (!v.isString()) return false;
  auto str = v.asString();
  auto cps = utf8_codepoints(str);
  if (!cps || *cps > max) return false;
  for (const unsigned char c : str)
    if (c < 32 || c == 127) return false;
  return true;
}

inline bool capability_time(const std::string& value) {
  // RFC3339 shape; Postgres validates calendar/time details as timestamptz.
  static const std::regex pattern(
      R"(^[0-9]{4}-(0[1-9]|1[0-2])-([0-2][0-9]|3[01])T([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](\.[0-9]{1,9})?(Z|[+-]([01][0-9]|2[0-3]):[0-5][0-9])$)",
      std::regex::ECMAScript);
  return value.size() <= 40 && std::regex_match(value,pattern);
}

inline bool capability_state(const Json::Value& state) {
  if (!state.isString()) return false;
  const auto s = state.asString();
  return s == "SUPPORTED" || s == "UNSUPPORTED" || s == "PERMISSION_REQUIRED" ||
         s == "OS_REJECTED" || s == "UNKNOWN";
}

inline CapabilityCheck check_capability_body(const Json::Value& body) {
  if (!body.isObject()) return CapabilityCheck::Malformed;
  for (const auto& key : body.getMemberNames()) {
    if (key!="observed_at" && key!="android_api" && key!="manufacturer" &&
        key!="model" && key!="app_version" && key!="device_mode" &&
        key!="is_device_owner" && key!="location" && key!="usage_access" &&
        key!="notifications" && key!="managed_package_suspend")
      return CapabilityCheck::Malformed;
  }
  for (const auto& key: {"observed_at","android_api","device_mode","is_device_owner",
                         "location","usage_access","notifications","managed_package_suspend"})
    if (!body.isMember(key)) return CapabilityCheck::Malformed;
  if (!body["observed_at"].isString() || !body["android_api"].isInt() ||
      !body["device_mode"].isString() || !body["is_device_owner"].isBool() ||
      !capability_state(body["location"]) || !capability_state(body["usage_access"]) ||
      !capability_state(body["notifications"]) || !capability_state(body["managed_package_suspend"]))
    return CapabilityCheck::Malformed;
  for (const auto& name: {"manufacturer","model","app_version"})
    if (body.isMember(name) && !body[name].isString()) return CapabilityCheck::Malformed;

  if (!capability_time(body["observed_at"].asString()) ||
      body["android_api"].asInt() < 29 || body["android_api"].asInt() > 45 ||
      (body["device_mode"] != "STANDARD" && body["device_mode"] != "MANAGED_DEVICE_OWNER" &&
       body["device_mode"] != "UNKNOWN") ||
      (body["device_mode"] == "MANAGED_DEVICE_OWNER" && !body["is_device_owner"].asBool()) ||
      (body["is_device_owner"].asBool() && body["device_mode"] != "MANAGED_DEVICE_OWNER") ||
      (body.isMember("manufacturer") && !capability_text(body["manufacturer"],60)) ||
      (body.isMember("model") && !capability_text(body["model"],100)) ||
      (body.isMember("app_version") && !capability_text(body["app_version"],60)))
    return CapabilityCheck::OutOfRange;
  return CapabilityCheck::Ok;
}

inline Json::Value capability_feature_json(const Json::Value& body) {
  Json::Value features(Json::objectValue);
  for (const auto& key: {"location","usage_access","notifications","managed_package_suspend",
                         "manufacturer","model","app_version"})
    if (body.isMember(key)) features[key] = body[key];
  return features;
}
} // namespace ma
