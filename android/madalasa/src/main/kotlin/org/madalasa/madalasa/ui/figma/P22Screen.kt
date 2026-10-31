package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-22: Map evidence legend; Figma functional handoff.
 * TODO(INTEGRATION/API): Quality codes and source timestamps in route result
 * TODO(INTEGRATION/GATE): Parent can flag interpretation, not change raw GPS
 * TODO(INTEGRATION/FAILURE): Unknown source; missing accuracy
 * Acceptance: Accessible map colors and legend agree.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P22Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-22", title = "Map evidence legend", hero = "Every marker has a meaning",
        kind = "map", milestone = "M3", requirement = "FR-028/030",
        details = listOf("OBSERVED, APPROXIMATE, GAP, STOP_CONFIRMED"),
        action = "Inspect evidence", modifier = modifier
    )
}
