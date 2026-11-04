package org.madalasa.alarka.service

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class Android10To16PermissionPlanTest {
    private fun approved(api: Int) = AndroidLocationSetupFacts(
        api = api,
        paired = true, admitted = true, consentAuthorized = true, releaseApproved = true,
        foregroundLocationDeclared = true,
        backgroundLocationDeclared = true,
        notificationPermissionDeclared = true,
        locationServiceDeclared = true,
        locationServicePermissionDeclared = true,
        gpsOrNetworkProvider = true, systemLocationEnabled = true,
        coarseGranted = true, fineGranted = false,
        backgroundGranted = false,
        notificationGranted = true, notificationsEnabled = true
    )

    @Test fun coversEveryAndroidSdk29To36WithoutImplicitPreciseAccess() {
        for (api in 29..36) {
            val actual = Android10To16PermissionPlan.evaluate(approved(api))
            assertEquals("API $api",LocationSetupAction.READY_FOR_VISIBLE_LOCATION_SERVICE,actual.action)
            assertTrue(actual.mayAttemptVisibleService)
        }
    }

    @Test fun allVersionsDenyUnpairedQueuedOrRevokedConsent() {
        for (api in 29..36) {
            val good=approved(api)
            for (blocked in listOf(
                good.copy(paired=false),
                good.copy(admitted=false),
                good.copy(consentAuthorized=false),
                good.copy(releaseApproved=false)
            )) {
                assertFalse("API $api",Android10To16PermissionPlan.evaluate(blocked).mayAttemptVisibleService)
            }
        }
    }

    @Test fun neverTreatsAnOsPermissionAsLegalApproval() {
        for (api in 29..36) {
            val p=Android10To16PermissionPlan.evaluate(approved(api).copy(releaseApproved=false))
            assertEquals(LocationSetupAction.AWAITING_RELEASE_APPROVAL,p.action)
        }
    }

    @Test fun foregroundRequestAcceptsCoarseWithoutForcingPrecise() {
        for(api in 29..36) {
            val denied=Android10To16PermissionPlan.evaluate(
                approved(api).copy(coarseGranted=false,fineGranted=false)
            )
            assertEquals(LocationSetupAction.REQUEST_FOREGROUND_LOCATION,denied.action)
            assertFalse(denied.mayAttemptVisibleService)
        }
    }

    @Test fun android10BackgroundRuntimeVsAndroid11To16SeparateSettings() {
        assertEquals(LocationSetupAction.REQUEST_BACKGROUND_LOCATION_ANDROID_10,
            Android10To16PermissionPlan.evaluate(
                approved(29).copy(backgroundLocationRequired=true)).action)
        for (api in 30..36) {
            val result=Android10To16PermissionPlan.evaluate(
                approved(api).copy(backgroundLocationRequired=true))
            assertEquals("API $api",LocationSetupAction.OPEN_BACKGROUND_LOCATION_SETTINGS,result.action)
        }
    }

    @Test fun notificationPermissionStartsAtApi33NotBefore() {
        for (api in 29..32) {
            assertEquals(LocationSetupAction.READY_FOR_VISIBLE_LOCATION_SERVICE,
                Android10To16PermissionPlan.evaluate(
                    approved(api).copy(notificationGranted=false)).action)
        }
        for (api in 33..36) {
            assertEquals(LocationSetupAction.REQUEST_NOTIFICATION_PERMISSION,
                Android10To16PermissionPlan.evaluate(
                    approved(api).copy(notificationGranted=false)).action)
        }
    }

    @Test fun android14PlusRequiresSpecificForegroundLocationManifestPermission() {
        for(api in 29..33) {
            assertEquals(LocationSetupAction.READY_FOR_VISIBLE_LOCATION_SERVICE,
                Android10To16PermissionPlan.evaluate(
                    approved(api).copy(locationServicePermissionDeclared=false)).action)
        }
        for(api in 34..36) {
            assertEquals(LocationSetupAction.MANIFEST_NOT_READY,
                Android10To16PermissionPlan.evaluate(
                    approved(api).copy(locationServicePermissionDeclared=false)).action)
        }
    }

    @Test fun backgroundServiceStartAndSystemRejectionStayBlocked() {
        for(api in 29..36) {
            assertEquals(LocationSetupAction.OPEN_APP_TO_START_SERVICE,
                Android10To16PermissionPlan.evaluate(
                    approved(api).copy(foregroundAppVisible=false)).action)
            assertEquals(LocationSetupAction.FOREGROUND_SERVICE_REJECTED,
                Android10To16PermissionPlan.evaluate(
                    approved(api).copy(osRejectedForegroundService=true)).action)
        }
        for(api in 34..36) {
            assertEquals(LocationSetupAction.OPEN_APP_TO_START_SERVICE,
                Android10To16PermissionPlan.evaluate(
                    approved(api).copy(foregroundAppVisible=false,startExemptionVerified=true)).action)
        }
    }

    @Test fun locationDisabledAndNotificationsOffNeedVisibleUserAction() {
        val v=approved(36)
        assertEquals(LocationSetupAction.ENABLE_SYSTEM_LOCATION,
            Android10To16PermissionPlan.evaluate(v.copy(systemLocationEnabled=false)).action)
        assertEquals(LocationSetupAction.OPEN_NOTIFICATION_SETTINGS,
            Android10To16PermissionPlan.evaluate(v.copy(notificationsEnabled=false)).action)
        assertEquals(LocationSetupAction.NO_LOCATION_PROVIDER,
            Android10To16PermissionPlan.evaluate(v.copy(gpsOrNetworkProvider=false)).action)
    }

    @Test fun unsupportedAndroidVersionsCannotActivate() {
        for(api in listOf(28,37,100)) {
            assertEquals(LocationSetupAction.UNSUPPORTED_ANDROID,
                Android10To16PermissionPlan.evaluate(approved(api)).action)
        }
    }
}
