package org.madalasa.madalasa.repository

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.madalasa.madalasa.api.ChildSummaryResponse
import org.madalasa.madalasa.api.MadalasaApiClient
import org.madalasa.madalasa.api.ParentProfileResponse
import org.madalasa.madalasa.domain.VerifiedLocationState

/**
 * Synthetic repository holding mock state for UI development.
 */
class SyntheticMadalasaRepository(
    private val apiClient: MadalasaApiClient
) : MadalasaRepository {

    private val _profile = MutableStateFlow<ParentProfileResponse?>(null)
    override val profile: StateFlow<ParentProfileResponse?> = _profile.asStateFlow()

    private val _children = MutableStateFlow<List<ChildSummaryResponse>>(emptyList())
    override val children: StateFlow<List<ChildSummaryResponse>> = _children.asStateFlow()

    private val _selectedChildId = MutableStateFlow<String?>(null)
    override val selectedChildId: StateFlow<String?> = _selectedChildId.asStateFlow()

    private val _selectedChildLocation = MutableStateFlow<VerifiedLocationState?>(null)
    override val selectedChildLocation: StateFlow<VerifiedLocationState?> = _selectedChildLocation.asStateFlow()

    override suspend fun refreshProfile(): Result<Unit> {
        val result = apiClient.getMe()
        return if (result.isSuccess) {
            _profile.value = result.getOrNull()
            refreshChildren()
            Result.success(Unit)
        } else {
            Result.failure(result.exceptionOrNull() ?: Exception("Unknown profile error"))
        }
    }

    override suspend fun refreshChildren(): Result<Unit> {
        val familyId = _profile.value?.familyIds?.firstOrNull() ?: "00000000-0000-0000-0000-00000000000a"
        val result = apiClient.getChildren(familyId)
        return if (result.isSuccess) {
            val list = result.getOrDefault(emptyList())
            _children.value = list
            if (_selectedChildId.value == null && list.isNotEmpty()) {
                selectChild(list.first().id)
            }
            Result.success(Unit)
        } else {
            Result.failure(result.exceptionOrNull() ?: Exception("Unknown children error"))
        }
    }

    override suspend fun selectChild(childId: String): Result<Unit> {
        _selectedChildId.value = childId
        val locResult = apiClient.getChildLocation(childId)
        if (locResult.isSuccess) {
            _selectedChildLocation.value = locResult.getOrNull()
        }
        return Result.success(Unit)
    }

    override suspend fun generatePairingCode(childId: String): Result<String> {
        val result = apiClient.createPairingCode(childId)
        return if (result.isSuccess) {
            Result.success(result.getOrThrow().pairingCode)
        } else {
            Result.failure(result.exceptionOrNull() ?: Exception("Failed to generate code"))
        }
    }
}
