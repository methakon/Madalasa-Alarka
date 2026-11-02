package org.madalasa.alarka.service

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** L09-001: child safety signal accessible; device receipt != guardian acknowledgement. */
class ChildSafetySignalTest {

    private val service = SyntheticChildSafetyService()

    @Test
    fun raisingSosStartsQueuedAndUnacknowledged() {
        val s = service.raise(SafetySignalKind.SOS, nowEpochMs = 1_000L)
        assertEquals(SafetySignalKind.SOS, s.kind)
        assertEquals(SignalSubmitState.QUEUED, s.submitState)
        assertFalse(s.isAcknowledgedByGuardian)
    }

    @Test
    fun submittedIsNotGuardianAcknowledged() {
        val submitted = service.markSubmitted(service.raise(SafetySignalKind.SOS, 1_000L))
        assertEquals(SignalSubmitState.SUBMITTED, submitted.submitState)
        // Handing to transport must never read as "a guardian saw it".
        assertFalse(submitted.isAcknowledgedByGuardian)
    }

    @Test
    fun guardianAckOnlyAppliedFromServerConfirmation() {
        val s = service.markSubmitted(service.raise(SafetySignalKind.SOS, 1_000L))
        val acked = service.applyGuardianAck(s, acknowledged = true)
        assertTrue(acked.isAcknowledgedByGuardian)
    }

    @Test
    fun allSafetyKindsAreAvailable() {
        SafetySignalKind.values().forEach { kind ->
            val s = service.raise(kind, 1_000L)
            assertEquals(kind, s.kind)
            assertFalse(s.isAcknowledgedByGuardian)
        }
    }

    @Test
    fun failedSubmissionIsNotAcknowledged() {
        val failed = service.markFailed(service.raise(SafetySignalKind.NEED_PICKUP, 1_000L))
        assertEquals(SignalSubmitState.FAILED, failed.submitState)
        assertFalse(failed.isAcknowledgedByGuardian)
    }
}
