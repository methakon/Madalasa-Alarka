// Cryptographic helpers for device enrollment, credentials, and verification.
// SYNTHETIC DATA ONLY. Strict validation and zero secrets in source.
#pragma once
#include <openssl/bn.h>
#include <openssl/core_names.h>
#include <openssl/ecdsa.h>
#include <openssl/evp.h>
#include <openssl/rand.h>
#include <openssl/x509.h>

#include <array>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

#include "idempotency_key.h"

namespace ma {

// Base64url encode without padding.
inline std::string base64url_encode(std::string_view data) {
  static constexpr char kTable[] =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
  std::string out;
  out.reserve((data.size() * 4 + 2) / 3);
  std::size_t i = 0;
  while (i < data.size()) {
    std::size_t rem = data.size() - i;
    std::uint32_t octet_a = static_cast<std::uint8_t>(data[i++]);
    std::uint32_t octet_b = (rem > 1) ? static_cast<std::uint8_t>(data[i++]) : 0;
    std::uint32_t octet_c = (rem > 2) ? static_cast<std::uint8_t>(data[i++]) : 0;

    std::uint32_t triple = (octet_a << 16) | (octet_b << 8) | octet_c;

    out.push_back(kTable[(triple >> 18) & 0x3F]);
    out.push_back(kTable[(triple >> 12) & 0x3F]);
    if (rem > 1) out.push_back(kTable[(triple >> 6) & 0x3F]);
    if (rem > 2) out.push_back(kTable[triple & 0x3F]);
  }
  return out;
}

// Strict base64url decode (no padding, rejecting unused bits and invalid characters).
inline std::optional<std::string> base64url_decode(std::string_view s) {
  if (s.empty() || s.size() % 4 == 1) return std::nullopt;
  std::string out;
  out.reserve(s.size() * 3 / 4);
  unsigned acc = 0;
  int bits = 0;
  for (unsigned char c : s) {
    unsigned v;
    if (c >= 'A' && c <= 'Z') v = c - 'A';
    else if (c >= 'a' && c <= 'z') v = c - 'a' + 26;
    else if (c >= '0' && c <= '9') v = c - '0' + 52;
    else if (c == '-') v = 62;
    else if (c == '_') v = 63;
    else return std::nullopt;
    acc = (acc << 6) | v;
    bits += 6;
    if (bits >= 8) {
      bits -= 8;
      out.push_back(static_cast<char>((acc >> bits) & 0xFF));
    }
  }
  if (bits && (acc & ((1u << bits) - 1))) return std::nullopt;
  return out;
}

// Base64 encode with '=' padding.
inline std::string base64_encode(std::string_view data) {
  static constexpr char kTable[] =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  std::string out;
  out.reserve(((data.size() + 2) / 3) * 4);
  std::size_t i = 0;
  while (i < data.size()) {
    std::size_t remaining = data.size() - i;
    std::uint32_t octet_a = static_cast<std::uint8_t>(data[i++]);
    std::uint32_t octet_b = (remaining > 1) ? static_cast<std::uint8_t>(data[i++]) : 0;
    std::uint32_t octet_c = (remaining > 2) ? static_cast<std::uint8_t>(data[i++]) : 0;

    std::uint32_t triple = (octet_a << 16) | (octet_b << 8) | octet_c;

    out.push_back(kTable[(triple >> 18) & 0x3F]);
    out.push_back(kTable[(triple >> 12) & 0x3F]);
    out.push_back((remaining > 1) ? kTable[(triple >> 6) & 0x3F] : '=');
    out.push_back((remaining > 2) ? kTable[triple & 0x3F] : '=');
  }
  return out;
}

// Strict standard base64 decode (accepts standard '+' and '/', handles optional '=' padding).
inline std::optional<std::string> base64_decode(std::string_view s) {
  if (s.empty()) return std::nullopt;
  // Strip trailing whitespace or padding for parsing
  std::size_t len = s.size();
  while (len > 0 && s[len - 1] == '=') --len;
  if (len % 4 == 1) return std::nullopt;

  std::string out;
  out.reserve(s.size() * 3 / 4);
  unsigned acc = 0;
  int bits = 0;
  for (std::size_t i = 0; i < len; ++i) {
    unsigned char c = static_cast<unsigned char>(s[i]);
    unsigned v;
    if (c >= 'A' && c <= 'Z') v = c - 'A';
    else if (c >= 'a' && c <= 'z') v = c - 'a' + 26;
    else if (c >= '0' && c <= '9') v = c - '0' + 52;
    else if (c == '+') v = 62;
    else if (c == '/') v = 63;
    else return std::nullopt;
    acc = (acc << 6) | v;
    bits += 6;
    if (bits >= 8) {
      bits -= 8;
      out.push_back(static_cast<char>((acc >> bits) & 0xFF));
    }
  }
  if (bits && (acc & ((1u << bits) - 1))) return std::nullopt;
  return out;
}

// Generate cryptographically secure random bytes.
inline bool secure_random_bytes(unsigned char* buf, std::size_t len) {
  return RAND_bytes(buf, static_cast<int>(len)) == 1;
}

// Generate a random opaque base64url token of specified byte length (default 32 bytes -> 43 chars).
inline std::string generate_secure_token(std::size_t num_bytes = 32) {
  std::vector<unsigned char> buf(num_bytes);
  if (!secure_random_bytes(buf.data(), buf.size())) {
    throw std::runtime_error("failed to generate secure random bytes");
  }
  return base64url_encode(std::string_view(reinterpret_cast<const char*>(buf.data()), buf.size()));
}

// Generate human-friendly random pairing code (10 characters, unambiguous uppercase alphanumerics).
inline std::string generate_pairing_code() {
  // 32-character alphabet without confusing glyphs: 0/O, 1/I
  static constexpr char kAlphabet[] = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
  std::array<unsigned char, 10> raw{};
  if (!secure_random_bytes(raw.data(), raw.size())) {
    throw std::runtime_error("failed to generate random pairing code");
  }
  std::string code;
  code.reserve(10);
  for (auto b : raw) {
    code.push_back(kAlphabet[b % 32]);
  }
  return code;
}

// Compute key fingerprint (SHA-256 of SPKI DER bytes, encoded as unpadded base64url: 43 chars).
inline std::string compute_key_fingerprint(std::string_view spki_der) {
  Sha256 h = sha256_bytes(spki_der);
  return base64url_encode(std::string_view(reinterpret_cast<const char*>(h.data()), h.size()));
}

// Validate that raw bytes form a valid OpenSSL EC P-256 SPKI public key.
inline bool validate_ec_p256_spki(std::string_view spki_der) {
  if (spki_der.size() < 80 || spki_der.size() > 4096) return false;
  const unsigned char* p = reinterpret_cast<const unsigned char*>(spki_der.data());
  EVP_PKEY* pkey = d2i_PUBKEY(nullptr, &p, static_cast<long>(spki_der.size()));
  if (!pkey) return false;

  bool ok = false;
  if (EVP_PKEY_base_id(pkey) == EVP_PKEY_EC) {
    char group_name[64] = {0};
    std::size_t group_name_len = 0;
    if (EVP_PKEY_get_utf8_string_param(pkey, OSSL_PKEY_PARAM_GROUP_NAME,
                                       group_name, sizeof(group_name), &group_name_len)) {
      std::string_view name(group_name, group_name_len);
      if (name == "prime256v1" || name == "P-256" || name == "secp256r1") {
        ok = true;
      }
    }
  }
  EVP_PKEY_free(pkey);
  return ok;
}

// Verify an ECDSA P-256 SHA-256 signature against SPKI DER bytes.
// Supports both ASN.1 DER signatures and IEEE P1363 (raw 64-byte r||s) signatures.
inline bool verify_ecdsa_p256_sha256(std::string_view spki_der,
                                     std::string_view message,
                                     std::string_view signature_bytes) {
  if (spki_der.empty() || signature_bytes.empty()) return false;
  const unsigned char* p = reinterpret_cast<const unsigned char*>(spki_der.data());
  EVP_PKEY* pkey = d2i_PUBKEY(nullptr, &p, static_cast<long>(spki_der.size()));
  if (!pkey) return false;

  std::string der_sig;
  const unsigned char* sig_data = reinterpret_cast<const unsigned char*>(signature_bytes.data());
  std::size_t sig_len = signature_bytes.size();

  // If signature is raw 64 bytes (IEEE P1363: 32 bytes r, 32 bytes s), convert to ASN.1 DER
  if (sig_len == 64) {
    BIGNUM* r = BN_bin2bn(sig_data, 32, nullptr);
    BIGNUM* s = BN_bin2bn(sig_data + 32, 32, nullptr);
    if (!r || !s) {
      if (r) BN_free(r);
      if (s) BN_free(s);
      EVP_PKEY_free(pkey);
      return false;
    }
    ECDSA_SIG* ec_sig = ECDSA_SIG_new();
    if (!ec_sig || !ECDSA_SIG_set0(ec_sig, r, s)) {
      if (r) BN_free(r);
      if (s) BN_free(s);
      if (ec_sig) ECDSA_SIG_free(ec_sig);
      EVP_PKEY_free(pkey);
      return false;
    }
    unsigned char* der_buf = nullptr;
    int der_size = i2d_ECDSA_SIG(ec_sig, &der_buf);
    ECDSA_SIG_free(ec_sig);
    if (der_size <= 0 || !der_buf) {
      EVP_PKEY_free(pkey);
      return false;
    }
    der_sig.assign(reinterpret_cast<char*>(der_buf), der_size);
    OPENSSL_free(der_buf);
    sig_data = reinterpret_cast<const unsigned char*>(der_sig.data());
    sig_len = der_sig.size();
  }

  EVP_MD_CTX* ctx = EVP_MD_CTX_new();
  if (!ctx) {
    EVP_PKEY_free(pkey);
    return false;
  }

  bool verified = false;
  if (EVP_DigestVerifyInit(ctx, nullptr, EVP_sha256(), nullptr, pkey) == 1) {
    if (EVP_DigestVerifyUpdate(ctx, message.data(), message.size()) == 1) {
      if (EVP_DigestVerifyFinal(ctx, sig_data, sig_len) == 1) {
        verified = true;
      }
    }
  }

  EVP_MD_CTX_free(ctx);
  EVP_PKEY_free(pkey);
  return verified;
}

// Convert arbitrary raw bytes to PostgreSQL \x hex representation for bytea queries.
inline std::string bytes_to_pg_bytea(std::string_view data) {
  static constexpr char kHex[] = "0123456789abcdef";
  std::string s = "\\x";
  s.reserve(2 + data.size() * 2);
  for (unsigned char b : data) {
    s += kHex[b >> 4];
    s += kHex[b & 15];
  }
  return s;
}

// Convert PostgreSQL \x hex string or raw string back to binary bytes.
inline std::string pg_bytea_to_bytes(std::string_view hex) {
  if (hex.starts_with("\\x")) hex.remove_prefix(2);
  auto nib = [](char c) -> int {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
  };
  std::string out;
  out.reserve(hex.size() / 2);
  for (std::size_t i = 0; i + 1 < hex.size(); i += 2) {
    int hi = nib(hex[i]), lo = nib(hex[i + 1]);
    if (hi >= 0 && lo >= 0) {
      out.push_back(static_cast<char>((hi << 4) | lo));
    }
  }
  return out;
}

}  // namespace ma
