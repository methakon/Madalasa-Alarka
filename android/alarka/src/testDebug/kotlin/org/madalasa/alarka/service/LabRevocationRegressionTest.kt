package org.madalasa.alarka.service

import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test
import java.io.File
import java.net.URL
import java.net.URLConnection
import java.net.URLStreamHandler
import javax.crypto.KeyGenerator
import javax.net.ssl.HttpsURLConnection

/** Exercises the real HTTPS status classification and stop routing without network or Android. */
class LabRevocationRegressionTest {
    companion object {
        private var response = 200
        init {
            URL.setURLStreamHandlerFactory { protocol ->
                if (protocol != "https") null else object : URLStreamHandler() {
                    override fun openConnection(url: URL): URLConnection = object : HttpsURLConnection(url) {
                        override fun connect() = Unit
                        override fun disconnect() = Unit
                        override fun usingProxy() = false
                        override fun getCipherSuite() = "fixture"
                        override fun getLocalCertificates(): Array<java.security.cert.Certificate>? = null
                        override fun getServerCertificates(): Array<java.security.cert.Certificate> = emptyArray()
                        override fun getResponseCode() = response
                    }
                }
            }
        }
    }

    private class Disk : LabQueueStorage {
        var bytes: ByteArray? = null
        override fun read() = bytes
        override fun write(bytes: ByteArray) { this.bytes = bytes }
    }
    private fun cipher() = LabQueueCipher(KeyGenerator.getInstance("AES").apply { init(256) }.generateKey())
    private fun gateway() = HttpsChildPrivacyGateway("https://example.invalid",
        { "00000000-0000-0000-0000-000000000001" }, { "synthetic-bearer" })

    @Test fun definitiveConsentHttpDenialsAreTypedNotGeneric() = runTest {
        for (status in listOf(401, 403, 404, 410)) {
            response = status
            val error = gateway().readConsentStatus().exceptionOrNull()
            assertTrue("HTTP $status must be a definitive denial, was $error",
                error is ChildAuthorizationDenied)
        }
    }

    @Test fun transientAndMalformedResponsesAreNotDenials() = runTest {
        for (status in listOf(429, 500, 503, 200)) {
            response = status // 200 without a valid body is malformed, not a revocation.
            val result = gateway().readConsentStatus()
            assertTrue("HTTP $status must fail", result.isFailure)
            assertFalse("HTTP $status must stay retryable", result.exceptionOrNull() is ChildAuthorizationDenied)
        }
    }

    @Test fun denialRevokesAndLaterSuccessCannotReplayOldRecords() {
        val disk = Disk(); val cipher = cipher()
        DurableLabQueue(disk, cipher, "device-a").enqueue("old", "old-fixture")
        assertEquals(LabStop.REVOKE, LabStopPolicy.forConsentFailure(ChildAuthorizationDenied()))
        // What the service performs on REVOKE:
        DurableLabQueue(disk, cipher, "device-a").halt()
        // Restart, then a later session is authorized again: nothing replayed.
        val later = DurableLabQueue(disk, cipher, "device-a")
        assertTrue(later.lease().isEmpty())
        assertThrows(IllegalStateException::class.java) { later.enqueue("new", "new-fixture") }
    }

    @Test fun transientFailurePausesWithoutDestroyingQueueOrOwner() {
        assertEquals(LabStop.PAUSE, LabStopPolicy.forConsentFailure(java.io.IOException("timeout")))
        assertEquals(LabStop.PAUSE, LabStopPolicy.forConsentFailure(IllegalStateException("HTTP 503")))
        val disk = Disk(); val cipher = cipher()
        val queue = DurableLabQueue(disk, cipher, "device-a")
        queue.enqueue("kept", "fixture")
        // PAUSE performs neither halt() nor session clear.
        assertEquals(listOf("kept"), DurableLabQueue(disk, cipher, "device-a").lease().map { it.id })
    }

    @Test fun providerDisabledPausesWhileAuthorityLossRevokes() {
        assertEquals(LabStop.PAUSE, LabStopPolicy.forOsState(true, true, true, providerEnabled = false))
        assertEquals(LabStop.CONTINUE, LabStopPolicy.forOsState(true, true, true, providerEnabled = true))
        assertEquals(LabStop.REVOKE, LabStopPolicy.forOsState(false, true, true, providerEnabled = true))
        assertEquals(LabStop.REVOKE, LabStopPolicy.forOsState(true, false, true, providerEnabled = true))
        assertEquals(LabStop.REVOKE, LabStopPolicy.forOsState(true, true, false, providerEnabled = true))
        assertEquals(LabStop.REVOKE, LabStopPolicy.forServerVerdict(false))
        assertEquals(LabStop.CONTINUE, LabStopPolicy.forServerVerdict(true))
    }

    @Test fun serviceRoutesThroughStopPolicyRatherThanBlanketRevocation() {
        val service = File("src/debug/kotlin/org/madalasa/alarka/service/LabLocationService.kt").readText()
        assertTrue(service.contains("LabStopPolicy.forConsentFailure("))
        assertTrue(service.contains("LabStopPolicy.forServerVerdict("))
        assertTrue(service.contains("LabStopPolicy.forOsState("))
        // GPS switched off must not clear the local session or halt the durable queue.
        assertTrue(service.contains("onProviderDisabled(provider: String) { finishLab(false) }"))
        assertFalse(service.contains("if (!osReady() || !eligible(consent)"))
        val gateway = File("src/main/kotlin/org/madalasa/alarka/service/ChildPrivacyGateway.kt").readText()
        assertTrue(gateway.contains("throw ChildAuthorizationDenied()"))
        assertTrue(gateway.contains("listOf(401, 403, 404, 410)"))
    }
}
