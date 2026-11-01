package org.madalasa.uicommon

import org.junit.Assert.*
import org.junit.Test

/** Exact 2026-10-26 Figma handoff inventory; no synthetic network calls. */
class FigmaScreenCatalogTest {
    @Test fun allEightyOneIdsAreUnique() {
        assertEquals(81, FigmaScreenCatalog.screens.size)
        assertEquals(81, FigmaScreenCatalog.screens.map { it.id.value }.toSet().size)
    }
    @Test fun allParentAndChildHandoffScreensArePresent() {
        assertEquals(60, FigmaScreenCatalog.forActor(AppActor.PARENT).size)
        assertEquals(21, FigmaScreenCatalog.forActor(AppActor.CHILD).size)
        (1..60).forEach {
            assertNotNull(FigmaScreenCatalog.find(ScreenId("P-%02d".format(it))))
        }
        (1..21).forEach {
            assertNotNull(FigmaScreenCatalog.find(ScreenId("C-%02d".format(it))))
        }
    }
    @Test fun eachScreenHasNonEmptyHandoffAndSecurityGate() {
        FigmaScreenCatalog.screens.forEach {
            assertTrue(it.headline.isNotBlank())
            assertTrue(it.primaryAction.isNotBlank())
            assertTrue(it.apiHook.isNotBlank())
            assertTrue(it.securityGate.isNotBlank())
            assertTrue(it.failureState.isNotBlank())
        }
    }
}
