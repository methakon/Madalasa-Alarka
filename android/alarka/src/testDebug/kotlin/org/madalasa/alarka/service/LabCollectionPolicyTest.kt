package org.madalasa.alarka.service

import org.junit.Assert.*
import org.junit.Test

class LabCollectionPolicyTest {
    private val consent = ServerConsentStatus(true, true, false, false, false, true, true)
    @Test fun labOptInDoesNotSubstituteForAnyAuthorizationOrOsGrant() {
        assertTrue(LabCollectionPolicy.allowed(true, true, true, true, true, true, consent))
        for (missing in 0..5) {
            val flags = MutableList(6) { true }; flags[missing] = false
            assertFalse(LabCollectionPolicy.allowed(flags[0], flags[1], flags[2], flags[3], flags[4], flags[5], consent))
        }
        assertFalse(LabCollectionPolicy.allowed(true, true, true, true, true, true, null))
        for (blocked in listOf(consent.copy(coreConsent=false), consent.copy(locationConsent=false),
            consent.copy(childDeleted=true), consent.copy(collectionAuthorized=false),
            consent.copy(childServiceAdmitted=false))) {
            assertFalse(LabCollectionPolicy.allowed(true, true, true, true, true, true, blocked))
        }
    }
    @Test fun currentServerRawCommitAndLostReceiptRetryAreAcknowledged() {
        assertTrue(LabCollectionPolicy.isReceipt("a", "a", "RAW_OBSERVATIONS_COMMITTED", 1, 0, 0))
        assertTrue(LabCollectionPolicy.isReceipt("a", "a", "RAW_OBSERVATIONS_COMMITTED", 0, 0, 1))
        assertFalse(LabCollectionPolicy.isReceipt("a", "a", "RAW_OBSERVATIONS_COMMITTED", 1, 0, 1))
        assertFalse(LabCollectionPolicy.isReceipt("a", "a", "RAW_OBSERVATIONS_COMMITTED", 2, 0, -1))
    }
    @Test fun onlyMatchingCommittedSingleRecordReceiptCanAcknowledge() {
        assertTrue(LabCollectionPolicy.isReceipt("a", "a", "INBOX_COMMITTED", 1, 0))
        assertFalse(LabCollectionPolicy.isReceipt("a", "b", "INBOX_COMMITTED", 1, 0))
        assertFalse(LabCollectionPolicy.isReceipt("a", "a", "QUEUED", 1, 0))
        assertFalse(LabCollectionPolicy.isReceipt("a", "a", "INBOX_COMMITTED", 0, 0))
        assertFalse(LabCollectionPolicy.isReceipt("a", "a", "INBOX_COMMITTED", 1, 1))
    }
}
