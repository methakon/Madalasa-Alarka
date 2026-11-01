#include <drogon/drogon.h>
#include "admin_faq_read.h"
#include <iostream>
static int failures=0;
#define CHECK(x) do{if(!(x)){std::cerr<<"FAIL "<<__LINE__<<"\n";++failures;}}while(0)
int main(){
  auto req=drogon::HttpRequest::newHttpRequest();
  req->setMethod(drogon::Get);
  CHECK(drogon::sync_wait(ma::read_faqs(req,true))->statusCode()==drogon::k401Unauthorized);
  CHECK(drogon::sync_wait(ma::read_faqs(req,true,"bad-id"))->statusCode()==drogon::k400BadRequest);
  CHECK(drogon::sync_wait(ma::read_faqs(req,false))->statusCode()==drogon::k503ServiceUnavailable);
  req->addHeader("cookie","__Host-ma_admin_s="+std::string(64,'a'));
  CHECK(drogon::sync_wait(ma::read_faqs(req,true))->statusCode()==drogon::k503ServiceUnavailable);
  if(failures)return 1;
  std::cout<<"FAQ public/admin read negative tests PASS\n";
}
