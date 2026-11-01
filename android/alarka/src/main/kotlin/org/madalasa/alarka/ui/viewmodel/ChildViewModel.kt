package org.madalasa.alarka.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.madalasa.alarka.di.ChildAppContainer
import org.madalasa.alarka.service.DeviceCapabilityReport
import org.madalasa.alarka.service.EnrollmentResult

data class ChildUiState(
    val disclosureAcknowledged: Boolean = false,
    val pairingCode: String = "",
    val suggestedCode: String = "482-901",
    val isEnrolling: Boolean = false,
    val enrollmentResult: EnrollmentResult? = null,
    val capabilityReport: DeviceCapabilityReport? = null,
    val connectivityStatus: String = "Standby (Synthetic)",
    val errorMessage: String? = null
)

class ChildViewModel(
    private val container: ChildAppContainer
) : ViewModel() {

    private val _uiState = MutableStateFlow(ChildUiState())
    val uiState: StateFlow<ChildUiState> = _uiState.asStateFlow()

    init {
        loadInitialState()
    }

    private fun loadInitialState() {
        val report = container.capabilityScanner.getCapabilityReport()
        _uiState.value = _uiState.value.copy(
            capabilityReport = report,
            suggestedCode = "482-901"
        )
    }

    fun acknowledgeDisclosure() {
        _uiState.value = _uiState.value.copy(disclosureAcknowledged = true)
    }

    fun updatePairingCode(code: String) {
        _uiState.value = _uiState.value.copy(
            pairingCode = code,
            errorMessage = null
        )
    }

    fun submitPairing() {
        val code = _uiState.value.pairingCode.ifBlank { _uiState.value.suggestedCode }
        _uiState.value = _uiState.value.copy(isEnrolling = true, errorMessage = null)
        viewModelScope.launch {
            val result = container.enrollmentService.completeEnrollment(code)
            result.onSuccess { enrollment ->
                _uiState.value = _uiState.value.copy(
                    isEnrolling = false,
                    enrollmentResult = enrollment,
                    connectivityStatus = "Connected to Guardian (Synthetic)"
                )
            }.onFailure { error ->
                _uiState.value = _uiState.value.copy(
                    isEnrolling = false,
                    errorMessage = error.message ?: "Pairing failed"
                )
            }
        }
    }

    fun resetPairing() {
        viewModelScope.launch {
            container.enrollmentService.unpairDevice()
            _uiState.value = _uiState.value.copy(
                enrollmentResult = null,
                pairingCode = "",
                connectivityStatus = "Standby (Synthetic)",
                errorMessage = null
            )
        }
    }
}
