package org.madalasa.madalasa.repository

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.madalasa.madalasa.api.ChildSummaryResponse
import org.madalasa.madalasa.api.MadalasaApiClient
import org.madalasa.madalasa.api.PairingCodeResponse
import org.madalasa.madalasa.api.ParentProfileResponse
import org.madalasa.madalasa.domain.VerifiedLocationState

class ChildRevocationGuardTest {
    private class FakeApi : MadalasaApiClient {
        var children = listOf(ChildSummaryResponse("child-a", "family-a", "Child A"))
        var failRefresh = false
        override suspend fun getMe() = Result.success(ParentProfileResponse("adult-a", listOf("family-a")))
        override suspend fun getChildren(familyId: String): Result<List<ChildSummaryResponse>> =
            if (failRefresh) Result.failure(IllegalStateException("grant revoked")) else Result.success(children)
        override suspend fun getChildLocation(childId: String): Result<VerifiedLocationState> =
            Result.failure(IllegalStateException("offline"))
        override suspend fun createPairingCode(childId: String) =
            Result.success(PairingCodeResponse("123-456", 1000))
    }

    @Test fun unknownOrSiblingChildNeverSelectedOrPaired() = runTest {
        val repo = SyntheticMadalasaRepository(FakeApi())
        repo.refreshProfile()
        assertTrue(repo.selectChild("child-b").isFailure)
        assertNull(repo.selectedChildId.value)
        assertNull(repo.selectedChildLocation.value)
        assertTrue(repo.generatePairingCode("child-b").isFailure)
    }

    @Test fun failedLocationSelectionDoesNotShowOldLocation() = runTest {
        val repo = SyntheticMadalasaRepository(FakeApi())
        repo.refreshProfile()
        assertTrue(repo.selectChild("child-a").isFailure)
        assertNull(repo.selectedChildId.value)
        assertNull(repo.selectedChildLocation.value)
    }

    @Test fun grantRefreshFailureClearsCachedChildList() = runTest {
        val api = FakeApi()
        val repo = SyntheticMadalasaRepository(api)
        repo.refreshProfile()
        api.failRefresh = true
        assertTrue(repo.refreshChildren().isFailure)
        assertTrue(repo.children.value.isEmpty())
        assertNull(repo.selectedChildId.value)
        assertNull(repo.selectedChildLocation.value)
    }
}
