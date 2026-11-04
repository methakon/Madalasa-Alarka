package org.madalasa.madalasa.api

import android.app.Activity
import android.util.Base64
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.NoCredentialException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.google.android.libraries.identity.googleid.GoogleIdTokenParsingException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.IOException
import java.io.Reader
import java.net.URI
import java.net.URL
import java.security.SecureRandom
import java.time.Instant
import javax.net.ssl.HttpsURLConnection

/**
 * Actual, on-tap Google Credential Manager -> trusted Drogon parent session
 * exchange. The Google OAuth web CLIENT ID is not a secret; it is supplied by
 * build configuration, never invented or embedded as an example.
 *
 * Verified identity != guardian authority. No family/child access is granted
 * or inferred by this code. Token bytes are never persisted or logged.
 */
data class GoogleParentConfiguration(
    val webClientId: String,
    val apiOrigin: String
) {
    fun normalizedOrigin(): String? {
        val uri = runCatching { URI(apiOrigin.trim()) }.getOrNull() ?: return null
        if (uri.scheme != "https" || uri.host.isNullOrBlank() ||
            uri.rawUserInfo != null || uri.rawQuery != null || uri.rawFragment != null ||
            (!uri.rawPath.isNullOrEmpty() && uri.rawPath != "/") ||
            uri.port < -1 || uri.port > 65535
        ) return null
        return uri.toASCIIString().trimEnd('/')
    }

    fun isConfigured(): Boolean =
        Regex("[A-Za-z0-9-]+\\.apps\\.googleusercontent\\.com").matches(webClientId.trim()) &&
            normalizedOrigin() != null
}

data class VerifiedParentSession(
    val bearer: String,
    val expiresAt: Instant,
    val actorId: String
) {
    fun validAt(now: Instant): Boolean =
        Regex("[0-9a-f]{64}").matches(bearer) &&
            Regex("[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}").matches(actorId) &&
            expiresAt.isAfter(now)
}

/** Process-local only, for development: a process restart requires sign-in. */
class ParentSessionMemory {
    @Volatile private var session: VerifiedParentSession? = null

    @Synchronized fun accept(newSession: VerifiedParentSession): Boolean {
        if (!newSession.validAt(Instant.now())) {
            session = null
            return false
        }
        session = newSession
        return true
    }

    @Synchronized fun currentToken(): String? =
        session?.takeIf { it.validAt(Instant.now()) }?.bearer

    /** Only an accepted, unexpired server-issued session may supply this actor ID. */
    @Synchronized fun currentActorId(): String? =
        session?.takeIf { it.validAt(Instant.now()) }?.actorId

    @Synchronized fun clear() { session = null }
}

enum class GoogleHandoffFailure {
    NOT_CONFIGURED,
    CANCELLED,
    NO_ACCOUNT,
    INVALID_CREDENTIAL,
    SERVICE_UNAVAILABLE,
    SERVER_REJECTED
}

sealed interface GoogleHandoffResult {
    data class Accepted(
        val session: VerifiedParentSession,
        val displayLabel: String
    ) : GoogleHandoffResult

    data class Denied(val reason: GoogleHandoffFailure) : GoogleHandoffResult
}

internal fun googleHandoffMessage(failure: GoogleHandoffFailure): String = when (failure) {
    GoogleHandoffFailure.NOT_CONFIGURED ->
        "Configure the Google web client ID and HTTPS development API origin before sign-in."
    GoogleHandoffFailure.CANCELLED ->
        "Google account selection was cancelled. No parent session was created."
    GoogleHandoffFailure.NO_ACCOUNT ->
        "No Google account is available. Add an account on this device and try again."
    GoogleHandoffFailure.INVALID_CREDENTIAL ->
        "The credential response was unrecognized. Please retry account selection."
    GoogleHandoffFailure.SERVICE_UNAVAILABLE ->
        "The sign-in service is unavailable. No parent session was created."
    GoogleHandoffFailure.SERVER_REJECTED ->
        "The server did not accept this identity. No guardian or child access was granted."
}

internal fun makeFreshNonce(): String {
    val bytes = ByteArray(32)
    SecureRandom().nextBytes(bytes)
    return Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)
}

