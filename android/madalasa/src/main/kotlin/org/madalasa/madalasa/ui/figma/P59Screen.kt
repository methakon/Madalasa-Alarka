package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-59: Phone and watch source handoff; Figma functional handoff.
 * TODO(INTEGRATION/API): Future device_source identities and timestamp-qualified observations
 * TODO(INTEGRATION/GATE): Wear OS support conditional; do not infer exact location from stale watch
 * TODO(INTEGRATION/FAILURE): Source conflict; watch offline; mixed accuracy
 * Acceptance: Provenance and uncertainty present, no forced merge.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P59Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-59", title = "Phone and watch source handoff", hero = "Device is not the child as a person",
        kind = "list", milestone = "P2", requirement = "FR-020/038",
        details = listOf("Phone/watch source and battery", "provenance", "conflict reasons"),
        action = "Inspect chosen source", modifier = modifier
    )
}
