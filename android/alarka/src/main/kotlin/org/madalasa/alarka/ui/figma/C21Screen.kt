package org.madalasa.alarka.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** C-21: Secure re-enrollment; Figma functional handoff.
 * TODO(INTEGRATION/API): POST /enrollment and challenge/proof for fresh key
 * TODO(INTEGRATION/GATE): Do not resurrect old revoked credentials or grants
 * TODO(INTEGRATION/FAILURE): Key lost; child moved families; replay code
 * Acceptance: New credential created only after verified new owner pairing.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun C21Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "C-21", title = "Secure re-enrollment", hero = "Replace lost or revoked device identity",
        kind = "code", milestone = "M1", requirement = "FR-001",
        details = listOf("Old key invalid", "new pairing", "parent owner approval", "instructions"),
        action = "Start new secure pairing", modifier = modifier
    )
}
