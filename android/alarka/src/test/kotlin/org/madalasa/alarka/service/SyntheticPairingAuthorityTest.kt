package org.madalasa.alarka.service

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Negative/fault coverage for synthetic pairing policy.
 * Backs Phase-05 L05-002 (expiry, wrong-family, replay),
 * L05-003 (copied device token rejected) and
 * L05-004 (device proof + monotonic config revisions).
 */
class SyntheticPairingAuthorityTest {

    private var clockValue: Long = 0L

    private fun newAuthority(ttl: Long = 1000L, family: String = "fam-A"): SyntheticPairingAuthority {
        clockValue = 0L
        return SyntheticPairingAuthority(familyId = family, ttlMillis = ttl, clock = { clockValue })
    }

    // ---- L05-002: time-limited, wrong-family, replay ----

    @Test
    fun validChallengeRedeemsOnce() {
        val auth = newAuthority()
        val c = auth.issueChallenge()
        val token = auth.redeem(c.code, c.familyId, c.nonce, deviceKeyId = "key-1")
        assertEquals("key-1", token.deviceKeyId)
        assertEquals("fam-A", token.familyId)
    }

    @Test
    fun expiredChallengeIsRejected() {
        val auth = newAuthority(ttl = 1000L)
        val c = auth.issueChallenge()
        clockValue = c.expiresAtMillis() // reached expiry boundary
        val ex = assertThrows(PairingException::class.java) {
            auth.redeem(c.code, c.familyId, c.nonce, "key-1")
        }
        assertEquals(PairingRejection.EXPIRED, ex.rejection)
    }

    @Test
    fun wrongFamilyIsRejected() {
        val auth = newAuthority(family = "fam-A")
        val c = auth.issueChallenge()
        val ex = assertThrows(PairingException::class.java) {
            auth.redeem(c.code, "fam-OTHER", c.nonce, "key-1")
        }
        assertEquals(PairingRejection.WRONG_FAMILY, ex.rejection)
    }

    @Test
    fun replayedChallengeIsRejected() {
        val auth = newAuthority()
        val c = auth.issueChallenge()
        auth.redeem(c.code, c.familyId, c.nonce, "key-1")
        val ex = assertThrows(PairingException::class.java) {
            auth.redeem(c.code, c.familyId, c.nonce, "key-1")
        }
        assertEquals(PairingRejection.REPLAYED, ex.rejection)
    }

    // ---- L05-003: copied device token rejected (synthetic Keystore PoP) ----

    @Test
    fun tokenCopiedToAnotherDeviceIsRejected() {
        val auth = newAuthority()
        val c = auth.issueChallenge()
        val token = auth.redeem(c.code, c.familyId, c.nonce, deviceKeyId = "key-original")
        // Same token value presented by a different device key must fail.
        val ex = assertThrows(PairingException::class.java) {
            SyntheticPairingAuthority.verifyDeviceBinding(token, presentingDeviceKeyId = "key-attacker")
        }
        assertEquals(PairingRejection.DEVICE_KEY_MISMATCH, ex.rejection)
    }

    @Test
    fun tokenOnOwningDeviceIsAccepted() {
        val auth = newAuthority()
        val c = auth.issueChallenge()
        val token = auth.redeem(c.code, c.familyId, c.nonce, deviceKeyId = "key-original")
        SyntheticPairingAuthority.verifyDeviceBinding(token, presentingDeviceKeyId = "key-original")
    }

    // ---- L05-004: device proof + monotonic config revisions ----

    @Test
    fun revisionsAreMonotonicAcrossIssuance() {
        val auth = newAuthority()
        val first = auth.issueChallenge().configRevision
        val second = auth.issueChallenge().configRevision
        assertTrue(second > first)
        assertNotEquals(first, second)
    }

    @Test
    fun staleConfigRevisionIsRejected() {
        val ex = assertThrows(PairingException::class.java) {
            SyntheticPairingAuthority.requireMonotonicRevision(appliedRevision = 5, incomingRevision = 5)
        }
        assertEquals(PairingRejection.STALE_CONFIG_REVISION, ex.rejection)
    }

    @Test
    fun newerConfigRevisionIsAccepted() {
        SyntheticPairingAuthority.requireMonotonicRevision(appliedRevision = 5, incomingRevision = 6)
    }
}
