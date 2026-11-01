#include <drogon/drogon.h>
#include "admin_session.h"
#include <iostream>
static int failed=0;
#define CHECK(p) do {if(!(p)){std::cerr<<"FAIL "<<__LINE__<<"\n";++failed;}}while(0)
int main() {
  using ma::admin_session_cookie;
  const std::string token(64,'a');
  CHECK(admin_session_cookie("__Host-ma_admin_s="+token)==token);
  CHECK(admin_session_cookie("unrelated=1; __Host-ma_admin_s="+token)==token);
  CHECK(!admin_session_cookie("__Host-ma_admin_s="+token+"; __Host-ma_admin_s="+token));
  CHECK(!admin_session_cookie("__Host-ma_admin_s="+token+"x"));
  CHECK(!admin_session_cookie("__Host-ma_admin_s="+std::string(64,'Z')));
  CHECK(!admin_session_cookie("__Host-ma_admin_s="+std::string(64,'g')));
  CHECK(!admin_session_cookie("foo__Host-ma_admin_s="+token));
  CHECK(!admin_session_cookie("other=123"));
  auto req=drogon::HttpRequest::newHttpRequest();
  req->setMethod(drogon::Get);req->setPath("/v1/admin/access/me");
  auto none=drogon::sync_wait(ma::admin_access_me(req));
  CHECK(none->statusCode()==drogon::k401Unauthorized);
  req->addHeader("cookie","__Host-ma_admin_s="+token);
  auto offline=drogon::sync_wait(ma::admin_access_me(req));
  CHECK(offline->statusCode()==drogon::k503ServiceUnavailable);
  CHECK(offline->getJsonObject()!=nullptr);
  CHECK((*offline->getJsonObject())["code"]=="SERVICE_UNAVAILABLE");
  if(failed)return 1;
  std::cout<<"admin-cookie negative tests PASS\n";
}
