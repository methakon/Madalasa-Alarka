package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-37: Managed eligibility; Figma functional handoff.
 * TODO(INTEGRATION/API): Android DevicePolicyManager isDeviceOwnerApp on child
 * TODO(INTEGRATION/GATE): No remote conversion of ordinary installed app to device owner
 * TODO(INTEGRATION/FAILURE): Non-resettable device; unsupported API; enrollment failed
 * Acceptance: STANDARD remains usable and managed features disabled.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P37Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-37", title = "Managed eligibility", hero = "Managed mode is an explicit choice",
        kind = "managed", milestone = "M5", requirement = "FR-007",
        details = listOf("Eligible device info", "OEM/API", "ownership status", "setup caveat"),
        action = "Open lab provisioning guide", modifier = modifier
    )
}
