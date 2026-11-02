package org.madalasa.alarka.service

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** L06-002: free cadence lower than paid, battery saver steps down, never guaranteed. */
class TrackingCadencePolicyTest {

    @Test
    fun freeMovingCadenceIsLowerThanPaid() {
        val free = TrackingCadencePolicy.requestFor(Tier.FREE, MotionState.MOVING, PowerState.NORMAL)
        val paid = TrackingCadencePolicy.requestFor(Tier.PAID, MotionState.MOVING, PowerState.NORMAL)
        assertTrue("free interval must be larger (lower cadence)",
            free.requestedIntervalMillis > paid.requestedIntervalMillis)
    }

    @Test
    fun cadenceIsNeverGuaranteed() {
        val r = TrackingCadencePolicy.requestFor(Tier.PAID, MotionState.MOVING, PowerState.NORMAL)
        assertFalse(r.guaranteed)
    }

    @Test
    fun batterySaverStepsDownNeverDenser() {
        val normal = TrackingCadencePolicy.requestFor(Tier.PAID, MotionState.MOVING, PowerState.NORMAL)
        val saver = TrackingCadencePolicy.requestFor(Tier.PAID, MotionState.MOVING, PowerState.BATTERY_SAVER)
        assertTrue(saver.requestedIntervalMillis >= normal.requestedIntervalMillis)
    }

    @Test
    fun stationaryCadenceIsLowerThanMoving() {
        val moving = TrackingCadencePolicy.requestFor(Tier.FREE, MotionState.MOVING, PowerState.NORMAL)
        val stationary = TrackingCadencePolicy.requestFor(Tier.FREE, MotionState.STATIONARY, PowerState.NORMAL)
        assertTrue(stationary.requestedIntervalMillis > moving.requestedIntervalMillis)
    }

    @Test
    fun guardianInactivityRelaxesRoutineRate() {
        val active = TrackingCadencePolicy.requestFor(Tier.FREE, MotionState.MOVING, PowerState.NORMAL, guardianInactiveHours = 0)
        val inactive = TrackingCadencePolicy.requestFor(Tier.FREE, MotionState.MOVING, PowerState.NORMAL, guardianInactiveHours = 168)
        assertTrue(inactive.requestedIntervalMillis > active.requestedIntervalMillis)
        // Contract target: free routine moving at 168h inactivity = 20min.
        assertEquals(1_200_000L, inactive.requestedIntervalMillis)
    }
}
