package org.madalasa.madalasa.api

import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

class FreeHistoryResponseTest {
    private val child = "11111111-1111-1111-1111-111111111111"
    // Field names and limits follow backend/src/free_location_reads.h, not draft OpenAPI.
    private fun payload() = JSONObject("""{"child_id":"$child","history_window_hours":6,"server_verified":true,"items":[{"event_id":"22222222-2222-2222-2222-222222222222","source_device_id":"33333333-3333-3333-3333-333333333333","observed_at_epoch_ms":1000,"ingested_at_epoch_ms":2000,"latitude_e6":123,"longitude_e6":456,"accuracy_meters":5.5}],"has_more":false}""")
    @Test fun readsActualBackendShapeAndPreservesPartialPageFlag() {
        val result = parseFreeHistory(child, payload().put("has_more", true))
        assertEquals(child, result.childId); assertEquals(123, result.items.single().latitudeE6)
        assertEquals(1000L, result.items.single().observedAtEpochMs); assertTrue(result.hasMore)
    }
    @Test fun rejectsWrongChildUnverifiedAndExpandedWindow() {
        for (p in listOf(payload().put("child_id", "44444444-4444-4444-4444-444444444444"),
            payload().put("server_verified", false), payload().put("history_window_hours", 24))) {
            assertTrue(runCatching { parseFreeHistory(child, p) }.isFailure)
        }
    }
    @Test fun rejectsPartialOutOfRangeAndUnknownAccuracy() {
        for (field in listOf("longitude_e6", "observed_at_epoch_ms", "accuracy_meters")) {
            val p = payload(); p.getJSONArray("items").getJSONObject(0).remove(field)
            assertTrue(runCatching { parseFreeHistory(child, p) }.isFailure)
        }
        val p = payload(); p.getJSONArray("items").getJSONObject(0).put("latitude_e6", 90000001)
        assertTrue(runCatching { parseFreeHistory(child, p) }.isFailure)
    }
    @Test fun emptyHistoryIsVerifiedEmptyNotUnavailable() {
        val p = payload().put("items", org.json.JSONArray())
        assertTrue(parseFreeHistory(child, p).items.isEmpty())
    }
}
