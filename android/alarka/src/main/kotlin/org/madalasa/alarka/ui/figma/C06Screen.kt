package org.madalasa.alarka.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** C-06: Child permission overview; Figma functional handoff.
 * TODO(INTEGRATION/API): CapabilityRegistry / POST /devices/{id}/capabilities
 * TODO(INTEGRATION/GATE): No remote parent-granted Android permissions, show actual OS state
 * TODO(INTEGRATION/FAILURE): UNKNOWN; OS_REJECTED; DENIED
 * Acceptance: Settings recheck onResume, no assumed success.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun C06Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "C-06", title = "Child permission overview", hero = "Check each setting on this phone",
        kind = "permission", milestone = "M1", requirement = "FR-002",
        details = listOf("Location", "notifications", "battery", "usage OFF"),
        action = "Open a permission guide", modifier = modifier
    )
}
