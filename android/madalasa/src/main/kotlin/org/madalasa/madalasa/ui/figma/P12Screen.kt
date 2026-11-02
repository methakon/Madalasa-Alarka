package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-12: Location permission walkthrough; Figma functional handoff.
 * TODO(INTEGRATION/API): Child launches Settings; onResume rechecks actual permission state
 * TODO(INTEGRATION/GATE): OS background rules still apply after grant
 * TODO(INTEGRATION/FAILURE): Approximate only; denied; OS_REJECTED
 * Acceptance: Never mark enabled based only on opened settings.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P12Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-12", title = "Location permission walkthrough", hero = "Android Location Settings guide",
        kind = "permission", milestone = "M2", requirement = "FR-002/003",
        details = listOf("Open child's app info", "choose location permission", "return and test"),
        action = "Show next step", modifier = modifier
    )
}
