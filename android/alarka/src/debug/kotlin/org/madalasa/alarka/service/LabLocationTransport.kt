package org.madalasa.alarka.service

import org.json.JSONArray
import org.json.JSONObject
import java.net.URI
import java.net.URL
import javax.net.ssl.HttpsURLConnection

class LabAuthorizationDenied : Exception()

/** One immutable record per batch: batch UUID == event UUID across retries/restarts. */
class LabLocationTransport(origin: String) {
    private val base: String
    init {
        val uri = URI(origin)
        require(uri.scheme == "https" && !uri.host.isNullOrBlank() && uri.rawUserInfo == null &&
            uri.rawQuery == null && uri.rawFragment == null && uri.rawPath.orEmpty() in listOf("", "/"))
        base = uri.toASCIIString().trimEnd('/')
    }
    fun health(session: VerifiedDeviceSession, battery: Int?, charging: Boolean) {
        val connection = URL("$base/v1/devices/${session.deviceId}/health")
            .openConnection() as HttpsURLConnection
        try {
            connection.requestMethod = "POST"
            connection.instanceFollowRedirects = false
            connection.connectTimeout = 8000; connection.readTimeout = 8000
            connection.useCaches = false
            connection.setRequestProperty("Authorization", "Bearer ${session.credential}")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.doOutput = true
            val payload = JSONObject().put("observed_at", java.time.Instant.now().toString())
                .put("battery_percent", battery ?: JSONObject.NULL).put("charging", charging)
                .put("permission_revision", 1)
            connection.outputStream.use { it.write(payload.toString().toByteArray(Charsets.UTF_8)) }
            if (connection.responseCode in listOf(401, 403, 404, 410)) throw LabAuthorizationDenied()
            check(connection.responseCode == 202) { "Lab health receipt unavailable" }
        } finally { connection.disconnect() }
    }

    fun upload(session: VerifiedDeviceSession, record: LabQueueRecord): Boolean {
        val connection = URL("$base/v1/devices/${session.deviceId}/locations:batch")
            .openConnection() as HttpsURLConnection
        try {
            connection.requestMethod = "POST"
            connection.instanceFollowRedirects = false
            connection.connectTimeout = 8000; connection.readTimeout = 8000
            connection.useCaches = false
            connection.setRequestProperty("Authorization", "Bearer ${session.credential}")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Accept", "application/json")
            connection.setRequestProperty("Cache-Control", "no-store")
            connection.doOutput = true
            val body = JSONObject().put("batch_id", record.id)
                .put("events", JSONArray().put(JSONObject(record.payload)))
            connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            val status = connection.responseCode
            if (status in listOf(401, 403, 404, 410)) throw LabAuthorizationDenied()
            if (status != 202) return false
            if (!connection.contentType.orEmpty().contains("application/json", true)) return false
            val text = StringBuilder()
            connection.inputStream.bufferedReader().use { reader ->
                val chunk = CharArray(1024)
                while (true) {
                    val n = reader.read(chunk); if (n < 0) break
                    require(text.length + n <= 16384)
                    text.append(chunk, 0, n)
                }
            }
            val receipt = JSONObject(text.toString())
            return LabCollectionPolicy.isReceipt(record.id, receipt.getString("batch_id"),
                receipt.getString("durable_stage"), receipt.getInt("accepted_count"),
                receipt.getInt("rejected_count"), receipt.getInt("duplicate_count"))
        } finally { connection.disconnect() }
    }
}
