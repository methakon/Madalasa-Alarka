package org.madalasa.alarka.service

import org.junit.Assert.*
import org.junit.Test
import java.io.File

/** Source-set/entry wiring regression only; not Android runtime evidence. */
class LabWiringTest {
    @Test fun releaseExcludesLabAndStartIsExplicitAndForeground() {
        val debug = File("src/debug/AndroidManifest.xml").readText()
        val main = File("src/main/AndroidManifest.xml").readText()
        assertTrue(debug.contains("LabLocationService"))
        assertTrue(debug.contains("LabLocationActivity"))
        assertFalse(main.contains("LabLocation"))
        val activity = File("src/debug/kotlin/org/madalasa/alarka/LabLocationActivity.kt").readText()
        assertTrue(activity.contains("requestPermissions("))
        assertTrue(activity.contains("startForegroundService("))
        assertTrue(activity.contains("setChecked(false)"))
        val service = File("src/debug/kotlin/org/madalasa/alarka/service/LabLocationService.kt").readText()
        assertTrue(service.contains("requestLocationUpdates("))
        assertTrue(service.contains("removeUpdates("))
        assertTrue(service.contains("START_NOT_STICKY"))
        assertTrue(service.contains("readConsentStatus()"))
        assertTrue(service.contains("BATTERY_PROPERTY_CAPACITY"))
        assertTrue(service.contains("transport.health("))
        assertFalse(service.contains("SecureLocalQueue("))
    }
}
