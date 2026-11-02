package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-27: Add named place; Figma functional handoff.
 * TODO(INTEGRATION/API): PostGIS point/radius validation; scoped child place API
 * TODO(INTEGRATION/GATE): Allow only authorized owner and lawful purpose
 * TODO(INTEGRATION/FAILURE): Out-of-bounds; geocode failure; overlap
 * Acceptance: Place saved once; map clearly approximate.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P27Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-27", title = "Add named place", hero = "Save a meaningful location",
        kind = "form", milestone = "M3", requirement = "FR-015",
        details = listOf("Map picker", "name", "radius", "accuracy caveat"),
        action = "Save place", modifier = modifier
    )
}
