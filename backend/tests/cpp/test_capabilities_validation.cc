// No account, location permission or child identity needed for pure fixture validation.
#include "capabilities_validation.h"
#include <iostream>
static int errors = 0;
#define CHECK(x) do { if (!(x)) { ++errors; std::cerr << "FAIL at line " << __LINE__ << "\n"; } } while (0)
int main() {
  using namespace ma;
  Json::Value v(Json::objectValue);
  v["observed_at"]="2026-10-31T13:45:12Z";
  v["android_api"]=36;
  v["device_mode"]="STANDARD";
  v["is_device_owner"]=false;
  for (const auto& key : {"location","usage_access","notifications","managed_package_suspend"})
    v[key]="UNKNOWN";
  CHECK(check_capability_body(v)==CapabilityCheck::Ok);
  v["unknown_privileged_capability"]=true;
  CHECK(check_capability_body(v)==CapabilityCheck::Malformed);
  v.removeMember("unknown_privileged_capability");
  v["android_api"]=28;
  CHECK(check_capability_body(v)==CapabilityCheck::OutOfRange);
  v["android_api"]=36;
  v["device_mode"]="MANAGED_DEVICE_OWNER";
  CHECK(check_capability_body(v)==CapabilityCheck::OutOfRange);
  v["device_mode"]="STANDARD";
  v["usage_access"]="GRANTED";
  CHECK(check_capability_body(v)==CapabilityCheck::Malformed);
  v["usage_access"]="UNKNOWN";
  v["observed_at"]="not-a-time";
  CHECK(check_capability_body(v)==CapabilityCheck::OutOfRange);
  v["observed_at"]="2026-10-31T13:45:12Z";
  v["model"]=std::string(101,'X');
  CHECK(check_capability_body(v)==CapabilityCheck::OutOfRange);
  v["model"]="synthetic-api36";
  CHECK(check_capability_body(v)==CapabilityCheck::Ok);
  auto features = capability_feature_json(v);
  CHECK(features.isMember("model"));
  CHECK(!features.isMember("is_device_owner"));
  CHECK(!features.isMember("observed_at"));
  if (errors) return 1;
  std::cout << "capability validation fixture matrix PASS\n";
}
