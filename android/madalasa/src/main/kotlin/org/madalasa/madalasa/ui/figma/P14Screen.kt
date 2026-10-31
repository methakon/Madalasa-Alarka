package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-14: Setup/device verification; Figma functional handoff.
 * TODO(INTEGRATION/API): GET child devices; POST /devices/{id}/health + capabilities
 * TODO(INTEGRATION/GATE): Only OS-proven MANAGED_DEVICE_OWNER label; no fake DPC
 * TODO(INTEGRATION/FAILURE): No heartbeat; revoked credential; stale response
 * Acceptance: PASS/PENDING/FAILED shown with actual timestamps.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P14Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-14", title = "Setup/device verification", hero = "Step 5 of 6 • Verify child phone",
        kind = "metrics", milestone = "M1", requirement = "FR-001/014/048",
        details = listOf("Android API", "enrolled key", "heartbeat", "notifications"),
        action = "Run device check", modifier = modifier
    )
}
