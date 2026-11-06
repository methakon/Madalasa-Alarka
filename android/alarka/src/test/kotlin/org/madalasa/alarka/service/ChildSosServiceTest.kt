package org.madalasa.alarka.service

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException

class InMemorySosOutbox : PersistentSosOutbox {
    private var pending: PersistedSosEvent? = null

    override fun savePending(state: ManualSosState, observedAt: String) {
        pending = PersistedSosEvent(state.eventId, observedAt, state.stage, state.revoked)
    }

    override fun updateStage(state: ManualSosState) {
        val cur = pending ?: return
        if (cur.eventId == state.eventId) {
            pending = cur.copy(stage = state.stage, revoked = state.revoked)
        }
    }

    override fun readPending(): PersistedSosEvent? = pending

    override fun clearPending(eventId: String) {
        if (pending?.eventId == eventId) {
            pending = null
        }
    }
}

@OptIn(ExperimentalCoroutinesApi::class)
class ChildSosServiceTest {

    private val testDispatcher = StandardTestDispatcher()
    private val testScope = TestScope(testDispatcher)

    @Test
    fun outboxSavesAndRestoresPendingEventAcrossRestart() {
        val outbox = InMemorySosOutbox()
        val eventId = "3fa85f64-5717-4562-b3fc-2c963f66afa6"
        val state = ManualSosState(eventId = eventId, stage = ManualSosStage.LOCAL_QUEUED)
        outbox.savePending(state, "2026-11-06T00:00:00Z")

        val restored = outbox.readPending()
        assertNotNull(restored)
        assertEquals(eventId, restored?.eventId)
        assertEquals(ManualSosStage.LOCAL_QUEUED, restored?.stage)
        assertFalse(restored?.revoked ?: true)

        // Confirmation-based deletion
        outbox.clearPending("different-id")
        assertNotNull(outbox.readPending())

        outbox.clearPending(eventId)
        assertNull(outbox.readPending())
    }

    @Test
    fun unauthenticatedDeviceFailsClosedWithoutGeneratingFakeClaims() = runTest(testDispatcher) {
        val outbox = InMemorySosOutbox()
        val service = HttpsChildSosService(
            origin = "https://127.0.0.1:8443",
            deviceIdProvider = { null },
            credentialProvider = { null },
            outbox = outbox,
            coroutineScope = testScope,
            ioDispatcher = testDispatcher
        )

        val result = service.triggerSos()
        assertTrue(result.isFailure)
        val state = service.sosState.value
        assertNotNull(state)
        assertEquals(ManualSosStage.DELIVERY_FAILED, state?.stage)
        assertFalse(state?.guardianHasAcknowledged ?: true)
    }

    @Test
    fun restartRestoresPendingEventFromOutbox() = runTest(testDispatcher) {
        val outbox = InMemorySosOutbox()
        val eventId = "e87e1a39-9f44-42b7-8ce2-472a5a2283a0"
        val pendingState = ManualSosState(eventId = eventId, stage = ManualSosStage.DELIVERY_FAILED)
        outbox.savePending(pendingState, "2026-11-06T00:00:00Z")

        val service = HttpsChildSosService(
            origin = "https://127.0.0.1:8443",
            deviceIdProvider = { "c0a80101-0000-0000-0000-000000000001" },
            credentialProvider = { "test_credential_token" },
            outbox = outbox,
            coroutineScope = testScope,
            ioDispatcher = testDispatcher
        )

        assertEquals(eventId, service.sosState.value?.eventId)
        assertEquals(ManualSosStage.DELIVERY_FAILED, service.sosState.value?.stage)
    }

    @Test
    fun exactEventRetryPreservesEventId() = runTest(testDispatcher) {
        val outbox = InMemorySosOutbox()
        val eventId = "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d"
        outbox.savePending(ManualSosState(eventId = eventId, stage = ManualSosStage.DELIVERY_FAILED), "2026-11-06T00:00:00Z")

        val service = HttpsChildSosService(
            origin = "https://127.0.0.1:8443",
            deviceIdProvider = { "c0a80101-0000-0000-0000-000000000001" },
            credentialProvider = { "test_credential_token" },
            outbox = outbox,
            coroutineScope = testScope,
            ioDispatcher = testDispatcher
        )

        // Triggering again or retrying must reuse the exact same eventId
        val res = service.retryPendingSos()
        // Will fail because network host is not running in pure unit test, but eventId must be preserved
        assertTrue(res.isFailure)
        assertEquals(eventId, service.sosState.value?.eventId)
        assertEquals(ManualSosStage.DELIVERY_FAILED, service.sosState.value?.stage)
    }

    @Test
    fun syntheticServiceClearlySeparatesSimulation() = runTest(testDispatcher) {
        val synth = SyntheticChildSosService()
        assertTrue(synth.isSynthetic)
        assertNull(synth.sosState.value)

        synth.triggerSos()
        val afterTrigger = synth.sosState.value
        assertNotNull(afterTrigger)
        assertEquals(ManualSosStage.NOTIFICATION_DELIVERED, afterTrigger?.stage)
        assertFalse(afterTrigger?.guardianHasAcknowledged ?: true)

        synth.acknowledgeSimulatedSos()
        assertTrue(synth.sosState.value?.guardianHasAcknowledged ?: false)
    }

    @Test
    fun rejectedDurableWriteDoesNotDisplayQueuedOrAttemptNetwork() = runTest(testDispatcher) {
        val outbox = object : PersistentSosOutbox {
            override fun savePending(state: ManualSosState, observedAt: String) {
                throw IOException("Cannot persist SOS")
            }
            override fun updateStage(state: ManualSosState) = Unit
            override fun readPending(): PersistedSosEvent? = null
            override fun clearPending(eventId: String) = Unit
        }
        val service = HttpsChildSosService(
            origin = "https://127.0.0.1:8443",
            deviceIdProvider = { "c0a80101-0000-0000-0000-000000000001" },
            credentialProvider = { "test_token" },
            outbox = outbox,
            coroutineScope = testScope,
            ioDispatcher = testDispatcher
        )
        assertTrue(service.triggerSos().isFailure)
        assertNull(service.sosState.value)
    }

    @Test
    fun offlineFailedSosCannotBeResetBeforeGuardianAcknowledges() = runTest(testDispatcher) {
        val outbox = InMemorySosOutbox()
        val eventId = "e87e1a39-9f44-42b7-8ce2-472a5a2283a0"
        outbox.savePending(
            ManualSosState(eventId = eventId, stage = ManualSosStage.DELIVERY_FAILED),
            "2026-11-06T00:00:00Z"
        )
        val service = HttpsChildSosService(
            origin = "https://127.0.0.1:8443",
            deviceIdProvider = { null },
            credentialProvider = { null },
            outbox = outbox,
            coroutineScope = testScope,
            ioDispatcher = testDispatcher
        )
        service.resetSos()
        assertEquals(eventId, outbox.readPending()?.eventId)
        assertEquals(eventId, service.sosState.value?.eventId)
    }

}
