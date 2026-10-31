package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-15: Travel history overview; Figma functional handoff.
 * TODO(INTEGRATION/API): M3 trip/segment revision reads from C++ event-time worker
 * TODO(INTEGRATION/GATE): History OFF for minors until separate legal review
 * TODO(INTEGRATION/FAILURE): GPS gap; low accuracy; late event
 * Acceptance: No invented paths or 'precise road' guess.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P15Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-15", title = "Travel history overview", hero = "Observed route and unknown gaps",
        kind = "map", milestone = "M3", requirement = "FR-004/016/028/030",
        details = listOf("Day filter", "segmented map", "stops", "quality legend"),
        action = "Open trip detail", modifier = modifier
    )
}
