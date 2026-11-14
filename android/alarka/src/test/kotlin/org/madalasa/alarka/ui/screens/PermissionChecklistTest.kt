package org.madalasa.alarka.ui.screens

import android.Manifest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.madalasa.alarka.service.DeviceCapabilityReport

class PermissionChecklistTest {

    @Test
    fun nullReportHandledWithoutCrashingAndDefaultsToUngranted() {
        val items = PermissionChecklistEvaluator.buildChecklist(null)
        assertEquals(5, items.size)
        items.forEach { item ->
            assertFalse("Permission must not be claimed granted when report is null", item.isPermissionGranted)
        }
        val loc = items.first { it.id == "location" }
        assertEquals("Unknown — scan pending", loc.statusText)
    }

    @Test
    fun hardwarePresenceDoesNotImplyPermissionGrant() {
        // Device has GPS, camera, and microphone hardware, but user has not granted permissions
        val report = DeviceCapabilityReport(
            osVersion = 34,
            hasGpsHardware = true,
            hasBleHardware = true,
            hasCameraHardware = true,
            hasMicrophoneHardware = true,
            permissionsGranted = emptyList(),
            permissionsDeclared = listOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            )
        )

        val items = PermissionChecklistEvaluator.buildChecklist(report)
        val locationItem = items.first { it.id == "location" }
        assertTrue("Hardware should be detected", locationItem.isHardwareDetected)
        assertFalse("Permission must not be marked granted without explicit runtime grant", locationItem.isPermissionGranted)
        assertEquals("Not granted · feature OFF", locationItem.statusText)
        assertTrue(locationItem.explanation.contains("OS permission has NOT been granted"))
    }

    @Test
    fun backgroundLocationRequiresSeparateGrant() {
        val foregroundOnlyReport = DeviceCapabilityReport(
            osVersion = 34,
            hasGpsHardware = true,
            hasBleHardware = false,
            hasCameraHardware = false,
            hasMicrophoneHardware = false,
            permissionsGranted = listOf(Manifest.permission.ACCESS_FINE_LOCATION)
        )

        val items = PermissionChecklistEvaluator.buildChecklist(foregroundOnlyReport)
        val fgLoc = items.first { it.id == "location" }
        val bgLoc = items.first { it.id == "background_location" }

        assertTrue("Foreground location should be granted", fgLoc.isPermissionGranted)
        assertFalse("Background location must not be inferred from foreground grant", bgLoc.isPermissionGranted)
        assertEquals("Not granted", bgLoc.statusText)
    }

    @Test
    fun notificationPermissionEvaluatesApiVersionDifferences() {
        // API 33+ requires runtime POST_NOTIFICATIONS grant
        val api33WithoutNotif = DeviceCapabilityReport(
            osVersion = 33,
            hasGpsHardware = true,
            hasBleHardware = false,
            hasCameraHardware = false,
            hasMicrophoneHardware = false,
            permissionsGranted = emptyList(),
            notificationsEnabled = true // system enabled, but runtime permission missing
        )
        val items33NoGrant = PermissionChecklistEvaluator.buildChecklist(api33WithoutNotif)
        val notif33 = items33NoGrant.first { it.id == "notifications" }
        assertFalse("API 33 requires POST_NOTIFICATIONS runtime grant", notif33.isPermissionGranted)

        val api33WithGrant = api33WithoutNotif.copy(
            permissionsGranted = listOf(Manifest.permission.POST_NOTIFICATIONS)
        )
        val items33WithGrant = PermissionChecklistEvaluator.buildChecklist(api33WithGrant)
        assertTrue(items33WithGrant.first { it.id == "notifications" }.isPermissionGranted)

        // API 30 uses notificationsEnabled setting
        val api30WithNotif = DeviceCapabilityReport(
            osVersion = 30,
            hasGpsHardware = true,
            hasBleHardware = false,
            hasCameraHardware = false,
            hasMicrophoneHardware = false,
            permissionsGranted = emptyList(),
            notificationsEnabled = true
        )
        val items30 = PermissionChecklistEvaluator.buildChecklist(api30WithNotif)
        assertTrue("API 30 honors notificationsEnabled", items30.first { it.id == "notifications" }.isPermissionGranted)
    }

    @Test
    fun covertRecordingIsStrictlyProhibitedEvenWithHardwarePresent() {
        val deviceWithMedia = DeviceCapabilityReport(
            osVersion = 34,
            hasGpsHardware = true,
            hasBleHardware = true,
            hasCameraHardware = true,
            hasMicrophoneHardware = true,
            permissionsGranted = listOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            )
        )

        val items = PermissionChecklistEvaluator.buildChecklist(deviceWithMedia)
        val covertItem = items.first { it.id == "covert_capture" }

        assertTrue("Hardware camera/mic is present", covertItem.isHardwareDetected)
        assertFalse("Covert permission must never be granted", covertItem.isPermissionGranted)
        assertEquals("Strictly Prohibited & Inactive", covertItem.statusText)
        assertTrue(covertItem.explanation.contains("Zero audio/video surveillance"))
    }
}
