package org.madalasa.alarka.ui.figma

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
        assertEquals(24, capability.size)
        assertEquals(0, media.size)
        assertEquals(24, catalog.map { it.id }.distinct().size)
        assertEquals(24, catalog.map { it.figmaNode }.distinct().size)
        (1..24).forEach {
            assertNotNull(SupplementalFigmaCatalog.find("A-" + "%02d".format(it)))
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
