#include <drogon/drogon.h>
#include "admin_owner.h"
#include <iostream>
static int failures=0;
#define CHECK(x) do {if(!(x)){std::cerr<<"FAIL "<<__LINE__<<"\n";++failures;}}while(0)
int main(){
  auto req=drogon::HttpRequest::newHttpRequest();
  req->setMethod(drogon::Get);req->setPath("/v1/admin/owner/access-requests");
  auto anon=drogon::sync_wait(ma::admin_owner_access_requests(req));
  CHECK(anon->statusCode()==drogon::k401Unauthorized);
  req->addHeader("cookie","__Host-ma_admin_s="+std::string(64,'a'));
  auto offline=drogon::sync_wait(ma::admin_owner_access_requests(req));
  CHECK(offline->statusCode()==drogon::k503ServiceUnavailable);
  CHECK(offline->getJsonObject()&&(*offline->getJsonObject())["code"]=="SERVICE_UNAVAILABLE");
  if(failures)return 1;
  std::cout<<"admin owner access queue negative tests PASS\n";
}
