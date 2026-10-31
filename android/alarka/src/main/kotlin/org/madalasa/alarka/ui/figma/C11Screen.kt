package org.madalasa.alarka.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** C-11: Managed DPC setup; Figma functional handoff.
 * TODO(INTEGRATION/API): DevicePolicyManager.isDeviceOwnerApp; documented factory provisioning
 * TODO(INTEGRATION/GATE): Ordinary installed app cannot become DPC with a tap
 * TODO(INTEGRATION/FAILURE): Not resettable; STANDARD; protected package
 * Acceptance: Never mark managed without OS device owner confirmation.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun C11Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "C-11", title = "Managed DPC setup", hero = "Managed ownership requires special provisioning",
        kind = "managed", milestone = "M5", requirement = "FR-007/037",
        details = listOf("Device-owner prerequisites", "backup/reset warning", "lab-only guide"),
        action = "Check provisioning status", modifier = modifier
    )
}
