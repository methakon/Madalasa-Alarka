package org.madalasa.madalasa.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** L07-008 pagination (no overlap leak/dup) and L07-009 metadata-only (no snapping). */
class RouteTimelineTest {

    private fun observed(id: String, t: Long) =
        RoutePoint(id, t, RoutePointKind.OBSERVED, 1, 1)

    private val all = (1..25).map { observed("e$it", 1000L + it * 1000) }

    @Test
    fun adjacentPagesDoNotOverlapOrDuplicate() {
        val first = RouteTimelinePager.page(all, afterExclusiveEpochMs = null, pageSize = 10)
        assertEquals(10, first.points.size)
        assertEquals(1000L + 10 * 1000, first.nextCursorEpochMs)

        val second = RouteTimelinePager.page(all, afterExclusiveEpochMs = first.nextCursorEpochMs, pageSize = 10)
        // No id appears in both pages.
        val firstIds = first.points.mapNotNull { it.eventId }.toSet()
        val secondIds = second.points.mapNotNull { it.eventId }.toSet()
        assertTrue((firstIds intersect secondIds).isEmpty())
        // And no point between the two cursors is skipped.
        assertEquals("e11", second.points.first().eventId)
    }

    @Test
    fun lastPageHasNullCursor() {
        var cursor: Long? = null
        val seen = mutableListOf<String>()
        repeat(3) {
            val p = RouteTimelinePager.page(all, cursor, 10)
            seen += p.points.mapNotNull { it.eventId }
            cursor = p.nextCursorEpochMs
        }
        assertEquals(25, seen.toSet().size) // every point seen exactly once
        assertNull(cursor)
    }

    @Test
    fun duplicateEventIdsAreCollapsed() {
        val withDup = all + observed("e5", 1000L + 5 * 1000)
        val page = RouteTimelinePager.page(withDup, null, 500)
        assertEquals(25, page.points.mapNotNull { it.eventId }.toSet().size)
        assertEquals(25, page.points.size)
    }

    @Test
    fun gapPointsAreNotPlottedAndCarryNoPosition() {
        val gap = RoutePoint(null, 5000L, RoutePointKind.GAP, null, null)
        val points = listOf(observed("e1", 1000L), gap, observed("e2", 9000L))
        val plottable = RouteTimelinePager.plottable(points)
        assertEquals(2, plottable.size)
        assertFalse(plottable.any { it.kind == RoutePointKind.GAP })
        assertNull(gap.latitudeE6) // never snapped to an invented road coordinate
    }
}
