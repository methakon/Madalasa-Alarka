package org.madalasa.alarka.service

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.IOException
import java.net.URI
import java.net.URL
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.MessageDigest
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import java.time.Instant
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.net.ssl.HttpsURLConnection

/**
 * A child-side *device* session, not authority/consent to begin monitoring.
 * Token is decrypted only for authenticated requests and never logged/exported.
 */
data class VerifiedDeviceSession(
    val deviceId: String,
    val credential: String,
    val expiresAt: Instant
)

/**
 * AndroidKeyStore-backed device key plus AES-GCM encrypted credential.
 * The signing key's identity binds the stored bearer to this installation;
 * uninstall/restore must not resurrect a previous server enrollment.
 */
class KeystoreDeviceSessionStore(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences(
        "alarka_keystore_session_v1", Context.MODE_PRIVATE
    )
    private val signingAlias = "alarka_device_p256_v1"
    private val encryptionAlias = "alarka_session_aes_v1"

    private fun keystore() = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
    private fun b64(bytes: ByteArray) = Base64.encodeToString(bytes, Base64.NO_WRAP)
    private fun decode(s: String) = Base64.decode(s, Base64.NO_WRAP)

    private fun aesKey(): SecretKey {
        val existing = keystore().getKey(encryptionAlias, null) as? SecretKey
        if (existing != null) return existing
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        val spec = KeyGenParameterSpec.Builder(
            encryptionAlias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        ).setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setRandomizedEncryptionRequired(true)
            .build()
        generator.init(spec)
        return generator.generateKey()
    }

    /** Replaces only the child app's prior local signing identity. */
    fun createNewDeviceKey(): KeyPair {
        val store = keystore()
        if (store.containsAlias(signingAlias)) store.deleteEntry(signingAlias)
        val generator = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore")
        generator.initialize(
            KeyGenParameterSpec.Builder(
                signingAlias, KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY
            )
                .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
                .setDigests(KeyProperties.DIGEST_SHA256)
                .build()
        )
        return generator.generateKeyPair()
    }

    private fun fingerprint(publicKey: ByteArray) =
        b64(MessageDigest.getInstance("SHA-256").digest(publicKey))

    fun persistVerifiedSession(deviceId: String, credential: String, expiresAt: Instant, spki: ByteArray) {
        check(keystore().containsAlias(signingAlias)) { "Device signing key missing" }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, aesKey())
        val ciphertext = cipher.doFinal(credential.toByteArray(Charsets.UTF_8))
        check(prefs.edit()
            .putString("deviceId", deviceId)
            .putString("expiry", expiresAt.toString())
            .putString("fingerprint", fingerprint(spki))
            .putString("iv", b64(cipher.iv))
            .putString("ciphertext", b64(ciphertext))
            .commit()) { "Could not securely save device credential" }
    }

    fun currentSession(): VerifiedDeviceSession? {
        val deviceId = prefs.getString("deviceId", null) ?: return null
        val expiryString = prefs.getString("expiry", null) ?: return null
        val expiry = runCatching { Instant.parse(expiryString) }.getOrNull() ?: return null
        if (!expiry.isAfter(Instant.now())) return null
        val cert = keystore().getCertificate(signingAlias) ?: return null
        if (fingerprint(cert.publicKey.encoded) != prefs.getString("fingerprint", "")) return null
        return runCatching {
            val iv = decode(prefs.getString("iv", "") ?: "")
            val encrypted = decode(prefs.getString("ciphertext", "") ?: "")
            require(iv.size == 12 && encrypted.size in 16..4096)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, aesKey(), GCMParameterSpec(128, iv))
            val token = String(cipher.doFinal(encrypted), Charsets.UTF_8)
            require(Regex("^[A-Za-z0-9_-]{30,200}$").matches(token))
            VerifiedDeviceSession(UUID.fromString(deviceId).toString(), token, expiry)
        }.getOrNull()
    }

    /** Locally stops use of credentials. Parent-side server revocation remains independent. */
    fun clearLocalSession() {
        prefs.edit().clear().commit()
        val store = keystore()
        if (store.containsAlias(signingAlias)) store.deleteEntry(signingAlias)
        if (store.containsAlias(encryptionAlias)) store.deleteEntry(encryptionAlias)
    }
}

/**
 * Production-capable parent-issued code redemption + server challenge proof.
 * This service never collects location, starts an Android FGS or infers consent.
 * Monitoring is an independent permission/consent/admission state machine.
 */
