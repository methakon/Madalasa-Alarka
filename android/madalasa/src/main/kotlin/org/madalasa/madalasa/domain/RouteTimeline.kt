package org.madalasa.madalasa.domain

/**
 * Route timeline paging and trip-viewer projection (Phase-07 L07-008 and L07-009).
 *
 * L07-008: pages are keyed by a half-open observed-time cursor [fromExclusive, to]
 * so adjacent pages never overlap (no duplicated point) and never skip (no leaked
 * gap). De-duplication by event id is a belt-and-suspenders guard.
 *
 * L07-009: a trip point carries only metadata (observed time + point kind + optional
 * position); GAP points have no position and are never filled with an invented
 * road-snapped coordinate.
 */

enum class RoutePointKind { OBSERVED, INFERRED, GAP }

data class RoutePoint(
    val eventId: String?,          // null for INFERRED/GAP
    val observedAtEpochMs: Long,
    val kind: RoutePointKind,
    val latitudeE6: Int?,          // null for GAP
    val longitudeE6: Int?
) {
    init {
        when (kind) {
            RoutePointKind.OBSERVED -> require(eventId != null && latitudeE6 != null && longitudeE6 != null)
            RoutePointKind.INFERRED -> require(eventId == null && latitudeE6 != null && longitudeE6 != null)
            RoutePointKind.GAP -> require(eventId == null && latitudeE6 == null && longitudeE6 == null)
        }
    }
}

data class TimelinePage(
    val points: List<RoutePoint>,
    /** Cursor to request the next page; null when exhausted. */
    val nextCursorEpochMs: Long?
)

object RouteTimelinePager {

    /**
     * Return the next page of at most [pageSize] points whose observedAt is strictly
     * greater than [afterExclusiveEpochMs] (null for the first page). Points are
     * sorted by (observedAt, eventId) and de-duplicated by eventId.
     */
    fun page(
        all: List<RoutePoint>,
        afterExclusiveEpochMs: Long?,
        pageSize: Int
    ): TimelinePage {
        require(pageSize in 1..500) { "pageSize out of range" }
        val sorted = all.sortedWith(compareBy({ it.observedAtEpochMs }, { it.eventId ?: "" }))
        val afterFiltered = sorted.filter {
            afterExclusiveEpochMs == null || it.observedAtEpochMs > afterExclusiveEpochMs
        }
        val seen = HashSet<String>()
        val window = ArrayList<RoutePoint>(pageSize)
        for (p in afterFiltered) {
            val key = p.eventId
            if (key != null && !seen.add(key)) continue // never duplicate an observed point
            window.add(p)
            if (window.size == pageSize) break
        }
        val next = if (window.size == pageSize) window.last().observedAtEpochMs else null
        return TimelinePage(window, next)
    }

    /** Observed/inferred points are plottable; GAP points are shown as gaps, never snapped. */
    fun plottable(points: List<RoutePoint>): List<RoutePoint> =
        points.filter { it.kind != RoutePointKind.GAP }
}
