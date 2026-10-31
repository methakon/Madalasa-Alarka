package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-31: Usage overview (gated); Figma functional handoff.
 * TODO(INTEGRATION/API): Android UsageStatsManager only after separate lawful-purpose approval
 * TODO(INTEGRATION/GATE): India minor behavioral monitoring remains OFF
 * TODO(INTEGRATION/FAILURE): No access; partial intervals; no legal signoff
 * Acceptance: No real usage records collected by default.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P31Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-31", title = "Usage overview (gated)", hero = "Usage reports disabled by default",
        kind = "usage", milestone = "M4", requirement = "FR-005/047",
        details = listOf("Legal gate notice", "possible day/week chart preview"),
        action = "Read why disabled", modifier = modifier
    )
}
