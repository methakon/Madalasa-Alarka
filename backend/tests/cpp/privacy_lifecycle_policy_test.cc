#include "../../src/privacy_lifecycle_policy.h"
#include <cassert>
#include <cstdint>
#include <iostream>
using ma::privacy::ErasureWorkflow;
using ma::privacy::State;
using ma::privacy::Store;

int main() {
  ErasureWorkflow workflow;
  assert(workflow.readAllowed());
  assert(!workflow.request(0));
  assert(workflow.request(11));
  assert(!workflow.request(12));  // never overwrite an unfinished request
  assert(!workflow.readAllowed());
  assert(!workflow.markTombstoneCommitted(11));  // revoke before purge
  assert(!workflow.markRevoked(10));
  assert(workflow.markRevoked(11));
  assert(!workflow.recordReceipt(11, Store::RawLocation));  // fence missing
  assert(workflow.markTombstoneCommitted(11));
  assert(!workflow.recordReceipt(10, Store::RawLocation));  // stale worker
  assert(!workflow.recordReceipt(11, Store::Count));  // invalid store
  assert(!workflow.complete(11));  // cannot certify partial purge
  for (std::size_t i=0; i<ma::privacy::kStoreCount; ++i) {
    auto store=static_cast<Store>(i);
    assert(workflow.recordReceipt(11,store));
    assert(workflow.recordReceipt(11,store));  // idempotent
  }
  assert(!workflow.complete(10));
  assert(workflow.complete(11));
  assert(workflow.state()==State::Complete);
  assert(!workflow.readAllowed());
  assert(!workflow.restoredItemCanSurface(10));
  assert(!workflow.restoredItemCanSurface(11));
  assert(!workflow.restoredItemCanSurface(12));  // no child resurrection
  assert(!workflow.request(13));  // completed erasure never resets
  std::cout << "privacy_lifecycle_policy PASS\n";
  return 0;
}
