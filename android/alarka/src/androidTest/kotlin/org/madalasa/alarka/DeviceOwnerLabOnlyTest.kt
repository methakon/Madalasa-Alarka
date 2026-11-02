package org.madalasa.alarka

import android.app.admin.DevicePolicyManager
import android.content.Context
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertFalse
import org.junit.Test
import org.junit.runner.RunWith
import org.madalasa.alarka.service.DeviceManagementModeDetector
import org.madalasa.alarka.service.DevicePolicyFacts

/**
 * L09-009: real Device Owner DPC controls are lab-only. On any ordinary (non
 * factory-reset-provisioned) device this test proves the app is NOT a Device Owner
 * and the management-mode classifier reports STANDARD — managed controls are only
 * ever active after genuine DPC provisioning on a dedicated test phone.
 *
 * Run: ./gradlew :alarka:connectedDebugAndroidTest
 */
@RunWith(AndroidJUnit4::class)
class DeviceOwnerLabOnlyTest {

    private val context: Context
        get() = InstrumentationRegistry.getInstrumentation().targetContext

    @Test
    fun appIsNotDeviceOwnerOnOrdinaryDevice() {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        // The real platform must not report this synthetic build as device owner.
        assertFalse(
            "Synthetic/CI device must never be provisioned as Device Owner",
            dpm.isDeviceOwnerApp(context.packageName)
        )
    }

    @Test
    fun classifierReportsStandardWhenPlatformHasNoOwnership() {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val facts = DevicePolicyFacts(
            isDeviceOwner = dpm.isDeviceOwnerApp(context.packageName),
            isProfileOwner = dpm.isProfileOwnerApp(context.packageName)
        )
        // On an ordinary device both are false => STANDARD, never claims Device Owner.
        assertFalse(DeviceManagementModeDetector.claimsDeviceOwner(facts))
    }
}
