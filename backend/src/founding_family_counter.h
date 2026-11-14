// L10-004 — Founding family 1008 distinct paid counter & eligibility rules.
//
// Governance:
//   - SRS §billing / SUBSCRIPTION_TIERS_PRICING_AND_DISCOUNTS.md
//   - docs/data-model/FIGMA_SCREEN_GAP_PHYSICAL_SCHEMA_REVIEW_2026-10-28.md:
//     "founding rank 1–1008 is distinct paying family, not counted per child.
//      Child added later to an admitted founding family inherits the founding rate."
//   - Migration 0004: ap_m1.founding_families (qualifying_rank BETWEEN 1 AND 1008)
#pragma once
#include <cstdint>
#include <optional>
#include <string>
#include <string_view>
#include <unordered_map>
#include <unordered_set>

namespace ma::billing {

inline constexpr std::int32_t kMaxFoundingFamilies = 1008;

inline constexpr std::int32_t kPublicMonthPaise = 9900;
inline constexpr std::int32_t kFoundingMonthPaise = 5000;

inline constexpr std::int32_t kPublicYearPaise = 99900;
inline constexpr std::int32_t kFoundingYearPaise = 50000;

inline constexpr std::int32_t kExtraViewer100dPaise = 10000;

enum class SkuKind { Month, Year, Addon };

inline std::optional<SkuKind> parse_sku_kind(std::string_view sku_id) {
  if (sku_id == "local_prepaid_month") return SkuKind::Month;
  if (sku_id == "local_prepaid_year") return SkuKind::Year;
  if (sku_id == "local_extra_viewer_100d") return SkuKind::Addon;
  return std::nullopt;
}

// Determines whether a given qualifying rank qualifies for founding benefits.
inline constexpr bool is_founding_rank(std::int32_t rank) noexcept {
  return rank >= 1 && rank <= kMaxFoundingFamilies;
}

// Computes the amount in paise for a purchase given founding eligibility, SKU, and number of children.
inline std::optional<std::int64_t> calculate_purchase_amount(
    std::string_view sku_id, bool is_founding, std::size_t child_count) {
  if (child_count == 0) return std::nullopt;
  auto kind = parse_sku_kind(sku_id);
  if (!kind) return std::nullopt;

  std::int32_t unit_price = 0;
  switch (*kind) {
    case SkuKind::Month:
      unit_price = is_founding ? kFoundingMonthPaise : kPublicMonthPaise;
      break;
    case SkuKind::Year:
      unit_price = is_founding ? kFoundingYearPaise : kPublicYearPaise;
      break;
    case SkuKind::Addon:
      unit_price = kExtraViewer100dPaise;
      break;
  }
  return static_cast<std::int64_t>(unit_price) * static_cast<std::int64_t>(child_count);
}

// In-memory model of the 1008 distinct paying family counter, mirroring PostgreSQL
// ap_m1.founding_families and the advisory lock serialization in migration 0004.
class FoundingFamilyRegistry {
 public:
  struct AdmissionResult {
    bool newly_admitted{false};
    bool is_founding{false};
    std::optional<std::int32_t> rank{};
  };

  AdmissionResult record_paid_purchase(const std::string& family_id, bool is_addon) {
    if (family_id.empty()) return {false, false, std::nullopt};

    // If family is already admitted, it preserves its founding rank
    auto it = family_ranks_.find(family_id);
    if (it != family_ranks_.end()) {
      return {false, true, it->second};
    }

    // Addon purchases do not qualify a new family for founding status (SQL: c.kind <> 'ADDON')
    if (is_addon) {
      return {false, false, std::nullopt};
    }

    // Next rank allocation
    std::int32_t next_rank = static_cast<std::int32_t>(family_ranks_.size()) + 1;
    if (next_rank <= kMaxFoundingFamilies) {
      family_ranks_[family_id] = next_rank;
      return {true, true, next_rank};
    }

    // Above 1008: not founding eligible
    return {false, false, std::nullopt};
  }

  bool is_family_founding(const std::string& family_id) const {
    return family_ranks_.find(family_id) != family_ranks_.end();
  }

  std::size_t admitted_count() const noexcept {
    return family_ranks_.size();
  }

  std::optional<std::int32_t> get_rank(const std::string& family_id) const {
    auto it = family_ranks_.find(family_id);
    if (it != family_ranks_.end()) return it->second;
    return std::nullopt;
  }

 private:
  std::unordered_map<std::string, std::int32_t> family_ranks_;
};

} // namespace ma::billing
