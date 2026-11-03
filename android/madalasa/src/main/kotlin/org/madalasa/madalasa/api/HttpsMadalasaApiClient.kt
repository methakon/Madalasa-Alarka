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
 * The current Drogon server exposes live family/child grant-filtered reads and
 * pairing codes. It does NOT expose a parent latest-location GET endpoint yet.
 * We therefore verify the child's scope and return explicitly UNAVAILABLE,
 * never invented coordinates or a current position.
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
                        alias = row.getString("alias").take(100)
                    )
                }
            }
        }

    override suspend fun getChildLocation(childId: String): Result<VerifiedLocationState> =
        withContext(Dispatchers.IO) {
            runCatching {
                val child = exactId(childId)
                // GET child details is RLS filtered; 404/403 denies any location
                // projection. The latest-location API is not yet released.
                val response = request("/v1/children/" + child)
                check(exactId(response.getString("id")) == child) {
                    "Child response did not match requested scope"
                }
                VerifiedLocationState(
                    childId = child,
                    sourceDeviceId = "",
                    observedAtEpochMs = null,
                    ingestedAtEpochMs = null,
                    tripProcessedAtEpochMs = null,
                    latitudeE6 = null,
                    longitudeE6 = null,
                    accuracyMeters = null,
                    freshness = Freshness.UNAVAILABLE
                )
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
                check(Regex("[0-9]{3}-?[0-9]{3}").matches(code)) {
                    "Unexpected pairing code format"
                }
                val expiry = Instant.parse(payload.getString("expires_at")).toEpochMilli()
                PairingCodeResponse(code, expiry)
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
