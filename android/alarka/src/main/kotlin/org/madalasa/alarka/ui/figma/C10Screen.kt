package org.madalasa.alarka.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** C-10: Usage Access (disabled); Figma functional handoff.
 * TODO(INTEGRATION/API): UsageStatsManager path only after Indian counsel/owner approval
 * TODO(INTEGRATION/GATE): OFF for Indian minors by default even with OS grant
 * TODO(INTEGRATION/FAILURE): No consent; missing Usage Access; partial report
 * Acceptance: No actual usage data collected in initial minor pilot.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun C10Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "C-10", title = "Usage Access (disabled)", hero = "App usage is legally gated",
        kind = "usage", milestone = "M4", requirement = "FR-005/047",
        details = listOf("Show reason", "no hidden usage table", "opt-in review if approved"),
        action = "Read feature requirements", modifier = modifier
    )
}
