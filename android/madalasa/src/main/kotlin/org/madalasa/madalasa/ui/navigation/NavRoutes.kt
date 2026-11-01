package org.madalasa.madalasa.ui.navigation

sealed class Screen(val route: String) {
    data object Onboarding : Screen("onboarding")
    data object Welcome : Screen("welcome")
    data object Authentication : Screen("auth")
    data object CreateAccount : Screen("create_account")
    data object ChildSelection : Screen("child_selection")
    data object Shell : Screen("shell")
}
