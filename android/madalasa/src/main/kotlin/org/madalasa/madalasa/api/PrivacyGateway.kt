package org.madalasa.madalasa.api

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.URL
import javax.net.ssl.HttpsURLConnection

/**
 * Real parent privacy transport for the reviewed Drogon V2 endpoints.
 * There is deliberately no hardcoded bearer, synthetic grant or embedded login bypass.
 * Inject an authenticated, short-lived V2 opaque session from the future OIDC bridge.
 */
data class GuardianPrivacyGrant(
    val grantId: String,
    val adultId: String,
    val scope: String,
    val expiresAt: String
)

data class ChildPurposeDecision(
    val purpose: String,
    val status: String,
    val legalState: String,
    val noticeVersion: String
)

interface PrivacyGateway {
    suspend fun guardianGrants(childId: String): Result<List<GuardianPrivacyGrant>>
    suspend fun childConsents(childId: String): Result<List<ChildPurposeDecision>>
    suspend fun revokeGuardianGrant(childId: String, grantId: String): Result<Unit>
}

/** Used until the real Google sign-in/opaque-session exchange is connected. */
class UnauthenticatedPrivacyGateway : PrivacyGateway {
    private fun <T> unavailable(): Result<T> =
        Result.failure(IllegalStateException("Authenticated parent session is required"))
    override suspend fun guardianGrants(childId: String) =
        unavailable<List<GuardianPrivacyGrant>>()
    override suspend fun childConsents(childId: String) =
        unavailable<List<ChildPurposeDecision>>()
    override suspend fun revokeGuardianGrant(childId: String, grantId: String) =
        unavailable<Unit>()
}

/**
 * HTTPS only, short timeouts, no response cache, no token logging.
 * No implicit retries for state-changing DELETE.
 */
class HttpsPrivacyGateway(
    private val origin: String,
    private val tokenProvider: () -> String?
) : PrivacyGateway {
    init {
        require(origin.startsWith("https://") && !origin.contains('?') && !origin.contains('#')) {
            "Privacy API origin must use HTTPS"
        }
    }

    private fun pathId(id: String): String {
        require(Regex("[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}").matches(id)) {
            "Invalid resource ID"
        }
        return id
    }

    private fun request(method: String, path: String): String {
        val token = tokenProvider()?.takeIf { Regex("[a-f0-9]{64}").matches(it) }
            ?: error("No verified parent session; sign in first")
        val conn = URL(origin.trimEnd('/') + path).openConnection() as HttpsURLConnection
        try {
            conn.requestMethod = method
            conn.connectTimeout = 8_000
            conn.readTimeout = 8_000
            conn.useCaches = false
            conn.setRequestProperty("Authorization", "Bearer $token")
            conn.setRequestProperty("Accept", "application/json")
            val code = conn.responseCode
            if (code == 401) error("Parent session expired; sign in again")
            if (code == 403 || code == 404) error("This child's data is not accessible")
            if (code !in 200..299) error("Privacy service unavailable (HTTP $code)")
            if (code == 204) return ""
            return conn.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
        } finally {
            conn.disconnect()
        }
    }

    override suspend fun guardianGrants(childId: String): Result<List<GuardianPrivacyGrant>> =
        withContext(Dispatchers.IO) {
            runCatching {
                val payload = JSONObject(request("GET", "/v1/children/${pathId(childId)}/guardian-grants"))
                val items = payload.getJSONArray("items")
                (0 until items.length()).map { i ->
                    val o = items.getJSONObject(i)
                    GuardianPrivacyGrant(
                        grantId = o.getString("id"),
                        adultId = o.getString("adult_id"),
                        scope = o.getString("scope"),
                        expiresAt = o.optString("expires_at")
                    )
                }
            }
        }

    override suspend fun childConsents(childId: String): Result<List<ChildPurposeDecision>> =
        withContext(Dispatchers.IO) {
            runCatching {
                val payload = JSONObject(request("GET", "/v1/children/${pathId(childId)}/consents"))
                val items = payload.getJSONArray("items")
                (0 until items.length()).map { i ->
                    val o = items.getJSONObject(i)
                    ChildPurposeDecision(
                        purpose = o.getString("purpose"),
                        status = o.getString("status"),
                        legalState = o.getString("legal_state"),
                        noticeVersion = o.getString("notice_version")
                    )
                }
            }
        }

    override suspend fun revokeGuardianGrant(childId: String, grantId: String): Result<Unit> =
        withContext(Dispatchers.IO) {
            runCatching {
                request("DELETE", "/v1/children/${pathId(childId)}/guardian-grants/${pathId(grantId)}")
                Unit
            }
        }
}
