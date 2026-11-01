package org.madalasa.alarka.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** C-14: Encrypted offline queue; Figma functional handoff.
 * TODO(INTEGRATION/API): Encrypted local durable queue; idempotent event_uuid upload on reconnect
 * TODO(INTEGRATION/GATE): Only delete local events after confirmed DB commit ACK
 * TODO(INTEGRATION/FAILURE): No network; low disk; duplicate; revoked child
 * Acceptance: No duplicate server record and no fake successful send.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun C14Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "C-14", title = "Encrypted offline queue", hero = "Waiting to synchronize safely",
        kind = "offline", milestone = "M2", requirement = "FR-023/024",
        details = listOf("Event count", "oldest pending age", "last ACK", "errors"),
        action = "Retry when available", modifier = modifier
    )
}
