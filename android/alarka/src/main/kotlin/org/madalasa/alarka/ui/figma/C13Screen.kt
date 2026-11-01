package org.madalasa.alarka.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** C-13: Child device health; Figma functional handoff.
 * TODO(INTEGRATION/API): POST /devices/{deviceId}/health and /capabilities
 * TODO(INTEGRATION/GATE): Heartbeat is not GPS; report as separately timestamped
 * TODO(INTEGRATION/FAILURE): Revoked key; OS permission changed; offline
 * Acceptance: No false fresh state from stale heartbeat.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun C13Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "C-13", title = "Child device health", hero = "Why might reports be delayed?",
        kind = "metrics", milestone = "M1", requirement = "FR-014/048",
        details = listOf("Battery", "network", "Android API", "app version"),
        action = "Send health check", modifier = modifier
    )
}
