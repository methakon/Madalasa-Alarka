package org.madalasa.madalasa.ui.figma

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** P-02 contract and negative states, independent of credentials and live sessions. */
class P02SignInScreenTest {
    @Test fun bothAndroidCredentialManagerAndTrustedExchangeAreRequired() {
        assertFalse(canStartGoogleSignIn(false, false))
        assertFalse(canStartGoogleSignIn(true, false))
        assertFalse(canStartGoogleSignIn(false, true))
        assertTrue(canStartGoogleSignIn(true, true))
    }

    @Test fun cancelOfflineAndExpiryNeverClaimSuccessfulAuthentication() {
        for (issue in SignInIssue.entries) {
            val message = signInStateDescription(issue)
            assertTrue(message.isNotBlank())
            assertFalse(message.contains("Sign-in successful"))
        }
        assertTrue(signInStateDescription(SignInIssue.CANCELLED).contains("No session"))
        assertTrue(signInStateDescription(SignInIssue.OFFLINE).contains("connectivity"))
        assertTrue(signInStateDescription(SignInIssue.TOKEN_EXPIRED).contains("expired"))
    }
}
