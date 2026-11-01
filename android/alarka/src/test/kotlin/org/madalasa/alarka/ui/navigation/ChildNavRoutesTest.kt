package org.madalasa.alarka.ui.navigation

import org.junit.Assert.assertEquals
import org.junit.Test

class ChildNavRoutesTest {

    @Test
    fun routesHaveDistinctPaths() {
        val routes = ChildNavRoute.all
        val uniquePaths = routes.map { it.route }.toSet()
        assertEquals(routes.size, uniquePaths.size)
    }

    @Test
    fun fromRouteResolvesExpectedDestinations() {
        assertEquals(ChildNavRoute.Disclosure, ChildNavRoute.fromRoute("disclosure"))
        assertEquals(ChildNavRoute.Pairing, ChildNavRoute.fromRoute("pairing"))
        assertEquals(ChildNavRoute.Permissions, ChildNavRoute.fromRoute("permissions"))
        assertEquals(ChildNavRoute.Connectivity, ChildNavRoute.fromRoute("connectivity"))
        assertEquals(ChildNavRoute.AccountInfo, ChildNavRoute.fromRoute("account_info"))
        assertEquals(ChildNavRoute.Disclosure, ChildNavRoute.fromRoute("unknown_route"))
    }
}
