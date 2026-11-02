package org.madalasa.madalasa.ui.figma

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ThemeCSharingCatalogTest {
    @Test fun allEightUniqueFigmaStatesAreMapped() {
        val entries = ThemeCSharingCatalog.screens
        assertEquals(8, entries.size)
        assertEquals(8, entries.map { it.id }.distinct().size)
        assertEquals(8, entries.map { it.figmaNode }.distinct().size)
        assertEquals(setOf("P-47", "P-49", "SH-01", "SH-02", "SH-03",
            "SH-04", "SH-05", "SH-06"), entries.map { it.id }.toSet())
    }

    @Test fun screensRetainEditableCopyAsNativeText() {
        ThemeCSharingCatalog.screens.forEach { design ->
            assertTrue(design.title.isNotBlank())
            assertTrue(design.content.size >= 5)
            assertTrue(design.content.all { it.isNotBlank() })
        }
    }
}
