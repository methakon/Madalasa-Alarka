package org.madalasa.alarka.service

/**
 * Manual SOS delivery truth model. This is not a transport or an emergency-service
 * integration: only externally authenticated, event-scoped server evidence may
 * advance a signal beyond LOCAL_QUEUED.
 *
 * The parent app must not present SERVER_ACCEPTED or NOTIFICATION_DELIVERED
 * as human acknowledgement. UI and transport integration require separate tests.
 */
enum class ManualSosStage {
    LOCAL_QUEUED,
    SENDING,
    SERVER_ACCEPTED,
    NOTIFICATION_DELIVERED,
    GUARDIAN_ACKNOWLEDGED,
    DELIVERY_FAILED,
    AUTHORIZATION_REVOKED
}

enum class ManualSosEvidence {
    RETRY_ATTEMPT,
    SERVER_ACCEPTED,
    NOTIFICATION_DELIVERED,
    GUARDIAN_ACKNOWLEDGED,
    TRANSIENT_FAILURE,
    AUTHORIZATION_REVOKED
}

data class ManualSosState(
    val eventId: String,
    val stage: ManualSosStage = ManualSosStage.LOCAL_QUEUED,
    /** A definitive revocation blocks every future local retry or receipt. */
    val revoked: Boolean = false
) {
    val guardianHasAcknowledged: Boolean get() =
        !revoked && stage == ManualSosStage.GUARDIAN_ACKNOWLEDGED
}

object ManualSosDeliveryPolicy {
    /**
     * The caller MUST verify the source and bind a server observation to the
     * exact enrolled child/device/event before providing evidence here.
     *
     * No network or credential work occurs in this reducer. Wrong-event
     * receipts and out-of-order acknowledgements fail closed.
     */
    fun apply(
        current: ManualSosState,
        eventId: String,
        evidence: ManualSosEvidence,
        verifiedServerReceipt: Boolean = false
    ): ManualSosState {
        if (eventId != current.eventId || eventId.isBlank()) return current
        if (current.revoked) return current
        if (evidence == ManualSosEvidence.AUTHORIZATION_REVOKED) {
            // The authorization layer must supply a definitive denial, not a
            // timeout, missing snapshot, or stale observation.
            return current.copy(stage = ManualSosStage.AUTHORIZATION_REVOKED, revoked = true)
        }
        if (current.stage == ManualSosStage.GUARDIAN_ACKNOWLEDGED) return current

        return when (evidence) {
            ManualSosEvidence.RETRY_ATTEMPT ->
                if (current.stage == ManualSosStage.LOCAL_QUEUED ||
                    current.stage == ManualSosStage.DELIVERY_FAILED
                ) current.copy(stage = ManualSosStage.SENDING) else current
            ManualSosEvidence.TRANSIENT_FAILURE ->
                if (current.stage == ManualSosStage.LOCAL_QUEUED ||
                    current.stage == ManualSosStage.SENDING ||
                    current.stage == ManualSosStage.DELIVERY_FAILED
                ) current.copy(stage = ManualSosStage.DELIVERY_FAILED) else current
            ManualSosEvidence.SERVER_ACCEPTED ->
                if (verifiedServerReceipt && (current.stage == ManualSosStage.SENDING ||
                    current.stage == ManualSosStage.DELIVERY_FAILED ||
                    current.stage == ManualSosStage.LOCAL_QUEUED))
                    current.copy(stage = ManualSosStage.SERVER_ACCEPTED) else current
            ManualSosEvidence.NOTIFICATION_DELIVERED ->
                if (verifiedServerReceipt &&
                    current.stage == ManualSosStage.SERVER_ACCEPTED)
                    current.copy(stage = ManualSosStage.NOTIFICATION_DELIVERED) else current
            ManualSosEvidence.GUARDIAN_ACKNOWLEDGED ->
                // A confirmed guardian action can precede push-provider delivery
                // telemetry (e.g. the guardian saw an in-app alert). Do not
                // require NOTIFICATION_DELIVERED as a prerequisite, but never
                // accept a local send or an unverified claim as human ACK.
                if (verifiedServerReceipt &&
                    (current.stage == ManualSosStage.SERVER_ACCEPTED ||
                     current.stage == ManualSosStage.NOTIFICATION_DELIVERED))
                    current.copy(stage = ManualSosStage.GUARDIAN_ACKNOWLEDGED) else current
            ManualSosEvidence.AUTHORIZATION_REVOKED -> current // handled above
        }
    }
}
