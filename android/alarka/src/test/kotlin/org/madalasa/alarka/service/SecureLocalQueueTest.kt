package org.madalasa.alarka.service

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.madalasa.alarka.domain.LocationObservation
import org.junit.Test

/**
 * L05-010: no plaintext child GPS at rest (backups/logcat).
 * L05-012: guardian revoke / local stop halts uploads; status + uninstall guidance.
 */
class SecureLocalQueueTest {

    private fun obs(lat: Int = 12_971_598, lon: Int = 77_594_562) = LocationObservation(
        eventId = "evt-1",
        observedAtEpochMs = 1_730_000_000_000L,
        latitudeE6 = lat,
        longitudeE6 = lon,
        accuracyMeters = 5.0f,
        speedMetersPerSecond = 1.2f,
        sourceDeviceId = "synthetic-device-1"
    )

    // ---- L05-010 ----

    @Test
    fun atRestFormContainsNoPlaintextCoordinates() {
        val q = SecureLocalQueue()
        q.enqueue(obs())
        val atRest = q.atRestSnapshot().joinToString("\n")
        // The raw coordinate values must not be recoverable from the sealed form.
        assertFalse(atRest.contains("12971598"))
        assertFalse(atRest.contains("77594562"))
        assertFalse(atRest.contains("synthetic-device-1"))
    }

    @Test
    fun sealedEntryRoundTripsBackToOriginalOnFlush() {
        val q = SecureLocalQueue()
        val original = obs()
        q.enqueue(original)
        val flushed = q.flush()
        assertEquals(1, flushed.size)
        assertEquals(original, flushed.first())
        assertEquals(0, q.pendingCount())
    }

    // ---- L05-012 ----

    @Test
    fun guardianRevokeHaltsUploadsAndDropsPending() {
        val q = SecureLocalQueue()
        q.enqueue(obs())
        q.haltOnRevoke()
        assertFalse(q.isActive)
        assertEquals(QueueState.HALTED_REVOKED, q.state)
        assertEquals(0, q.pendingCount())
        assertTrue(q.flush().isEmpty())
        val ex = assertThrows(IllegalStateException::class.java) { q.enqueue(obs()) }
        assertTrue(ex.message!!.contains("halted"))
    }

    @Test
    fun localStopHaltsUploads() {
        val q = SecureLocalQueue()
        q.enqueue(obs())
        q.haltOnStop()
        assertEquals(QueueState.HALTED_STOPPED, q.state)
        assertThrows(IllegalStateException::class.java) { q.enqueue(obs()) }
    }

    @Test
    fun revokeStatusCarriesUninstallGuidance() {
        val status = EnrollmentStatus.forHaltedRevoke()
        assertFalse(status.enrolled)
        assertEquals(QueueState.HALTED_REVOKED, status.queueState)
        assertTrue(status.guidance.contains("uninstall", ignoreCase = true))
        assertTrue(status.guidance.contains("No data is being sent"))
    }
}
