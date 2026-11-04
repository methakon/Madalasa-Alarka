package org.madalasa.madalasa.api

import org.json.JSONObject
import org.madalasa.madalasa.domain.Freshness
import org.madalasa.madalasa.domain.VerifiedLocationState

/** Current backend contract: newest-first, at most 200 rows, no pagination query. */
data class FreeChildHistory(
    val childId: String,
    val items: List<VerifiedLocationState>,
    val hasMore: Boolean
)

internal fun parseFreeHistory(child: String, response: JSONObject): FreeChildHistory {
    check(response.getString("child_id") == child &&
        response.getInt("history_window_hours") == 6 && response.getBoolean("server_verified")) {
        "History response is unverified or belongs to another child"
    }
    val rows = response.getJSONArray("items")
    check(rows.length() <= 200) { "History exceeds server page limit" }
    val points = (0 until rows.length()).map { i ->
        val row = rows.getJSONObject(i)
        check(Regex("[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}")
            .matches(row.getString("event_id")))
        val latitude = row.getInt("latitude_e6")
        val longitude = row.getInt("longitude_e6")
        val accuracy = row.getDouble("accuracy_meters")
        val observed = row.getLong("observed_at_epoch_ms")
        val ingested = row.getLong("ingested_at_epoch_ms")
        check(latitude in -90_000_000..90_000_000 && longitude in -180_000_000..180_000_000 &&
            accuracy.isFinite() && accuracy >= 0 && accuracy <= Float.MAX_VALUE && observed > 0 && ingested > 0) {
            "Invalid history observation"
        }
        VerifiedLocationState(child, row.getString("source_device_id"), observed, ingested,
            null, latitude, longitude, accuracy.toFloat(), Freshness.LAST_KNOWN)
    }
    return FreeChildHistory(child, points, response.getBoolean("has_more"))
}
