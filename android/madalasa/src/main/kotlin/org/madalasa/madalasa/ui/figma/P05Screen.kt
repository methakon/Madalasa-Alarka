package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-05: Home dashboard; Figma functional handoff.
 * TODO(INTEGRATION/API): Backend latest-qualified observation+health; auth per child
 * TODO(INTEGRATION/GATE): Never request fresh GPS just because parent opens map
 * TODO(INTEGRATION/FAILURE): Offline; old fix; no location consent
 * Acceptance: Stale badge and unknown position shown accurately.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P05Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-05", title = "Home dashboard", hero = "Last observed child location",
        kind = "map", milestone = "M2", requirement = "FR-003/014/026/031",
        details = listOf("Child switcher", "map preview", "location timestamp", "battery"),
        action = "View child location", modifier = modifier
    )
}
