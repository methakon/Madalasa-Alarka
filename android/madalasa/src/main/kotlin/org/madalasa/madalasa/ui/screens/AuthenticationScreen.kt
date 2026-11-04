package org.madalasa.madalasa.ui.screens

import androidx.compose.runtime.Composable
import org.madalasa.madalasa.ui.figma.P02Screen

/**
 * Keep the existing local development demo reachable without misrepresenting
 * it as a verified Google/OIDC session. The verified flow is a separate
 * Credential Manager handoff. Synthetic preview is deliberately optional.
 */
@Composable
fun AuthenticationScreen(
    onAuthenticated: (() -> Unit)? = null,
    onBackToWelcome: (() -> Unit)? = null,
    onExploreAccountSetup: (() -> Unit)? = null,
    onGoogleAccountHandoff: (() -> Unit)? = null
) {
    P02Screen(
        onSyntheticContinue = onAuthenticated,
        onBack = onBackToWelcome,
        onExploreAccountSetup = onExploreAccountSetup,
        onGoogleAccountHandoff = onGoogleAccountHandoff
    )
}
