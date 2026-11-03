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

    // Client-side guard prevents stale/sibling preview data. Backend child grants/RLS
    // remain authoritative; this is NOT a substitute for checking them on the server.
    private fun selectedChildAllowed(id: String): Boolean =
        _children.value.any { child ->
            child.id == id && child.freeServiceState == "ADMITTED" &&
                _profile.value?.familyIds?.contains(child.familyId) == true
        }

    private fun clearSelectedChild() {
        _selectedChildId.value = null
        _selectedChildLocation.value = null
    }

    override suspend fun refreshProfile(): Result<Unit> {
        val result = apiClient.getMe()
        return if (result.isSuccess) {
            _profile.value = result.getOrNull()
            refreshChildren()
        } else {
            _profile.value = null
            _children.value = emptyList()
            clearSelectedChild()
            Result.failure(result.exceptionOrNull() ?: Exception("Unknown profile error"))
        }
    }

    override suspend fun refreshChildren(): Result<Unit> {
        val families = _profile.value?.familyIds?.distinct()
            ?: return Result.failure(IllegalStateException("Verified parent session unavailable"))
        if (families.isEmpty()) {
            // A newly signed-in adult may legitimately have no family yet.
            _children.value = emptyList()
            clearSelectedChild()
            return Result.success(Unit)
        }
        val discovered = mutableListOf<ChildSummaryResponse>()
        for (familyId in families) {
            val result = apiClient.getChildren(familyId)
            if (result.isFailure) {
                _children.value = emptyList()
                clearSelectedChild()
                return Result.failure(result.exceptionOrNull()
                    ?: IllegalStateException("Family authorization refresh failed"))
            }
            for (child in result.getOrThrow()) {
                if (child.familyId != familyId) {
                    _children.value = emptyList()
                    clearSelectedChild()
                    return Result.failure(SecurityException(
                        "Child was returned under a different family scope"
                    ))
                }
                discovered += child
            }
        }
        // Preserve a child in a blended-family account only if it survived all
        // fresh family-scope reads. Never promote one sibling's visibility to another.
        _children.value = discovered.distinctBy { it.id }
        if (_selectedChildId.value != null &&
            !selectedChildAllowed(_selectedChildId.value!!)) {
            clearSelectedChild()
        }
        // Signup and waitlist review must not require location authorization.
        // A parent explicitly selects a child after consent/device setup.
        return Result.success(Unit)
    }

    override suspend fun selectChild(childId: String): Result<Unit> {
        if (!selectedChildAllowed(childId)) {
            clearSelectedChild()
            return Result.failure(SecurityException("Child is absent from the authorized family list"))
        }
        // Clear before IO so an old child's coordinates are never rendered with a new label.
        clearSelectedChild()
        val locResult = apiClient.getChildLocation(childId)
        if (locResult.isFailure) {
            return Result.failure(locResult.exceptionOrNull()
                ?: IllegalStateException("Child location is unavailable"))
        }
        _selectedChildId.value = childId
        _selectedChildLocation.value = locResult.getOrNull()
        return Result.success(Unit)
    }

    override suspend fun registerChild(familyLabel: String, alias: String): Result<ChildSummaryResponse> {
        val profile=_profile.value
            ?: return Result.failure(SecurityException("Parent must sign in before registration"))
        val familyId=profile.familyIds.firstOrNull()
            ?: apiClient.createFamily(familyLabel).getOrElse { return Result.failure(it) }
        val created=apiClient.createChild(familyId,alias)
        if(created.isSuccess) refreshProfile()
        return created
    }

    override suspend fun generatePairingCode(childId: String): Result<String> {
        if (!selectedChildAllowed(childId)) {
            return Result.failure(SecurityException("Pairing requires an authorized child"))
        }
        val result = apiClient.createPairingCode(childId)
        return if (result.isSuccess) {
            Result.success(result.getOrThrow().pairingCode)
        } else {
            Result.failure(result.exceptionOrNull() ?: Exception("Failed to generate code"))
        }
    }
}
