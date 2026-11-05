package org.madalasa.alarka.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.UUID
import org.madalasa.alarka.di.ChildAppContainer
import org.madalasa.alarka.service.CapabilitySyncReconciler
import org.madalasa.alarka.service.ChildPairingPolicy
import org.madalasa.alarka.service.DeviceCapabilityReport
import org.madalasa.alarka.service.EnrollmentResult
import org.madalasa.alarka.service.ManualSosDeliveryPolicy
import org.madalasa.alarka.service.ManualSosEvidence
import org.madalasa.alarka.service.ManualSosStage
import org.madalasa.alarka.service.ManualSosState
import org.madalasa.alarka.service.SyntheticAlarkaEnrollmentService

data class ChildUiState(
    val disclosureAcknowledged: Boolean = false,
    val pairingCode: String = "",
    val suggestedCode: String = "",
    val isEnrolling: Boolean = false,
    val enrollmentResult: EnrollmentResult? = null,
    val capabilityReport: DeviceCapabilityReport? = null,
    val lastRevokedPermissions: List<String> = emptyList(),
    val uploadsHalted: Boolean = false,
    val connectivityStatus: String = "Not paired · No monitoring",
    val errorMessage: String? = null,
    val sosState: ManualSosState? = null,
    val isOfflineMode: Boolean = false
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
            suggestedCode = if (container.enrollmentService is SyntheticAlarkaEnrollmentService) "482-901" else ""
        )
    }

    /** Re-read device-local OS state when opened/returned from Android Settings.
     * Reconciles against the last-applied snapshot so a permission revoked while
     * offline is detected now and fails closed (halts synthetic uploads).
     * No permissions are requested and no report is uploaded from this preview.
     */
    fun refreshCapabilities() {
        val previous = _uiState.value.capabilityReport
        val current = container.capabilityScanner.getCapabilityReport()
        val reconciliation = CapabilitySyncReconciler.reconcile(previous, current)
        _uiState.value = _uiState.value.copy(
            capabilityReport = current,
            lastRevokedPermissions = reconciliation.revoked,
            uploadsHalted = _uiState.value.uploadsHalted || reconciliation.mustHaltUploads
        )
    }

    /** Local evidence only; server must still approve this device and child. */
    fun hasVerifiedParentPairing(): Boolean = container.hasVerifiedParentPairing()

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
        if (_uiState.value.isEnrolling) return
        val validated = ChildPairingPolicy.validate(
            _uiState.value.disclosureAcknowledged, _uiState.value.pairingCode,
            syntheticPreview = container.enrollmentService is SyntheticAlarkaEnrollmentService
        )
        if (validated.isFailure) {
            _uiState.value = _uiState.value.copy(
                isEnrolling = false,
                errorMessage = validated.exceptionOrNull()?.message ?: "Pairing not permitted"
            )
            return
        }
        val code = validated.getOrThrow()
        _uiState.value = _uiState.value.copy(isEnrolling = true, errorMessage = null)
        viewModelScope.launch {
            val result = container.enrollmentService.completeEnrollment(code)
            result.onSuccess { enrollment ->
                if (enrollment.success) {
                    _uiState.value = _uiState.value.copy(
                        isEnrolling = false,
                        enrollmentResult = enrollment,
                        connectivityStatus = if (container.enrollmentService is SyntheticAlarkaEnrollmentService)
                            "Synthetic pairing preview · no live guardian connection"
                        else "Device paired · Monitoring not yet authorized"
                    )
                } else {
                    _uiState.value = _uiState.value.copy(
                        isEnrolling = false,
                        enrollmentResult = null,
                        connectivityStatus = "Not enrolled",
                        errorMessage = enrollment.errorMessage ?: "Device enrollment not accepted"
                    )
                }
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
            val outcome = container.enrollmentService.unpairDevice()
            if (outcome.getOrNull() == true) {
                _uiState.value = _uiState.value.copy(
                    enrollmentResult = null,
                    pairingCode = "",
                    disclosureAcknowledged = false,
                    connectivityStatus = "Disconnected locally · Guardian must revoke device in Madalasa",
                    errorMessage = null
                )
            } else {
                // Server/device refusal is not a confirmed unpair operation.
                _uiState.value = _uiState.value.copy(
                    errorMessage = outcome.exceptionOrNull()?.message
                        ?: "Device unpairing not verified"
                )
            }
        }
    }

    fun triggerManualSos() {
        val eventId = "sos-${UUID.randomUUID()}"
        var state = ManualSosState(eventId = eventId, stage = ManualSosStage.LOCAL_QUEUED)
        _uiState.value = _uiState.value.copy(sosState = state, errorMessage = null)

        viewModelScope.launch {
            state = ManualSosDeliveryPolicy.apply(state, eventId, ManualSosEvidence.RETRY_ATTEMPT)
            _uiState.value = _uiState.value.copy(sosState = state)

            if (_uiState.value.isOfflineMode) {
                kotlinx.coroutines.delay(400)
                state = ManualSosDeliveryPolicy.apply(state, eventId, ManualSosEvidence.TRANSIENT_FAILURE)
                _uiState.value = _uiState.value.copy(sosState = state)
            } else {
                kotlinx.coroutines.delay(500)
                state = ManualSosDeliveryPolicy.apply(state, eventId, ManualSosEvidence.SERVER_ACCEPTED, verifiedServerReceipt = true)
                _uiState.value = _uiState.value.copy(sosState = state)

                kotlinx.coroutines.delay(600)
                state = ManualSosDeliveryPolicy.apply(state, eventId, ManualSosEvidence.NOTIFICATION_DELIVERED, verifiedServerReceipt = true)
                _uiState.value = _uiState.value.copy(sosState = state)
            }
        }
    }

    fun retryOfflineSos() {
        val current = _uiState.value.sosState ?: return
        viewModelScope.launch {
            var state = ManualSosDeliveryPolicy.apply(current, current.eventId, ManualSosEvidence.RETRY_ATTEMPT)
            _uiState.value = _uiState.value.copy(sosState = state)
            kotlinx.coroutines.delay(500)
            state = ManualSosDeliveryPolicy.apply(state, current.eventId, ManualSosEvidence.SERVER_ACCEPTED, verifiedServerReceipt = true)
            _uiState.value = _uiState.value.copy(sosState = state)
            kotlinx.coroutines.delay(600)
            state = ManualSosDeliveryPolicy.apply(state, current.eventId, ManualSosEvidence.NOTIFICATION_DELIVERED, verifiedServerReceipt = true)
            _uiState.value = _uiState.value.copy(sosState = state)
        }
    }

    fun acknowledgeSosFromGuardian() {
        val current = _uiState.value.sosState ?: return
        viewModelScope.launch {
            val state = ManualSosDeliveryPolicy.apply(current, current.eventId, ManualSosEvidence.GUARDIAN_ACKNOWLEDGED, verifiedServerReceipt = true)
            _uiState.value = _uiState.value.copy(sosState = state)
        }
    }

    fun toggleOfflineSimulation() {
        _uiState.value = _uiState.value.copy(isOfflineMode = !_uiState.value.isOfflineMode)
    }

    fun resetSos() {
        _uiState.value = _uiState.value.copy(sosState = null)
    }
}
