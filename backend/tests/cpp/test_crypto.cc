#include <iostream>
#include <string>
#include <vector>
#include "crypto_support.h"

namespace {
int passed = 0, failed = 0;
void check(const std::string& name, bool good) {
  if (good) {
    ++passed;
  } else {
    ++failed;
    std::cerr << "FAIL " << name << '\n';
  }
}
}  // namespace

int main() {
  try {
    // 1. Base64url encode and decode
    std::string test_data = "Hello, world! 12345";
    std::string enc = ma::base64url_encode(test_data);
    auto dec = ma::base64url_decode(enc);
    check("base64url roundtrip", dec && *dec == test_data);
    check("base64url no padding", enc.find('=') == std::string::npos);

    // 2. Base64 encode and decode
    std::string b64 = ma::base64_encode(test_data);
    auto b64_dec = ma::base64_decode(b64);
    check("base64 roundtrip", b64_dec && *b64_dec == test_data);

    // 3. Pairing code generation
    std::string code1 = ma::generate_pairing_code();
    std::string code2 = ma::generate_pairing_code();
    check("pairing code length 10", code1.size() == 10 && code2.size() == 10);
    check("pairing code distinct", code1 != code2);

    // 4. Token generation
    std::string tok1 = ma::generate_secure_token(32);
    check("token length 43", tok1.size() == 43);

    // 5. ECDSA P-256 Key generation & signature verification
    EVP_PKEY_CTX* pctx = EVP_PKEY_CTX_new_id(EVP_PKEY_EC, nullptr);
    EVP_PKEY_keygen_init(pctx);
    EVP_PKEY_CTX_set_ec_paramgen_curve_nid(pctx, NID_X9_62_prime256v1);
    EVP_PKEY* pkey = nullptr;
    EVP_PKEY_keygen(pctx, &pkey);
    EVP_PKEY_CTX_free(pctx);

    unsigned char* spki_buf = nullptr;
    int spki_len = i2d_PUBKEY(pkey, &spki_buf);
    check("spki export valid", spki_len > 0 && spki_buf != nullptr);
    std::string spki_der(reinterpret_cast<char*>(spki_buf), spki_len);
    OPENSSL_free(spki_buf);

    check("validate_ec_p256_spki true", ma::validate_ec_p256_spki(spki_der));

    // Sign a message
    std::string msg = "amar-pola-m1-device-enroll-v1:test-nonce-123456";
    EVP_MD_CTX* mctx = EVP_MD_CTX_new();
    EVP_DigestSignInit(mctx, nullptr, EVP_sha256(), nullptr, pkey);
    EVP_DigestSignUpdate(mctx, msg.data(), msg.size());
    std::size_t sig_len = 0;
    EVP_DigestSignFinal(mctx, nullptr, &sig_len);
    std::vector<unsigned char> sig(sig_len);
    EVP_DigestSignFinal(mctx, sig.data(), &sig_len);
    EVP_MD_CTX_free(mctx);
    EVP_PKEY_free(pkey);

    std::string sig_bytes(reinterpret_cast<char*>(sig.data()), sig_len);

    // Verify valid signature
    check("verify_ecdsa_p256_sha256 valid", ma::verify_ecdsa_p256_sha256(spki_der, msg, sig_bytes));

    // Verify tampered message fails
    check("verify_ecdsa_p256_sha256 tampered msg fails", !ma::verify_ecdsa_p256_sha256(spki_der, msg + "x", sig_bytes));

    // Verify wrong key fails
    EVP_PKEY_CTX* pctx2 = EVP_PKEY_CTX_new_id(EVP_PKEY_EC, nullptr);
    EVP_PKEY_keygen_init(pctx2);
    EVP_PKEY_CTX_set_ec_paramgen_curve_nid(pctx2, NID_X9_62_prime256v1);
    EVP_PKEY* pkey2 = nullptr;
    EVP_PKEY_keygen(pctx2, &pkey2);
    EVP_PKEY_CTX_free(pctx2);
    unsigned char* spki2_buf = nullptr;
    int spki2_len = i2d_PUBKEY(pkey2, &spki2_buf);
    std::string spki2_der(reinterpret_cast<char*>(spki2_buf), spki2_len);
    OPENSSL_free(spki2_buf);
    EVP_PKEY_free(pkey2);
    check("verify_ecdsa_p256_sha256 wrong key fails", !ma::verify_ecdsa_p256_sha256(spki2_der, msg, sig_bytes));

    // 6. Fingerprint computation
    std::string fp = ma::compute_key_fingerprint(spki_der);
    check("fingerprint length 43", fp.size() == 43);

    // 7. Bytea roundtrip
    std::string pg = ma::bytes_to_pg_bytea(test_data);
    std::string rt = ma::pg_bytea_to_bytes(pg);
    check("pg_bytea roundtrip", rt == test_data);

  } catch (const std::exception& e) {
    ++failed;
    std::cerr << "FAIL exception: " << e.what() << '\n';
  }

  std::cout << passed << " passed, " << failed << " failed\n";
  return failed ? 1 : 0;
}
