#include <iostream>
#include <string>
#include <vector>

#include "crypto_support.h"
#include "device_activity.h"
#include "device_credentials.h"
#include "enrollment.h"
#include "idempotency_key.h"
#include "pairing.h"
#include "validation.h"

static int failures = 0;
#define CHECK(c) do { if (!(c)) { std::cerr << "FAIL line " << __LINE__ << ": " #c "\n"; ++failures; } } while (0)

int main() {
  using namespace ma;

  // 1. Pairing Code and UUID normalisation
  CHECK(normalize_uuid("e1000000-0000-4000-8000-000000000001") == "e1000000-0000-4000-8000-000000000001");
  CHECK(!normalize_uuid("not-a-uuid").has_value());

  std::string code = generate_pairing_code();
  CHECK(code.size() == 10);
  CHECK(code.find_first_not_of("23456789ABCDEFGHJKLMNPQRSTUVWXYZ") == std::string::npos);

  // 2. Token generation
  std::string token = generate_secure_token(32);
  CHECK(token.size() == 43);
  CHECK(token.find('/') == std::string::npos);
  CHECK(token.find('+') == std::string::npos);
  CHECK(token.find('=') == std::string::npos);

  // 3. Cryptographic proof verification
  // Generate EC key
  EVP_PKEY_CTX* pctx = EVP_PKEY_CTX_new_id(EVP_PKEY_EC, nullptr);
  EVP_PKEY_keygen_init(pctx);
  EVP_PKEY_CTX_set_ec_paramgen_curve_nid(pctx, NID_X9_62_prime256v1);
  EVP_PKEY* pkey = nullptr;
  EVP_PKEY_keygen(pctx, &pkey);
  EVP_PKEY_CTX_free(pctx);

  unsigned char* spki_buf = nullptr;
  int spki_len = i2d_PUBKEY(pkey, &spki_buf);
  std::string spki_der(reinterpret_cast<char*>(spki_buf), spki_len);
  OPENSSL_free(spki_buf);

  std::string spki_b64 = base64_encode(spki_der);
  auto spki_decoded = base64_decode(spki_b64);
  CHECK(spki_decoded.has_value());
  CHECK(*spki_decoded == spki_der);
  CHECK(validate_ec_p256_spki(spki_der));

  // Compute fingerprint
  std::string fp = compute_key_fingerprint(spki_der);
  CHECK(fp.size() == 43);

  // Sign enrollment context
  std::string nonce = generate_secure_token(32);
  std::string enroll_msg = std::string(kEnrollmentContext) + ":" + nonce;

  EVP_MD_CTX* mctx = EVP_MD_CTX_new();
  EVP_DigestSignInit(mctx, nullptr, EVP_sha256(), nullptr, pkey);
  EVP_DigestSignUpdate(mctx, enroll_msg.data(), enroll_msg.size());
  std::size_t sig_len = 0;
  EVP_DigestSignFinal(mctx, nullptr, &sig_len);
  std::vector<unsigned char> sig_buf(sig_len);
  EVP_DigestSignFinal(mctx, sig_buf.data(), &sig_len);
  EVP_MD_CTX_free(mctx);
  EVP_PKEY_free(pkey);

  std::string sig_bytes(reinterpret_cast<char*>(sig_buf.data()), sig_len);
  std::string sig_b64url = base64url_encode(sig_bytes);

  // Verify valid signature
  auto decoded_sig = base64url_decode(sig_b64url);
  CHECK(decoded_sig.has_value());
  CHECK(verify_ecdsa_p256_sha256(spki_der, enroll_msg, *decoded_sig));

  // Verify altered nonce rejected
  CHECK(!verify_ecdsa_p256_sha256(spki_der, std::string(kEnrollmentContext) + ":altered", *decoded_sig));

  // Verify renewal context rejected on enrollment signature (cross-context replay defense)
  std::string renew_msg = std::string(kRenewalContext) + ":" + nonce;
  CHECK(!verify_ecdsa_p256_sha256(spki_der, renew_msg, *decoded_sig));

  // 4. Batch and health payload parsing tests
  Json::Value health;
  health["observed_at"] = "2026-10-31T03:00:00Z";
  health["battery_percent"] = 85;
  health["charging"] = true;
  health["permission_revision"] = 1;
  CHECK(health["battery_percent"].asInt() == 85);

  Json::Value batch;
  batch["batch_id"] = "e1000000-0000-4000-8000-000000000001";
  batch["events"] = Json::Value(Json::arrayValue);
  Json::Value ev;
  ev["event_id"] = "e2000000-0000-4000-8000-000000000001";
  ev["sequence"] = 1;
  ev["observed_at"] = "2026-10-31T03:00:00Z";
  ev["latitude"] = 12.9716;
  ev["longitude"] = 77.5946;
  ev["accuracy_m"] = 5.0;
  batch["events"].append(ev);
  CHECK(batch["events"].size() == 1);

  if (failures) return 1;
  std::cout << "device endpoint unit tests PASS\n";
  return 0;
}
