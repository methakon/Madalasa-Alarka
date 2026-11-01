package org.madalasa.alarka.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** C-03: Enter pairing code; Figma functional handoff.
 * TODO(INTEGRATION/API): POST /enrollment code, P-256 public key SPKI
 * TODO(INTEGRATION/GATE): Code consumed one time; only hashed server storage
 * TODO(INTEGRATION/FAILURE): Invalid code; expired; attempted brute force
 * Acceptance: Rejected code cannot create active device.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun C03Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "C-03", title = "Enter pairing code", hero = "Pair Alarka with the verified Madalasa guardian",
        kind = "code", milestone = "M1", requirement = "FR-001",
        details = listOf("Code entry", "QR optional", "single-use notice", "expiry countdown"),
        action = "Pair securely", modifier = modifier
    )
}
