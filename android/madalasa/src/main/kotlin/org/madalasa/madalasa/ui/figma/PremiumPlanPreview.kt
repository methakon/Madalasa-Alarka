package org.madalasa.madalasa.ui.figma

/**
 * Approved 2026-11-04 free-first premium plan preview.
 *
 * Regular list prices are shown to every free user, including waitlisted families, without
 * implying paid priority. Checkout is a **preview only**: "Pay now" opens a Coming Soon
 * overlay and must never invoke an in-app billing SDK, a hosted checkout, a payment profile,
 * a payment-method form, an order API, a coupon, an entitlement grant or a trial.
 *
 * Server-side FREE_ONLY enforcement stays authoritative; this UI cannot create a paid state
 * and the 108-child admission cap is never purchasable.
 */
enum class PlanInterval(val label: String) {
    MONTHLY("Monthly"),
    YEARLY("Yearly"),
}

/**
 * A catalog entry. [listPriceInr] is the regular list price in whole rupees; no founding,
 * coupon or tax-inclusive amount is modelled here because none is approved.
 */
data class PlanPreview(
    val interval: PlanInterval,
    val title: String,
    val listPriceInr: Int,
    val cadence: String,
    val summary: String,
    val benefits: List<String>,
    val contingentNote: String,
)

/** What "Pay now" is allowed to do in this release. */
sealed interface PayNowOutcome {
    /** The only permitted outcome: show the Coming Soon overlay. */
    data object ComingSoon : PayNowOutcome
}

/**
 * Catalog of previewable plans. Prices are the owner-approved regular list prices:
 * ₹99 per month per paid child and ₹999 per year per paid child.
 */
object PremiumPlanPreviewCatalog {
    const val MONTHLY_LIST_PRICE_INR = 99
    const val YEARLY_LIST_PRICE_INR = 999

    val monthly = PlanPreview(
        interval = PlanInterval.MONTHLY,
        title = "Premium · monthly",
        listPriceInr = MONTHLY_LIST_PRICE_INR,
        cadence = "per month, per paid child",
        summary = "Prepaid monthly plan for one selected child.",
        benefits = listOf(
            "Live location for the selected child",
            "Longer visible location history",
            "One premium live viewer per paid child",
        ),
        contingentNote = "Benefits are future and contingent on OS, legal, Play and device capability.",
    )

    val yearly = PlanPreview(
        interval = PlanInterval.YEARLY,
        title = "Premium · yearly",
        listPriceInr = YEARLY_LIST_PRICE_INR,
        cadence = "per year, per paid child",
        summary = "Prepaid yearly plan for one selected child — no automatic renewal.",
        benefits = monthly.benefits + "One prepaid year at the yearly list price",
        contingentNote = monthly.contingentNote,
    )

    val plans: List<PlanPreview> = listOf(monthly, yearly)

    /** Administrative fee notes must never appear as a purchasable amount in preview. */
    val deferredToCheckout: List<String> = listOf(
        "Coupon or founding discount",
        "Eligibility checks",
        "Taxes and final payable amount",
    )
}

/**
 * Pure preview state machine. Deliberately dependency-free: it holds no billing client, no
 * network access and no entitlement store, so a forged tap cannot create a purchase.
 */
class PremiumPlanPreviewState(initial: PlanPreview? = PremiumPlanPreviewCatalog.monthly) {

    var selectedPlan: PlanPreview? = initial
        private set

    var comingSoonVisible: Boolean = false
        private set

    var lastOutcome: PayNowOutcome? = null
        private set

    /** No payment, no trial and no entitlement is ever granted from this preview. */
    val grantedEntitlements: List<String> get() = emptyList()

    /** Purchases do not exist yet; a caller asking for one gets an empty list, not a token. */
    val pendingPurchaseTokens: List<String> get() = emptyList()

    fun select(plan: PlanPreview) {
        selectedPlan = plan
    }

    fun select(interval: PlanInterval) {
        PremiumPlanPreviewCatalog.plans.firstOrNull { it.interval == interval }?.let(::select)
    }

    /** Pay now can only ever open Coming Soon. */
    fun payNow(): PayNowOutcome.ComingSoon {
        comingSoonVisible = true
        lastOutcome = PayNowOutcome.ComingSoon
        return PayNowOutcome.ComingSoon
    }

    /** Both "Close" and "Got it — continue free" dismiss to the unchanged free experience. */
    fun dismissComingSoon() {
        comingSoonVisible = false
    }

    /** Free access is unchanged by previewing or dismissing. */
    val freeAccessUnchanged: Boolean get() = grantedEntitlements.isEmpty()
}

/** Display helper so both plan surfaces render the same regular list price. */
fun PlanPreview.priceLabel(): String = when (interval) {
    PlanInterval.MONTHLY -> "₹${listPriceInr} / month · per paid child"
    PlanInterval.YEARLY -> "₹${listPriceInr} / year · per paid child"
}
