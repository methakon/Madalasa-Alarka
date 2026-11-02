package org.madalasa.alarka.service

import java.util.UUID

/**
 * Child-initiated safety signal model (Phase-09 L09-001). Mirrors the backend
 * `ap_m1.child_signals` kinds. The child app can always raise a signal; local
 * submission state (QUEUED/SUBMITTED/FAILED) is kept strictly distinct from a
 * guardian acknowledgement — a device receipt is never shown as "a guardian saw it".
 */
enum class SafetySignalKind { SOS, IM_SAFE, PLEASE_CALL, NEED_PICKUP }

enum class SignalSubmitState {
    QUEUED,       // created locally, not yet sent
    SUBMITTED,    // handed to transport (not a guarantee of delivery)
    FAILED        // transport refused/offline; will retry
}

data class ChildSafetySignal(
    val eventId: String,
    val kind: SafetySignalKind,
    val createdAtEpochMs: Long,
    val submitState: SignalSubmitState,
    /** Set ONLY when the server confirms a guardian acknowledged — never inferred locally. */
    val guardianAcknowledged: Boolean = false
) {
    /** A local receipt is not a guardian acknowledgement. */
    val isAcknowledgedByGuardian: Boolean get() = guardianAcknowledged
}

interface ChildSafetyService {
    fun raise(kind: SafetySignalKind, nowEpochMs: Long): ChildSafetySignal
    fun markSubmitted(signal: ChildSafetySignal): ChildSafetySignal
    fun markFailed(signal: ChildSafetySignal): ChildSafetySignal
    fun applyGuardianAck(signal: ChildSafetySignal, acknowledged: Boolean): ChildSafetySignal
}

/** Synthetic, local-only safety service for UI development and tests. */
class SyntheticChildSafetyService : ChildSafetyService {
    override fun raise(kind: SafetySignalKind, nowEpochMs: Long): ChildSafetySignal =
        ChildSafetySignal(
            eventId = "sig-${UUID.randomUUID()}",
            kind = kind,
            createdAtEpochMs = nowEpochMs,
            submitState = SignalSubmitState.QUEUED,
            guardianAcknowledged = false
        )

    override fun markSubmitted(signal: ChildSafetySignal): ChildSafetySignal =
        signal.copy(submitState = SignalSubmitState.SUBMITTED)

    override fun markFailed(signal: ChildSafetySignal): ChildSafetySignal =
        signal.copy(submitState = SignalSubmitState.FAILED)

    override fun applyGuardianAck(signal: ChildSafetySignal, acknowledged: Boolean): ChildSafetySignal =
        signal.copy(guardianAcknowledged = acknowledged)
}
