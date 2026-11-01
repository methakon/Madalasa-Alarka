package org.madalasa.madalasa.ui.screens

import androidx.compose.runtime.Composable
import org.madalasa.madalasa.ui.figma.P02Screen

/**
 * Keep the existing local development demo reachable without misrepresenting
 * it as a verified Google/OIDC session. The actual parent identity integration
 * remains blocked until Android Credential Manager and backend exchange are wired.
 */
@Composable
fun AuthenticationScreen(
    onAuthenticated: () -> Unit,
    onBackToWelcome: (() -> Unit)? = null,
    onExploreAccountSetup: (() -> Unit)? = null
) {
    P02Screen(
        onSyntheticContinue = onAuthenticated,
        onBack = onBackToWelcome,
        onExploreAccountSetup = onExploreAccountSetup
    )
}
