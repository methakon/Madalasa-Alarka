package org.madalasa.alarka.service

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertTrue
import org.junit.Test

class ChildPrivacyGatewayTest {
    @Test fun noEnrolledDeviceDoesNotInventConsent() = runTest {
        val source = UnauthenticatedChildPrivacyGateway()
        assertTrue(source.readConsentStatus().isFailure)
    }

    @Test fun originMustNotCarryCredentialsPathOrQuery() {
        for (origin in listOf("https://user@example.invalid", "https://example.invalid/path",
            "https://example.invalid?token=x", "https://example.invalid#fragment", "https:///")) {
            assertTrue(origin, runCatching { HttpsChildPrivacyGateway(origin, { null }, { null }) }.isFailure)
        }
    }

    @Test fun insecureTransportIsRejected() {
        val candidate = runCatching {
            HttpsChildPrivacyGateway("http://example.invalid", { null }, { null })
        }
        assertTrue(candidate.isFailure)
    }

    @Test fun noDeviceCredentialsFailsBeforeNetwork() = runTest {
        val source = HttpsChildPrivacyGateway("https://example.invalid", { null }, { null })
        val result = source.readConsentStatus()
        assertTrue(result.isFailure)
        assertTrue(result.exceptionOrNull()?.message.orEmpty().contains("device ID"))
    }
}
