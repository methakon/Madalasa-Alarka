package org.madalasa.madalasa.ui.figma

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Source screen inventory only; Android compilation and visual QA are separate gates. */
class ThemeCFunctionalCatalogTest {
    @Test fun allEightUpdatedParentScreensHaveUniqueSourceNodes() {
        val screens = ThemeCFunctionalCatalog.screens
        assertEquals(8, screens.size)
        assertEquals(8, screens.map { it.id }.distinct().size)
        assertEquals(8, screens.map { it.figmaNode }.distinct().size)
        assertEquals(
            setOf("P-05", "P-15", "P-24", "P-28", "P-31", "P-39", "P-48", "P-58"),
            screens.map { it.id }.toSet()
        )
    }

    @Test fun eachUpdatedScreenCarriesVisibleSourceCopy() {
        ThemeCFunctionalCatalog.screens.forEach { spec ->
            assertTrue(spec.text.size >= 7)
            assertTrue(spec.text.all { it.isNotBlank() })
            assertEquals(spec, ThemeCFunctionalCatalog.find(spec.id))
        }
    }
}
