package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-13: Battery settings walkthrough; Figma functional handoff.
 * TODO(INTEGRATION/API): Child package battery-intent + health capability report
 * TODO(INTEGRATION/GATE): No bypass of Doze or manufacturer limits
 * TODO(INTEGRATION/FAILURE): OEM UI differs; setting denied; device offline
 * Acceptance: Parent shows observed setting and stale/unknown if unavailable.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P13Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-13", title = "Battery settings walkthrough", hero = "Power & background guidance",
        kind = "permission", milestone = "M2", requirement = "FR-018/036",
        details = listOf("Explain OS battery restriction", "allow user choice", "recheck"),
        action = "Open child battery settings", modifier = modifier
    )
}
