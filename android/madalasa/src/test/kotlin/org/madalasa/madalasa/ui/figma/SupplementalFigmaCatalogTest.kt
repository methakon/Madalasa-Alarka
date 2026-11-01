package org.madalasa.madalasa.ui.figma

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Design-coverage tests only: not evidence of Android permissions, UI screenshot QA or API integration. */
class SupplementalFigmaCatalogTest {
    private val catalog = SupplementalFigmaCatalog.screens

    @Test fun everySourceFrameHasOneScreen() {
        val capability = catalog.filter { it.kind == "CAPABILITY" }
        val media = catalog.filter { it.kind == "MEDIA" }
        assertEquals(22, capability.size)
        assertEquals(11, media.size)
        assertEquals(33, catalog.map { it.id }.distinct().size)
        assertEquals(33, catalog.map { it.figmaNode }.distinct().size)
        (1..22).forEach {
            assertNotNull(SupplementalFigmaCatalog.find("P-" + "%02d".format(it)))
        }
        (1..11).forEach {
            assertNotNull(SupplementalFigmaCatalog.find("PA-" + "%02d".format(it)))
        }
    }

    @Test fun designsHaveActionableContentAndAreNeverRuntimeEvidence() {
        catalog.forEach { screen ->
            assertTrue(screen.title.isNotBlank())
            assertTrue(screen.summary.isNotBlank())
            assertTrue(screen.figmaNode.matches(Regex("[0-9]+:[0-9]+")))
            assertFalse(screen.rows.isEmpty())
            assertTrue(screen.rows.all { it.label.isNotBlank() && it.detail.isNotBlank() })
        }
    }
}
