package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-11: Parent permission coach; Figma functional handoff.
 * TODO(INTEGRATION/API): Child POST signed capability; parent reads status
 * TODO(INTEGRATION/GATE): Parent cannot remotely grant Android OS permission
 * TODO(INTEGRATION/FAILURE): DENIED; UNKNOWN; UNSUPPORTED
 * Acceptance: Only fresh child report marks a permission granted.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P11Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-11", title = "Parent permission coach", hero = "Step 4 of 6 • Permission guide",
        kind = "permission", milestone = "M1", requirement = "FR-002/031",
        details = listOf("Location", "notifications", "battery", "usage OFF"),
        action = "See child-phone steps", modifier = modifier
    )
}
