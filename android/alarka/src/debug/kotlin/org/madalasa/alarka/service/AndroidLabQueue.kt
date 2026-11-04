package org.madalasa.alarka.service

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import java.io.File
import java.security.KeyStore
import java.util.UUID
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey

object AndroidLabQueue {
    fun open(context: Context, device: String): DurableLabQueue {
        require(UUID.fromString(device).toString() == device)
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val alias = "alarka_lab_queue_aes_v1"
        val key = (store.getKey(alias, null) as? SecretKey) ?: KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore"
        ).apply {
            init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true).setKeySize(256).build())
        }.generateKey()
        val atomic = AtomicFile(File(context.noBackupFilesDir, "lab-queue-$device.enc"))
        val storage = object : LabQueueStorage {
            override fun read(): ByteArray? {
                if (!atomic.baseFile.exists() && !File(atomic.baseFile.path + ".bak").exists()) return null
                atomic.openRead().use { input ->
                    val buffer = java.io.ByteArrayOutputStream()
                    val chunk = ByteArray(8192)
                    while (true) {
                        val count = input.read(chunk)
                        if (count < 0) break
                        require(buffer.size() + count <= 4_194_304)
                        buffer.write(chunk, 0, count)
                    }
                    return buffer.toByteArray()
                }
            }
            override fun write(bytes: ByteArray) {
                val output = atomic.startWrite()
                try {
                    output.write(bytes)
                    output.fd.sync()
                    atomic.finishWrite(output)
                } catch (error: Exception) {
                    atomic.failWrite(output)
                    throw error
                }
            }
        }
        return DurableLabQueue(storage, LabQueueCipher(key), device)
    }
}
