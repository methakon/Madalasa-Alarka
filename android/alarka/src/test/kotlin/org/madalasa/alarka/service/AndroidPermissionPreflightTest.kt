package org.madalasa.alarka.service

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class AndroidPermissionPreflightTest {
    private val approvedServer = ServerConsentStatus(
        coreConsent = true, locationConsent = true, usageConsent = false,
        mediaConsent = false, childDeleted = false, collectionAuthorized = true,
        childServiceAdmitted = true
    )
    private fun report(api: Int) = DeviceCapabilityReport(
        osVersion = api,
        hasGpsHardware = true, hasBleHardware = false,
        hasCameraHardware = true, hasMicrophoneHardware = true,
        permissionsGranted = listOf(
            "android.permission.ACCESS_COARSE_LOCATION",
            "android.permission.POST_NOTIFICATIONS"
        ),
        permissionsDeclared = listOf(
            "android.permission.ACCESS_COARSE_LOCATION",
            "android.permission.ACCESS_FINE_LOCATION",
            "android.permission.POST_NOTIFICATIONS",
            "android.permission.FOREGROUND_SERVICE",
            "android.permission.FOREGROUND_SERVICE_LOCATION"
        ),
        systemLocationEnabled = true, notificationsEnabled = true,
        locationForegroundServiceDeclared = true
    )

    @Test fun noAndroidScanDoesNotPretendToHavePermissions() {
        assertFalse(AndroidPermissionPreflight.evaluate(null,true,approvedServer,true).mayAttemptVisibleService)
    }

    @Test fun denyForUnpairedOrWaitlistedChildOnEveryAndroidVersion() {
        for(api in 29..36) {
            assertEquals(LocationSetupAction.NOT_PAIRED_OR_ADMITTED,
                AndroidPermissionPreflight.evaluate(report(api),false,approvedServer,true).action)
            assertEquals(LocationSetupAction.NOT_PAIRED_OR_ADMITTED,
                AndroidPermissionPreflight.evaluate(
                    report(api),true,approvedServer.copy(childServiceAdmitted=false),true
                ).action)
        }
    }

    @Test fun consentRevocationOrMissingServerNeverAllowsPermissions() {
        for(api in 29..36) {
            for(server in listOf(
                null, approvedServer.copy(coreConsent=false),
                approvedServer.copy(locationConsent=false),
                approvedServer.copy(childDeleted=true),
                approvedServer.copy(collectionAuthorized=false)
            )) {
                val decision=AndroidPermissionPreflight.evaluate(report(api),true,server,true)
                assertEquals("API $api",LocationSetupAction.AWAITING_SERVER_CONSENT,decision.action)
            }
        }
    }

    @Test fun publicReleaseManifestAndPolicyRemainOffEvenForPairedChild() {
        for(api in 29..36) {
            val r=report(api).copy(
                permissionsDeclared=listOf("android.permission.INTERNET"),
                locationForegroundServiceDeclared=false
            )
            assertEquals(LocationSetupAction.AWAITING_RELEASE_APPROVAL,
                AndroidPermissionPreflight.evaluate(r,true,approvedServer,false).action)
            assertEquals(LocationSetupAction.MANIFEST_NOT_READY,
                AndroidPermissionPreflight.evaluate(r,true,approvedServer,true).action)
        }
    }

    @Test fun approvedInternalPlanSupportsApproximateAcrossAllVersions() {
        for(api in 29..36) {
            assertEquals(LocationSetupAction.READY_FOR_VISIBLE_LOCATION_SERVICE,
                AndroidPermissionPreflight.evaluate(report(api),true,approvedServer,true).action)
        }
    }
}
