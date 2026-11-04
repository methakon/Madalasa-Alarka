package org.madalasa.alarka.service

/**
 * Pairing is necessary but never sufficient. All checks are independent:
 * the user can open this entirely free child app while monitoring remains OFF.
 * This is the shared fail-closed policy for future location/usage/FGS workers;
 * Android and server state must be freshly re-evaluated before each start.
 */
enum class ChildActivationState {
    UNPAIRED,
    WAITING_FOR_CHILD_SLOT,
    PAIRING_EXPIRED_OR_REVOKED,
    WAITING_FOR_AUTHORITY_AND_CONSENT,
    WAITING_FOR_ANDROID_PERMISSIONS,
    WAITING_FOR_VISIBLE_DISCLOSURE,
    NOT_LEGALLY_ELIGIBLE,
    ACTIVE
}

data class VerifiedChildActivationFacts(
    val devicePairingVerified: Boolean = false,
    val credentialFresh: Boolean = false,
    /** Must be server-confirmed ADMITTED for this exact child, never inferred. */
    val childServiceAdmitted: Boolean = false,
    val serverConsent: ServerConsentStatus? = null,
    val androidLocationPermissionGranted: Boolean = false,
    val visibleOngoingNotificationReady: Boolean = false,
    /** Independent Android, Play and data-protection release signoff. */
    val platformAndLegalLocationGateApproved: Boolean = false
)

object ChildMonitoringActivationPolicy {
    fun evaluate(facts: VerifiedChildActivationFacts): ChildActivationState {
        if (!facts.devicePairingVerified) return ChildActivationState.UNPAIRED
        if (!facts.credentialFresh) return ChildActivationState.PAIRING_EXPIRED_OR_REVOKED
        if (!facts.childServiceAdmitted) return ChildActivationState.WAITING_FOR_CHILD_SLOT
        val consent = facts.serverConsent
        if (consent == null || consent.childDeleted ||
            !consent.coreConsent || !consent.locationConsent || !consent.collectionAuthorized
        ) return ChildActivationState.WAITING_FOR_AUTHORITY_AND_CONSENT
        if (!facts.platformAndLegalLocationGateApproved) {
            return ChildActivationState.NOT_LEGALLY_ELIGIBLE
        }
        if (!facts.androidLocationPermissionGranted)
            return ChildActivationState.WAITING_FOR_ANDROID_PERMISSIONS
        if (!facts.visibleOngoingNotificationReady)
            return ChildActivationState.WAITING_FOR_VISIBLE_DISCLOSURE
        return ChildActivationState.ACTIVE
    }

    fun mayCollectLocation(facts: VerifiedChildActivationFacts): Boolean =
        evaluate(facts) == ChildActivationState.ACTIVE
}
