package org.madalasa.alarka.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** C-08: Notification Settings guide; Figma functional handoff.
 * TODO(INTEGRATION/API): POST_NOTIFICATIONS as supported by OS; capability report
 * TODO(INTEGRATION/GATE): App may not force notification allowance or DND bypass
 * TODO(INTEGRATION/FAILURE): Disabled channel; API old; OS_REJECTED
 * Acceptance: Reported notification status matches device truth.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun C08Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "C-08", title = "Notification Settings guide", hero = "Allow visible status and alerts",
        kind = "permission", milestone = "M1", requirement = "FR-002/014",
        details = listOf("Android notification permission/channel list", "test notice"),
        action = "Open notification settings", modifier = modifier
    )
}
