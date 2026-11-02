package org.madalasa.alarka.service

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.URL
import javax.net.ssl.HttpsURLConnection

/** Server observations and actual Android permission grants remain distinct. */
data class ServerConsentStatus(
    val coreConsent: Boolean,
    val locationConsent: Boolean,
    val usageConsent: Boolean,
    val mediaConsent: Boolean,
    val childDeleted: Boolean,
    val collectionAuthorized: Boolean
)

interface ChildPrivacyGateway {
    suspend fun readConsentStatus(): Result<ServerConsentStatus>
}

/** No credentials means no device-specific server claims, even on a lab phone. */
class UnauthenticatedChildPrivacyGateway : ChildPrivacyGateway {
    override suspend fun readConsentStatus(): Result<ServerConsentStatus> =
        Result.failure(IllegalStateException("Device is not authenticated with the server"))
}

/** Real HTTPS DeviceBearer transport, injected after secure Keystore enrollment. */
class HttpsChildPrivacyGateway(
    private val origin: String,
    private val deviceIdProvider: () -> String?,
    private val credentialProvider: () -> String?
) : ChildPrivacyGateway {
    init {
        require(origin.startsWith("https://") && !origin.contains('?') && !origin.contains('#')) {
            "Device privacy API origin must use HTTPS"
        }
    }

    override suspend fun readConsentStatus(): Result<ServerConsentStatus> =
        withContext(Dispatchers.IO) {
            runCatching {
                val id = deviceIdProvider()?.takeIf {
                    Regex("[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}").matches(it)
                } ?: error("No enrolled device ID")
                val bearer = credentialProvider()?.takeIf {
                    it.isNotBlank() && it.length <= 4096 && !it.any(Char::isWhitespace)
                } ?: error("No enrolled device credential")
                val connection = URL(origin.trimEnd('/') + "/v1/devices/$id/consent-status")
                    .openConnection() as HttpsURLConnection
                try {
                    connection.requestMethod = "GET"
                    connection.connectTimeout = 8_000
                    connection.readTimeout = 8_000
                    connection.useCaches = false
                    connection.setRequestProperty("Authorization", "Bearer $bearer")
                    connection.setRequestProperty("Accept", "application/json")
                    val status = connection.responseCode
                    if (status == 401 || status == 404) error("Device enrollment or consent status unavailable")
                    if (status != 200) error("Privacy service unavailable (HTTP $status)")
                    val body = JSONObject(connection.inputStream.bufferedReader().use { it.readText() })
                    ServerConsentStatus(
                        coreConsent = body.getBoolean("core_consent"),
                        locationConsent = body.getBoolean("location_consent"),
                        usageConsent = body.getBoolean("usage_consent"),
                        mediaConsent = body.getBoolean("media_consent"),
                        childDeleted = body.getBoolean("deleted"),
                        collectionAuthorized = body.getBoolean("collection_authorized")
                    )
                } finally {
                    connection.disconnect()
                }
            }
        }
}
