package org.madalasa.madalasa.repository

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test
import org.madalasa.madalasa.api.*
import org.madalasa.madalasa.domain.*

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class DeferredSelectionTest {
    private class Api : MadalasaApiClient {
        var admitted = true
        var signedIn = true
        val pending = mutableMapOf<String, CompletableDeferred<Result<VerifiedLocationState>>>()
        val history = CompletableDeferred<Result<FreeChildHistory>>()
        override suspend fun getChildHistory(childId: String) = history.await()
        override suspend fun getMe(): Result<ParentProfileResponse> = if (signedIn)
            Result.success(ParentProfileResponse("adult", listOf("family"))) else Result.failure(SecurityException("expired"))
        override suspend fun getChildren(familyId: String) = Result.success(if (admitted)
            listOf("a", "b").map { ChildSummaryResponse(it, "family", it, "ADMITTED") } else emptyList())
        override suspend fun getChildLocation(childId: String) = pending.getOrPut(childId) { CompletableDeferred() }.await()
        override suspend fun createPairingCode(childId: String) = Result.success(PairingCodeResponse("23456789AB", 123))
    }
    private fun location(id: String) = VerifiedLocationState(id, "device", 1, 2, null, 1, 2, 3f, Freshness.LAST_KNOWN)

    @Test fun enrollmentSelectionNeedsNoLocationRead() = runTest {
        val api = Api(); val repo = SyntheticMadalasaRepository(api); repo.refreshProfile()
        assertTrue(repo.chooseChild("b").isSuccess)
        assertEquals("b", repo.selectedChildId.value)
        assertTrue(api.pending.isEmpty())
        assertTrue(repo.generatePairingCode("b").isSuccess)
        assertTrue(repo.chooseChild("unknown").isFailure)
        assertNull(repo.selectedChildId.value)
    }

    @Test fun leavingForegroundInvalidatesInFlightRead() = runTest {
        val api = Api(); val repo = SyntheticMadalasaRepository(api); repo.refreshProfile()
        val read = async { repo.selectChild("a") }; runCurrent()
        repo.clearVisibleData()
        api.pending.getValue("a").complete(Result.success(location("a")))
        assertTrue(read.await().isFailure); assertNull(repo.selectedChildLocation.value)
    }

    @Test fun revokedHistoryDoesNotReappear() = runTest {
        val api = Api(); val repo = SyntheticMadalasaRepository(api); repo.refreshProfile(); repo.chooseChild("a")
        val read = async { repo.refreshHistory() }; runCurrent()
        api.admitted = false; repo.refreshChildren()
        api.history.complete(Result.success(FreeChildHistory("a", listOf(location("a")), false)))
        assertTrue(read.await().isFailure); assertNull(repo.history.value.data)
    }
    @Test fun emptyHistoryIsDistinctFromNetworkFailure() = runTest {
        val api = Api(); val repo = SyntheticMadalasaRepository(api); repo.refreshProfile(); repo.chooseChild("a")
        api.history.complete(Result.success(FreeChildHistory("a", emptyList(), false)))
        assertTrue(repo.refreshHistory().isSuccess); assertNotNull(repo.history.value.data)
        repo.chooseChild("b"); assertNull(repo.history.value.data)
    }
    @Test fun wrongChildHistoryIsRejected() = runTest {
        val api = Api(); val repo = SyntheticMadalasaRepository(api); repo.refreshProfile(); repo.chooseChild("a")
        api.history.complete(Result.success(FreeChildHistory("b", listOf(location("b")), false)))
        assertTrue(repo.refreshHistory().isFailure); assertNull(repo.history.value.data)
    }
    @Test fun enrollmentSurvivesOrdinaryLocationOutageButNotDeniedRead() = runTest {
        val api = Api(); val repo = SyntheticMadalasaRepository(api); repo.refreshProfile()
        api.pending["a"] = CompletableDeferred(Result.failure(java.io.IOException("offline")))
        assertTrue(repo.selectChild("a").isFailure); assertEquals("a", repo.selectedChildId.value)
        api.pending["a"] = CompletableDeferred(Result.failure(SecurityException("revoked")))
        assertTrue(repo.selectChild("a").isFailure); assertNull(repo.selectedChildId.value)
    }

    @Test fun revokedDuringReadCannotRestoreSelection() = runTest {
        val api = Api(); val repo = SyntheticMadalasaRepository(api); repo.refreshProfile()
        val read = async { repo.selectChild("a") }; runCurrent()
        api.admitted = false; repo.refreshChildren()
        api.pending.getValue("a").complete(Result.success(location("a")))
        assertTrue(read.await().isFailure)
        assertNull(repo.selectedChildId.value); assertNull(repo.selectedChildLocation.value)
    }
    @Test fun reverseCompletionKeepsLatestExplicitSelection() = runTest {
        val api = Api(); val repo = SyntheticMadalasaRepository(api); repo.refreshProfile()
        val a = async { repo.selectChild("a") }; runCurrent()
        val b = async { repo.selectChild("b") }; runCurrent()
        api.pending.getValue("b").complete(Result.success(location("b"))); assertTrue(b.await().isSuccess)
        api.pending.getValue("a").complete(Result.success(location("a"))); assertTrue(a.await().isFailure)
        assertEquals("b", repo.selectedChildId.value); assertEquals("b", repo.selectedChildLocation.value?.childId)
    }
    @Test fun expiredSessionDuringReadCannotRestoreSelection() = runTest {
        val api = Api(); val repo = SyntheticMadalasaRepository(api); repo.refreshProfile()
        val read = async { repo.selectChild("a") }; runCurrent()
        api.signedIn = false; repo.refreshProfile()
        api.pending.getValue("a").complete(Result.success(location("a")))
        assertTrue(read.await().isFailure); assertNull(repo.selectedChildId.value)
    }
    @Test fun wrongChildResponseNeverRendered() = runTest {
        val api = Api(); val repo = SyntheticMadalasaRepository(api); repo.refreshProfile()
        val read = async { repo.selectChild("a") }; runCurrent()
        api.pending.getValue("a").complete(Result.success(location("b")))
        assertTrue(read.await().isFailure); assertNull(repo.selectedChildLocation.value)
    }
}
