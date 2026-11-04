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

    fun isReceipt(expected: String, actual: String, stage: String, accepted: Int, rejected: Int) =
        expected == actual && stage == "INBOX_COMMITTED" && accepted == 1 && rejected == 0
}
