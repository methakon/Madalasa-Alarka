package org.madalasa.alarka.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** C-20: Optional media capture request; Figma functional handoff.
 * TODO(INTEGRATION/API): No M1 endpoint; conditional child-initiated capture API research
 * TODO(INTEGRATION/GATE): Background OS limits persist after grant; cannot pretend stealth capture
 * TODO(INTEGRATION/FAILURE): Denied; not foreground; privacy indicator
 * Acceptance: Default DISABLED, no automatic hidden recording.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun C20Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "C-20", title = "Optional media capture request", hero = "No hidden camera or microphone access",
        kind = "managed", milestone = "P3", requirement = "FR-009/010",
        details = listOf("Feature unavailable notice", "OS/version support", "visible permission flow if approved"),
        action = "See capability explanation", modifier = modifier
    )
}
