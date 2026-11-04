package org.madalasa.alarka.service

/** What the lab collector must do when an OS or server signal arrives. */
enum class LabStop {
    /** Continue collecting and uploading. */
    CONTINUE,

    /** Stop this session but keep the durable queue and local session for a later retry. */
    PAUSE,

    /** Definitive authorization loss: durably halt the queue and clear the local session. */
    REVOKE
}

/**
 * Separates a definitive authorization denial from a transient/unknown failure and from a
 * merely unavailable location provider. Unpairing is destructive, so only proof of denied
 * authority may revoke; an offline server, a 5xx, malformed JSON or GPS switched off must
 * never destroy a still-valid local enrollment.
 */
object LabStopPolicy {
    fun forConsentFailure(error: Throwable?): LabStop = when (error) {
        // 401/403/404/410 from the consent endpoint, or an explicit typed denial.
        is ChildAuthorizationDenied, is LabAuthorizationDenied -> LabStop.REVOKE
        // Timeouts, TLS resets, 5xx/429 and unparseable bodies are unknown, not a denial.
        else -> LabStop.PAUSE
    }

    /**
     * A missing snapshot, a waitlisted child or an absent admission flag is not proof that
     * authority was taken away. Only withdrawal of consent, deletion or an explicit
     * non-collection verdict may destroy the enrollment and its queued records.
     */
    fun forConsentSnapshot(status: ServerConsentStatus?): LabStop = when {
        status == null -> LabStop.PAUSE
        status.childDeleted -> LabStop.REVOKE
        !status.coreConsent || !status.locationConsent -> LabStop.REVOKE
        !status.childServiceAdmitted -> LabStop.PAUSE
        !status.collectionAuthorized -> LabStop.REVOKE
        else -> LabStop.CONTINUE
    }

    /**
     * A fix arriving while the consent snapshot is stale is a refresh gap, not proof of denial.
     * Pausing keeps the encrypted queue; only a verdict that actually failed eligibility revokes.
     * Treating staleness as revocation would unpair and delete pending records during a slow
     * upload or a stalled health check.
     */
    fun forFixArrival(status: ServerConsentStatus?, consentFresh: Boolean): LabStop {
        // A verdict already recorded in the snapshot keeps its meaning however old it is;
        // staleness on its own may only pause.
        val verdict = forConsentSnapshot(status)
        if (verdict != LabStop.CONTINUE) return verdict
        return if (consentFresh) LabStop.CONTINUE else LabStop.PAUSE
    }

    /**
     * Permission, notification-visibility and enrollment identity are authority to collect and
     * must fail closed. A switched-off location provider is an availability condition only.
     */
    fun forOsState(
        locationGranted: Boolean,
        notificationReady: Boolean,
        sessionIntact: Boolean,
        providerEnabled: Boolean
    ): LabStop = when {
        !locationGranted || !notificationReady || !sessionIntact -> LabStop.REVOKE
        !providerEnabled -> LabStop.PAUSE
        else -> LabStop.CONTINUE
    }
}
