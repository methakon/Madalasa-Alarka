package org.madalasa.alarka.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** C-07: Location Settings guide; Figma functional handoff.
 * TODO(INTEGRATION/API): Intent for app permission settings; FusedLocationProvider only if legal
 * TODO(INTEGRATION/GATE): Background collection limited by version, user and Play rules
 * TODO(INTEGRATION/FAILURE): Permission denied; location OFF; background restricted
 * Acceptance: No GPS collected until all required gates pass.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun C07Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "C-07", title = "Location Settings guide", hero = "Choose Android location permission",
        kind = "permission", milestone = "M2", requirement = "FR-002/003",
        details = listOf("App info > Permissions > Location", "precise vs approximate"),
        action = "Open Android Settings", modifier = modifier
    )
}
