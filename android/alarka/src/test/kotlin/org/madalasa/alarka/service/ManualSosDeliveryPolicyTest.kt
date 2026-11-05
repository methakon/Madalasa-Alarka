package org.madalasa.alarka.service

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ManualSosDeliveryPolicyTest {
    private val event = "test-sos-event"
    private fun apply(
        s: ManualSosState,
        evidence: ManualSosEvidence,
        verified: Boolean = false,
        id: String = event
    ) = ManualSosDeliveryPolicy.apply(s, id, evidence, verified)

    @Test fun localSosNeverImpliesDeliveryOrHumanAcknowledgement() {
        val queued = ManualSosState(event)
        assertEquals(ManualSosStage.LOCAL_QUEUED, queued.stage)
        assertFalse(queued.guardianHasAcknowledged)
        val sending = apply(queued, ManualSosEvidence.RETRY_ATTEMPT)
        assertEquals(ManualSosStage.SENDING, sending.stage)
        assertFalse(sending.guardianHasAcknowledged)
        assertEquals(sending, apply(sending, ManualSosEvidence.SERVER_ACCEPTED))
        assertEquals(sending, apply(sending, ManualSosEvidence.GUARDIAN_ACKNOWLEDGED, true))
    }

    @Test fun onlyAuthenticatedEventScopedReceiptsAdvanceAllDistinctStages() {
        val start = apply(ManualSosState(event), ManualSosEvidence.RETRY_ATTEMPT)
        val accepted = apply(start, ManualSosEvidence.SERVER_ACCEPTED, true)
        assertEquals(ManualSosStage.SERVER_ACCEPTED, accepted.stage)
        assertFalse(accepted.guardianHasAcknowledged)
        val delivered = apply(accepted, ManualSosEvidence.NOTIFICATION_DELIVERED, true)
        assertEquals(ManualSosStage.NOTIFICATION_DELIVERED, delivered.stage)
        assertFalse(delivered.guardianHasAcknowledged)
        val acknowledged = apply(delivered, ManualSosEvidence.GUARDIAN_ACKNOWLEDGED, true)
        assertTrue(acknowledged.guardianHasAcknowledged)
        assertEquals(acknowledged, apply(acknowledged, ManualSosEvidence.TRANSIENT_FAILURE))
    }

    @Test fun wrongEventAndOutOfOrderReceiptsNeverAdvance() {
        val queued = ManualSosState(event)
        assertEquals(queued, apply(queued, ManualSosEvidence.SERVER_ACCEPTED, true, "other-event"))
        assertEquals(queued, apply(queued, ManualSosEvidence.SERVER_ACCEPTED, true, ""))
        assertEquals(queued, apply(queued, ManualSosEvidence.NOTIFICATION_DELIVERED, true))
        assertEquals(queued, apply(queued, ManualSosEvidence.GUARDIAN_ACKNOWLEDGED, true))
        val accepted = apply(queued, ManualSosEvidence.SERVER_ACCEPTED, true)
        assertEquals(accepted, apply(accepted, ManualSosEvidence.GUARDIAN_ACKNOWLEDGED, true))
        assertEquals(accepted, apply(accepted, ManualSosEvidence.NOTIFICATION_DELIVERED))
    }

    @Test fun offlineFailureRetriesButDoesNotPretendServerAccepted() {
        val queued = ManualSosState(event)
        val failed = apply(queued, ManualSosEvidence.TRANSIENT_FAILURE)
        assertEquals(ManualSosStage.DELIVERY_FAILED, failed.stage)
        assertFalse(failed.guardianHasAcknowledged)
        val retry = apply(failed, ManualSosEvidence.RETRY_ATTEMPT)
        assertEquals(ManualSosStage.SENDING, retry.stage)
    }

    @Test fun explicitRevocationIsTerminalEvenAfterLateReceipts() {
        val accepted = apply(ManualSosState(event), ManualSosEvidence.SERVER_ACCEPTED, true)
        val revoked = apply(accepted, ManualSosEvidence.AUTHORIZATION_REVOKED)
        assertTrue(revoked.revoked)
        assertFalse(revoked.guardianHasAcknowledged)
        for (e in ManualSosEvidence.values()) {
            assertEquals(revoked, apply(revoked, e, true))
        }
    }

    @Test fun staleOrMissingStatusIsNotSyntheticRevocation() {
        // There is intentionally no missing/stale status 'evidence' value.
        // Only a definitive authorization response may trigger terminal revoke.
        val sending = apply(ManualSosState(event), ManualSosEvidence.RETRY_ATTEMPT)
        val offline = apply(sending, ManualSosEvidence.TRANSIENT_FAILURE)
        assertFalse(offline.revoked)
        assertEquals(ManualSosStage.DELIVERY_FAILED, offline.stage)
    }
}
