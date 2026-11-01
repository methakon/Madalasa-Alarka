package org.madalasa.madalasa.api

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PrivacyGatewayTest {
    @Test fun unauthenticatedGatewayNeverInventsSuccessfulGrantConsentOrRevocation() = runTest {
        val gateway = UnauthenticatedPrivacyGateway()
        val child = "11111111-1111-1111-1111-111111111111"
        assertTrue(gateway.guardianGrants(child).isFailure)
        assertTrue(gateway.childConsents(child).isFailure)
        assertTrue(gateway.revokeGuardianGrant(child, child).isFailure)
    }

    @Test fun realGatewayRejectsInsecureHttpAndAcceptsHttpsConstructor() {
        val failed = runCatching { HttpsPrivacyGateway("http://example.invalid", { null }) }
        assertTrue(failed.isFailure)
        val gateway = HttpsPrivacyGateway("https://example.invalid", { null })
        assertFalse(gateway is UnauthenticatedPrivacyGateway)
    }

    @Test fun noSessionFailsBeforeAnyOutboundNetworkRequest() = runTest {
        val gateway = HttpsPrivacyGateway("https://example.invalid", { null })
        val failure = gateway.guardianGrants("00000000-0000-0000-0000-000000000001")
        assertTrue(failure.isFailure)
        assertTrue(failure.exceptionOrNull()?.message.orEmpty().contains("sign in"))
    }
}
