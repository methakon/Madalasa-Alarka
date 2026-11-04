package org.madalasa.alarka.service

import java.io.*
import javax.crypto.Cipher
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Implementations must atomically replace and fsync, or throw without replacing. */
interface LabQueueStorage {
    fun read(): ByteArray?
    fun write(bytes: ByteArray)
}

data class LabQueueRecord(val id: String, val payload: String)

/** Random nonce for every snapshot; device identity is authenticated, not just encrypted. */
class LabQueueCipher(private val key: SecretKey) {
    fun seal(plain: ByteArray, device: String): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key)
        cipher.updateAAD("alarka-lab-queue-v1:$device".toByteArray())
        return cipher.iv + cipher.doFinal(plain)
    }
    fun open(bytes: ByteArray, device: String): ByteArray {
        require(bytes.size in 28..4_194_304)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, bytes.copyOfRange(0, 12)))
        cipher.updateAAD("alarka-lab-queue-v1:$device".toByteArray())
        return cipher.doFinal(bytes.copyOfRange(12, bytes.size))
    }
}

/** Debug lab only; no automatic TTL or oldest-drop. Full queue stops acceptance. */
class DurableLabQueue(
    private val storage: LabQueueStorage,
    private val cipher: LabQueueCipher,
    private val device: String
) {
    private var halted = false
    private var records: List<LabQueueRecord> = storage.read()?.let { encrypted ->
        DataInputStream(ByteArrayInputStream(cipher.open(encrypted, device))).use { input ->
            require(input.readInt() == 1)
            halted = input.readBoolean()
            val count = input.readInt(); require(count in 0..1000)
            List(count) { LabQueueRecord(input.readUTF(), input.readUTF()) }.also {
                require(input.read() == -1)
                require(it.map { r -> r.id }.distinct().size == it.size)
            }
        }
    } ?: emptyList()

    @Synchronized fun enqueue(id: String, payload: String) {
        check(!halted) { "Enrollment queue revoked" }
        require(id.isNotBlank() && id.length <= 128 && payload.toByteArray().size <= 2048)
        val existing = records.find { it.id == id }
        if (existing != null) { require(existing.payload == payload); return }
        check(records.size < 1000) { "Lab queue full; collection must stop" }
        persist(records + LabQueueRecord(id, payload))
    }

    /** ACK is the exact immutable leased record, never a count or queue position. */
    @Synchronized fun acknowledge(record: LabQueueRecord) {
        persist(records.filterNot { it == record })
    }

    @Synchronized fun lease(): List<LabQueueRecord> = records.toList()

    @Synchronized fun halt() {
        persist(emptyList(), true)
        halted = true
    }

    private fun persist(next: List<LabQueueRecord>, stopped: Boolean = halted) {
        val bytes = ByteArrayOutputStream()
        DataOutputStream(bytes).use { output ->
            output.writeInt(1); output.writeBoolean(stopped); output.writeInt(next.size)
            next.forEach { output.writeUTF(it.id); output.writeUTF(it.payload) }
        }
        storage.write(cipher.seal(bytes.toByteArray(), device))
        records = next
    }
}
