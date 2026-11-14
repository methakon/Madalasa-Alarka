#include "../../src/privacy_lifecycle_policy.h"
#include <cassert>
#include <cstdint>
#include <iostream>
using ma::privacy::ErasureWorkflow;
using ma::privacy::State;
using ma::privacy::Store;

static int failed = 0;
static void chk(bool ok, const char* label) {
  if (!ok) { std::cerr << "FAIL " << label << '\n'; ++failed; }
}

int main() {
  ErasureWorkflow workflow;
  chk(workflow.readAllowed(),            "initial readAllowed");
  chk(!workflow.request(0),             "request(0) rejected");
  chk(workflow.request(11),             "request(11) accepted");
  chk(!workflow.request(12),            "no overwrite unfinished");
  chk(!workflow.readAllowed(),           "readAllowed false after request");
  chk(!workflow.markTombstoneCommitted(11), "tombstone before revoke rejected");
  chk(!workflow.markRevoked(10),         "wrong epoch revoke rejected");
  chk(workflow.markRevoked(11),          "markRevoked(11) ok");
  chk(!workflow.recordReceipt(11, Store::RawLocation), "receipt before tombstone rejected");
  chk(workflow.markTombstoneCommitted(11), "markTombstoneCommitted ok");
  chk(!workflow.recordReceipt(10, Store::RawLocation), "stale epoch receipt rejected");
  chk(!workflow.recordReceipt(11, Store::Count),       "invalid store rejected");
  chk(!workflow.complete(11),            "cannot certify partial purge");
  for (std::size_t i = 0; i < ma::privacy::kStoreCount; ++i) {
    const auto store = static_cast<Store>(i);
    chk(workflow.recordReceipt(11, store), "recordReceipt idempotent-first");
    chk(workflow.recordReceipt(11, store), "recordReceipt idempotent-second");
  }
  chk(!workflow.complete(10),            "wrong epoch complete rejected");
  chk(workflow.complete(11),             "complete(11) ok");
  chk(workflow.state() == State::Complete, "state Complete");
  chk(!workflow.readAllowed(),           "readAllowed false after complete");
  chk(!workflow.restoredItemCanSurface(10), "restored stale epoch hidden");
  chk(!workflow.restoredItemCanSurface(11), "restored current epoch hidden");
  chk(!workflow.restoredItemCanSurface(12), "no child resurrection");
  chk(!workflow.request(13),             "completed erasure never resets");
  if (failed) return 1;
  std::cout << "privacy_lifecycle_policy PASS\n";
  return 0;
}
