package org.madalasa.alarka.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** C-15: Child quick check-in; Figma functional handoff.
 * TODO(INTEGRATION/API): Child-signed event UUID to durable SOS/check-in ingress
 * TODO(INTEGRATION/GATE): Parent receives only if RECEIVE_CHECKIN grant verified
 * TODO(INTEGRATION/FAILURE): Offline; no recipient; FCM accepted
 * Acceptance: Human ACK shown separately from server acceptance.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun C15Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "C-15", title = "Child quick check-in", hero = "Let a guardian know you're okay",
        kind = "alerts", milestone = "M4", requirement = "FR-046",
        details = listOf("Visible I'm OK / Need contact", "queue and status"),
        action = "Send check-in", modifier = modifier
    )
}
