package org.madalasa.alarka.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** C-05: Guardian authority review; Figma functional handoff.
 * TODO(INTEGRATION/API): Parent identity+verified consent/exception record once legally designed
 * TODO(INTEGRATION/GATE): Google OIDC token alone cannot prove guardian authority
 * TODO(INTEGRATION/FAILURE): Dispute; missing adult verification; purpose OFF
 * Acceptance: No real under-18 telemetry until signed legal gate.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun C05Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "C-05", title = "Guardian authority review", hero = "This adult must be authorized",
        kind = "privacy", milestone = "M0", requirement = "FR-001/013",
        details = listOf("Parent identity", "relationship notice", "rights", "approval status"),
        action = "Review safe setup", modifier = modifier
    )
}
