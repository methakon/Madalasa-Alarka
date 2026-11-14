package org.madalasa.madalasa.ui.navigation

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.madalasa.madalasa.api.ChildSummaryResponse
import org.madalasa.madalasa.api.ParentProfileResponse

class ParentDeepLinkNavigatorTest {

    private val navigator = ParentDeepLinkNavigator()

    private val testChildId = "11111111-1111-1111-1111-111111111111"
    private val foreignChildId = "22222222-2222-2222-2222-222222222222"
    private val pendingChildId = "33333333-3333-3333-3333-333333333333"

    private val profile = ParentProfileResponse(
        adultId = "00000000-0000-0000-0000-000000000001",
        familyIds = listOf("family-alpha", "family-beta")
    )

    private val children = listOf(
        ChildSummaryResponse(
            id = testChildId,
            familyId = "family-alpha",
            alias = "Admitted Child",
            freeServiceState = "ADMITTED"
        ),
        ChildSummaryResponse(
            id = foreignChildId,
            familyId = "family-gamma", // Not in profile.familyIds
            alias = "Foreign Child",
            freeServiceState = "ADMITTED"
        ),
        ChildSummaryResponse(
            id = pendingChildId,
            familyId = "family-alpha",
            alias = "Pending Child",
            freeServiceState = "PENDING_CONSENT"
        )
    )

    @Test
    fun nullOrBlankUriReturnsInvalid() {
        assertTrue(navigator.resolve(null, true, profile, children) is DeepLinkResolution.InvalidUri)
        assertTrue(navigator.resolve("", true, profile, children) is DeepLinkResolution.InvalidUri)
        assertTrue(navigator.resolve("   ", true, profile, children) is DeepLinkResolution.InvalidUri)
    }

    @Test
    fun unsupportedSchemeOrHostReturnsInvalid() {
        val res1 = navigator.resolve("ftp://child/$testChildId", true, profile, children)
        assertTrue(res1 is DeepLinkResolution.InvalidUri)

        val res2 = navigator.resolve("https://otherdomain.com/child/$testChildId", true, profile, children)
        assertTrue(res2 is DeepLinkResolution.InvalidUri)
    }

    @Test
    fun malformedChildUuidReturnsInvalid() {
        val res = navigator.resolve("madalasa://child/not-a-valid-uuid", true, profile, children)
        assertTrue(res is DeepLinkResolution.InvalidUri)
        assertTrue((res as DeepLinkResolution.InvalidUri).reason.contains("UUID"))
    }

    @Test
    fun unauthenticatedCallerDeniedAndRedirectedToAuth() {
        val res = navigator.resolve("madalasa://child/$testChildId", false, profile, children)
        assertTrue(res is DeepLinkResolution.DeniedUnauthenticated)
        val denied = res as DeepLinkResolution.DeniedUnauthenticated
        assertEquals(Screen.Authentication.route, denied.redirectRoute)
    }

    @Test
    fun unknownChildDeniedAndRedirectedToChildSelection() {
        val unknownUuid = "99999999-9999-9999-9999-999999999999"
        val res = navigator.resolve("madalasa://child/$unknownUuid", true, profile, children)
        assertTrue(res is DeepLinkResolution.DeniedUnauthorizedChild)
        val denied = res as DeepLinkResolution.DeniedUnauthorizedChild
        assertEquals(unknownUuid, denied.requestedChildId)
        assertEquals(Screen.ChildSelection.route, denied.redirectRoute)
    }

    @Test
    fun nonAdmittedChildDeniedAndRedirectedToChildSelection() {
        val res = navigator.resolve("madalasa://child/$pendingChildId", true, profile, children)
        assertTrue(res is DeepLinkResolution.DeniedUnauthorizedChild)
        val denied = res as DeepLinkResolution.DeniedUnauthorizedChild
        assertEquals(pendingChildId, denied.requestedChildId)
        assertEquals(Screen.ChildSelection.route, denied.redirectRoute)
        assertTrue(denied.reason.contains("PENDING_CONSENT"))
    }

    @Test
    fun foreignFamilyChildDeniedAndRedirectedToChildSelection() {
        val res = navigator.resolve("madalasa://child/$foreignChildId", true, profile, children)
        assertTrue(res is DeepLinkResolution.DeniedUnauthorizedChild)
        val denied = res as DeepLinkResolution.DeniedUnauthorizedChild
        assertEquals(foreignChildId, denied.requestedChildId)
        assertEquals(Screen.ChildSelection.route, denied.redirectRoute)
        assertTrue(denied.reason.contains("family-gamma"))
    }

    @Test
    fun authorizedChildViaCustomSchemeSucceeds() {
        val res = navigator.resolve("madalasa://child/$testChildId", true, profile, children)
        assertTrue(res is DeepLinkResolution.Authorized)
        val auth = res as DeepLinkResolution.Authorized
        assertEquals(testChildId, auth.childId)
        assertEquals(Screen.Shell.route, auth.targetRoute)
        assertNull(auth.subPage)
    }

    @Test
    fun authorizedChildViaWebHttpsSchemeSucceeds() {
        val res = navigator.resolve("https://app.madalasa.org/child/$testChildId", true, profile, children)
        assertTrue(res is DeepLinkResolution.Authorized)
        val auth = res as DeepLinkResolution.Authorized
        assertEquals(testChildId, auth.childId)
        assertEquals(Screen.Shell.route, auth.targetRoute)
        assertNull(auth.subPage)
    }

    @Test
    fun authorizedChildWithSubPathRoutePreservesSubpage() {
        val resLoc = navigator.resolve("madalasa://child/$testChildId/location", true, profile, children)
        assertTrue(resLoc is DeepLinkResolution.Authorized)
        assertEquals("location", (resLoc as DeepLinkResolution.Authorized).subPage)

        val resPriv = navigator.resolve("https://app.madalasa.org/child/$testChildId/privacy", true, profile, children)
        assertTrue(resPriv is DeepLinkResolution.Authorized)
        assertEquals("privacy", (resPriv as DeepLinkResolution.Authorized).subPage)
    }
}
