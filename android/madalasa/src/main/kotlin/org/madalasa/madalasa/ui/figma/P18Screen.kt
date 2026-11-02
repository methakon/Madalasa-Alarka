package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-18: Plans and app settings; Figma functional handoff.
 * TODO(INTEGRATION/API): Play product details and backend verified subscriptionsv2
 * TODO(INTEGRATION/GATE): Prices proposed; checkout governs tax, period and amount
 * TODO(INTEGRATION/FAILURE): Payment pending; unsupported child capability
 * Acceptance: No seats granted until verified paid state.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P18Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-18", title = "Plans and app settings", hero = "Family subscription options",
        kind = "billing", milestone = "M7", requirement = "FR-012/039",
        details = listOf("₹50 monthly", "₹500 yearly per child", "seats", "theme preference"),
        action = "Review actual Play checkout", modifier = modifier
    )
}
