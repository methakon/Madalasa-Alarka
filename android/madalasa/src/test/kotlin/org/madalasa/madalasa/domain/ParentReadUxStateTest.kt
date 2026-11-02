package org.madalasa.madalasa.domain

import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** L07-010: offline/auth/permission UX; revocation clears cache, stale shown truthfully. */
class ParentReadUxStateTest {

    private val cached = VerifiedLocationState(
        "c1", "d1", 1L, 2L, null, 22_000_000, 88_000_000, 15f, Freshness.VERIFIED_CURRENT
    )

    @Test
    fun authRevocationPurgesCachedLocation() {
        val ux = ParentReadUxState.resolve(ReadCondition.AUTH_REVOKED)
        assertFalse(ux.retainCachedLocation)
        assertNull(ParentReadUxState.projectCache(ReadCondition.AUTH_REVOKED, cached))
    }

    @Test
    fun permissionDeniedPurgesCachedLocation() {
        assertNull(ParentReadUxState.projectCache(ReadCondition.PERMISSION_DENIED, cached))
    }

    @Test
    fun offlineKeepsLastKnownButFlagsStale() {
        val ux = ParentReadUxState.resolve(ReadCondition.OFFLINE)
        assertTrue(ux.retainCachedLocation)
        assertTrue(ux.showStaleBadge)
        assertNotNull(ParentReadUxState.projectCache(ReadCondition.OFFLINE, cached))
    }

    @Test
    fun okShowsLiveWithoutStaleBadge() {
        val ux = ParentReadUxState.resolve(ReadCondition.OK)
        assertTrue(ux.retainCachedLocation)
        assertFalse(ux.showStaleBadge)
    }
}
