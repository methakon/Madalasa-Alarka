package org.madalasa.alarka.service

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * L05-009: visible monitoring notification + identifying app. Proves monitoring can
 * never be operational without a valid persistent (ongoing, visible, app-identifying)
 * disclosure — covert operation is impossible by construction.
 */
class MonitoringDisclosureTest {

    @Test
    fun defaultPersistentSpecIsAValidIdentifyingDisclosure() {
        val spec = MonitoringDisclosure.persistentSpec
        assertTrue(spec.ongoing)
        assertTrue(spec.visibleWhileMonitoring)
        assertTrue(spec.title.contains("Alarka", ignoreCase = true))
        assertTrue(spec.isValidDisclosure())
    }

    @Test
    fun monitoringIsNotPermittedWithoutValidDisclosure() {
        val silent = MonitoringNotificationSpec(
            channelId = "x", title = "Alarka is active", body = "b",
            ongoing = false, visibleWhileMonitoring = false
        )
        assertFalse(silent.isValidDisclosure())
        assertFalse(MonitoringDisclosure.monitoringPermitted(monitoringRequested = true, disclosure = silent))
    }

    @Test
    fun monitoringIsPermittedOnlyWithValidDisclosure() {
        assertTrue(
            MonitoringDisclosure.monitoringPermitted(
                monitoringRequested = true,
                disclosure = MonitoringDisclosure.persistentSpec
            )
        )
        // Even a valid disclosure does not start monitoring unless requested.
        assertFalse(
            MonitoringDisclosure.monitoringPermitted(
                monitoringRequested = false,
                disclosure = MonitoringDisclosure.persistentSpec
            )
        )
    }
}
