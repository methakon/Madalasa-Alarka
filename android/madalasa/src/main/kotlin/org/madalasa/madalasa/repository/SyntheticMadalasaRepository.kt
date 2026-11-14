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

    private val _activeSignals = MutableStateFlow<List<org.madalasa.madalasa.api.ChildSignalSummary>>(emptyList())
    override val activeSignals: StateFlow<List<org.madalasa.madalasa.api.ChildSignalSummary>> = _activeSignals.asStateFlow()

    // Client-side guard prevents stale/sibling preview data. Backend child grants/RLS
    // remain authoritative; this is NOT a substitute for checking them on the server.
    private fun selectedChildAllowed(id: String): Boolean =
        _children.value.any { child ->
            child.id == id && child.freeServiceState == "ADMITTED" &&
                _profile.value?.familyIds?.contains(child.familyId) == true
        }

    private val _history = MutableStateFlow(HistoryReadState())
    override val history = _history.asStateFlow()
    private var historyGeneration = 0L
    private var profileGeneration = 0L
    private var childrenGeneration = 0L
    private var selectionGeneration = 0L

    private fun invalidateReads() {
        selectionGeneration++
        historyGeneration++
        _selectedChildLocation.value = null
        _history.value = HistoryReadState()
    }

    override fun clearVisibleData() {
        // Also invalidate suspended authorization refreshes when backgrounded.
        profileGeneration++
        childrenGeneration++
        invalidateReads()
    }

    private fun clearSelectedChild() {
        invalidateReads()
        _selectedChildId.value = null
    }

    override suspend fun refreshProfile(): Result<Unit> {
        val previousActor = _profile.value?.adultId
        val generation = ++profileGeneration
        _profile.value = null
        invalidateReads()
        _children.value = emptyList()
        val result = apiClient.getMe()
        if (generation != profileGeneration)
            return Result.failure(SecurityException("A newer session refresh superseded this response"))
        return if (result.isSuccess) {
            _profile.value = result.getOrNull()
            if (previousActor != _profile.value?.adultId) clearSelectedChild()
            refreshChildren()
        } else {
            _profile.value = null
            _children.value = emptyList()
            clearSelectedChild()
            Result.failure(result.exceptionOrNull() ?: Exception("Unknown profile error"))
        }
    }

    override suspend fun refreshChildren(): Result<Unit> {
        val generation = ++childrenGeneration
        val session = profileGeneration
        invalidateReads()
        _children.value = emptyList()
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
            if (generation != childrenGeneration || session != profileGeneration)
                return Result.failure(SecurityException("Authorization refresh superseded"))
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

    // Explicit enrollment selection uses the authenticated child list, not LOCATION consent.
    override fun chooseChild(childId: String): Result<Unit> {
        clearSelectedChild()
        if (!selectedChildAllowed(childId))
            return Result.failure(SecurityException("Select an admitted, authorized child"))
        _selectedChildId.value = childId
        return Result.success(Unit)
    }

    override suspend fun selectChild(childId: String): Result<Unit> {
        if (!selectedChildAllowed(childId)) {
            clearSelectedChild()
            return Result.failure(SecurityException("Child is absent from the authorized family list"))
        }
        // Clear before IO so an old child's coordinates are never rendered with a new label.
        chooseChild(childId)
        val generation = selectionGeneration
        val actor = _profile.value?.adultId
        val locResult = apiClient.getChildLocation(childId)
        if (generation != selectionGeneration || actor != _profile.value?.adultId ||
            !selectedChildAllowed(childId)) {
            return Result.failure(SecurityException("Selection or authority changed during read"))
        }
        if (locResult.isFailure) {
            if (locResult.exceptionOrNull() is SecurityException) clearSelectedChild()
            return Result.failure(locResult.exceptionOrNull()
                ?: IllegalStateException("Child location is unavailable"))
        }
        if (locResult.getOrNull()?.childId != childId) {
            clearSelectedChild()
            return Result.failure(SecurityException("Location belongs to another child"))
        }
        _selectedChildId.value = childId
        _selectedChildLocation.value = locResult.getOrNull()
        return Result.success(Unit)
    }

    override suspend fun refreshHistory(): Result<Unit> {
        val child = _selectedChildId.value
        if (child == null || !selectedChildAllowed(child)) {
            _history.value = HistoryReadState()
            return Result.failure(SecurityException("Select an admitted, authorized child"))
        }
        val selection = selectionGeneration
        val generation = ++historyGeneration
        _history.value = HistoryReadState(status = "Loading authenticated six-hour history…")
        val result = apiClient.getChildHistory(child)
        if (generation != historyGeneration || selection != selectionGeneration ||
            _selectedChildId.value != child || !selectedChildAllowed(child)) {
            return Result.failure(SecurityException("History selection or authority changed"))
        }
        val data = result.getOrNull()
        if (result.isFailure || data?.childId != child || data.items.any { it.childId != child }) {
            if (result.exceptionOrNull() is SecurityException || (data != null && data.childId != child))
                clearSelectedChild()
            _history.value = HistoryReadState(status = "History unavailable. Refresh authorization and try again.")
            return Result.failure(result.exceptionOrNull() ?: SecurityException("History child mismatch"))
        }
        _history.value = HistoryReadState(data, "Server-verified six-hour history")
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

    override suspend fun getPairedDevice(childId: String): Result<org.madalasa.madalasa.api.PairedChildDevice?> {
        val allowed = _children.value.any { it.id == childId &&
            _profile.value?.familyIds?.contains(it.familyId) == true }
        if (!allowed) return Result.failure(SecurityException("Child is not in the verified family list"))
        val generation = selectionGeneration
        val result = apiClient.getPairedChildDevice(childId)
        if (generation != selectionGeneration || !selectedChildAllowed(childId))
            return Result.failure(SecurityException("Device selection or authority changed"))
        if (result.exceptionOrNull() is SecurityException) clearSelectedChild()
        return result
    }

    override suspend fun generatePairingCode(childId: String): Result<String> {
        if (!selectedChildAllowed(childId)) {
            return Result.failure(SecurityException("Pairing requires an authorized child"))
        }
        val generation = selectionGeneration
        val result = apiClient.createPairingCode(childId)
        if (generation != selectionGeneration || !selectedChildAllowed(childId))
            return Result.failure(SecurityException("Pairing selection or authority changed"))
        if (result.exceptionOrNull() is SecurityException) clearSelectedChild()
        return if (result.isSuccess) {
            Result.success(result.getOrThrow().pairingCode)
        } else {
            Result.failure(result.exceptionOrNull() ?: Exception("Failed to generate code"))
        }
    }

    override suspend fun refreshSignals(): Result<Unit> {
        val child = _selectedChildId.value ?: return Result.success(Unit)
        if (!selectedChildAllowed(child)) {
            _activeSignals.value = emptyList()
            return Result.success(Unit)
        }
        val res = apiClient.getChildSignals(child)
        if (res.isSuccess) {
            _activeSignals.value = res.getOrDefault(emptyList()).filter { !it.acknowledged }
        }
        return res.map { }
    }

    override suspend fun acknowledgeSignal(eventId: String): Result<Boolean> {
        val child = _selectedChildId.value ?: return Result.failure(IllegalStateException("No child selected"))
        val res = apiClient.acknowledgeChildSignal(child, eventId)
        if (res.isSuccess) {
            _activeSignals.value = _activeSignals.value.filter { it.eventId != eventId }
        }
        return res
    }
}
