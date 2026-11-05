package org.madalasa.alarka.ui.navigation

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import org.madalasa.alarka.R
import org.madalasa.alarka.service.AndroidPermissionPreflight
import org.madalasa.alarka.service.LocationSetupAction
import android.content.Intent
import android.net.Uri
import android.provider.Settings

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import org.madalasa.alarka.ui.figma.SupplementalFigmaCatalog
import org.madalasa.alarka.ui.figma.SupplementalFigmaScreen
import org.madalasa.alarka.service.ChildPrivacyGateway
import org.madalasa.alarka.service.ServerConsentStatus
import org.madalasa.alarka.ui.screens.AccountInfoScreen
import org.madalasa.alarka.ui.screens.ConnectivityScreen
import org.madalasa.alarka.ui.screens.PairingScreen
import org.madalasa.alarka.ui.screens.PermissionsScreen
import org.madalasa.alarka.ui.screens.ChildPrivacyPage
import org.madalasa.alarka.ui.screens.ChildPrivacyScreen
import org.madalasa.alarka.ui.screens.TransparencyDisclosureScreen
import org.madalasa.alarka.ui.viewmodel.ChildViewModel

@Composable
fun ChildNavHost(
    viewModel: ChildViewModel,
    privacyGateway: ChildPrivacyGateway,
    modifier: Modifier = Modifier
) {
    val navController = rememberNavController()
    val context = LocalContext.current
    val uiState by viewModel.uiState.collectAsState()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route
    var consentStatus by remember { mutableStateOf<ServerConsentStatus?>(null) }
    var consentError by remember { mutableStateOf<String?>(null) }
    val permissionPlan = AndroidPermissionPreflight.evaluate(
        report = uiState.capabilityReport,
        pairedWithVerifiedCredential = viewModel.hasVerifiedParentPairing(),
        server = consentStatus,
        locationReleaseApproved =
            context.resources.getBoolean(R.bool.alarka_location_release_approved)
    )
    val foregroundLocationRequest = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { viewModel.refreshCapabilities() }
    val backgroundLocationRequest = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { viewModel.refreshCapabilities() }
    val notificationRequest = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { viewModel.refreshCapabilities() }

    // Server consent and current Android permission are independent observations.
    LaunchedEffect(currentRoute, uiState.capabilityReport) {
        if (currentRoute == ChildNavRoute.Privacy.route ||
            currentRoute == ChildNavRoute.LocationUnavailable.route ||
            currentRoute == ChildNavRoute.Permissions.route) {
            consentStatus = null
            privacyGateway.readConsentStatus().fold(
                onSuccess = { status ->
                    consentStatus = status
                    consentError = null
                },
                onFailure = { e ->
                    consentStatus = null
                    consentError = e.message ?: "Server authorization is unavailable"
                }
            )
        }
    }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        bottomBar = {
            NavigationBar {
                ChildNavRoute.all.forEach { route ->
                    NavigationBarItem(
                        selected = currentRoute == route.route,
                        onClick = {
                            navController.navigate(route.route) {
                                popUpTo(navController.graph.findStartDestination().id) {
                                    saveState = true
                                }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                        icon = {
                            Text(route.title.take(3).uppercase())
                        },
                        label = {
                            Text(route.title)
                        }
                    )
                }
            }
        }
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = ChildNavRoute.Disclosure.route,
            modifier = Modifier.padding(innerPadding)
        ) {
            composable(ChildNavRoute.Disclosure.route) {
                TransparencyDisclosureScreen(
                    isAcknowledged = uiState.disclosureAcknowledged,
                    onAcknowledge = { viewModel.acknowledgeDisclosure() },
                    onNavigateNext = { navController.navigate(ChildNavRoute.Pairing.route) },
                    onReadPrivacy = { navController.navigate(ChildNavRoute.Privacy.route) }
                )
            }

            composable(ChildNavRoute.Pairing.route) {
                PairingScreen(
                    pairingCode = uiState.pairingCode,
                    suggestedCode = uiState.suggestedCode,
                    isEnrolling = uiState.isEnrolling,
                    enrollmentResult = uiState.enrollmentResult,
                    errorMessage = uiState.errorMessage,
                    onCodeChange = { viewModel.updatePairingCode(it) },
                    onSubmit = { viewModel.submitPairing() },
                    onNavigateNext = { navController.navigate(ChildNavRoute.Permissions.route) }
                )
            }

            composable(ChildNavRoute.Permissions.route) {
                PermissionsScreen(
                    report = uiState.capabilityReport,
                    pairedForOptionalModules = viewModel.hasVerifiedParentPairing(),
                    onNavigateNext = { navController.navigate(ChildNavRoute.Connectivity.route) },
                    onRefresh = { viewModel.refreshCapabilities() },
                    onViewCapabilityGuide = { navController.navigate(ChildNavRoute.CapabilityGuide.route) },
                    onViewPrivacy = { navController.navigate(ChildNavRoute.Privacy.route) },
                    permissionPlan = permissionPlan,
                    onRequestForegroundLocation = {
                        if (permissionPlan.action == LocationSetupAction.REQUEST_FOREGROUND_LOCATION) {
                            foregroundLocationRequest.launch(arrayOf(
                                Manifest.permission.ACCESS_COARSE_LOCATION,
                                Manifest.permission.ACCESS_FINE_LOCATION
                            ))
                        }
                    },
                    onRequestBackgroundLocation = {
                        if (Build.VERSION.SDK_INT == 29 &&
                            permissionPlan.action ==
                                LocationSetupAction.REQUEST_BACKGROUND_LOCATION_ANDROID_10) {
                            backgroundLocationRequest.launch(
                                Manifest.permission.ACCESS_BACKGROUND_LOCATION
                            )
                        }
                    },
                    onRequestNotifications = {
                        if (Build.VERSION.SDK_INT >= 33 &&
                            permissionPlan.action == LocationSetupAction.REQUEST_NOTIFICATION_PERMISSION) {
                            notificationRequest.launch(Manifest.permission.POST_NOTIFICATIONS)
                        }
                    },
                    onOpenLocationSettings = {
                        if (permissionPlan.action == LocationSetupAction.ENABLE_SYSTEM_LOCATION)
                            context.startActivity(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS))
                    },
                    onOpenAppSettings = {
                        if (permissionPlan.action in setOf(
                                LocationSetupAction.OPEN_BACKGROUND_LOCATION_SETTINGS,
                                LocationSetupAction.MANIFEST_NOT_READY
                            )) {
                            context.startActivity(
                                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                    data = Uri.fromParts("package", context.packageName, null)
                                }
                            )
                        }
                    },
                    onOpenNotificationSettings = {
                        if (permissionPlan.action == LocationSetupAction.OPEN_NOTIFICATION_SETTINGS)
                            context.startActivity(
                                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                                    putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                                }
                            )
                    }
                )
            }

            // Read-only Figma design journey, accessible without enrollment and never an OS prompt.
            composable(ChildNavRoute.CapabilityGuide.route) {
                var index by remember { mutableIntStateOf(0) }
                val entries = SupplementalFigmaCatalog.screens.filter { it.kind == "CAPABILITY" }
                val spec = entries.getOrNull(index)
                if (spec != null) {
                    SupplementalFigmaScreen(spec, onNextDesign = {
                        index = (index + 1) % entries.size
                    })
                }
            }

            // Current permission facts are local; guardian scope/purpose remain UNKNOWN.
            // Only an explicit tap opens Android's own app-permission settings.
            composable(ChildNavRoute.Privacy.route) {
                ChildPrivacyScreen(
                    page = ChildPrivacyPage.TRANSPARENCY,
                    report = uiState.capabilityReport,
                    serverStatus = consentStatus,
                    serverError = consentError,
                    onBack = { navController.popBackStack() },
                    onShowLocationUnavailable = {
                        navController.navigate(ChildNavRoute.LocationUnavailable.route)
                    },
                    onOpenAndroidSettings = {
                        context.startActivity(
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.fromParts("package", context.packageName, null)
                            }
                        )
                    }
                )
            }
            composable(ChildNavRoute.LocationUnavailable.route) {
                ChildPrivacyScreen(
                    page = ChildPrivacyPage.LOCATION_UNAVAILABLE,
                    report = uiState.capabilityReport,
                    onBack = { navController.popBackStack() },
                    onShowLocationUnavailable = {},
                    onOpenAndroidSettings = {
                        context.startActivity(
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.fromParts("package", context.packageName, null)
                            }
                        )
                    }
                )
            }

            composable(ChildNavRoute.Connectivity.route) {
                ConnectivityScreen(
                    connectivityStatus = uiState.connectivityStatus,
                    onNavigateNext = { navController.navigate(ChildNavRoute.AccountInfo.route) }
                )
            }

            composable(ChildNavRoute.AccountInfo.route) {
                AccountInfoScreen(
                    enrollmentResult = uiState.enrollmentResult,
                    sosState = uiState.sosState,
                    isOfflineMode = uiState.isOfflineMode,
                    onTriggerSos = { viewModel.triggerManualSos() },
                    onRetrySos = { viewModel.retryOfflineSos() },
                    onAcknowledgeSos = { viewModel.acknowledgeSosFromGuardian() },
                    onToggleOffline = { viewModel.toggleOfflineSimulation() },
                    onResetSos = { viewModel.resetSos() },
                    onResetPairing = { viewModel.resetPairing() },
                    onNavigateHome = {
                        navController.navigate(ChildNavRoute.Disclosure.route) {
                            popUpTo(ChildNavRoute.Disclosure.route) { inclusive = true }
                        }
                    }
                )
            }
        }
    }
}
