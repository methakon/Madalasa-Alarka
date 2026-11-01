package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-09: Pair child device; Figma functional handoff.
 * TODO(INTEGRATION/API): POST /children/{childId}/pairing-codes; signed enrollment proof
 * TODO(INTEGRATION/GATE): PAIR_DEVICE scope; code hashes, one use, no log secrets
 * TODO(INTEGRATION/FAILURE): Expired; replay; forged proof
 * Acceptance: ACTIVE device only after valid Keystore proof.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P09Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-09", title = "Pair child device", hero = "Pair the Alarka companion securely",
        kind = "code", milestone = "M1", requirement = "FR-001",
        details = listOf("One-time code", "QR optional", "10-min expiry countdown"),
        action = "Generate new code", modifier = modifier
    )
}
