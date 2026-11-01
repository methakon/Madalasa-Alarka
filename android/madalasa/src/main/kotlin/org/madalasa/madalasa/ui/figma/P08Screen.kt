package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-08: Install child app; Figma functional handoff.
 * TODO(INTEGRATION/API): Local onboarding wizard then capability precheck
 * TODO(INTEGRATION/GATE): Cannot remotely install app or silently grant child permissions
 * TODO(INTEGRATION/FAILURE): App absent; wrong Android API; no Play
 * Acceptance: Instructions include clear return-to-parent step.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P08Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-08", title = "Install child app", hero = "Install Alarka on the child's Android phone",
        kind = "wizard", milestone = "M1", requirement = "FR-001/002",
        details = listOf("On child's phone install app", "open visible setup", "check OS"),
        action = "Continue to pairing", modifier = modifier
    )
}
