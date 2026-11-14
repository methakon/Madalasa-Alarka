package org.madalasa.madalasa.api

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import org.madalasa.madalasa.domain.Freshness
import org.madalasa.madalasa.domain.VerifiedLocationState
import java.io.IOException
import java.net.URI
import java.net.URL
import java.time.Instant
import java.util.UUID
import javax.net.ssl.HttpsURLConnection

/**
 * Parent data requests must be authenticated with an accepted, unexpired V2
 * session. No synthetic child, guardian scope or location is inferred here.
 *
 * The free-first API returns RLS-scoped latest location and the last 6 hours of
 * observations. Missing/stale data is UNAVAILABLE, never invented coordinates.
 */
class HttpsMadalasaApiClient(
    origin: String,
    private val bearer: () -> String?,
    private val actorId: () -> String?
) : MadalasaApiClient {

    private val baseUrl: String

    init {
        val uri = URI(origin.trim())
        require(
            uri.scheme == "https" && !uri.host.isNullOrBlank() &&
                uri.rawUserInfo == null && uri.rawQuery == null && uri.rawFragment == null &&
                (uri.rawPath.isNullOrEmpty() || uri.rawPath == "/") &&
                uri.port >= -1 && uri.port <= 65535
        ) { "Parent API requires a trusted HTTPS origin" }
        baseUrl = uri.toASCIIString().trimEnd('/')
    }

    private fun exactId(id: String): String {
        require(Regex("[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}").matches(id)) {
            "Invalid resource identifier"
        }
        return id.lowercase()
    }

    private fun request(path: String, body: String? = null): JSONObject {
        val token = bearer()?.takeIf { Regex("[0-9a-f]{64}").matches(it) }
            ?: error("Verified parent session required; sign in first")
        val conn = URL(baseUrl + path).openConnection() as HttpsURLConnection
        try {
            conn.requestMethod = if (body == null) "GET" else "POST"
            conn.connectTimeout = 8_000
            conn.readTimeout = 8_000
            conn.useCaches = false
            conn.instanceFollowRedirects = false
            conn.setRequestProperty("Authorization", "Bearer " + token)
            conn.setRequestProperty("Accept", "application/json")
            conn.setRequestProperty("Cache-Control", "no-store")
            if (body != null) {
                conn.setRequestProperty("Content-Type", "application/json")
                conn.setRequestProperty("Idempotency-Key", UUID.randomUUID().toString())
                conn.doOutput = true
                conn.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            }
            val status = conn.responseCode
            if (status == 401) throw SecurityException("Session expired; sign in again")
            if (status == 403 || status == 404)
                throw SecurityException("This resource is not accessible to this guardian")
            if (status !in 200..299)
                throw IOException("Parent service unavailable (HTTP " + status + ")")
            val contentType = conn.contentType.orEmpty()
            if (!contentType.contains("application/json", ignoreCase = true))
                throw IOException("Unexpected server response")
            val payload = StringBuilder()
            conn.inputStream.bufferedReader(Charsets.UTF_8).use { reader ->
                val buffer = CharArray(4096)
                while (true) {
                    val n = reader.read(buffer)
                    if (n < 0) break
                    if (payload.length + n > 65_536)
                        throw IOException("Parent response exceeds allowed size")
                    payload.append(buffer, 0, n)
                }
            }
            if (bearer() != token) throw SecurityException("Parent session changed during request")
            return JSONObject(payload.toString())
        } finally {
            conn.disconnect()
        }
    }

    override suspend fun getMe(): Result<ParentProfileResponse> =
        withContext(Dispatchers.IO) {
            runCatching {
                val verifiedActor = exactId(actorId()
                    ?: error("Verified parent session required; sign in first"))
                val array = request("/v1/families").getJSONArray("items")
                check(array.length() <= 200) { "Too many family records" }
                val families = (0 until array.length()).map { index ->
                    exactId(array.getJSONObject(index).getString("id"))
                }.distinct()
                ParentProfileResponse(verifiedActor, families)
            }
        }

    override suspend fun getChildren(familyId: String): Result<List<ChildSummaryResponse>> =
        withContext(Dispatchers.IO) {
            runCatching {
                val family = exactId(familyId)
                val array = request("/v1/families/" + family + "/children").getJSONArray("items")
                check(array.length() <= 300) { "Too many child records" }
                (0 until array.length()).map { index ->
                    val row = array.getJSONObject(index)
                    val rowFamily = exactId(row.getString("family_id"))
                    check(rowFamily == family) { "Family response did not match requested scope" }
                    ChildSummaryResponse(
                        id = exactId(row.getString("id")),
                        familyId = rowFamily,
                        alias = row.getString("alias").take(100),
                        freeServiceState = row.optString("free_service_state","UNAVAILABLE"),
                        queuePosition = if (row.isNull("queue_position")) null else row.optLong("queue_position",0).takeIf { it>0 },
                        slotLimit = row.optInt("slot_limit",108)
                    )
                }
            }
        }

    override suspend fun getChildLocation(childId: String): Result<VerifiedLocationState> =
        withContext(Dispatchers.IO) {
            runCatching {
                val child = exactId(childId)
                val response = request("/v1/children/" + child + "/location/latest")
                check(exactId(response.getString("child_id")) == child &&
                    response.optInt("history_window_hours",-1) == 6 &&
                    response.optBoolean("server_verified",false)) {
                    "Free location response is unverified or mismatched"
                }
                val point = response.optJSONObject("location")
                val latitude = if (point?.has("latitude_e6") == true) point.getInt("latitude_e6") else null
                val longitude = if (point?.has("longitude_e6") == true) point.getInt("longitude_e6") else null
                if ((latitude == null) != (longitude == null)) {
                    throw SecurityException("Partial location must never be rendered")
                }
                VerifiedLocationState(
                    childId = child,
                    sourceDeviceId = point?.optString("source_device_id").orEmpty(),
                    observedAtEpochMs = point?.optLong("observed_at_epoch_ms"),
                    ingestedAtEpochMs = point?.optLong("ingested_at_epoch_ms"),
                    tripProcessedAtEpochMs = null,
                    latitudeE6 = latitude,
                    longitudeE6 = longitude,
                    accuracyMeters = point?.optDouble("accuracy_meters")?.toFloat(),
                    // Do not infer freshness from device clock or API success.
                    freshness = if (point == null) Freshness.UNAVAILABLE else Freshness.LAST_KNOWN
                )
            }
        }

    override suspend fun getChildHistory(childId: String): Result<FreeChildHistory> =
        withContext(Dispatchers.IO) {
            runCatching {
                val child = exactId(childId)
                parseFreeHistory(child, request("/v1/children/" + child + "/location/history"))
            }
        }

    override suspend fun createFamily(label: String): Result<String> =
        withContext(Dispatchers.IO) {
            runCatching {
                require(label.isNotBlank() && label.length <= 100) { "Enter a family name" }
                exactId(request("/v1/families", JSONObject().put("label",label.trim()).toString())
                    .getString("id"))
            }
        }

    override suspend fun createChild(familyId: String, alias: String): Result<ChildSummaryResponse> =
        withContext(Dispatchers.IO) {
            runCatching {
                val family = exactId(familyId)
                require(alias.isNotBlank() && alias.length <= 80) { "Enter a child nickname (1–80 characters)" }
                val row=request("/v1/families/" + family + "/children",
                    JSONObject().put("alias",alias.trim()).toString())
                check(exactId(row.getString("family_id")) == family)
                val state=row.getString("free_service_state")
                check(state=="ADMITTED" || state=="WAITLISTED") {
                    "Child admission was not confirmed by the server"
                }
                ChildSummaryResponse(
                    id=exactId(row.getString("id")),
                    familyId=family,
                    alias=row.getString("alias"),
                    freeServiceState=state,
                    queuePosition=if(row.isNull("queue_position")) null else row.getLong("queue_position"),
                    slotLimit=row.optInt("slot_limit",108)
                )
            }
        }

    override suspend fun getPairedChildDevice(childId: String): Result<PairedChildDevice?> =
        withContext(Dispatchers.IO) {
            runCatching {
                val child = exactId(childId)
                val body = request("/v1/children/" + child + "/paired-device")
                check(exactId(body.getString("child_id")) == child) {
                    "Pairing status belongs to another child"
                }
                when (body.getString("state")) {
                    "UNPAIRED" -> null
                    "PAIRED" -> {
                        val device = body.getJSONObject("device")
                        PairedChildDevice(
                            id = exactId(device.getString("device_id")),
                            manufacturer = device.getString("manufacturer").take(80),
                            model = device.getString("model").take(120),
                            androidApi = if (device.isNull("android_api")) null else device.getInt("android_api"),
                            appVersion = device.getString("app_version").take(60),
                            pairingMethod = device.getString("pairing_method"),
                            pairedAt = device.optString("paired_at").takeIf { it.isNotBlank() }
                        )
                    }
                    else -> throw SecurityException("Unverified device pairing state")
                }
            }
        }

    override suspend fun createPairingCode(childId: String): Result<PairingCodeResponse> =
        withContext(Dispatchers.IO) {
            runCatching {
                val child = exactId(childId)
                val payload = request(
                    "/v1/children/" + child + "/pairing-codes",
                    JSONObject().put("requested_ttl_seconds", 300).toString()
                )
                check(exactId(payload.getString("child_id")) == child) {
                    "Pairing response did not match requested child"
                }
                val code = payload.getString("pairing_code")
                check(Regex("[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{10}").matches(code)) {
                    "Unexpected pairing code format"
                }
                val expiry = Instant.parse(payload.getString("expires_at")).toEpochMilli()
                PairingCodeResponse(code, expiry)
            }
        }

    override suspend fun getChildSignals(childId: String): Result<List<ChildSignalSummary>> =
        withContext(Dispatchers.IO) {
            runCatching {
                val child = exactId(childId)
                val body = request("/v1/children/" + child + "/signals")
                val array = body.optJSONArray("signals") ?: body.optJSONArray("items") ?: org.json.JSONArray()
                (0 until array.length()).map { i ->
                    val obj = array.getJSONObject(i)
                    ChildSignalSummary(
                        eventId = exactId(obj.getString("event_id")),
                        kind = obj.getString("kind"),
                        observedAt = obj.getString("observed_at"),
                        acknowledged = obj.optBoolean("acknowledged", false)
                    )
                }
            }
        }

    override suspend fun acknowledgeChildSignal(childId: String, eventId: String): Result<Boolean> =
        withContext(Dispatchers.IO) {
            runCatching {
                val child = exactId(childId)
                val event = exactId(eventId)
                val body = request("/v1/children/" + child + "/signals/" + event + "/ack", "{}")
                body.optString("stage") == "GUARDIAN_ACKNOWLEDGED"
            }
        }
}

/** Always refuses authenticated operations when no approved backend is configured. */
class UnavailableMadalasaApiClient : MadalasaApiClient {
    private fun <T> unavailable(): Result<T> =
        Result.failure(IllegalStateException("A verified parent session and HTTPS backend are required"))
    override suspend fun getMe(): Result<ParentProfileResponse> = unavailable()
    override suspend fun getChildren(familyId: String): Result<List<ChildSummaryResponse>> = unavailable()
    override suspend fun getChildLocation(childId: String): Result<VerifiedLocationState> = unavailable()
    override suspend fun createPairingCode(childId: String): Result<PairingCodeResponse> = unavailable()
}
