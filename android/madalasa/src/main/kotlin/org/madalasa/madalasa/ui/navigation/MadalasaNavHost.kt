package org.madalasa.madalasa.ui.navigation

import android.content.pm.ApplicationInfo
import androidx.compose.ui.platform.LocalContext
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import kotlinx.coroutines.launch
import org.madalasa.madalasa.api.GoogleParentConfiguration
import org.madalasa.madalasa.api.ParentSessionMemory
import org.madalasa.madalasa.api.PrivacyGateway
import org.madalasa.madalasa.ui.screens.ParentPrivacyRow
import org.madalasa.madalasa.ui.screens.parentVerifiedOverviewRows
import androidx.compose.runtime.collectAsState
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import org.madalasa.madalasa.ui.figma.P01Screen
import org.madalasa.madalasa.ui.figma.P03Screen
import org.madalasa.madalasa.ui.figma.P04Screen
import org.madalasa.madalasa.ui.figma.P18Screen
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
    googleConfiguration: GoogleParentConfiguration,
    parentSessionMemory: ParentSessionMemory,
    deepLinkUri: String? = null,
    onDeepLinkConsumed: () -> Unit = {},
    navController: NavHostController = rememberNavController()
) {
    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current
    val lifecycleOwner = androidx.lifecycle.compose.LocalLifecycleOwner.current
    val deepLinkNavigator = remember { ParentDeepLinkNavigator() }

    LaunchedEffect(deepLinkUri, uiState.profile, uiState.children) {
        val uri = deepLinkUri ?: return@LaunchedEffect
        val isAuthenticated = parentSessionMemory.currentToken() != null
        when (val outcome = deepLinkNavigator.resolve(uri, isAuthenticated, uiState.profile, uiState.children)) {
            is DeepLinkResolution.Authorized -> {
                viewModel.selectChild(outcome.childId) {
                    navController.navigate(outcome.targetRoute) {
                        popUpTo(Screen.ChildSelection.route) { inclusive = false }
                    }
                }
                onDeepLinkConsumed()
            }
            is DeepLinkResolution.DeniedUnauthenticated -> {
                navController.navigate(outcome.redirectRoute)
                onDeepLinkConsumed()
            }
            is DeepLinkResolution.DeniedUnauthorizedChild -> {
                navController.navigate(outcome.redirectRoute)
                onDeepLinkConsumed()
            }
            is DeepLinkResolution.InvalidUri -> {
                onDeepLinkConsumed()
            }
        }
    }

    androidx.compose.runtime.DisposableEffect(lifecycleOwner, viewModel) {
        val observer = androidx.lifecycle.LifecycleEventObserver { _, event ->
            when (event) {
                androidx.lifecycle.Lifecycle.Event.ON_RESUME -> viewModel.loadData()
                androidx.lifecycle.Lifecycle.Event.ON_STOP -> viewModel.clearVisibleData()
                else -> Unit
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }
    val syntheticPreviewEnabled =
        context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0 &&
            googleConfiguration.normalizedOrigin() == null

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
                onAuthenticated = if (!syntheticPreviewEnabled) null else ({
                    // Synthetic preview is never reachable from configured
                    // OIDC/backend environments or a non-debuggable release.
                    viewModel.loadData()
                    navController.navigate(Screen.ChildSelection.route) {
                        popUpTo(Screen.Onboarding.route) { inclusive = true }
                    }
                }),
                onBackToWelcome = {
                    navController.popBackStack()
                },
                onExploreAccountSetup = {
                    navController.navigate(Screen.CreateAccount.route)
                },
                onGoogleAccountHandoff = {
                    navController.navigate(Screen.GoogleHandoff.route)
                }
            )
        }

        composable(Screen.CreateAccount.route) {
            P03Screen(onBack = { navController.popBackStack() })
        }

        composable(Screen.GoogleHandoff.route) {
            P04Screen(
                configuration = googleConfiguration,
                onNewAttempt = { parentSessionMemory.clear() },
                onVerifiedSession = { verified ->
                    val accepted = parentSessionMemory.accept(verified)
                    if (accepted) {
                        viewModel.loadData()
                        navController.navigate(Screen.ChildSelection.route) {
                            popUpTo(Screen.Onboarding.route) { inclusive = true }
                        }
                    }
                    accepted
                },
                onBack = { navController.popBackStack() }
            )
        }

        composable(Screen.ChildSelection.route) {
            ChildSelectionScreen(
                uiState = uiState,
                syntheticPreview = syntheticPreviewEnabled,
                onChildSelected = { childId ->
                    viewModel.chooseChild(childId)
                },
                onOpenLocation = {
                    navController.navigate(Screen.Shell.route)
                    viewModel.loadData()
                },
                onRegisterChild = { familyLabel,childAlias,onResult ->
                    viewModel.registerChild(familyLabel,childAlias,onResult)
                },
                onRefreshServiceStatus = { viewModel.loadData() },
                onExplorePremiumPlans = { navController.navigate("premium-preview") },
                onViewPairedDevice = { onResult ->
                    val currentId = uiState.selectedChildId
                    if (currentId == null) onResult("No admitted child profile available")
                    else viewModel.checkPairedDevice(currentId, onResult)
                },
                onPairNewChild = { onCode, onError ->
                    val currentId = uiState.selectedChildId
                    if (currentId != null) {
                        viewModel.generatePairingCode(currentId, onCode, onError)
                    } else {
                        onError("No admitted child profile is available for pairing")
                    }
                }
            )
        }

        composable(Screen.Shell.route) {
            ShellScreen(
                uiState = uiState,
                syntheticPreview = !googleConfiguration.isConfigured(),
                onRefresh = { viewModel.loadData() },
                onNavigateToChildSelection = {
                    navController.navigate(Screen.ChildSelection.route)
                },
                onNavigateToPrivacy = {
                    navController.navigate(ParentPrivacyPage.OVERVIEW.route)
                },
                onExplorePremiumPlans = { navController.navigate("premium-preview") },
                onAcknowledgeSignal = { eventId -> viewModel.acknowledgeSignal(eventId) }
            )
        }
        // Preview-only premium catalog: reachable without child admission and never bills.
        composable("premium-preview") {
            P18Screen()
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
                                    rows = parentVerifiedOverviewRows(decisions)
                                    apiStatus = "SERVER VERIFIED · consent records"
                                },
                                onFailure = { e ->
                                    rows = null
                                    apiStatus = e.message ?: "Privacy API unavailable"
                                }
                            )
                        }
                        ParentPrivacyPage.REQUESTS -> {
                            apiStatus = "Loading authenticated privacy request status"
                            val erasures = privacyGateway.erasureRequests(selectedChildId)
                            val exports = privacyGateway.exportRequests(selectedChildId)
                            if (erasures.isSuccess && exports.isSuccess) {
                                val jobs = erasures.getOrThrow() + exports.getOrThrow()
                                rows = if (jobs.isEmpty()) listOf(
                                    ParentPrivacyRow("No privacy requests",
                                        "No verified deletion or export request was returned for this child.")
                                ) else jobs.map { job ->
                                    ParentPrivacyRow(
                                        "${job.kind} · ${job.state}",
                                        "Request ${job.requestId.take(8)}… · ${job.requestedAt.ifBlank { "Time unavailable" }}"
                                    )
                                }
                                apiStatus = "SERVER VERIFIED · request status only; deletion not assumed complete"
                            } else {
                                rows = null
                                apiStatus = erasures.exceptionOrNull()?.message
                                    ?: exports.exceptionOrNull()?.message ?: "Privacy service unavailable"
                            }
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
