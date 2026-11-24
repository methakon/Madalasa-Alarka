package org.madalasa.madalasa.ui.screens

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.madalasa.madalasa.domain.Freshness

class ChildActivityCardTest {

    @Test
    fun batteryFormatReflectsHonestValuesAndUnavailableStates() {
        assertEquals("85% 🔋", ChildActivityCardState.formatBattery(85, false))
        assertEquals("42% ⚡ Charging", ChildActivityCardState.formatBattery(42, true))
        assertEquals("0% 🔋", ChildActivityCardState.formatBattery(0, false))
        assertEquals("100% ⚡ Charging", ChildActivityCardState.formatBattery(100, true))

        // Negative tests: out of range or uncollected telemetry
        assertEquals("Battery telemetry unavailable", ChildActivityCardState.formatBattery(null, null))
        assertEquals("Battery telemetry unavailable", ChildActivityCardState.formatBattery(-5, false))
        assertEquals("Battery telemetry unavailable", ChildActivityCardState.formatBattery(105, false))
    }

    @Test
    fun serviceStatusDistinguishesAdmittedQueuedAndUnavailable() {
        assertEquals("Active · Free Tier", ChildActivityCardState.formatServiceStatus("ADMITTED", null))
        assertEquals("Waitlisted (#42 in queue of 108)", ChildActivityCardState.formatServiceStatus("QUEUED", 42L))
        assertEquals("Waitlisted (#? in queue of 108)", ChildActivityCardState.formatServiceStatus("QUEUED", null))
        assertEquals("Service unavailable", ChildActivityCardState.formatServiceStatus("UNAVAILABLE", null))
        assertEquals("Service unavailable", ChildActivityCardState.formatServiceStatus("UNKNOWN", null))
    }

    @Test
    fun locationFreshnessFormattingAvoidsInventedMotion() {
        val now = 1_000_000_000L
        val fiveMinsAgo = now - (5 * 60 * 1000L)
        val thirtyMinsAgo = now - (30 * 60 * 1000L)
        val twoHoursAgo = now - (120 * 60 * 1000L)

        assertEquals("Verified current · 5m ago",
            ChildActivityCardState.formatLocationStatus(Freshness.VERIFIED_CURRENT, fiveMinsAgo, now))
        assertEquals("Delayed update · 30m ago",
            ChildActivityCardState.formatLocationStatus(Freshness.DELAYED, thirtyMinsAgo, now))
        assertEquals("Last known · 120m ago",
            ChildActivityCardState.formatLocationStatus(Freshness.LAST_KNOWN, twoHoursAgo, now))

        // Unavailable states never infer or guess coordinates
        assertEquals("Location unavailable · No coordinates inferred",
            ChildActivityCardState.formatLocationStatus(Freshness.UNAVAILABLE, null, now))
        assertEquals("Location unavailable · No coordinates inferred",
            ChildActivityCardState.formatLocationStatus(Freshness.UNKNOWN, null, now))
    }

    @Test
    fun cardStateMaintainsSosAndPrivacyInvariants() {
        val stateWithoutSos = ChildActivityCardState(
            childId = "c-1",
            alias = "Test Child",
            freeServiceState = "ADMITTED",
            batteryPercent = 90,
            isCharging = false,
            locationFreshness = Freshness.VERIFIED_CURRENT,
            hasActiveSos = false
        )
        assertFalse(stateWithoutSos.hasActiveSos)
        assertEquals("Active · Free Tier", stateWithoutSos.serviceStatusDisplay())
        assertEquals("90% 🔋", stateWithoutSos.batteryDisplay())

        val stateWithSos = stateWithoutSos.copy(
            hasActiveSos = true,
            activeSosEventId = "sos-event-999"
        )
        assertTrue(stateWithSos.hasActiveSos)
        assertEquals("sos-event-999", stateWithSos.activeSosEventId)
    }
}
