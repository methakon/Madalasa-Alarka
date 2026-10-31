package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-04: Google account handoff; Figma functional handoff.
 * TODO(INTEGRATION/API): Credential Manager verified ID token, nonce and backend session
 * TODO(INTEGRATION/GATE): Google account is NOT DPDP verifiable parent proof
 * TODO(INTEGRATION/FAILURE): Wrong account; canceled grant; replay
 * Acceptance: Separate verification pending state, no family data leaked.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P04Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-04", title = "Google account handoff", hero = "Choose a Google account",
        kind = "auth", milestone = "M1", requirement = "FR-001",
        details = listOf("Account chooser", "profile indicator", "guardian disclosure"),
        action = "Continue securely", modifier = modifier
    )
}
