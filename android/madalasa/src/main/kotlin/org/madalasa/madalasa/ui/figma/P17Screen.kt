package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-17: Alerts and check-ins; Figma functional handoff.
 * TODO(INTEGRATION/API): SOS outbox status and guardian ACK endpoint (planned)
 * TODO(INTEGRATION/GATE): No guaranteed emergency dispatch from single OCI VM
 * TODO(INTEGRATION/FAILURE): OFFLINE_QUEUED; PROVIDER_ACCEPTED; UNACKED
 * Acceptance: Child and parent statuses match server evidence.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P17Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-17", title = "Alerts and check-ins", hero = "Acknowledgement is not FCM delivery",
        kind = "alerts", milestone = "M4", requirement = "FR-014/044/046/049",
        details = listOf("Event cards", "priority", "delivery and human ACK states"),
        action = "Acknowledge check-in", modifier = modifier
    )
}
