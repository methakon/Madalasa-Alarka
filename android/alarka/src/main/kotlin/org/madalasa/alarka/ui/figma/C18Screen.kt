package org.madalasa.alarka.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** C-18: Child settings & appearance; Figma functional handoff.
 * TODO(INTEGRATION/API): Local DataStore; child capability+policy read
 * TODO(INTEGRATION/GATE): Theme implementation left to developers; visual design one style
 * TODO(INTEGRATION/FAILURE): Preference unavailable; no server; permission denied
 * Acceptance: Privacy notice available regardless of selected theme.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun C18Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "C-18", title = "Child settings & appearance", hero = "Simple device-level preferences",
        kind = "detail", milestone = "M1", requirement = "FR-041",
        details = listOf("Light/dark/eco future handoff", "disclosure", "help", "permission shortcuts"),
        action = "Open app settings", modifier = modifier
    )
}
