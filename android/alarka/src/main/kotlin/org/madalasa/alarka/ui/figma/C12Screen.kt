package org.madalasa.alarka.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** C-12: Monitoring center; Figma functional handoff.
 * TODO(INTEGRATION/API): Scoped server grants and on-device collection flags
 * TODO(INTEGRATION/GATE): Always accessible even if app's setup Activity is closed
 * TODO(INTEGRATION/FAILURE): Offline; pending policy; revoked family
 * Acceptance: Disclosure correctly reflects actual enabled categories.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun C12Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "C-12", title = "Monitoring center", hero = "Child-visible monitoring summary",
        kind = "privacy", milestone = "M1", requirement = "FR-041",
        details = listOf("Active categories", "approved adults", "time of last sync", "revoke info"),
        action = "View monitoring scope", modifier = modifier
    )
}
