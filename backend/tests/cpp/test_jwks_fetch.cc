#include "google_jwks.h"
#include <cassert>
#include <iostream>
#include <limits>
#include <string>

int main(int argc, char** argv) {
  using namespace ma::jwks_detail;
  unsigned checks = 0;
  auto check = [&](bool v) { if (!v) { std::cerr << "failed check " << checks + 1 << '\n'; std::abort(); } ++checks; };
  const auto p = transport_policy();
  check(p.url == "https://www.googleapis.com/oauth2/v3/certs");
  check(p.verify_peer && p.verify_host && !p.follow_redirects);
  check(p.protocols == "https" && p.encoding == "identity");
  check(p.connect_timeout_ms == 1000 && p.total_timeout_ms == 3000);
  check(p.max_body_bytes == 256 * 1024 && p.max_header_bytes == 16 * 1024);
  ResponseCollector c;
  check(c.header("HTTP/1.1 200 OK\r\n"));
  check(c.header("Content-Type: application/json; charset=UTF-8\r\n"));
  check(c.header("Cache-Control: public, max-age=3600\r\n"));
  check(c.header("Age: 60\r\n"));
  check(c.append("{}", 1, 2));
  auto r = c.finish(200);
  check(r && r->body == "{}" && r->ttl.count() == 3540);
  check(!c.finish(302) && !c.finish(500));
  ResponseCollector full;
  std::string payload(p.max_body_bytes, 'x');
  check(full.append(payload.data(), 1, payload.size()));
  check(!full.append("x", 1, 1) && full.body_size() == p.max_body_bytes);
  ResponseCollector overflow;
  check(!overflow.append("", std::numeric_limits<std::size_t>::max(), 2));
  auto response = [](std::string_view headers) {
    ResponseCollector x;
    x.header("HTTP/1.1 200 OK\r\n");
    x.header("Content-Type: application/json\r\n");
    x.header(headers);
    x.append("{}", 1, 2);
    return x.finish(200);
  };
  check(!response("Cache-Control: max-age=4, max-age=8\r\n"));
  check(!response("Cache-Control: no-cache, max-age=8\r\n"));
  check(!response("Cache-Control: no-store, max-age=8\r\n"));
  check(!response("Cache-Control: max-age=abc\r\n"));
  check(!response("Cache-Control: max-age=0\r\n"));
  check(!response("Cache-Control: max-age=18446744073709551616\r\n"));
  check(!response("Cache-Control: public\r\n"));
  check(response("Cache-Control: max-age=999999\r\n")->ttl.count() == 86400);
  ResponseCollector encoded;
  check(!encoded.header("Content-Encoding: gzip\r\n"));
  check(!encoded.finish(200));
  ResponseCollector many;
  check(!many.header(std::string(p.max_header_bytes + 1, 'x')));
  ResponseCollector duplicate;
  duplicate.header("Content-Type: application/json\r\n");
  check(!duplicate.header("Content-Type: application/json\r\n"));
  ResponseCollector stale;
  stale.header("Content-Type: application/json\r\n");
  stale.header("Cache-Control: max-age=10\r\n");
  stale.header("Age: 10\r\n");
  stale.append("{}",1,2);
  check(!stale.finish(200));
  ResponseCollector mime;
  mime.header("Content-Type: text/html\r\n");
  mime.header("Cache-Control: max-age=10\r\n");
  mime.append("{}",1,2);
  check(!mime.finish(200));
  ResponseCollector duplicate_age;
  duplicate_age.header("Age: 1\r\n");
  check(!duplicate_age.header("Age: 2\r\n"));
  ResponseCollector interim;
  interim.header("HTTP/1.1 100 Continue\r\n");
  interim.header("Content-Type: application/json\r\n");
  interim.header("HTTP/2 200\r\n");
  interim.header("Content-Type: application/json\r\n");
  interim.header("Cache-Control: max-age=10\r\n");
  interim.append("{}",1,2);
  check(bool(interim.finish(200)));
  if (argc == 2 && std::string(argv[1]) == "--live") {
    auto live = ma::fetch_google_jwks();
    check(live && !live->body.empty() && live->ttl.count() > 0);
    std::cout << "live public fixed-origin Google fetch accepted\n";
  }
  std::cout << checks << " transport checks passed\n";
}
