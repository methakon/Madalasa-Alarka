// Pure request-validation helpers (no I/O), unit-tested in tests/cpp/test_core.cc.
#pragma once
#include <cstddef>
#include <cstdint>
#include <optional>
#include <string>
#include <string_view>

#include <json/json.h>

#include "idempotency_key.h"

namespace ma {

// Strict UTF-8 (rejects overlongs, surrogates, > U+10FFFF). Returns the number of code points, or nullopt if invalid.
inline std::optional<std::size_t> utf8_codepoints(std::string_view s) {
  std::size_t n = 0, i = 0;
  while (i < s.size()) {
    auto c = static_cast<std::uint8_t>(s[i]);
    std::size_t len;
    std::uint32_t cp;
    if (c < 0x80) { len = 1; cp = c; }
    else if (c >= 0xC2 && c <= 0xDF) { len = 2; cp = c & 0x1F; }
    else if (c >= 0xE0 && c <= 0xEF) { len = 3; cp = c & 0x0F; }
    else if (c >= 0xF0 && c <= 0xF4) { len = 4; cp = c & 0x07; }
    else return std::nullopt;
    if (i + len > s.size()) return std::nullopt;
    for (std::size_t k = 1; k < len; ++k) {
      auto cc = static_cast<std::uint8_t>(s[i + k]);
      if ((cc & 0xC0) != 0x80) return std::nullopt;
      cp = (cp << 6) | (cc & 0x3F);
    }
    if ((len == 3 && cp < 0x800) || (len == 4 && (cp < 0x10000 || cp > 0x10FFFF))) return std::nullopt;
    if (cp >= 0xD800 && cp <= 0xDFFF) return std::nullopt;
    i += len;
    ++n;
  }
  return n;
}

// Strict JSON parse: no comments, no duplicate keys, no trailing data, nesting limited.
inline bool parse_json_strict(std::string_view text, Json::Value& out) {
  Json::CharReaderBuilder b;
  Json::CharReaderBuilder::strictMode(&b.settings_);
  b["rejectDupKeys"] = true;
  b["failIfExtra"] = true;
  b["stackLimit"] = 16;
  std::string errs;
  std::unique_ptr<Json::CharReader> r(b.newCharReader());
  return r->parse(text.data(), text.data() + text.size(), &out, &errs);
}

// Canonical form of a parsed body: member names sorted (jsoncpp objects are ordered maps), no whitespace.
inline std::string canonical_json(const Json::Value& v) {
  Json::StreamWriterBuilder w;
  w["indentation"] = "";
  w["emitUTF8"] = true;
  return Json::writeString(w, v);
}

inline Sha256 request_hash(const Json::Value& body) { return sha256_bytes(canonical_json(body)); }

enum class LabelCheck { Ok, Malformed, OutOfRange };

// createFamily body: exactly {"label": string}. Wrong shape or a NUL/invalid UTF-8 -> Malformed (400);
// well-formed but not 1..100 characters -> OutOfRange (422), matching API conventions section 5.3 rule 4.
inline LabelCheck check_family_body(const Json::Value& body, std::string& label_out) {
  if (!body.isObject() || body.size() != 1 || !body.isMember("label") || !body["label"].isString())
    return LabelCheck::Malformed;
  label_out = body["label"].asString();
  if (label_out.find('\0') != std::string::npos) return LabelCheck::Malformed;
  auto n = utf8_codepoints(label_out);
  if (!n) return LabelCheck::Malformed;
  return (*n >= 1 && *n <= 100) ? LabelCheck::Ok : LabelCheck::OutOfRange;
}

}  // namespace ma
