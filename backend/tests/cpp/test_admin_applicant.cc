#include <drogon/drogon.h>
#include "admin_applicant.h"
#include <iostream>
static int failures=0;
#define CHECK(x) do {if(!(x)){std::cerr<<"FAIL "<<__LINE__<<"\n";++failures;}}while(0)
int main(){
  const auto token=std::string(64,'a');
  auto req=drogon::HttpRequest::newHttpRequest();
  req->setMethod(drogon::Get);
  req->setPath("/v1/admin/access/profile");
  auto a=drogon::sync_wait(ma::admin_applicant_self_read(req,false));
  CHECK(a->statusCode()==drogon::k401Unauthorized);
  auto b=drogon::sync_wait(ma::admin_applicant_self_read(req,true));
  CHECK(b->statusCode()==drogon::k401Unauthorized);
  req->addHeader("cookie","__Host-ma_admin_s="+token);
  auto c=drogon::sync_wait(ma::admin_applicant_self_read(req,false));
  CHECK(c->statusCode()==drogon::k503ServiceUnavailable);
  auto d=drogon::sync_wait(ma::admin_applicant_self_read(req,true));
  CHECK(d->statusCode()==drogon::k503ServiceUnavailable);
  CHECK(d->getJsonObject() && (*d->getJsonObject())["code"]=="SERVICE_UNAVAILABLE");
  if(failures)return 1;
  std::cout<<"admin applicant read negative tests PASS\n";
}
