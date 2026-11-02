package org.madalasa.alarka.domain

/**
 * Design-only, Android-independent data contract. Not an application entry point.
 * Coordinates use fixed-point 1e-6 degrees. Never infer legal permission from DTO presence.
 * No Android Manifest or Gradle build is supplied yet.
 *
 * Phase-06 L06-001: retains observed timestamp, accuracy and provenance (which
 * provider produced the fix and whether it was sensor-fused) so the server and UI
 * can report truthful source/quality rather than an invented precise path.
 */
data class LocationObservation(
    val eventId: String,
    val observedAtEpochMs: Long,
    val latitudeE6: Int,
    val longitudeE6: Int,
    val accuracyMeters: Float,
    val speedMetersPerSecond: Float?,
    val sourceDeviceId: String,
    /** Which Android location provider produced this fix (e.g. "fused", "gps", "network"). */
    val provider: String = "unknown",
    /** True when the fix came from FusedLocationProvider (sensor fusion of GNSS + sensors). */
    val sensorFused: Boolean = false
) {
    fun hasPlausibleCoordinates(): Boolean =
        latitudeE6 in -90_000_000..90_000_000 &&
        longitudeE6 in -180_000_000..180_000_000 &&
        accuracyMeters.isFinite() &&
        accuracyMeters >= 0f

    /**
     * Quality classification mirroring the server contract (QUALIFIED when the
     * reported horizontal accuracy is within 100 m, otherwise COARSE). Accuracy is
     * provider-reported uncertainty, never a deterministic bound.
     */
    fun quality(): String = if (accuracyMeters <= 100f) "QUALIFIED" else "COARSE"
}

enum class LocalUploadState {
    PENDING_LOCAL,
    IN_FLIGHT,
    DURABLY_ACKNOWLEDGED,
    REJECTED
}

/**
 * Conceptual inbox receipt. A server QUEUED response is not a GPS trip-completion signal.
 * Runtime auth, Android permission gating, encryption and network code are NOT implemented.
 */
data class DurableGpsReceipt(
    val batchId: String,
    val acceptedCount: Int,
    val processingStage: String
)
