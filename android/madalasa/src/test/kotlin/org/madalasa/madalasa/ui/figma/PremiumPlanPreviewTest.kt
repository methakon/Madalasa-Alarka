package org.madalasa.madalasa.ui.figma

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Approved 2026-11-04 free-first plan preview: regular list prices are visible, "Pay now" can
 * only open Coming Soon, and no purchase, trial or entitlement is reachable.
 */
class PremiumPlanPreviewTest {

    @Test
    fun bothRegularListPricesArePresented() {
        assertEquals(99, PremiumPlanPreviewCatalog.MONTHLY_LIST_PRICE_INR)
        assertEquals(999, PremiumPlanPreviewCatalog.YEARLY_LIST_PRICE_INR)
        assertEquals(
            listOf("₹99 / month · per paid child", "₹999 / year · per paid child"),
            PremiumPlanPreviewCatalog.plans.map { it.priceLabel() },
        )
    }

    @Test
    fun foundingAndCouponPricesAreNotPurchaseAmounts() {
        // ₹50 / ₹500 are not offered anywhere in the preview catalog.
        val amounts = PremiumPlanPreviewCatalog.plans.map { it.listPriceInr }
        assertFalse("founding monthly price must not be a purchasable amount", 50 in amounts)
        assertFalse("founding yearly price must not be a purchasable amount", 500 in amounts)
    }

    @Test
    fun payNowOnlyEverOpensComingSoon() {
        val state = PremiumPlanPreviewState()
        assertFalse(state.comingSoonVisible)
        val outcome = state.payNow()
        assertEquals(PayNowOutcome.ComingSoon, outcome)
        assertTrue("Pay now must surface the Coming Soon overlay", state.comingSoonVisible)
        assertEquals(PayNowOutcome.ComingSoon, state.lastOutcome)
    }

    @Test
    fun payNowGrantsNothingAndCreatesNoPurchase() {
        val state = PremiumPlanPreviewState()
        repeat(5) { state.payNow() }
        assertTrue("no entitlement may be granted from preview", state.grantedEntitlements.isEmpty())
        assertTrue("no purchase token may exist in preview", state.pendingPurchaseTokens.isEmpty())
        assertTrue(state.freeAccessUnchanged)
    }

    @Test
    fun bothDismissPathsReturnToUnchangedFreeAccess() {
        val state = PremiumPlanPreviewState()
        state.payNow()
        state.dismissComingSoon()
        assertFalse(state.comingSoonVisible)
        assertTrue(state.grantedEntitlements.isEmpty())

        // Re-opening and dismissing again must not accumulate any paid state.
        state.select(PlanInterval.YEARLY)
        state.payNow()
        state.dismissComingSoon()
        assertTrue(state.grantedEntitlements.isEmpty())
    }

    @Test
    fun planSelectionNeverImpliesPriorityForWaitlistedFamilies() {
        val state = PremiumPlanPreviewState()
        state.select(PlanInterval.YEARLY)
        assertEquals(PlanInterval.YEARLY, state.selectedPlan?.interval)
        // Selecting or previewing a plan cannot admit a child or change admission state.
        assertTrue(state.grantedEntitlements.isEmpty())
        assertEquals(999, state.selectedPlan?.listPriceInr)
        assertNull(state.lastOutcome)
    }

    @Test
    fun previewSourceReferencesNoPaymentProvider() {
        val candidates = listOf(
            "src/main/kotlin/org/madalasa/madalasa/ui/figma/PremiumPlanPreview.kt",
            "src/main/kotlin/org/madalasa/madalasa/ui/figma/PremiumPlanPreviewScreen.kt",
            "src/main/kotlin/org/madalasa/madalasa/ui/figma/P18Screen.kt",
        )
        val forbidden = listOf(
            "BillingClient", "com.android.billingclient", "BillDesk", "billdesk",
            "startConnection", "launchBillingFlow", "purchaseToken", "acknowledgePurchase",
        )
        candidates.forEach { relative ->
            val file = File(relative)
            assertTrue("expected preview source at $relative", file.exists())
            val text = file.readText()
            forbidden.forEach { token ->
                assertFalse("$relative must not reference $token", text.contains(token))
            }
        }
    }
    @Test
    fun upgradePreviewIsReachableFromRealParentNavigation() {
        val nav = File("src/main/kotlin/org/madalasa/madalasa/ui/navigation/MadalasaNavHost.kt").readText()
        val shell = File("src/main/kotlin/org/madalasa/madalasa/ui/screens/ShellScreen.kt").readText()
        val childSelect = File("src/main/kotlin/org/madalasa/madalasa/ui/screens/ChildSelectionScreen.kt").readText()
        assertTrue("The free-release preview needs an actual destination", nav.contains("composable(\"premium-preview\")"))
        assertTrue("The parent shell must expose plan preview", shell.contains("onExplorePremiumPlans"))
        assertTrue("Waitlisted families need the same preview entry", childSelect.contains("onExplorePremiumPlans"))
        assertTrue("The entry must not require an admitted child", nav.contains("onExplorePremiumPlans = { navController.navigate(\"premium-preview\") }"))
    }

    @Test
    fun comingSoonComposeStateIsObservableAndDismissible() {
        val ui = File("src/main/kotlin/org/madalasa/madalasa/ui/figma/PremiumPlanPreviewScreen.kt").readText()
        assertTrue("Compose must observe changes to dialog visibility", ui.contains("var dialogVisible by remember { mutableStateOf(false) }"))
        assertTrue("Pay now must show the dialog", ui.contains("dialogVisible = true"))
        assertTrue("Dismiss must hide the dialog", ui.contains("dialogVisible = false"))
        assertFalse("A mutable plain state object inside mutableStateOf does not trigger recomposition",
            ui.contains("var state by remember { mutableStateOf(PremiumPlanPreviewState()) }"))
    }

}
