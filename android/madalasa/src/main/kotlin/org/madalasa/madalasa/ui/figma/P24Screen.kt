package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-24: Trip detail; Figma functional handoff.
 * TODO(INTEGRATION/API): M3 trip segments, stop versions and quality evidence
 * TODO(INTEGRATION/GATE): No road interpolation across gaps; Roads API OFF
 * TODO(INTEGRATION/FAILURE): Long gap; low confidence; late events
 * Acceptance: Renders unknown segments separately.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P24Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-24", title = "Trip detail", hero = "A path with honest uncertainty",
        kind = "map", milestone = "M3", requirement = "FR-016/017/024",
        details = listOf("Segment map", "distance range", "stop dwell", "source marker"),
        action = "Inspect segment", modifier = modifier
    )
}
