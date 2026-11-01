package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-53: Permission-change notice; Figma functional handoff.
 * TODO(INTEGRATION/API): Latest signed child capabilities with revision timestamp
 * TODO(INTEGRATION/GATE): Do not infer user denial from silent device
 * TODO(INTEGRATION/FAILURE): No fresh capability; app uninstalled; OS_CHANGED
 * Acceptance: Unknown differs from DENIED, parent can recheck.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P53Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-53", title = "Permission-change notice", hero = "A previously allowed feature stopped",
        kind = "permission", milestone = "M2", requirement = "FR-002/031",
        details = listOf("Lost location/notif privilege", "observed time", "child guide"),
        action = "Show guided repair steps", modifier = modifier
    )
}
