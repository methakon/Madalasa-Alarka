package org.madalasa.madalasa.ui.viewmodel

import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.*
import org.junit.Assert.*
import org.junit.Test
import org.madalasa.madalasa.api.*
import org.madalasa.madalasa.domain.*
import org.madalasa.madalasa.repository.SyntheticMadalasaRepository

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class ForegroundReadTest {
    @Test fun explicitSelectionRefreshAndRevocationClearUiState() = runTest {
        Dispatchers.setMain(UnconfinedTestDispatcher(testScheduler))
        try {
            var admitted = true
            val point = VerifiedLocationState("a", "device", 1, 2, null, 1, 2, 3f, Freshness.LAST_KNOWN)
            val api = object : MadalasaApiClient {
                override suspend fun getMe() = Result.success(ParentProfileResponse("adult", listOf("family")))
                override suspend fun getChildren(familyId: String) = Result.success(if (admitted)
                    listOf(ChildSummaryResponse("a", "family", "Adult fixture", "ADMITTED")) else emptyList())
                override suspend fun getChildLocation(childId: String) = Result.success(point)
                override suspend fun getChildHistory(childId: String) = Result.success(FreeChildHistory(childId, listOf(point), false))
                override suspend fun createPairingCode(childId: String) = Result.success(PairingCodeResponse("23456789AB", 123))
            }
            val vm = ParentViewModel(SyntheticMadalasaRepository(api))
            backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { vm.uiState.collect {} }
            vm.chooseChild("a"); runCurrent()
            assertEquals("a", vm.uiState.value.selectedChildId)
            assertNull(vm.uiState.value.selectedChildLocation)
            vm.loadData(); runCurrent()
            assertNotNull(vm.uiState.value.selectedChildLocation)
            assertNotNull(vm.uiState.value.history.data)
            vm.clearVisibleData(); runCurrent()
            assertNull(vm.uiState.value.selectedChildLocation); assertNull(vm.uiState.value.history.data)
            admitted = false; vm.loadData(); runCurrent()
            assertNull(vm.uiState.value.selectedChildId); assertNull(vm.uiState.value.history.data)
            vm.viewModelScope.coroutineContext[kotlinx.coroutines.Job]?.cancel()
        } finally {
            backgroundScope.coroutineContext[kotlinx.coroutines.Job]?.cancel()
            runCurrent()
            Dispatchers.resetMain()
        }
    }
}
