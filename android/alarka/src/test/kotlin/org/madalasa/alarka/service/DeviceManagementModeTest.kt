package org.madalasa.alarka.service

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * L05-008: managed-vs-standard device mode distinction.
 * "Normal install never claims Device Owner."
 */
class DeviceManagementModeTest {

    @Test
    fun normalInstallIsStandardAndNeverClaimsDeviceOwner() {
        val facts = DevicePolicyFacts(isDeviceOwner = false, isProfileOwner = false)
        assertEquals(DeviceManagementMode.STANDARD, DeviceManagementModeDetector.classify(facts))
        assertFalse(DeviceManagementModeDetector.claimsDeviceOwner(facts))
    }

    @Test
    fun deviceOwnerIsReportedOnlyWhenPlatformDesignatesIt() {
        val facts = DevicePolicyFacts(isDeviceOwner = true, isProfileOwner = false)
        assertEquals(DeviceManagementMode.MANAGED_DEVICE_OWNER, DeviceManagementModeDetector.classify(facts))
        assertTrue(DeviceManagementModeDetector.claimsDeviceOwner(facts))
    }

    @Test
    fun profileOwnerIsManagedButNotDeviceOwner() {
        val facts = DevicePolicyFacts(isDeviceOwner = false, isProfileOwner = true)
        assertEquals(DeviceManagementMode.MANAGED_PROFILE_OWNER, DeviceManagementModeDetector.classify(facts))
        assertFalse(DeviceManagementModeDetector.claimsDeviceOwner(facts))
    }
}
