package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-35: Managed screen-time rules; Figma functional handoff.
 * TODO(INTEGRATION/API): DevicePolicyManager on provisioned DPC only; server stores rules
 * TODO(INTEGRATION/GATE): STANDARD always UNSUPPORTED; protect launcher/dialer
 * TODO(INTEGRATION/FAILURE): Package protected; local policy conflict
 * Acceptance: No critical app suspended; revert possible.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P35Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-35", title = "Managed screen-time rules", hero = "Available only on real device owner",
        kind = "managed", milestone = "M5", requirement = "FR-007/047",
        details = listOf("Eligible app list", "time windows", "exclusion list"),
        action = "Create schedule", modifier = modifier
    )
}
