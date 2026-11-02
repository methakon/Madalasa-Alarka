package org.madalasa.madalasa.domain

import org.junit.Assert.assertEquals
import org.junit.Test

class VerifiedLocationStateTest {
    @Test fun unknownLocationMustNotInventCoordinates() {
        val state = VerifiedLocationState(
            childId = "synthetic-child",
            sourceDeviceId = "synthetic-device",
            observedAtEpochMs = null,
            ingestedAtEpochMs = null,
            tripProcessedAtEpochMs = null,
            latitudeE6 = null,
            longitudeE6 = null,
            accuracyMeters = null,
            freshness = Freshness.UNKNOWN
        )
        assertEquals(null, state.latitudeE6)
        assertEquals(Freshness.UNKNOWN, state.freshness)
    }
}
