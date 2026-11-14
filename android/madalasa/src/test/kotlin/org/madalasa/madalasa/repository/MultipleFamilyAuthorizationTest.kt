package org.madalasa.madalasa.repository

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.madalasa.madalasa.api.ChildSummaryResponse
import org.madalasa.madalasa.api.MadalasaApiClient
import org.madalasa.madalasa.api.ParentProfileResponse
import org.madalasa.madalasa.api.PairingCodeResponse
import org.madalasa.madalasa.domain.Freshness
import org.madalasa.madalasa.domain.VerifiedLocationState

class MultipleFamilyAuthorizationTest {
    private class FakeApi : MadalasaApiClient {
        var leakWrongFamily = false
        var failSecond = false
        override suspend fun getMe() =
            Result.success(ParentProfileResponse("adult", listOf("family-a", "family-b")))
        override suspend fun getChildren(familyId: String): Result<List<ChildSummaryResponse>> {
            if (familyId == "family-b" && failSecond)
                return Result.failure(SecurityException("scope revoked"))
            return Result.success(listOf(
                ChildSummaryResponse(if (familyId=="family-a") "a" else "b",
                    if (leakWrongFamily) "another-family" else familyId, "Test", "ADMITTED")
            ))
        }
        override suspend fun getChildLocation(childId: String) =
            Result.success(VerifiedLocationState(childId,"",null,null,null,null,null,null,Freshness.UNAVAILABLE))
        override suspend fun createPairingCode(childId: String) =
            Result.success(PairingCodeResponse("123-456",1000L))
    }

    @Test fun loadsOnlyExplicitFamilyScopes() = runTest {
        val repo = SyntheticMadalasaRepository(FakeApi())
        assertTrue(repo.refreshProfile().isSuccess)
        assertEquals(listOf("a","b"),repo.children.value.map { it.id })
        assertTrue(repo.selectChild("b").isSuccess)
    }

    @Test fun wrongFamilyRowFailsClosed() = runTest {
        val fake=FakeApi().apply { leakWrongFamily=true }
        val repo=SyntheticMadalasaRepository(fake)
        assertTrue(repo.refreshProfile().isFailure)
        assertTrue(repo.children.value.isEmpty())
    }

    @Test fun failureOfOneFamilyInvalidatesWholeCachedView() = runTest {
        val fake=FakeApi()
        val repo=SyntheticMadalasaRepository(fake)
        assertTrue(repo.refreshProfile().isSuccess)
        fake.failSecond=true
        assertTrue(repo.refreshChildren().isFailure)
        assertTrue(repo.children.value.isEmpty())
        assertEquals(null,repo.selectedChildLocation.value)
    }
}
