package org.madalasa.alarka

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.madalasa.alarka.service.AndroidLabQueue
import java.io.File
import java.util.UUID

/** No GPS or network. Requires Android Keystore; COMPILED ONLY until owner-run. */
@RunWith(AndroidJUnit4::class)
class DurableLabQueueInstrumentedTest {
    @Test fun realKeystoreAtomicRestartAndRevokedQueueSurvive() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val device = UUID.randomUUID().toString()
        val file = File(context.noBackupFilesDir, "lab-queue-$device.enc")
        try {
            val first = AndroidLabQueue.open(context, device)
            first.enqueue("synthetic-event", "synthetic-location-fixture")
            assertFalse(String(file.readBytes()).contains("synthetic-location-fixture"))
            val second = AndroidLabQueue.open(context, device)
            assertEquals(first.lease(), second.lease())
            second.halt()
            val restored = AndroidLabQueue.open(context, device)
            assertTrue(restored.lease().isEmpty())
            assertThrows(IllegalStateException::class.java) { restored.enqueue("x", "fixture") }
        } finally { file.delete(); File(file.path + ".bak").delete() }
    }
}
