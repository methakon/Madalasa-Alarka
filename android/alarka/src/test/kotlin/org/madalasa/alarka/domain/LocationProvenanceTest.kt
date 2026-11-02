package org.madalasa.alarka.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** L06-001: observed timestamp, accuracy and provenance (provider + fused) retained. */
class LocationProvenanceTest {

    private fun obs(acc: Float, provider: String, fused: Boolean) = LocationObservation(
        eventId = "e1",
        observedAtEpochMs = 1_730_000_000_000L,
        latitudeE6 = 12_971_598,
        longitudeE6 = 77_594_562,
        accuracyMeters = acc,
        speedMetersPerSecond = 1.0f,
        sourceDeviceId = "dev-1",
        provider = provider,
        sensorFused = fused
    )

    @Test
    fun provenanceAndTimestampAreRetained() {
        val o = obs(8f, "fused", true)
        assertEquals("fused", o.provider)
        assertTrue(o.sensorFused)
        assertEquals(1_730_000_000_000L, o.observedAtEpochMs)
        assertEquals(8f, o.accuracyMeters, 0.0001f)
    }

    @Test
    fun qualityIsQualifiedWithinHundredMetresElseCoarse() {
        assertEquals("QUALIFIED", obs(100f, "gps", false).quality())
        assertEquals("COARSE", obs(150f, "network", false).quality())
    }

    @Test
    fun defaultsPreserveBackwardCompatibility() {
        val legacy = LocationObservation(
            eventId = "e", observedAtEpochMs = 1L, latitudeE6 = 0, longitudeE6 = 0,
            accuracyMeters = 5f, speedMetersPerSecond = null, sourceDeviceId = "d"
        )
        assertEquals("unknown", legacy.provider)
        assertFalse(legacy.sensorFused)
    }
}
