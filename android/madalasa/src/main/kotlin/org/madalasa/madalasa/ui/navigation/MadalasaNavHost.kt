package org.madalasa.madalasa.ui.navigation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import kotlinx.coroutines.launch
import org.madalasa.madalasa.api.PrivacyGateway
import org.madalasa.madalasa.ui.screens.ParentPrivacyRow
import androidx.compose.runtime.collectAsState
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import org.madalasa.madalasa.ui.figma.P01Screen
import org.madalasa.madalasa.ui.figma.P03Screen
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
    privacyGateway: PrivacyGateway,
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
                },
                onBackToWelcome = {
                    navController.popBackStack()
                },
                onExploreAccountSetup = {
                    navController.navigate(Screen.CreateAccount.route)
                }
            )
        }

        composable(Screen.CreateAccount.route) {
            P03Screen(onBack = { navController.popBackStack() })
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
                val selectedChildId = uiState.selectedChildId
                val scope = rememberCoroutineScope()
                var rows by remember(page, selectedChildId) {
                    mutableStateOf<List<ParentPrivacyRow>?>(null)
                }
                var apiStatus by remember(page, selectedChildId) {
                    mutableStateOf("Waiting for authenticated privacy API")
                }

                LaunchedEffect(page, selectedChildId) {
                    if (selectedChildId == null) {
                        apiStatus = "NO AUTHORIZED CHILD SELECTED"
                        return@LaunchedEffect
                    }
                    when (page) {
                        ParentPrivacyPage.GUARDIANS -> {
                            apiStatus = "Loading authorized grants"
                            privacyGateway.guardianGrants(selectedChildId).fold(
                                onSuccess = { grants ->
                                    rows = if (grants.isEmpty()) listOf(
                                        ParentPrivacyRow("No grants returned",
                                            "Server returned no visible guardian grants.")
                                    ) else grants.map { g ->
                                        ParentPrivacyRow(
                                            "Guardian scope: ${g.scope}",
                                            "Adult ID: ${g.adultId.take(8)}… · Expires: ${g.expiresAt.ifBlank { "not specified" }}",
                                            grantId = g.grantId
                                        )
                                    }
                                    apiStatus = "SERVER VERIFIED · scoped grants"
                                },
                                onFailure = { e ->
                                    rows = null
                                    apiStatus = e.message ?: "Privacy API unavailable"
                                }
                            )
                        }
                        ParentPrivacyPage.OVERVIEW -> {
                            apiStatus = "Loading verified purpose decisions"
                            privacyGateway.childConsents(selectedChildId).fold(
                                onSuccess = { decisions ->
                                    rows = if (decisions.isEmpty()) listOf(
                                        ParentPrivacyRow("No authorized consent records",
                                            "No verified purposes are visible to this parent.")
                                    ) else decisions.map { d ->
                                        ParentPrivacyRow(
                                            "Purpose: ${d.purpose}",
                                            "Consent ${d.status} · review ${d.legalState} · notice ${d.noticeVersion}"
                                        )
                                    }
                                    apiStatus = "SERVER VERIFIED · consent records"
                                },
                                onFailure = { e ->
                                    rows = null
                                    apiStatus = e.message ?: "Privacy API unavailable"
                                }
                            )
                        }
                        else -> apiStatus = "Backend entitlement/requests API not yet connected"
                    }
                }
                ParentPrivacyScreen(
                    page = page,
                    hasSelectedChild = selectedChildId != null,
                    onBack = { navController.popBackStack() },
                    onNavigate = { destination -> navController.navigate(destination.route) },
                    verifiedRows = rows,
                    apiStatus = apiStatus,
                    onRevokeGrant = if (page == ParentPrivacyPage.GUARDIANS && selectedChildId != null) {
                        { grantId ->
                            scope.launch {
                                apiStatus = "Submitting revocation"
                                val result = privacyGateway.revokeGuardianGrant(selectedChildId, grantId)
                                if (result.isSuccess) {
                                    // Only a committed 204 is treated as success by the client.
                                    rows = rows?.filterNot { it.grantId == grantId }
                                    apiStatus = "SERVER ACCEPTED · grant revoked"
                                } else {
                                    apiStatus = result.exceptionOrNull()?.message ?: "Revocation failed"
                                }
                            }
                            Unit
                        }
                    } else null
                )
            }
        }
    }
}
