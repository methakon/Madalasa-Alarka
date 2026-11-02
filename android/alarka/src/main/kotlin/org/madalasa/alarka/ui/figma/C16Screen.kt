package org.madalasa.alarka.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** C-16: SOS status and manual call; Figma functional handoff.
 * TODO(INTEGRATION/API): High-priority outbox and optional SMS fallback if separately funded
 * TODO(INTEGRATION/GATE): No guarantee of rescue; real independent outage path absent
 * TODO(INTEGRATION/FAILURE): Primary VM down; offline; SMS vendor missing
 * Acceptance: Visible honest pending state, never fake guardian notified.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun C16Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "C-16", title = "SOS status and manual call", hero = "Best-effort safety contact, not dispatch",
        kind = "alerts", milestone = "M4", requirement = "FR-044",
        details = listOf("Queued", "server accepted", "push provider accepted", "guardian ACK"),
        action = "Open phone dialer", modifier = modifier
    )
}
