// L10-004 — Unit tests for founding family 1008 distinct paid counter & pricing logic.
#include <iostream>
#include <string>
#include "founding_family_counter.h"

static int failures = 0;
#define CHECK(x) do { if (!(x)) { std::cerr << "FAIL line " << __LINE__ << ": " #x "\n"; ++failures; } } while (0)

int main() {
  using namespace ma::billing;

  // 1. Rank boundary checks
  CHECK(!is_founding_rank(0));
  CHECK(is_founding_rank(1));
  CHECK(is_founding_rank(500));
  CHECK(is_founding_rank(1008));
  CHECK(!is_founding_rank(1009));
  CHECK(!is_founding_rank(-1));

  // 2. Price calculation unit tests
  CHECK(calculate_purchase_amount("local_prepaid_month", true, 1) == 5000);
  CHECK(calculate_purchase_amount("local_prepaid_month", false, 1) == 9900);
  CHECK(calculate_purchase_amount("local_prepaid_month", true, 2) == 10000);
  CHECK(calculate_purchase_amount("local_prepaid_month", false, 2) == 19800);

  CHECK(calculate_purchase_amount("local_prepaid_year", true, 1) == 50000);
  CHECK(calculate_purchase_amount("local_prepaid_year", false, 1) == 99900);
  CHECK(calculate_purchase_amount("local_prepaid_year", true, 3) == 150000);
  CHECK(calculate_purchase_amount("local_prepaid_year", false, 3) == 299700);

  CHECK(calculate_purchase_amount("local_extra_viewer_100d", true, 1) == 10000);
  CHECK(calculate_purchase_amount("local_extra_viewer_100d", false, 1) == 10000);

  CHECK(!calculate_purchase_amount("local_prepaid_month", true, 0).has_value());
  CHECK(!calculate_purchase_amount("unknown_sku", true, 1).has_value());

  // 3. FoundingFamilyRegistry behavior: exactly 1008 distinct families
  FoundingFamilyRegistry registry;
  CHECK(registry.admitted_count() == 0);

  // Addon does not grant founding status to an unpaid family
  auto addonRes = registry.record_paid_purchase("family-zero", true);
  CHECK(!addonRes.newly_admitted);
  CHECK(!addonRes.is_founding);
  CHECK(registry.admitted_count() == 0);

  // Admit families 1 through 1008
  for (int i = 1; i <= 1008; ++i) {
    std::string fid = "family-" + std::to_string(i);
    auto res = registry.record_paid_purchase(fid, false);
    CHECK(res.newly_admitted);
    CHECK(res.is_founding);
    CHECK(res.rank.has_value() && *res.rank == i);
    CHECK(registry.is_family_founding(fid));
  }
  CHECK(registry.admitted_count() == 1008);

  // Repeated purchase by existing founding family preserves rank and does not increment counter
  auto repeat = registry.record_paid_purchase("family-42", false);
  CHECK(!repeat.newly_admitted);
  CHECK(repeat.is_founding);
  CHECK(repeat.rank.has_value() && *repeat.rank == 42);
  CHECK(registry.admitted_count() == 1008);

  // Child added later to an admitted founding family inherits founding eligibility
  CHECK(registry.is_family_founding("family-42"));
  auto child2Price = calculate_purchase_amount("local_prepaid_month", registry.is_family_founding("family-42"), 1);
  CHECK(child2Price == 5000);

  // 1009th distinct family is denied founding rank
  auto f1009 = registry.record_paid_purchase("family-1009", false);
  CHECK(!f1009.newly_admitted);
  CHECK(!f1009.is_founding);
  CHECK(!f1009.rank.has_value());
  CHECK(!registry.is_family_founding("family-1009"));
  CHECK(registry.admitted_count() == 1008);

  // 1009th family pays public pricing
  auto f1009Price = calculate_purchase_amount("local_prepaid_month", registry.is_family_founding("family-1009"), 1);
  CHECK(f1009Price == 9900);

  if (failures) return 1;
  std::cout << "founding family 1008 counter & eligibility tests PASS\n";
  return 0;
}
