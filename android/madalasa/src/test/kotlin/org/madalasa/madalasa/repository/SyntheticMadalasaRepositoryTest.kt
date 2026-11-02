package org.madalasa.madalasa.repository

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.madalasa.madalasa.api.SyntheticMadalasaApiClient
import org.madalasa.madalasa.domain.Freshness

class SyntheticMadalasaRepositoryTest {

    private val apiClient = SyntheticMadalasaApiClient()
    private val repository = SyntheticMadalasaRepository(apiClient)

    @Test
    fun testRefreshProfileAndChildren() = runTest {
        val result = repository.refreshProfile()
        assertTrue("refreshProfile should succeed", result.isSuccess)

        val profile = repository.profile.value
        assertNotNull("profile must be populated", profile)
        assertEquals("00000000-0000-0000-0000-000000000001", profile?.adultId)

        val children = repository.children.value
        assertEquals("should have 2 synthetic children", 2, children.size)

        val selectedId = repository.selectedChildId.value
        assertEquals("should select first child by default", children.first().id, selectedId)

        val location = repository.selectedChildLocation.value
        assertNotNull("location should be loaded for selected child", location)
        assertEquals(Freshness.VERIFIED_CURRENT, location?.freshness)
    }

    @Test
    fun testGeneratePairingCode() = runTest {
        val codeResult = repository.generatePairingCode("00000000-0000-0000-0000-0000000000c1")
        assertTrue("Pairing code generation should succeed", codeResult.isSuccess)
        val code = codeResult.getOrThrow()
        assertEquals(10, code.length)
    }
}
