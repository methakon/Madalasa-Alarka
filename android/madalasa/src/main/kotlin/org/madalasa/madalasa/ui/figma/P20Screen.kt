package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-20: Alert detail; Figma functional handoff.
 * TODO(INTEGRATION/API): Alert event and authorized observation reference
 * TODO(INTEGRATION/GATE): No 'emergency' if FCM was merely accepted
 * TODO(INTEGRATION/FAILURE): Unknown device state; missing source
 * Acceptance: Confidence and staleness explicitly visible.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P20Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-20", title = "Alert detail", hero = "What happened, how certain?",
        kind = "detail", milestone = "M4", requirement = "FR-030/049",
        details = listOf("Source time", "reason", "data confidence", "ACK"),
        action = "Review evidence", modifier = modifier
    )
}