class GoogleParentCredentialFlow {
    /**
     * Google controls its native account chooser. A fresh client nonce is
     * requested; server-side signature/audience/issuer/expiry and one-time
     * exchange checks remain authoritative.
     */
    suspend fun chooseAndExchange(
        activity: Activity,
        configuration: GoogleParentConfiguration
    ): GoogleHandoffResult {
        if (!configuration.isConfigured()) {
            return GoogleHandoffResult.Denied(GoogleHandoffFailure.NOT_CONFIGURED)
        }

        val result = try {
            val googleOption = GetSignInWithGoogleOption.Builder(
                serverClientId = configuration.webClientId.trim()
            ).setNonce(makeFreshNonce()).build()

            val request = GetCredentialRequest.Builder()
                .addCredentialOption(googleOption)
                .build()

            CredentialManager.create(activity).getCredential(
                context = activity,
                request = request
            ).credential
        } catch (_: GetCredentialCancellationException) {
            return GoogleHandoffResult.Denied(GoogleHandoffFailure.CANCELLED)
        } catch (_: NoCredentialException) {
            return GoogleHandoffResult.Denied(GoogleHandoffFailure.NO_ACCOUNT)
        } catch (_: GetCredentialException) {
            return GoogleHandoffResult.Denied(GoogleHandoffFailure.SERVICE_UNAVAILABLE)
        } catch (_: RuntimeException) {
            return GoogleHandoffResult.Denied(GoogleHandoffFailure.SERVICE_UNAVAILABLE)
        }

        if (result !is CustomCredential ||
            result.type != GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL
        ) return GoogleHandoffResult.Denied(GoogleHandoffFailure.INVALID_CREDENTIAL)

        val credential = try {
            GoogleIdTokenCredential.createFrom(result.data)
        } catch (_: GoogleIdTokenParsingException) {
            return GoogleHandoffResult.Denied(GoogleHandoffFailure.INVALID_CREDENTIAL)
        } catch (_: RuntimeException) {
            return GoogleHandoffResult.Denied(GoogleHandoffFailure.INVALID_CREDENTIAL)
        }

        // No profile data or Google ID token is surfaced until the server accepts.
        val session = try {
            exchangeIdToken(configuration, credential.idToken)
        } catch (_: IOException) {
            return GoogleHandoffResult.Denied(GoogleHandoffFailure.SERVICE_UNAVAILABLE)
        } catch (_: RuntimeException) {
            return GoogleHandoffResult.Denied(GoogleHandoffFailure.SERVER_REJECTED)
        }

        if (session == null) {
            return GoogleHandoffResult.Denied(GoogleHandoffFailure.SERVER_REJECTED)
        }
        val label = credential.displayName?.takeIf { it.isNotBlank() }?.take(80)
            ?: credential.id.take(80)
        return GoogleHandoffResult.Accepted(session, label)
    }

    private suspend fun exchangeIdToken(
        configuration: GoogleParentConfiguration,
        googleToken: String
    ): VerifiedParentSession? = withContext(Dispatchers.IO) {
        val baseUrl = configuration.normalizedOrigin() ?: return@withContext null
        if (googleToken.isBlank() || googleToken.length > 16_384 ||
            !Regex("[A-Za-z0-9._-]+").matches(googleToken)
        ) return@withContext null

        val connection = URL(baseUrl + "/v1/auth/parent/google")
            .openConnection() as HttpsURLConnection
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 8_000
            connection.readTimeout = 8_000
            connection.instanceFollowRedirects = false
            connection.useCaches = false
            connection.doOutput = true
            connection.setRequestProperty("Authorization", "Bearer " + googleToken)
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Accept", "application/json")
            connection.outputStream.use { it.write("{}".toByteArray(Charsets.UTF_8)) }

            if (connection.responseCode != 201) return@withContext null
            val jsonBody = connection.inputStream.bufferedReader(Charsets.UTF_8).use {
                readSmallResponse(it, maxChars = 8192)
            } ?: return@withContext null
            val obj = JSONObject(jsonBody)
            if (obj.optString("token_type") != "Bearer" ||
                obj.optString("kind") != "PARENT" ||
                obj.optString("state") != "ACTIVE"
            ) return@withContext null

            val expiresAt = runCatching {
                Instant.parse(obj.getString("expires_at"))
            }.getOrNull() ?: return@withContext null

            val verified = VerifiedParentSession(
                bearer = obj.optString("session_token"),
                expiresAt = expiresAt,
                actorId = obj.optString("actor_id")
            )
            verified.takeIf { it.validAt(Instant.now()) }
        } finally {
            connection.disconnect()
        }
    }
}

private fun readSmallResponse(reader: Reader, maxChars: Int): String? {
    val text = StringBuilder()
    val buf = CharArray(1024)
    while (true) {
        val read = reader.read(buf)
        if (read == -1) break
        if (text.length + read > maxChars) return null
        text.append(buf, 0, read)
    }
    return text.toString()
}
