package org.madalasa.madalasa.api

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Network is never contacted: all tests fail before opening a TLS connection. */
class HttpsMadalasaApiClientTest {
    private val child = "11111111-1111-1111-1111-111111111111"

    @Test fun refusesHttpUserInfoAndInjectedPaths() {
        for (origin in listOf(
            "http://example.invalid", "https://user:pass@example.invalid",
            "https://example.invalid/v1", "https://example.invalid?x=1",
            "https://example.invalid/#fragment"
        )) {
            assertTrue(runCatching {
                HttpsMadalasaApiClient(origin, { null }, { null })
            }.isFailure)
        }
        assertTrue(runCatching {
            HttpsMadalasaApiClient("https://example.invalid", { null }, { null })
        }.isSuccess)
    }

    @Test fun neverMakesUnauthenticatedRequestsOrReturnsInventedLocation() = runTest {
        val client = HttpsMadalasaApiClient("https://example.invalid", { null }, { null })
        assertTrue(client.getMe().isFailure)
        assertTrue(client.getChildren(child).isFailure)
        assertTrue(client.getChildLocation(child).isFailure)
        assertTrue(client.createPairingCode(child).isFailure)
    }

    @Test fun failsIfActorIdIsMissingEvenWithBearer() = runTest {
        val client = HttpsMadalasaApiClient(
            "https://example.invalid", { "a".repeat(64) }, { null }
        )
        assertTrue(client.getMe().isFailure)
    }

    @Test fun unconfiguredProductionClientNeverClaimsSuccess() = runTest {
        val client = UnavailableMadalasaApiClient()
        assertFalse(client.getMe().isSuccess)
        assertFalse(client.getChildren(child).isSuccess)
        assertFalse(client.getChildLocation(child).isSuccess)
        assertFalse(client.createPairingCode(child).isSuccess)
    }
}
