package org.madalasa.alarka.service

/**
 * Synthetic, local-only pairing authority used by the Alarka child build.
 *
 * This is NOT production enrollment crypto. It exists so the Phase-05 acceptance
 * criteria (time-limited codes, wrong-family rejection, replay protection,
 * device-key binding and monotonic config revisions) can be exercised with
 * deterministic negative/fault tests against synthetic fixtures only.
 *
 * SOLID: this type owns pairing-challenge policy so that [AlarkaEnrollmentService]
 * implementations can delegate to it without re-implementing the rules.
 */

/** Reasons a synthetic pairing attempt is refused. Surfaced truthfully to the UI. */
enum class PairingRejection {
    EXPIRED,
    WRONG_FAMILY,
    REPLAYED,
    UNKNOWN_CODE,
    DEVICE_KEY_MISMATCH,
    STALE_CONFIG_REVISION
}

class PairingException(val rejection: PairingRejection, message: String) : Exception(message)

/** A single-use, time-limited, family-scoped pairing challenge. */
data class PairingChallenge(
    val code: String,
    val familyId: String,
    val nonce: String,
    val issuedAtMillis: Long,
    val ttlMillis: Long,
    /** Monotonic configuration revision this challenge was minted against. */
    val configRevision: Long
) {
    fun expiresAtMillis(): Long = issuedAtMillis + ttlMillis
    fun isExpiredAt(nowMillis: Long): Boolean = nowMillis >= expiresAtMillis()
}

/**
 * A synthetic device-bound proof-of-possession token.
 *
 * The [deviceKeyId] stands in for an Android Keystore key alias/attestation.
 * A token minted for one device key is rejected when replayed against a
 * different device key, which is the synthetic analogue of a copied-token attack.
 */
data class DeviceBoundToken(
    val value: String,
    val deviceKeyId: String,
    val familyId: String
)

class SyntheticPairingAuthority(
    private val familyId: String = "family-synthetic-alpha",
    private val ttlMillis: Long = 5 * 60 * 1000L,
    private val clock: () -> Long = { 0L }
) {
    private var revisionCounter: Long = 0L
    private var active: PairingChallenge? = null
    private val consumedNonces = mutableSetOf<String>()

    /** Issue a fresh, single-use challenge bound to this synthetic family. */
    fun issueChallenge(): PairingChallenge {
        val now = clock()
        revisionCounter += 1
        val nonce = "nonce-$revisionCounter-${now}"
        val code = syntheticCodeFor(revisionCounter)
        val challenge = PairingChallenge(
            code = code,
            familyId = familyId,
            nonce = nonce,
            issuedAtMillis = now,
            ttlMillis = ttlMillis,
            configRevision = revisionCounter
        )
        active = challenge
        return challenge
    }

    /**
     * Redeem a challenge. Enforces expiry, family scope and single-use (replay)
     * semantics. Returns a device-bound token on success.
     */
    fun redeem(
        code: String,
        familyId: String,
        nonce: String,
        deviceKeyId: String
    ): DeviceBoundToken {
        // Replay is detected independently of the active challenge: a nonce that was
        // already consumed must be rejected even after the challenge is cleared.
        if (consumedNonces.contains(nonce)) {
            throw PairingException(PairingRejection.REPLAYED, "Pairing challenge already used")
        }

        val challenge = active
            ?: throw PairingException(PairingRejection.UNKNOWN_CODE, "No active pairing challenge")

        if (challenge.isExpiredAt(clock())) {
            throw PairingException(PairingRejection.EXPIRED, "Pairing code has expired")
        }
        if (familyId != challenge.familyId) {
            throw PairingException(PairingRejection.WRONG_FAMILY, "Pairing code belongs to a different family")
        }
        if (code.replace("-", "").trim() != challenge.code.replace("-", "").trim()) {
            throw PairingException(PairingRejection.UNKNOWN_CODE, "Pairing code not recognised")
        }
        if (nonce != challenge.nonce) {
            throw PairingException(PairingRejection.REPLAYED, "Pairing challenge already used")
        }

        consumedNonces.add(nonce)
        active = null
        return DeviceBoundToken(
            value = "synthetic-pop-${deviceKeyId}-rev${challenge.configRevision}",
            deviceKeyId = deviceKeyId,
            familyId = challenge.familyId
        )
    }

    /** The current monotonic configuration revision. */
    fun currentRevision(): Long = revisionCounter

    private fun syntheticCodeFor(revision: Long): String {
        // Deterministic but revision-varying synthetic code (never a real secret).
        val n = (482_000 + (revision * 37) % 1000).toString().padStart(6, '0')
        return "${n.substring(0, 3)}-${n.substring(3)}"
    }

    companion object {
        /**
         * Validate a device-bound token against the key presenting it. A token minted
         * for another device key (a copied token) is rejected. Synthetic analogue of
         * Android Keystore proof-of-possession.
         */
        fun verifyDeviceBinding(token: DeviceBoundToken, presentingDeviceKeyId: String) {
            if (token.deviceKeyId != presentingDeviceKeyId) {
                throw PairingException(
                    PairingRejection.DEVICE_KEY_MISMATCH,
                    "Token was issued for a different device key"
                )
            }
        }

        /**
         * Enforce monotonic config revisions: a device must never accept a server
         * config whose revision is older than or equal to what it already applied.
         */
        fun requireMonotonicRevision(appliedRevision: Long, incomingRevision: Long) {
            if (incomingRevision <= appliedRevision) {
                throw PairingException(
                    PairingRejection.STALE_CONFIG_REVISION,
                    "Incoming config revision $incomingRevision is not newer than $appliedRevision"
                )
            }
        }
    }
}
