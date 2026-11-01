package org.madalasa.madalasa.ui.navigation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import org.madalasa.madalasa.ui.figma.P01Screen
import org.madalasa.madalasa.ui.screens.AuthenticationScreen
import org.madalasa.madalasa.ui.screens.ChildSelectionScreen
import org.madalasa.madalasa.ui.screens.OnboardingScreen
import org.madalasa.madalasa.ui.screens.ParentPrivacyPage
import org.madalasa.madalasa.ui.screens.ParentPrivacyScreen
import org.madalasa.madalasa.ui.screens.ShellScreen
import org.madalasa.madalasa.ui.viewmodel.ParentViewModel

@Composable
fun MadalasaNavHost(
    viewModel: ParentViewModel,
    navController: NavHostController = rememberNavController()
) {
    val uiState by viewModel.uiState.collectAsState()

    NavHost(
        navController = navController,
        startDestination = Screen.Onboarding.route
    ) {
        composable(Screen.Onboarding.route) {
            OnboardingScreen(
                onFinished = { navController.navigate(Screen.Welcome.route) },
                onSkip = { navController.navigate(Screen.Welcome.route) }
            )
        }

        // The P-01 Figma role selector is now the actual welcome step.
        // Only a user tap on the Parent CTA advances into authentication.
        composable(Screen.Welcome.route) {
            P01Screen(onStartParentSetup = {
                navController.navigate(Screen.Authentication.route)
            })
        }

        composable(Screen.Authentication.route) {
            AuthenticationScreen(
                onAuthenticated = {
                    viewModel.loadData()
                    navController.navigate(Screen.ChildSelection.route) {
                        popUpTo(Screen.Onboarding.route) { inclusive = true }
                    }
                }
            )
        }

        composable(Screen.ChildSelection.route) {
            ChildSelectionScreen(
                uiState = uiState,
                onChildSelected = { childId ->
                    viewModel.selectChild(childId)
                    navController.navigate(Screen.Shell.route)
                },
                onPairNewChild = {
                    val currentId = uiState.selectedChildId ?: uiState.children.firstOrNull()?.id ?: ""
                    if (currentId.isNotEmpty()) {
                        viewModel.generatePairingCode(currentId) {}
                    }
                }
            )
        }

        composable(Screen.Shell.route) {
            ShellScreen(
                uiState = uiState,
                onNavigateToChildSelection = {
                    navController.navigate(Screen.ChildSelection.route)
                },
                onNavigateToPrivacy = {
                    navController.navigate(ParentPrivacyPage.OVERVIEW.route)
                }
            )
        }
        // Four new parent privacy destinations, grouped under Settings.
        // No route grants access or fetches child data without server proof.
        ParentPrivacyPage.entries.forEach { page ->
            composable(page.route) {
                ParentPrivacyScreen(
                    page = page,
                    hasSelectedChild = uiState.selectedChildId != null,
                    onBack = { navController.popBackStack() },
                    onNavigate = { destination -> navController.navigate(destination.route) }
                )
            }
        }
    }
}
