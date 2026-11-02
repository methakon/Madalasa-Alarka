package org.madalasa.madalasa.map

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** L07-003 / L07-007: no API key in Git; no vendor falsely claimed supported; fallback. */
class MapProviderTest {

    @Test
    fun providerRequiringKeyWithBlankKeyIsUnconfiguredNotSupported() {
        val status = MapProviderRegistry.statusOf(
            MapProviderConfig(MapProviderId.VENDOR_A, runtimeApiKey = "", requiresKey = true, reachable = true, attribution = "Vendor A")
        )
        assertEquals(MapProviderAvailability.UNCONFIGURED, status.availability)
        assertFalse("must not claim supported without a key", status.isUsable)
    }

    @Test
    fun unreachableProviderIsUnavailable() {
        val status = MapProviderRegistry.statusOf(
            MapProviderConfig(MapProviderId.VENDOR_B, runtimeApiKey = "runtime-key", requiresKey = true, reachable = false, attribution = "Vendor B")
        )
        assertEquals(MapProviderAvailability.UNAVAILABLE, status.availability)
        assertFalse(status.isUsable)
    }

    @Test
    fun fallbackSelectsFirstSupportedOrNone() {
        val ordered = listOf(
            MapProviderConfig(MapProviderId.VENDOR_A, "", true, true, "Vendor A"),        // unconfigured
            MapProviderConfig(MapProviderId.VENDOR_B, "k", true, false, "Vendor B"),       // unavailable
            MapProviderConfig(MapProviderId.OSM_RASTER, null, false, true, "© OpenStreetMap") // keyless, reachable
        )
        val active = MapProviderRegistry.selectActive(ordered)
        assertEquals(MapProviderId.OSM_RASTER, active.id)
        assertTrue(active.isUsable)
    }

    @Test
    fun noProviderAvailableYieldsNoneNotAFalseClaim() {
        val ordered = listOf(
            MapProviderConfig(MapProviderId.VENDOR_A, "", true, true, "Vendor A"),
            MapProviderConfig(MapProviderId.VENDOR_B, "k", true, false, "Vendor B")
        )
        val active = MapProviderRegistry.selectActive(ordered)
        assertEquals(MapProviderId.NONE, active.id)
        assertFalse(active.isUsable)
    }

    @Test
    fun keylessProviderIsSupportedWithoutAnyEmbeddedSecret() {
        val status = MapProviderRegistry.statusOf(
            MapProviderConfig(MapProviderId.OSM_RASTER, runtimeApiKey = null, requiresKey = false, reachable = true, attribution = "© OpenStreetMap")
        )
        assertEquals(MapProviderAvailability.SUPPORTED, status.availability)
    }
}
