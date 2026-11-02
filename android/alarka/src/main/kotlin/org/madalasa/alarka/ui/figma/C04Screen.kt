package org.madalasa.alarka.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** C-04: Keystore proof in progress; Figma functional handoff.
 * TODO(INTEGRATION/API): POST /enrollment/{enrollmentId}/proof signed nonce
 * TODO(INTEGRATION/GATE): Hardware-backed/nonexportable private key remains on child phone
 * TODO(INTEGRATION/FAILURE): Wrong nonce; lost key; timeout; replay
 * Acceptance: Only valid signature yields bound device token.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun C04Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "C-04", title = "Keystore proof in progress", hero = "Prove this is the linked device",
        kind = "metrics", milestone = "M1", requirement = "FR-001",
        details = listOf("Public key fingerprint", "challenge timer", "verified status"),
        action = "Finish secure enrollment", modifier = modifier
    )
}
