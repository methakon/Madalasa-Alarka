package org.madalasa.madalasa.repository

import kotlinx.coroutines.flow.StateFlow
import org.madalasa.madalasa.api.ChildSummaryResponse
import org.madalasa.madalasa.api.ParentProfileResponse
import org.madalasa.madalasa.api.PairedChildDevice
import org.madalasa.madalasa.domain.VerifiedLocationState

/**
 * Repository interface exposing reactive StateFlow state and suspend operations
 * for Madalasa guardian UI screens.
 */
interface MadalasaRepository {
    val profile: StateFlow<ParentProfileResponse?>
    val children: StateFlow<List<ChildSummaryResponse>>
    val selectedChildId: StateFlow<String?>
    val history: StateFlow<HistoryReadState>
    suspend fun refreshHistory(): Result<Unit>
    val selectedChildLocation: StateFlow<VerifiedLocationState?>
    val activeSignals: StateFlow<List<org.madalasa.madalasa.api.ChildSignalSummary>>
        get() = kotlinx.coroutines.flow.MutableStateFlow(emptyList())

    suspend fun refreshSignals(): Result<Unit> = Result.success(Unit)
    suspend fun acknowledgeSignal(eventId: String): Result<Boolean> =
        Result.failure(IllegalStateException("Signal service unavailable"))

    suspend fun refreshProfile(): Result<Unit>
    suspend fun refreshChildren(): Result<Unit>
    fun clearVisibleData()
    fun chooseChild(childId: String): Result<Unit>
    suspend fun selectChild(childId: String): Result<Unit>
    suspend fun generatePairingCode(childId: String): Result<String>
    suspend fun getPairedDevice(childId: String): Result<PairedChildDevice?> =
        Result.failure(IllegalStateException("Device lookup unavailable"))
    suspend fun registerChild(familyLabel: String, alias: String): Result<ChildSummaryResponse> =
        Result.failure(IllegalStateException("Child signup unavailable"))
}
