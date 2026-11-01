package org.madalasa.alarka.ui.navigation

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import org.madalasa.alarka.ui.screens.AccountInfoScreen
import org.madalasa.alarka.ui.screens.ConnectivityScreen
import org.madalasa.alarka.ui.screens.PairingScreen
import org.madalasa.alarka.ui.screens.PermissionsScreen
import org.madalasa.alarka.ui.screens.TransparencyDisclosureScreen
import org.madalasa.alarka.ui.viewmodel.ChildViewModel

@Composable
fun ChildNavHost(
    viewModel: ChildViewModel,
    modifier: Modifier = Modifier
) {
    val navController = rememberNavController()
    val uiState by viewModel.uiState.collectAsState()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

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
                    onNavigateNext = { navController.navigate(ChildNavRoute.Pairing.route) }
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
                    onNavigateNext = { navController.navigate(ChildNavRoute.Connectivity.route) }
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
