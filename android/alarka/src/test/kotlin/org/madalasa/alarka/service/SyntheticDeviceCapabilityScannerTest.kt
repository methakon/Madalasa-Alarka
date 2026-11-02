package org.madalasa.alarka.service

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SyntheticDeviceCapabilityScannerTest {

    private val scanner = SyntheticDeviceCapabilityScanner()

    @Test
    fun capabilityReportReflectsConfiguredDefaults() {
        val report = scanner.getCapabilityReport()
        assertEquals(34, report.osVersion)
        assertTrue(report.hasGpsHardware)
        assertTrue(report.hasBleHardware)
        assertTrue(report.hasCameraHardware)
        assertTrue(report.hasMicrophoneHardware)
        assertTrue(report.permissionsGranted.isEmpty())
    }
}
