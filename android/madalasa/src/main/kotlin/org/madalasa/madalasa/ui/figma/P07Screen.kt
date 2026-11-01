package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-07: Child details; Figma functional handoff.
 * TODO(INTEGRATION/API): GET /children/{childId}/devices; child capabilities/health
 * TODO(INTEGRATION/GATE): STANDARD is not managed; show report timestamp
 * TODO(INTEGRATION/FAILURE): Offline; UNKNOWN; OS_REJECTED
 * Acceptance: Capability and last contact separate, no fabricated live claim.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P07Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-07", title = "Child details", hero = "Truthful device health",
        kind = "detail", milestone = "M1", requirement = "FR-014/020/048",
        details = listOf("Linked device", "Android version", "battery", "heartbeat"),
        action = "Open permissions and health", modifier = modifier
    )
}
