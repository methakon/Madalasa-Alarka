package org.madalasa.madalasa.map

/**
 * Map provider abstraction (Phase-07 L07-003 and L07-007). The app depends on this
 * interface, not a concrete vendor SDK, so:
 *  - no provider API key is compiled in or checked into Git (keys are injected at
 *    runtime from a non-versioned source; a blank key yields UNCONFIGURED, never a
 *    hardcoded secret);
 *  - a provider is only reported SUPPORTED when it is actually configured and
 *    available — no vendor/source is ever falsely claimed supported;
 *  - an ordered fallback selects the first available provider, else a plain
 *    attribution-only tile source, else "no map" (coordinates still listed).
 */
enum class MapProviderId { OSM_RASTER, VENDOR_A, VENDOR_B, NONE }

enum class MapProviderAvailability { SUPPORTED, UNCONFIGURED, UNAVAILABLE }

data class MapProviderStatus(
    val id: MapProviderId,
    val availability: MapProviderAvailability,
    val attribution: String
) {
    val isUsable: Boolean get() = availability == MapProviderAvailability.SUPPORTED
}

/** A provider descriptor whose key is supplied at runtime, never embedded. */
data class MapProviderConfig(
    val id: MapProviderId,
    /** Runtime-injected key; blank means not configured (never a committed secret). */
    val runtimeApiKey: String?,
    val requiresKey: Boolean,
    val reachable: Boolean,
    val attribution: String
)

object MapProviderRegistry {

    fun statusOf(config: MapProviderConfig): MapProviderStatus {
        val availability = when {
            config.requiresKey && config.runtimeApiKey.isNullOrBlank() -> MapProviderAvailability.UNCONFIGURED
            !config.reachable -> MapProviderAvailability.UNAVAILABLE
            else -> MapProviderAvailability.SUPPORTED
        }
        return MapProviderStatus(config.id, availability, config.attribution)
    }

    /**
     * Ordered fallback: the first SUPPORTED provider wins; otherwise NONE (the UI
     * still shows coordinates/age chips). A provider is never claimed supported just
     * because it is listed.
     */
    fun selectActive(ordered: List<MapProviderConfig>): MapProviderStatus {
        for (config in ordered) {
            val status = statusOf(config)
            if (status.isUsable) return status
        }
        return MapProviderStatus(MapProviderId.NONE, MapProviderAvailability.UNAVAILABLE, "No map provider available")
    }
}
