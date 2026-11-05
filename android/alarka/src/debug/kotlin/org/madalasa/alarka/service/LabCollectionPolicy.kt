package org.madalasa.alarka.service

/** Adult-owner lab eligibility never changes the production activation policy. */
object LabCollectionPolicy {
    fun allowed(debug: Boolean, buildOptIn: Boolean, userOptIn: Boolean,
        paired: Boolean, locationGrant: Boolean, notificationReady: Boolean,
        consent: ServerConsentStatus?): Boolean = debug && buildOptIn && userOptIn &&
        ChildMonitoringActivationPolicy.mayCollectLocation(VerifiedChildActivationFacts(
            devicePairingVerified = paired, credentialFresh = paired,
            childServiceAdmitted = consent?.childServiceAdmitted == true, serverConsent = consent,
            androidLocationPermissionGranted = locationGrant,
            visibleOngoingNotificationReady = notificationReady,
            // Only debug source set calls this policy; this is adult lab approval,
            // NOT a release, legal or Play authorization.
            platformAndLegalLocationGateApproved = debug && buildOptIn && userOptIn
        ))

    fun isReceipt(expected: String, actual: String, stage: String, accepted: Int, rejected: Int,
        duplicates: Int = 0) = expected == actual &&
        stage in setOf("INBOX_COMMITTED", "RAW_OBSERVATIONS_COMMITTED") &&
        accepted in 0..1 && duplicates in 0..1 && accepted + duplicates == 1 && rejected == 0
}
