package org.madalasa.alarka.ui.screens

import android.Manifest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.madalasa.alarka.service.DeviceCapabilityReport

class ChildPrivacyScreensTest {
    private fun report(grants: List<String>) = DeviceCapabilityReport(
        osVersion = 34,
        hasGpsHardware = true,
        hasBleHardware = true,
        hasCameraHardware = true,
        hasMicrophoneHardware = true,
        permissionsGranted = grants
    )

    @Test fun bothNewFigmaNodesMapToDistinctRoutes() {
        assertEquals(2, ChildPrivacyPage.entries.size)
        assertEquals(setOf("159:79", "159:98"),
            ChildPrivacyPage.entries.map { it.nodeId }.toSet())
        ChildPrivacyPage.entries.forEach {
            assertEquals(it, ChildPrivacyPage.fromRoute(it.route))
        }
        assertEquals(null, ChildPrivacyPage.fromRoute("privacy/unknown"))
    }

    @Test fun missingGrantDoesNotClaimTheUserExplicitlyDenied() {
        val description = locationGrantDescription(report(emptyList()))
        assertEquals(LocationGrantState.NOT_GRANTED, locationGrantState(report(emptyList())))
        assertTrue(description.contains("unrequested or denied"))
        assertEquals(LocationGrantState.UNKNOWN, locationGrantState(null))
    }

    @Test fun grantsHaveCorrectPrecedenceAndNeverImplyMonitoringAuthorized() {
        val fine = locationGrantDescription(report(listOf(
            Manifest.permission.ACCESS_COARSE_LOCATION, Manifest.permission.ACCESS_FINE_LOCATION
        )))
        assertTrue(fine.contains("Precise"))
        assertTrue(fine.contains("monitoring remains disabled"))
        val coarse = locationGrantDescription(report(listOf(
            Manifest.permission.ACCESS_COARSE_LOCATION
        )))
        assertTrue(coarse.contains("Approximate"))
        assertTrue(coarse.contains("monitoring remains disabled"))
    }

    @Test fun bothScreensRenderFourFigmaStateRows() {
        ChildPrivacyPage.entries.forEach {
            val rows = childPrivacyRows(it, report(emptyList()))
            assertEquals(4, rows.size)
            assertTrue(rows.all { row -> row.title.isNotBlank() && row.value.isNotBlank() })
        }
    }
}
