package org.madalasa.madalasa.ui.screens

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ParentPrivacyScreensTest {
    @Test fun fourLiveFigmaNodesMapToDistinctParentDestinations() {
        val pages = ParentPrivacyPage.entries
        assertEquals(4, pages.size)
        assertEquals(setOf("159:3", "159:22", "159:41", "159:60"),
            pages.map { it.figmaNode }.toSet())
        assertEquals(4, pages.map { it.route }.toSet().size)
        pages.forEach { assertEquals(it, ParentPrivacyPage.fromRoute(it.route)) }
        assertEquals(null, ParentPrivacyPage.fromRoute("privacy/another_family"))
    }

    @Test fun overviewCanNavigateOnlyToChildScopedReadOnlyPages() {
        val targets = parentPrivacyRows(ParentPrivacyPage.OVERVIEW)
            .mapNotNull { it.destination }
        assertEquals(
            setOf(ParentPrivacyPage.GUARDIANS, ParentPrivacyPage.HISTORY,
                ParentPrivacyPage.REQUESTS), targets.toSet()
        )
    }

    @Test fun everyPrivacyPageHasAllFourTruthfulStateCards() {
        ParentPrivacyPage.entries.forEach { page ->
            val rows = parentPrivacyRows(page)
            assertEquals(page, ParentPrivacyPage.fromRoute(page.route))
            assertEquals(4, rows.size)
            assertTrue(rows.all { it.heading.isNotBlank() && it.detail.isNotBlank() })
            assertFalse(rows.any { it.detail.contains("Arjun") })
        }
        assertNotNull(parentPrivacyRows(ParentPrivacyPage.REQUESTS)
            .firstOrNull { it.heading == "Request progress" &&
                it.detail.contains("No request submitted") })
    }
}
