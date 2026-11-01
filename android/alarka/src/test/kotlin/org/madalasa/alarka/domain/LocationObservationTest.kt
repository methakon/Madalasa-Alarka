package org.madalasa.alarka.domain

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LocationObservationTest {
    private fun sample(latitude: Int, accuracy: Float) = LocationObservation(
        eventId = "synthetic-event",
        observedAtEpochMs = 1000L,
        latitudeE6 = latitude,
        longitudeE6 = 0,
        accuracyMeters = accuracy,
        speedMetersPerSecond = null,
        sourceDeviceId = "synthetic-device"
    )

    @Test fun plausibleFixtureIsAccepted() {
        assertTrue(sample(26_700_000, 8f).hasPlausibleCoordinates())
    }
    @Test fun invalidLatitudeIsRejected() {
        assertFalse(sample(90_000_001, 8f).hasPlausibleCoordinates())
    }
    @Test fun negativeAccuracyIsRejected() {
        assertFalse(sample(0, -1f).hasPlausibleCoordinates())
    }
}
