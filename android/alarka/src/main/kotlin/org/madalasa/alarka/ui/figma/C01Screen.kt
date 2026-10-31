package org.madalasa.alarka.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** C-01: Child welcome; Figma functional handoff.
 * TODO(INTEGRATION/API): Local onboarding state; no sensors until legal and OS grants
 * TODO(INTEGRATION/GATE): Age-appropriate transparency and identifiable app entry
 * TODO(INTEGRATION/FAILURE): Guardian unverified; unsupported Android; offline
 * Acceptance: Accessible monitoring information always available.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun C01Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "C-01", title = "Child welcome", hero = "Welcome to Alarka, the transparent child companion",
        kind = "auth", milestone = "M1", requirement = "FR-002/041",
        details = listOf("Install disclosure", "what it does", "setup is not hidden"),
        action = "Begin setup", modifier = modifier
    )
}
