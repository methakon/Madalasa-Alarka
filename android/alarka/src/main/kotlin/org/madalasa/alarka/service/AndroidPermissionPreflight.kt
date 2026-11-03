package org.madalasa.alarka.service

/**
 * Joins observed Android state with current authenticated server state without
 * treating hardware/manifest, an old grant, or a pairing receipt as consent.
 */
object AndroidPermissionPreflight {
    fun evaluate(
        report: DeviceCapabilityReport?,
        pairedWithVerifiedCredential: Boolean,
        server: ServerConsentStatus?,
        locationReleaseApproved: Boolean
    ): AndroidLocationSetupPlan {
        if (report == null) return AndroidLocationSetupPlan(
            LocationSetupAction.MANIFEST_NOT_READY, "Android capability scan is unavailable"
        )
        val declared = report.permissionsDeclared.toSet()
        val granted = report.permissionsGranted.toSet()
        return Android10To16PermissionPlan.evaluate(AndroidLocationSetupFacts(
            api = report.osVersion,
            paired = pairedWithVerifiedCredential,
            admitted = server?.childServiceAdmitted == true,
            consentAuthorized = server?.let {
                it.coreConsent && it.locationConsent &&
                    it.collectionAuthorized && !it.childDeleted
            } == true,
            releaseApproved = locationReleaseApproved,
            foregroundLocationDeclared =
                "android.permission.ACCESS_COARSE_LOCATION" in declared ||
                    "android.permission.ACCESS_FINE_LOCATION" in declared,
            backgroundLocationDeclared =
                "android.permission.ACCESS_BACKGROUND_LOCATION" in declared,
            notificationPermissionDeclared =
                "android.permission.POST_NOTIFICATIONS" in declared,
            locationServiceDeclared = report.locationForegroundServiceDeclared,
            locationServicePermissionDeclared =
                "android.permission.FOREGROUND_SERVICE_LOCATION" in declared,
            gpsOrNetworkProvider =
                report.hasGpsHardware || report.hasNetworkLocationHardware,
            systemLocationEnabled = report.systemLocationEnabled,
            coarseGranted = "android.permission.ACCESS_COARSE_LOCATION" in granted,
            fineGranted = "android.permission.ACCESS_FINE_LOCATION" in granted,
            backgroundGranted = "android.permission.ACCESS_BACKGROUND_LOCATION" in granted,
            notificationGranted = "android.permission.POST_NOTIFICATIONS" in granted,
            notificationsEnabled = report.notificationsEnabled,
            // No runtime background-location demand for the already-running
            // and visible location FGS. If later approved, request separately.
            backgroundLocationRequired = false,
            foregroundAppVisible = true,
            serviceAlreadyRunning = false,
            startExemptionVerified = false,
            osRejectedForegroundService = false
        ))
    }
}
