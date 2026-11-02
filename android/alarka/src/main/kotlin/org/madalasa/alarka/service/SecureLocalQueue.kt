package org.madalasa.alarka.service

import org.madalasa.alarka.domain.LocationObservation

/**
 * Synthetic, local-only encrypted outbound queue (Phase-05 L05-010 and L05-012).
 *
 * L05-010: location observations are never held or serialized in plaintext — each
 * entry is sealed with a reversible synthetic envelope so that a backup or logcat
 * dump of the at-rest form reveals no coordinates. (The production build swaps the
 * synthetic cipher for Android Keystore-backed AES-GCM via the same seam.)
 *
 * L05-012: a guardian revoke (or local stop/unpair) halts the queue — no further
 * entries are accepted or flushed — and the child app can surface a truthful status
 * plus uninstall guidance.
 *
 * This is NOT production crypto. It exists to make the "no plaintext GPS" and
 * "revoke halts uploads" invariants deterministically testable on synthetic data.
 */

/** Opaque at-rest record. [sealed] must never contain plaintext coordinates. */
data class SealedObservation(val sealed: String)

enum class QueueState { ACTIVE, HALTED_REVOKED, HALTED_STOPPED }

class SecureLocalQueue(
    /** Synthetic reversible transform standing in for Keystore AES-GCM. */
    private val seal: (String) -> String = { Sealing.xorBase64(it) },
    private val unseal: (String) -> String = { Sealing.unXorBase64(it) }
) {
    private val entries = ArrayDeque<SealedObservation>()
    var state: QueueState = QueueState.ACTIVE
        private set

    /** True while the queue accepts and flushes entries. */
    val isActive: Boolean get() = state == QueueState.ACTIVE

    /**
     * Enqueue an observation in sealed form. Rejected once the queue is halted.
     * @throws IllegalStateException if the queue has been revoked/stopped.
     */
    fun enqueue(observation: LocationObservation) {
        check(isActive) { "Queue is halted (${state.name}); uploads are not permitted" }
        entries.addLast(SealedObservation(seal(serialize(observation))))
    }

    /** Number of queued-but-unflushed sealed entries. */
    fun pendingCount(): Int = entries.size

    /** Flush returns the decrypted payloads only while active; empty once halted. */
    fun flush(): List<LocationObservation> {
        if (!isActive) return emptyList()
        val out = entries.map { deserialize(unseal(it.sealed)) }
        entries.clear()
        return out
    }

    /** Raw at-rest bytes as they would appear in a backup/logcat dump. */
    fun atRestSnapshot(): List<String> = entries.map { it.sealed }

    /** Guardian revoked collection: halt and drop pending uploads. */
    fun haltOnRevoke() {
        state = QueueState.HALTED_REVOKED
        entries.clear()
    }

    /** Local stop/unpair: halt and drop pending uploads. */
    fun haltOnStop() {
        state = QueueState.HALTED_STOPPED
        entries.clear()
    }

    private fun serialize(o: LocationObservation): String =
        "${o.eventId}|${o.observedAtEpochMs}|${o.latitudeE6}|${o.longitudeE6}|" +
            "${o.accuracyMeters}|${o.speedMetersPerSecond ?: ""}|${o.sourceDeviceId}"

    private fun deserialize(s: String): LocationObservation {
        val p = s.split("|")
        return LocationObservation(
            eventId = p[0],
            observedAtEpochMs = p[1].toLong(),
            latitudeE6 = p[2].toInt(),
            longitudeE6 = p[3].toInt(),
            accuracyMeters = p[4].toFloat(),
            speedMetersPerSecond = p[5].ifBlank { null }?.toFloat(),
            sourceDeviceId = p[6]
        )
    }

    object Sealing {
        private const val KEY = 0x5A
        fun xorBase64(plain: String): String {
            val x = plain.toByteArray(Charsets.UTF_8).map { (it.toInt() xor KEY).toByte() }.toByteArray()
            return java.util.Base64.getEncoder().encodeToString(x)
        }
        fun unXorBase64(sealed: String): String {
            val x = java.util.Base64.getDecoder().decode(sealed).map { (it.toInt() xor KEY).toByte() }.toByteArray()
            return String(x, Charsets.UTF_8)
        }
    }
}

/** Status + uninstall/stop guidance surfaced to the child (L05-012). */
data class EnrollmentStatus(
    val enrolled: Boolean,
    val queueState: QueueState,
    val guidance: String
) {
    companion object {
        fun forHaltedRevoke(): EnrollmentStatus = EnrollmentStatus(
            enrolled = false,
            queueState = QueueState.HALTED_REVOKED,
            guidance = "Guardian has stopped monitoring. No data is being sent. " +
                "You may uninstall Alarka from Settings > Apps > Alarka > Uninstall."
        )

        fun forHaltedStop(): EnrollmentStatus = EnrollmentStatus(
            enrolled = false,
            queueState = QueueState.HALTED_STOPPED,
            guidance = "Monitoring stopped on this device. No data is being sent. " +
                "To fully remove, uninstall from Settings > Apps > Alarka > Uninstall."
        )
    }
}
