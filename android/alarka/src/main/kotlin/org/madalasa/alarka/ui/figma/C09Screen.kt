package org.madalasa.alarka.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** C-09: Battery & background guide; Figma functional handoff.
 * TODO(INTEGRATION/API): OS battery restriction read; vendor settings; WorkManager scheduling
 * TODO(INTEGRATION/GATE): No bypass of Android Doze/background launch restrictions
 * TODO(INTEGRATION/FAILURE): Restricted; OEM kills process; unavailable intent
 * Acceptance: Timings remain best-effort, status accurate.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun C09Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "C-09", title = "Battery & background guide", hero = "Power policy impacts observation age",
        kind = "permission", milestone = "M2", requirement = "FR-018/036",
        details = listOf("Battery restrictions", "delayed jobs", "Eco explanation"),
        action = "Open system battery settings", modifier = modifier
    )
}
