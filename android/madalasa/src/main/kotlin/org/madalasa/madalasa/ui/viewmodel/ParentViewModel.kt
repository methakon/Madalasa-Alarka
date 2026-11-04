package org.madalasa.madalasa.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import org.madalasa.madalasa.api.ChildSummaryResponse
import org.madalasa.madalasa.api.ParentProfileResponse
import org.madalasa.madalasa.domain.VerifiedLocationState
import org.madalasa.madalasa.repository.MadalasaRepository

data class ParentUiState(
    val profile: ParentProfileResponse? = null,
    val children: List<ChildSummaryResponse> = emptyList(),
    val selectedChildId: String? = null,
    val selectedChildLocation: VerifiedLocationState? = null,
    val isLoading: Boolean = false,
    val pairingCode: String? = null,
    val history: org.madalasa.madalasa.repository.HistoryReadState = org.madalasa.madalasa.repository.HistoryReadState()
)

class ParentViewModel(
    private val repository: MadalasaRepository
) : ViewModel() {

    val uiState: StateFlow<ParentUiState> = combine(
        repository.profile,
        repository.children,
        repository.selectedChildId,
        repository.selectedChildLocation,
        repository.history
    ) { profile, children, selectedChildId, location, history ->
        val allowed = selectedChildId != null && children.any {
            it.id == selectedChildId && it.freeServiceState == "ADMITTED" &&
                profile?.familyIds?.contains(it.familyId) == true
        }
        ParentUiState(
            profile = profile,
            children = children,
            selectedChildId = selectedChildId.takeIf { allowed },
            selectedChildLocation = location?.takeIf { allowed && it.childId == selectedChildId },
            history = history.takeIf { allowed && (it.data == null || it.data.childId == selectedChildId) }
                ?: org.madalasa.madalasa.repository.HistoryReadState(),
            isLoading = false
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = ParentUiState(isLoading = true)
    )

    private var refreshJob: kotlinx.coroutines.Job? = null

    init { loadData() }

    fun loadData() {
        refreshJob?.cancel()
        refreshJob = viewModelScope.launch {
            val selected = repository.selectedChildId.value
            if (repository.refreshProfile().isSuccess && selected != null &&
                repository.selectedChildId.value == selected) {
                repository.selectChild(selected)
                if (repository.selectedChildId.value == selected) repository.refreshHistory()
            }
        }
    }

    fun clearVisibleData() {
        refreshJob?.cancel()
        repository.clearVisibleData()
    }

    fun chooseChild(childId: String) { repository.chooseChild(childId) }

    fun selectChild(childId: String, onAuthorized: () -> Unit = {}) {
        viewModelScope.launch {
            // Do not navigate or present a child screen if the network/RLS
            // re-check failed (including a revoked or expired child grant).
            if (repository.selectChild(childId).isSuccess) onAuthorized()
        }
    }

    fun registerChild(familyLabel: String, alias: String, onResult: (String) -> Unit) {
        viewModelScope.launch {
            repository.registerChild(familyLabel,alias).fold(
                onSuccess = { child ->
                    onResult(if(child.freeServiceState=="WAITLISTED")
                        "Signup complete. You are in the service queue" +
                            (child.queuePosition?.let { " (position $it)" } ?: "") +
                            ". Your child's free services will begin when a slot becomes available."
                    else "Child profile created. A free slot is allocated; finish authority, consent and device setup.")
                },
                onFailure = { e -> onResult(e.message ?: "Registration could not be confirmed") }
            )
        }
    }

    fun checkPairedDevice(childId: String, onResult: (String) -> Unit) {
        viewModelScope.launch {
            repository.getPairedDevice(childId).fold(
                onSuccess = { device ->
                    onResult(if (device == null)
                        "No active paired device for this child."
                    else "Paired Alarka: ${device.manufacturer} ${device.model}" +
                        (device.androidApi?.let { " · Android API $it" } ?: "") +
                        " · App ${device.appVersion} · ${device.pairingMethod}" +
                        (device.pairedAt?.let { " · Paired $it" } ?: ""))
                },
                onFailure = { error ->
                    onResult(error.message ?: "Verified child device information is unavailable")
                }
            )
        }
    }

    fun generatePairingCode(
        childId: String,
        onGenerated: (String) -> Unit,
        onFailure: (String) -> Unit = {}
    ) {
        viewModelScope.launch {
            val result = repository.generatePairingCode(childId)
            if (result.isSuccess) {
                onGenerated(result.getOrThrow())
            } else {
                onFailure(result.exceptionOrNull()?.message ?: "Pairing code was not issued")
            }
        }
    }

    companion object {
        fun provideFactory(repository: MadalasaRepository): ViewModelProvider.Factory =
            object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST")
                override fun <T : ViewModel> create(modelClass: Class<T>): T {
                    return ParentViewModel(repository) as T
                }
            }
    }
}
