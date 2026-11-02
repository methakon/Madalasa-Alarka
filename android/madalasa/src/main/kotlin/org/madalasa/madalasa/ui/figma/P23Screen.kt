package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-23: Travel day selector; Figma functional handoff.
 * TODO(INTEGRATION/API): M3 trip list query with date+timezone window
 * TODO(INTEGRATION/GATE): No inferred travel for missing time
 * TODO(INTEGRATION/FAILURE): Empty; revised; out of order
 * Acceptance: Trip boundaries match event-time processing.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P23Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-23", title = "Travel day selector", hero = "One day, many trip legs",
        kind = "list", milestone = "M3", requirement = "FR-004/017",
        details = listOf("Date", "timezone", "day totals", "trip leg cards"),
        action = "Open selected trip", modifier = modifier
    )
}
