package org.madalasa.madalasa.ui.navigation

import org.junit.Assert.assertEquals
import org.junit.Test

class NavigationRouteTest {

    @Test
    fun testScreenRoutes() {
        assertEquals("onboarding", Screen.Onboarding.route)
        assertEquals("welcome", Screen.Welcome.route)
        assertEquals("auth", Screen.Authentication.route)
        assertEquals("child_selection", Screen.ChildSelection.route)
        assertEquals("shell", Screen.Shell.route)
    }
}
