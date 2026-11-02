package org.madalasa.alarka.service

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * L05-011 (fake-fixture portion): Android 10..16 permission matrix.
 * Unsupported modes must return an explicit reason and never allow the action.
 * The physical-device/OEM portion runs via the instrumented androidTest harness.
 */
class PermissionMatrixEvaluatorTest {

    // Android 10..16 => API 29..36
    private val supportedApis = (29..36).toList()

    @Test
    fun belowRangeOsIsUnsupportedWithReasonAndNoBypass() {
        val d = PermissionMatrixEvaluator.evaluate(28, ChildCapability.BACKGROUND_LOCATION, permissionGranted = true)
        assertEquals(CapabilityDecisionReason.UNSUPPORTED_OS, d.reason)
        assertFalse(d.allowsAction)
        assertTrue(d.explanation.contains("outside the supported range"))
    }

    @Test
    fun aboveRangeOsIsUnsupportedWithReason() {
        val d = PermissionMatrixEvaluator.evaluate(37, ChildCapability.POST_NOTIFICATIONS, permissionGranted = true)
        assertEquals(CapabilityDecisionReason.UNSUPPORTED_OS, d.reason)
        assertFalse(d.allowsAction)
    }

    @Test
    fun postNotificationsUnsupportedBelowApi33() {
        // Android 10..12 (29..32): runtime POST_NOTIFICATIONS capability not present.
        (29..32).forEach { api ->
            val d = PermissionMatrixEvaluator.evaluate(api, ChildCapability.POST_NOTIFICATIONS, permissionGranted = true)
            assertEquals("API $api", CapabilityDecisionReason.UNSUPPORTED_OS, d.reason)
            assertFalse(d.allowsAction)
        }
        // Android 13..16 (33..36): supported when granted.
        (33..36).forEach { api ->
            val d = PermissionMatrixEvaluator.evaluate(api, ChildCapability.POST_NOTIFICATIONS, permissionGranted = true)
            assertEquals("API $api", CapabilityDecisionReason.SUPPORTED, d.reason)
        }
    }

    @Test
    fun missingPermissionFailsClosedWithPermissionRequired() {
        supportedApis.forEach { api ->
            val d = PermissionMatrixEvaluator.evaluate(api, ChildCapability.BACKGROUND_LOCATION, permissionGranted = false)
            // On API < minApi it would be UNSUPPORTED_OS; BACKGROUND_LOCATION minApi is 29 so all are in range.
            assertEquals("API $api", CapabilityDecisionReason.PERMISSION_REQUIRED, d.reason)
            assertFalse("API $api must not bypass", d.allowsAction)
        }
    }

    @Test
    fun usageAccessRequiresSettingsActionBeforePermission() {
        val d = PermissionMatrixEvaluator.evaluate(
            api = 31,
            capability = ChildCapability.USAGE_ACCESS,
            permissionGranted = true,
            settingsActionDone = false
        )
        assertEquals(CapabilityDecisionReason.USER_ACTION_REQUIRED, d.reason)
        assertFalse(d.allowsAction)
    }

    @Test
    fun supportedPathAllowsActionOnlyWhenEverythingSatisfied() {
        val d = PermissionMatrixEvaluator.evaluate(
            api = 34,
            capability = ChildCapability.USAGE_ACCESS,
            permissionGranted = true,
            settingsActionDone = true
        )
        assertEquals(CapabilityDecisionReason.SUPPORTED, d.reason)
        assertTrue(d.allowsAction)
    }
}
