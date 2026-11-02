package org.madalasa.madalasa.domain

/**
 * Derives the age / accuracy / status chips shown on the parent map (Phase-07
 * L07-004) from a [VerifiedLocationState]. Unknown or unavailable location is shown
 * clearly and never dressed up as a current fix.
 */
data class LocationChips(
    val statusLabel: String,
    val ageLabel: String,
    val accuracyLabel: String,
    /** True only when coordinates may be drawn on the map. */
    val hasPlottablePosition: Boolean
)

object LocationStatusChips {

    fun derive(state: VerifiedLocationState?, nowEpochMs: Long): LocationChips {
        if (state == null || state.freshness == Freshness.UNAVAILABLE) {
            return LocationChips("Unavailable", "—", "—", hasPlottablePosition = false)
        }
        if (state.freshness == Freshness.UNKNOWN || state.latitudeE6 == null || state.longitudeE6 == null) {
            return LocationChips("Unknown", "No recent fix", "—", hasPlottablePosition = false)
        }

        val status = when (state.freshness) {
            Freshness.VERIFIED_CURRENT -> "Live"
            Freshness.DELAYED -> "Delayed"
            Freshness.LAST_KNOWN -> "Last known"
            else -> "Unknown"
        }
        val age = state.observedAtEpochMs?.let { ageLabel(nowEpochMs - it) } ?: "No recent fix"
        val accuracy = state.accuracyMeters
            ?.let { "±${it.toInt()} m" + if (it > 100f) " (approx)" else "" }
            ?: "—"
        return LocationChips(status, age, accuracy, hasPlottablePosition = true)
    }

    private fun ageLabel(deltaMs: Long): String {
        if (deltaMs < 0) return "just now"
        val sec = deltaMs / 1000
        return when {
            sec < 60 -> "${sec}s ago"
            sec < 3600 -> "${sec / 60}m ago"
            sec < 86400 -> "${sec / 3600}h ago"
            else -> "${sec / 86400}d ago"
        }
    }
}