class KeystoreAlarkaEnrollmentService(
    private val context: Context,
    origin: String,
    private val sessions: KeystoreDeviceSessionStore
) : AlarkaEnrollmentService {
    private val baseUrl: String
    private val gate = Mutex()
    private val contextLabel = "amar-pola-m1-device-enroll-v1"

    init {
        val uri = URI(origin.trim())
        require(
            uri.scheme == "https" && !uri.host.isNullOrBlank() &&
                uri.rawUserInfo == null && uri.rawQuery == null && uri.rawFragment == null &&
                (uri.rawPath.isNullOrBlank() || uri.rawPath == "/") &&
                uri.port >= -1 && uri.port <= 65535
        ) { "Alarka enrollment requires a trusted HTTPS origin" }
        baseUrl = uri.toASCIIString().trimEnd('/')
    }

    private fun send(path: String, payload: JSONObject): JSONObject {
        val connection = URL(baseUrl + path).openConnection() as HttpsURLConnection
        try {
            connection.requestMethod = "POST"
            connection.instanceFollowRedirects = false
            connection.connectTimeout = 8_000
            connection.readTimeout = 8_000
            connection.useCaches = false
            connection.setRequestProperty("Accept", "application/json")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Cache-Control", "no-store")
            connection.doOutput = true
            connection.outputStream.use {
                it.write(payload.toString().toByteArray(Charsets.UTF_8))
            }
            if (connection.responseCode != 201)
                throw IOException("Secure enrollment was not accepted (HTTP ${connection.responseCode})")
            if (!connection.contentType.orEmpty().contains("application/json", ignoreCase = true))
                throw IOException("Unexpected enrollment response type")
            val response = StringBuilder()
            connection.inputStream.bufferedReader(Charsets.UTF_8).use { reader ->
                val buffer = CharArray(4096)
                while (true) {
                    val n = reader.read(buffer)
                    if (n < 0) break
                    if (response.length + n > 65_536) throw IOException("Enrollment response too large")
                    response.append(buffer, 0, n)
                }
            }
            return JSONObject(response.toString())
        } finally {
            connection.disconnect()
        }
    }

    override suspend fun generatePairingChallenge(): Result<String> =
        Result.failure(IllegalStateException(
            "Create the pairing code from your guardian's Madalasa app"
        ))

    override suspend fun completeEnrollment(pairingCode: String): Result<EnrollmentResult> =
        withContext(Dispatchers.IO) {
            gate.withLock {
                runCatching {
                    val code = ChildPairingPolicy.normalizeEnteredCode(pairingCode)
                        ?: error("Enter the 10-character code issued by the guardian")
                    check(sessions.currentSession() == null) {
                        "This device is already paired; revoke it from Madalasa before pairing again"
                    }
                    sessions.clearLocalSession()
                    val keyPair = sessions.createNewDeviceKey()
                    try {
                        val challenge = send("/v1/enrollment", JSONObject()
                            .put("pairing_code", code)
                            .put("public_key_spki_base64",
                                Base64.encodeToString(keyPair.public.encoded, Base64.NO_WRAP))
                            .put("algorithm", "ECDSA_P256_SHA256")
                            .put("app_version", context.packageManager
                                .getPackageInfo(context.packageName, 0).versionName ?: "0.1")
                            .put("android_api", Build.VERSION.SDK_INT)
                            .put("device_info", JSONObject()
                                .put("manufacturer", Build.MANUFACTURER.filter { it >= ' ' }.take(80))
                                .put("model", Build.MODEL.filter { it >= ' ' }.take(120))))
                        val enrollmentId = UUID.fromString(challenge.getString("enrollment_id")).toString()
                        val deviceId = UUID.fromString(challenge.getString("device_id")).toString()
                        val nonce = challenge.getString("nonce_base64url")
                        check(Regex("^[A-Za-z0-9_-]{24,200}$").matches(nonce))
                        check(challenge.getString("challenge_context") == contextLabel)
                        check(Instant.parse(challenge.getString("expires_at")).isAfter(Instant.now())) {
                            "Pairing challenge expired"
                        }
                        val signer = Signature.getInstance("SHA256withECDSA")
                        signer.initSign(keyPair.private)
                        signer.update("$contextLabel:$nonce".toByteArray(Charsets.UTF_8))
                        val signature = Base64.encodeToString(
                            signer.sign(), Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING
                        )
                        val proof = send("/v1/enrollment/$enrollmentId/proof", JSONObject()
                            .put("nonce_base64url", nonce)
                            .put("signature_base64url", signature))
                        check(UUID.fromString(proof.getString("device_id")).toString() == deviceId) {
                            "Device identity mismatch in proof response"
                        }
                        val token = proof.getString("credential_token")
                        check(Regex("^[A-Za-z0-9_-]{30,200}$").matches(token))
                        val expiresAt = Instant.parse(proof.getString("expires_at"))
                        check(expiresAt.isAfter(Instant.now())) { "Device credential already expired" }
                        sessions.persistVerifiedSession(
                            deviceId, token, expiresAt, keyPair.public.encoded
                        )
                        EnrollmentResult(
                            success = true,
                            devicePseudonym = deviceId,
                            guardianAlias = null  // never claim to know an unverified adult's name
                        )
                    } catch (e: Exception) {
                        // No persisted credential or usable identity after an incomplete flow.
                        sessions.clearLocalSession()
                        throw e
                    }
                }
            }
        }

    override suspend fun unpairDevice(): Result<Boolean> =
        withContext(Dispatchers.IO) {
            gate.withLock {
                runCatching {
                    // Immediately stops this installation using the bearer.
                    // Does not claim to revoke the backend grant: guardian must
                    // also remove/revoke the device in Madalasa.
                    sessions.clearLocalSession()
                    true
                }
            }
        }
}
