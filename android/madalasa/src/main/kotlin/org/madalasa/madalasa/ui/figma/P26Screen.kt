package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-26: Named places list; Figma functional handoff.
 * TODO(INTEGRATION/API): Authorized saved places CRUD; PostGIS geography
 * TODO(INTEGRATION/GATE): Per-child guardians can see only scoped places
 * TODO(INTEGRATION/FAILURE): No place; radius invalid; duplication
 * Acceptance: Saved data stored with verified family and child.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P26Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-26", title = "Named places list", hero = "Places you name yourself",
        kind = "list", milestone = "M3", requirement = "FR-015",
        details = listOf("Home/School cards", "radius", "active child", "alert status"),
        action = "Add named place", modifier = modifier
    )
}
