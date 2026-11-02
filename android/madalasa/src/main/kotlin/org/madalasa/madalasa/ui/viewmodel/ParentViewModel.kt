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
    val pairingCode: String? = null
)

class ParentViewModel(
    private val repository: MadalasaRepository
) : ViewModel() {

    val uiState: StateFlow<ParentUiState> = combine(
        repository.profile,
        repository.children,
        repository.selectedChildId,
        repository.selectedChildLocation
    ) { profile, children, selectedChildId, location ->
        ParentUiState(
            profile = profile,
            children = children,
            selectedChildId = selectedChildId,
            selectedChildLocation = location,
            isLoading = false
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = ParentUiState(isLoading = true)
    )

    init {
        loadData()
    }

    fun loadData() {
        viewModelScope.launch {
            repository.refreshProfile()
        }
    }

    fun selectChild(childId: String) {
        viewModelScope.launch {
            repository.selectChild(childId)
        }
    }

    fun generatePairingCode(childId: String, onGenerated: (String) -> Unit) {
        viewModelScope.launch {
            val result = repository.generatePairingCode(childId)
            if (result.isSuccess) {
                onGenerated(result.getOrThrow())
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
