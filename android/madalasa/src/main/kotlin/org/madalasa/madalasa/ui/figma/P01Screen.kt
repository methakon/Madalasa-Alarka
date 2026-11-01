package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-01: Welcome; Figma functional handoff.
 * TODO(INTEGRATION/API): Local navigation; no API before user action
 * TODO(INTEGRATION/GATE): No collection until lawful authority and child disclosure
 * TODO(INTEGRATION/FAILURE): Offline; wrong role; policy unavailable
 * Acceptance: Both paths available; no child record created here.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P01Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-01", title = "Welcome", hero = "Welcome to Madalasa: family safety with transparency",
        kind = "auth", milestone = "M1", requirement = "FR-001/041",
        details = listOf("Parent or Child entry", "privacy, support and language links"),
        action = "Start parent setup", modifier = modifier
    )
}
