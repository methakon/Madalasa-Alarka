package org.madalasa.madalasa.domain

/**
 * Design-only UI projection. Not a running Android app, permission or map implementation.
 * Distinguishes observed, ingested and reconstructed clocks to avoid invented live location.
 */
data class VerifiedLocationState(
    val childId: String,
    val sourceDeviceId: String,
    val observedAtEpochMs: Long?,
    val ingestedAtEpochMs: Long?,
    val tripProcessedAtEpochMs: Long?,
    val latitudeE6: Int?,
    val longitudeE6: Int?,
    val accuracyMeters: Float?,
    val freshness: Freshness
)

enum class Freshness {
    VERIFIED_CURRENT,
    DELAYED,
    LAST_KNOWN,
    UNKNOWN,
    UNAVAILABLE
}
