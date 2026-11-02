package org.madalasa.madalasa.repository

import kotlinx.coroutines.flow.StateFlow
import org.madalasa.madalasa.api.ChildSummaryResponse
import org.madalasa.madalasa.api.ParentProfileResponse
import org.madalasa.madalasa.domain.VerifiedLocationState

/**
 * Repository interface exposing reactive StateFlow state and suspend operations
 * for Madalasa guardian UI screens.
 */
interface MadalasaRepository {
    val profile: StateFlow<ParentProfileResponse?>
    val children: StateFlow<List<ChildSummaryResponse>>
    val selectedChildId: StateFlow<String?>
    val selectedChildLocation: StateFlow<VerifiedLocationState?>

    suspend fun refreshProfile(): Result<Unit>
    suspend fun refreshChildren(): Result<Unit>
    suspend fun selectChild(childId: String): Result<Unit>
    suspend fun generatePairingCode(childId: String): Result<String>
}
