package org.madalasa.alarka

import android.os.Build
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.madalasa.alarka.service.AndroidDeviceCapabilityScanner
import org.madalasa.alarka.service.CapabilityDecisionReason
import org.madalasa.alarka.service.ChildCapability
import org.madalasa.alarka.service.PermissionMatrixEvaluator

/**
 * Instrumented Android 10..16 / OEM permission-matrix harness (Phase-05 L05-011).
 *
 * Runs on a physical device or emulator and evaluates the SAME
 * [PermissionMatrixEvaluator] against the real OS level and actual permission grants
 * reported by [AndroidDeviceCapabilityScanner]. Asserts that an unsupported capability
 * on the running OS returns an explicit reason and never allows the action (no bypass).
 *
 * This source set requires device/emulator execution:
 *   ./gradlew :alarka:connectedDebugAndroidTest
 * It is NOT exercised by JVM unit tests; the fake-fixture matrix is covered by
 * PermissionMatrixEvaluatorTest.
 */
@RunWith(AndroidJUnit4::class)
class PermissionMatrixInstrumentedTest {

    private val context get() = InstrumentationRegistry.getInstrumentation().targetContext

    @Test
    fun runningOsIsWithinSupportedRange() {
        val api = Build.VERSION.SDK_INT
        assertTrue(
            "Device API $api below supported minimum",
            api >= PermissionMatrixEvaluator.SUPPORTED_MIN_API
        )
    }

    @Test
    fun postNotificationsDecisionMatchesActualOsAndGrant() {
        val api = Build.VERSION.SDK_INT
        val granted = AndroidDeviceCapabilityScanner(context)
            .getCapabilityReport()
            .permissionsGranted
            .contains("android.permission.POST_NOTIFICATIONS")

        val decision = PermissionMatrixEvaluator.evaluate(
            api = api,
            capability = ChildCapability.POST_NOTIFICATIONS,
            permissionGranted = granted
        )

        if (api < ChildCapability.POST_NOTIFICATIONS.minApi) {
            // Android 10..12: capability not present → explicit unsupported reason, no bypass.
            assertFalse(decision.allowsAction)
            assert(decision.reason == CapabilityDecisionReason.UNSUPPORTED_OS)
        } else if (!granted) {
            assertFalse(decision.allowsAction)
            assert(decision.reason == CapabilityDecisionReason.PERMISSION_REQUIRED)
        } else {
            assertTrue(decision.allowsAction)
        }
    }

    @Test
    fun unsupportedCapabilityNeverBypassesOnThisDevice() {
        // Force an out-of-range OS to confirm fail-closed behavior regardless of device.
        val decision = PermissionMatrixEvaluator.evaluate(
            api = PermissionMatrixEvaluator.SUPPORTED_MIN_API - 1,
            capability = ChildCapability.BACKGROUND_LOCATION,
            permissionGranted = true
        )
        assertFalse(decision.allowsAction)
    }
}
