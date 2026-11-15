package org.madalasa.alarka.service

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ChildMonitoringActivationPolicyTest {
    private val consent = ServerConsentStatus(
        coreConsent = true, locationConsent = true, usageConsent = false,
        mediaConsent = false, childDeleted = false, collectionAuthorized = true
    )
    private val fullyAllowed = VerifiedChildActivationFacts(
        devicePairingVerified = true, credentialFresh = true, childServiceAdmitted = true,
        serverConsent = consent, androidLocationPermissionGranted = true,
        visibleOngoingNotificationReady = true, platformAndLegalLocationGateApproved = true
    )

    @Test fun installedButUnpairedNeverActivatesEvenIfEverythingElseIsTrue() {
        val facts = fullyAllowed.copy(devicePairingVerified = false)
        assertEquals(ChildActivationState.UNPAIRED, ChildMonitoringActivationPolicy.evaluate(facts))
        assertFalse(ChildMonitoringActivationPolicy.mayCollectLocation(facts))
    }

    @Test fun slotLimitBlocksEvenValidParentPairing() {
        val facts = fullyAllowed.copy(childServiceAdmitted = false)
        assertEquals(ChildActivationState.WAITING_FOR_CHILD_SLOT, ChildMonitoringActivationPolicy.evaluate(facts))
        assertFalse(ChildMonitoringActivationPolicy.mayCollectLocation(facts))
    }

    @Test fun offlineExpiredAndRevokedPermissionStatesFailClosed() {
        val variants = listOf(
            fullyAllowed.copy(credentialFresh=false),
            fullyAllowed.copy(serverConsent=null),
            fullyAllowed.copy(serverConsent=consent.copy(childDeleted=true)),
            fullyAllowed.copy(serverConsent=consent.copy(collectionAuthorized=false)),
            fullyAllowed.copy(serverConsent=consent.copy(locationConsent=false)),
            fullyAllowed.copy(androidLocationPermissionGranted=false),
            fullyAllowed.copy(visibleOngoingNotificationReady=false),
            fullyAllowed.copy(platformAndLegalLocationGateApproved=false)
        )
        for (fact in variants) assertFalse(ChildMonitoringActivationPolicy.mayCollectLocation(fact))
    }

    @Test fun canActivateOnlyWithAllIndependentGates() {
        assertTrue(ChildMonitoringActivationPolicy.mayCollectLocation(fullyAllowed))
    }

    @Test fun realCurrentBackendResponseIsNotAnActivationGrant() {
        assertFalse(ChildMonitoringActivationPolicy.mayCollectLocation(
            fullyAllowed.copy(serverConsent=consent.copy(collectionAuthorized=false))
        ))
    }
}
