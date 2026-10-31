package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-28: Place-alert configuration; Figma functional handoff.
 * TODO(INTEGRATION/API): Geofence or server-derived place transitions and dedupe
 * TODO(INTEGRATION/GATE): Unknown GPS is not confirmed leave/arrival
 * TODO(INTEGRATION/FAILURE): False detection; no location; notification off
 * Acceptance: No repeated alarm storm on jitter.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P28Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-28", title = "Place-alert configuration", hero = "Notify on selected arrivals",
        kind = "form", milestone = "M4", requirement = "FR-021/049",
        details = listOf("Child", "place", "arrival/departure", "debounce"),
        action = "Save alert rule", modifier = modifier
    )
}
