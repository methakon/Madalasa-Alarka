package org.madalasa.madalasa.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** L07-004: unknown/unavailable location clearly shown; chips never invent a fix. */
class LocationStatusChipsTest {

    private val now = 1_730_000_000_000L

    private fun state(freshness: Freshness, lat: Int?, lon: Int?, obs: Long?, acc: Float?) =
        VerifiedLocationState("c1", "d1", obs, obs?.plus(5_000), null, lat, lon, acc, freshness)

    @Test
    fun nullStateIsUnavailableAndNotPlottable() {
        val chips = LocationStatusChips.derive(null, now)
        assertEquals("Unavailable", chips.statusLabel)
        assertFalse(chips.hasPlottablePosition)
    }

    @Test
    fun unknownFreshnessShowsUnknownNoCoordinates() {
        val chips = LocationStatusChips.derive(state(Freshness.UNKNOWN, null, null, null, null), now)
        assertEquals("Unknown", chips.statusLabel)
        assertEquals("No recent fix", chips.ageLabel)
        assertFalse(chips.hasPlottablePosition)
    }

    @Test
    fun verifiedCurrentShowsLiveWithAgeAndAccuracy() {
        val chips = LocationStatusChips.derive(
            state(Freshness.VERIFIED_CURRENT, 22_000_000, 88_000_000, now - 90_000, 15f), now
        )
        assertEquals("Live", chips.statusLabel)
        assertEquals("1m ago", chips.ageLabel)
        assertEquals("±15 m", chips.accuracyLabel)
        assertTrue(chips.hasPlottablePosition)
    }

    @Test
    fun lowAccuracyIsMarkedApprox() {
        val chips = LocationStatusChips.derive(
            state(Freshness.LAST_KNOWN, 1, 1, now - 7_200_000, 250f), now
        )
        assertEquals("Last known", chips.statusLabel)
        assertEquals("2h ago", chips.ageLabel)
        assertTrue(chips.accuracyLabel.contains("approx"))
    }
}
