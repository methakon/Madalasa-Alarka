package org.madalasa.alarka.service

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONObject
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

data class PersistedSosEvent(
    val eventId: String,
    val observedAt: String,
    val stage: ManualSosStage,
    val revoked: Boolean = false
) {
    fun toManualSosState(): ManualSosState =
        ManualSosState(eventId = eventId, stage = stage, revoked = revoked)
}

interface PersistentSosOutbox {
    fun savePending(state: ManualSosState, observedAt: String)
    fun updateStage(state: ManualSosState)
    fun readPending(): PersistedSosEvent?
    fun clearPending(eventId: String)
}

/**
 * Keystore-encrypted, restart-persistent SOS outbox.
 * Retains exact event UUID across process kills and network outages.
 * Deletes from persistence only upon verified server/guardian confirmation.
 */
class KeystorePersistentSosOutbox(context: Context) : PersistentSosOutbox {
    private val prefs = context.applicationContext.getSharedPreferences(
        "alarka_sos_outbox_v1", Context.MODE_PRIVATE
    )
    private val encryptionAlias = "alarka_sos_outbox_aes_v1"

    private fun keystore(): KeyStore? = runCatching {
        KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
    }.getOrNull()

    private fun b64(bytes: ByteArray): String = Base64.encodeToString(bytes, Base64.NO_WRAP)
    private fun decode(s: String): ByteArray = Base64.decode(s, Base64.NO_WRAP)

    // Fallback key in memory/prefs for JVM test environments without AndroidKeyStore provider
    private fun getSecretKey(): SecretKey {
        val ks = keystore()
        if (ks != null) {
            val existing = ks.getKey(encryptionAlias, null) as? SecretKey
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
        } else {
            // Software fallback for JVM unit tests
            val raw = prefs.getString("jvm_test_key", null)
            if (raw != null) {
                return SecretKeySpec(decode(raw), "AES")
            }
            val keyGen = KeyGenerator.getInstance("AES")
            keyGen.init(256)
            val generated = keyGen.generateKey()
            prefs.edit().putString("jvm_test_key", b64(generated.encoded)).apply()
            return generated
        }
    }

    override fun savePending(state: ManualSosState, observedAt: String) {
        val json = """{"eventId":"${state.eventId}","observedAt":"$observedAt","stage":"${state.stage.name}","revoked":${state.revoked}}"""

        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, getSecretKey())
        val ciphertext = cipher.doFinal(json.toByteArray(Charsets.UTF_8))

        prefs.edit()
            .putString("eventId", state.eventId)
            .putString("iv", b64(cipher.iv))
            .putString("ciphertext", b64(ciphertext))
            .apply()
    }

    override fun updateStage(state: ManualSosState) {
        val current = readPending() ?: return
        if (current.eventId != state.eventId) return
        savePending(state, current.observedAt)
    }

    override fun readPending(): PersistedSosEvent? {
        val eventId = prefs.getString("eventId", null) ?: return null
        val ivStr = prefs.getString("iv", null) ?: return null
        val cipherStr = prefs.getString("ciphertext", null) ?: return null

        return runCatching {
            val iv = decode(ivStr)
            val ciphertext = decode(cipherStr)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, getSecretKey(), GCMParameterSpec(128, iv))
            val decryptedJson = String(cipher.doFinal(ciphertext), Charsets.UTF_8)
            val evId = Regex("\"eventId\"\\s*:\\s*\"([^\"]+)\"").find(decryptedJson)?.groupValues?.get(1) ?: return null
            val obsAt = Regex("\"observedAt\"\\s*:\\s*\"([^\"]+)\"").find(decryptedJson)?.groupValues?.get(1) ?: return null
            val stName = Regex("\"stage\"\\s*:\\s*\"([^\"]+)\"").find(decryptedJson)?.groupValues?.get(1) ?: return null
            val isRev = Regex("\"revoked\"\\s*:\\s*(true|false)").find(decryptedJson)?.groupValues?.get(1)?.toBoolean() ?: false
            PersistedSosEvent(
                eventId = evId,
                observedAt = obsAt,
                stage = ManualSosStage.valueOf(stName),
                revoked = isRev
            )
        }.getOrNull()
    }

    override fun clearPending(eventId: String) {
        val currentId = prefs.getString("eventId", null)
        if (currentId == eventId) {
            prefs.edit()
                .remove("eventId")
                .remove("iv")
                .remove("ciphertext")
                .apply()
        }
    }
}
