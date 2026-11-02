package org.madalasa.madalasa.api

import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class GoogleParentHandoffTest {
    private val validClientId = "1234567890-synthetic.apps.googleusercontent.com"
    private val goodOrigin = "https://parent.example.invalid"

    @Test fun configurationRejectsHttpCredentialsAndUrlTricks() {
        assertTrue(GoogleParentConfiguration(validClientId, goodOrigin).isConfigured())
        assertFalse(GoogleParentConfiguration("", goodOrigin).isConfigured())
        assertFalse(GoogleParentConfiguration(validClientId, "").isConfigured())
        assertFalse(GoogleParentConfiguration(validClientId, "http://parent.example.invalid").isConfigured())
        assertFalse(GoogleParentConfiguration(validClientId, "https://user@parent.example.invalid").isConfigured())
        assertFalse(GoogleParentConfiguration(validClientId, "https://parent.example.invalid/?token=x").isConfigured())
        assertFalse(GoogleParentConfiguration(validClientId, "https://parent.example.invalid/redirect").isConfigured())
        assertFalse(GoogleParentConfiguration("not-a-google-client", goodOrigin).isConfigured())
        assertEquals(goodOrigin, GoogleParentConfiguration(validClientId, goodOrigin + "/").normalizedOrigin())
    }

    @Test fun memoryDoesNotAcceptMalformedOrExpiredSessions() {
        val store = ParentSessionMemory()
        assertNull(store.currentToken())
        val token = "a".repeat(64)
        val actor = "00000000-0000-4000-8000-000000000001"
        assertFalse(store.accept(VerifiedParentSession(token, Instant.EPOCH, actor)))
        assertNull(store.currentToken())
        assertFalse(store.accept(VerifiedParentSession("bad", Instant.now().plusSeconds(60), actor)))
        assertNull(store.currentToken())
        assertFalse(store.accept(VerifiedParentSession(token, Instant.now().plusSeconds(60), "fake")))
        assertNull(store.currentToken())
    }

    @Test fun acceptedVerifiedSessionCanBeCleared() {
        val store = ParentSessionMemory()
        val token = "b".repeat(64)
        val session = VerifiedParentSession(token, Instant.now().plusSeconds(3600),
            "00000000-0000-4000-8000-000000000001")
        assertTrue(store.accept(session))
        assertEquals(token, store.currentToken())
        store.clear()
        assertNull(store.currentToken())
    }

    @Test fun allFailurePathsExplainNoUnverifiedAuthority() {
        GoogleHandoffFailure.entries.forEach { reason ->
            val message = googleHandoffMessage(reason)
            assertTrue(message.isNotBlank())
            assertFalse(message.contains("Sign-in successful"))
        }
        assertTrue(googleHandoffMessage(GoogleHandoffFailure.CANCELLED).contains("No parent session"))
        assertTrue(googleHandoffMessage(GoogleHandoffFailure.SERVER_REJECTED).contains("No guardian"))
    }
}
