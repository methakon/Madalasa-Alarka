#include <cstdlib>
#include <iostream>

#include "error_catalog.h"
#include "idempotency_key.h"
#include "validation.h"

static int failures = 0;
#define CHECK(c) do { if (!(c)) { std::cerr << "FAIL line " << __LINE__ << ": " #c "\n"; ++failures; } } while (0)

int main() {
  using namespace ma;
  // catalog
  CHECK(kErrors.size() == 12);
  CHECK(find_error("NOT_FOUND")->http_status == 404);
  CHECK(find_error("RATE_LIMITED")->retryable);
  CHECK(find_error("SERVICE_UNAVAILABLE")->retryable);
  CHECK(!find_error("CONFLICT")->retryable);
  CHECK(!find_error("NOPE").has_value());
  for (std::size_t i = 0; i < kErrors.size(); ++i)
    for (std::size_t j = i + 1; j < kErrors.size(); ++j) CHECK(kErrors[i].code != kErrors[j].code);

  // uuid normalisation
  CHECK(normalize_uuid("1D000000-0000-4000-8000-00000000000A") == std::string("1d000000-0000-4000-8000-00000000000a"));
  CHECK(!normalize_uuid("").has_value());
  CHECK(!normalize_uuid("1d000000000040008000-00000000000a").has_value());
  CHECK(!normalize_uuid("1d000000-0000-4000-8000-00000000000g").has_value());
  CHECK(!normalize_uuid("1d000000-0000-4000-8000-00000000000a ").has_value());

  // sha256 known vector: sha256("abc")
  auto h = sha256_bytes("abc");
  CHECK(h[0] == 0xba && h[1] == 0x78 && h[31] == 0xad);
  CHECK(to_pg_bytea(h).rfind("\\xba7816bf", 0) == 0 && to_pg_bytea(h).size() == 66);
  // same key in different case hashes identically; non-uuid is rejected
  CHECK(hash_idempotency_key("1D000000-0000-4000-8000-00000000000A") ==
        hash_idempotency_key("1d000000-0000-4000-8000-00000000000a"));
  CHECK(!hash_idempotency_key("not-a-uuid").has_value());
  CHECK(!hex_to_sha256(std::string(63, 'a')).has_value());

  // utf8 / label rules
  CHECK(utf8_codepoints("abc") == 3u);
  CHECK(utf8_codepoints("\xC3\xA9") == 1u);                // e acute
  CHECK(utf8_codepoints("\xF0\x9F\x98\x80") == 1u);       // emoji counts as one character, like Postgres char_length
  CHECK(!utf8_codepoints("\xC0\xAF").has_value());          // overlong
  CHECK(!utf8_codepoints("\xED\xA0\x80").has_value());     // surrogate
  CHECK(!utf8_codepoints("\xE2\x82").has_value());          // truncated
  CHECK(!utf8_codepoints("\xF5\x80\x80\x80").has_value()); // > U+10FFFF
  Json::Value b;
  std::string label;
  CHECK(parse_json_strict("{\"label\":\"x\"}", b) && check_family_body(b, label) == LabelCheck::Ok && label == "x");
  CHECK(parse_json_strict("{\"label\":\"\"}", b) && check_family_body(b, label) == LabelCheck::OutOfRange);
  CHECK(parse_json_strict("{\"label\":\"" + std::string(101, 'a') + "\"}", b) && check_family_body(b, label) == LabelCheck::OutOfRange);
  CHECK(parse_json_strict("{\"label\":\"" + std::string(100, 'a') + "\"}", b) && check_family_body(b, label) == LabelCheck::Ok);
  CHECK(parse_json_strict("{\"label\":\"a\",\"x\":1}", b) && check_family_body(b, label) == LabelCheck::Malformed);
  CHECK(parse_json_strict("{}", b) && check_family_body(b, label) == LabelCheck::Malformed);
  CHECK(parse_json_strict("{\"label\":5}", b) && check_family_body(b, label) == LabelCheck::Malformed);
  CHECK(parse_json_strict("[\"label\"]", b) && check_family_body(b, label) == LabelCheck::Malformed);
  CHECK(parse_json_strict("{\"label\":\"a\\u0000b\"}", b) && check_family_body(b, label) == LabelCheck::Malformed);  // NUL
  CHECK(!parse_json_strict("{\"label\":\"a\",\"label\":\"b\"}", b));                   // duplicate key
  CHECK(!parse_json_strict("{\"label\":\"a\"} x", b));                                  // trailing data
  CHECK(!parse_json_strict("{\"label\":\"a\"", b));                                     // truncated
  // canonical hash: key order and whitespace do not matter, content does
  Json::Value p, q, r2;
  parse_json_strict("{\"a\":1,\"b\":2}", p); parse_json_strict("{ \"b\" : 2,\n \"a\":1 }", q); parse_json_strict("{\"a\":1,\"b\":3}", r2);
  CHECK(request_hash(p) == request_hash(q));
  CHECK(request_hash(p) != request_hash(r2));

  if (failures) return 1;
  std::cout << "core tests PASS\n";
  return 0;
}
