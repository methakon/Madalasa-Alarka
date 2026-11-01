package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-32: App usage detail (gated); Figma functional handoff.
 * TODO(INTEGRATION/API): Scoped usage aggregate API only if allowed
 * TODO(INTEGRATION/GATE): Never imply complete report from partial telemetry
 * TODO(INTEGRATION/FAILURE): Permission revoked; timezone mismatch
 * Acceptance: Missing intervals visibly excluded.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P32Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-32", title = "App usage detail (gated)", hero = "Per-app time must disclose gaps",
        kind = "usage", milestone = "M4", requirement = "FR-005",
        details = listOf("App categories", "observed window", "time totals", "missing duration"),
        action = "Open usage interval", modifier = modifier
    )
}
