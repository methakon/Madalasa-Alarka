package org.madalasa.alarka.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** C-02: Child transparency disclosure; Figma functional handoff.
 * TODO(INTEGRATION/API): Signed family grant summary and consent-purpose registry
 * TODO(INTEGRATION/GATE): Child may inspect monitoring and OS permissions regardless of subscription
 * TODO(INTEGRATION/FAILURE): Policy unavailable; withdrawn guardian; offline
 * Acceptance: No hidden monitoring scope and last verified snapshot indicated.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun C02Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "C-02", title = "Child transparency disclosure", hero = "Who can see what?",
        kind = "privacy", milestone = "M1", requirement = "FR-041",
        details = listOf("Authorized adults", "live location", "history/usage off", "data purpose"),
        action = "View authorized people", modifier = modifier
    )
}
