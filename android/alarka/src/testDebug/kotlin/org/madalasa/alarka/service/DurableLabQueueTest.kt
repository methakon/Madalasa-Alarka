package org.madalasa.alarka.service

import org.junit.Assert.*
import org.junit.Test
import javax.crypto.KeyGenerator

class DurableLabQueueTest {
    private class Disk : LabQueueStorage {
        var bytes: ByteArray? = null
        var fail = false
        override fun read() = bytes
        override fun write(bytes: ByteArray) { check(!fail); this.bytes = bytes }
    }
    private fun cipher() = LabQueueCipher(KeyGenerator.getInstance("AES").apply { init(256) }.generateKey())

    @Test fun ackRemovesOnlyExactLeasedIdentityDespiteConcurrentAppend() {
        val disk = Disk(); val queue = DurableLabQueue(disk, cipher(), "device-a")
        queue.enqueue("a", "first"); val lease = queue.lease().single()
        queue.enqueue("b", "second")
        queue.acknowledge(lease)
        assertEquals(listOf("b"), queue.lease().map { it.id })
        queue.acknowledge(lease)
        assertEquals(listOf("b"), queue.lease().map { it.id })
    }

    @Test fun revokeSurvivesRestartAndRejectsFurtherCollection() {
        val disk = Disk(); val cipher = cipher(); val queue = DurableLabQueue(disk, cipher, "a")
        queue.enqueue("a", "fixture"); queue.halt()
        val restored = DurableLabQueue(disk, cipher, "a")
        assertTrue(restored.lease().isEmpty())
        assertThrows(IllegalStateException::class.java) { restored.enqueue("b", "fixture") }
    }

    @Test fun tamperWrongKeyAndDeviceFailClosed() {
        val disk = Disk(); val cipher = cipher()
        DurableLabQueue(disk, cipher, "a").enqueue("a", "fixture")
        assertThrows(Exception::class.java) { DurableLabQueue(disk, cipher, "b") }
        assertThrows(Exception::class.java) { DurableLabQueue(disk, cipher(), "a") }
        disk.bytes!![15] = (disk.bytes!![15].toInt() xor 1).toByte()
        assertThrows(Exception::class.java) { DurableLabQueue(disk, cipher, "a") }
    }

    @Test fun failedPersistDoesNotMutateMemoryOrLoseOldDiskState() {
        val disk = Disk(); val cipher = cipher(); val queue = DurableLabQueue(disk, cipher, "a")
        queue.enqueue("a", "fixture"); disk.fail = true
        assertThrows(IllegalStateException::class.java) { queue.acknowledge(queue.lease().single()) }
        assertEquals(queue.lease(), DurableLabQueue(disk, cipher, "a").lease())
    }

    @Test fun duplicateIdentityRequiresSamePayloadAndAckCannotDeleteDifferentPayload() {
        val queue = DurableLabQueue(Disk(), cipher(), "a")
        queue.enqueue("a", "first"); queue.enqueue("a", "first")
        assertThrows(IllegalArgumentException::class.java) { queue.enqueue("a", "other") }
        queue.acknowledge(LabQueueRecord("a", "other"))
        assertEquals(1, queue.lease().size)
    }

    @Test fun restartRestoresCiphertextWithoutPlaintext() {
        val disk = Disk(); val cipher = cipher()
        DurableLabQueue(disk, cipher, "device-a").enqueue("event-a", "synthetic-coordinate")
        assertFalse(String(disk.bytes!!).contains("synthetic-coordinate"))
        assertEquals(LabQueueRecord("event-a", "synthetic-coordinate"),
            DurableLabQueue(disk, cipher, "device-a").lease().single())
    }
}
