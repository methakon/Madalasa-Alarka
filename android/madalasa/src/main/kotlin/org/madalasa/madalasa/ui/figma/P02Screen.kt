package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-02: Sign in; Figma functional handoff.
 * TODO(INTEGRATION/API): Android Credential Manager then verified parent OIDC session
 * TODO(INTEGRATION/GATE): OIDC does not establish adult or lawful guardian identity
 * TODO(INTEGRATION/FAILURE): Canceled login; expired token; offline
 * Acceptance: Canceled sign-in leaves user logged out; server verifies issuer and audience.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P02Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-02", title = "Sign in", hero = "Sign in to Madalasa",
        kind = "auth", milestone = "M1", requirement = "FR-001",
        details = listOf("Email sign-in area", "Google identity button", "recovery link"),
        action = "Continue with Google", modifier = modifier
    )
}
