package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-57: Photo/video capability request; Figma functional handoff.
 * TODO(INTEGRATION/API): Backend request status; child OS Camera APIs after user-authorized visible flow
 * TODO(INTEGRATION/GATE): Camera permission does not override Android background camera limits
 * TODO(INTEGRATION/FAILURE): OS_REJECTED; UNSUPPORTED; user declined
 * Acceptance: Never show successful capture unless child actually produces authorized result.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P57Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-57", title = "Photo/video capability request", hero = "Camera request is conditional, not secret",
        kind = "managed", milestone = "P3", requirement = "FR-009",
        details = listOf("Explain device/version", "pending remote request", "visible child action"),
        action = "View supported capture mode", modifier = modifier
    )
}
