package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-36: Rule preview and rollback; Figma functional handoff.
 * TODO(INTEGRATION/API): Pure scheduling simulator + signed device execution receipts
 * TODO(INTEGRATION/GATE): Owner confirmation, safe revert and per-device capability
 * TODO(INTEGRATION/FAILURE): Timezone change; partial result; stale device
 * Acceptance: Preview matches execution; rollback restores harmless app.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P36Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-36", title = "Rule preview and rollback", hero = "Seven-day impact preview",
        kind = "managed", milestone = "M5", requirement = "FR-037",
        details = listOf("DST transitions", "protected apps", "expected blocks", "revert"),
        action = "Apply approved plan", modifier = modifier
    )
}
