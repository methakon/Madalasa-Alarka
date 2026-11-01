package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-38: Device provenance and handoff; Figma functional handoff.
 * TODO(INTEGRATION/API): Device observation provenance, source_id, confidence
 * TODO(INTEGRATION/GATE): Device location never automatically equals child's body
 * TODO(INTEGRATION/FAILURE): Stale watch; contradictory devices; device lost
 * Acceptance: Conflict visible; cannot merge sources as certainty.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P38Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-38", title = "Device provenance and handoff", hero = "Where did this observation come from?",
        kind = "list", milestone = "M3", requirement = "FR-020/038",
        details = listOf("Phone/tablet/watch source", "observed times", "disagreement states"),
        action = "Inspect source", modifier = modifier
    )
}
