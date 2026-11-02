package org.madalasa.alarka.manifest

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Manifest-invariant guard for Phase-05 L05-001: "No surveillance or concealed
 * permission onboarding." A pure JVM test (no Android runtime) that parses the
 * shipped AndroidManifest.xml and proves the child build declares no covert-capture
 * or background-tracking permissions and disables backup / cleartext exfiltration.
 */
class AlarkaManifestInvariantTest {

    private fun manifestText(): String {
        // Test working dir is the :alarka module dir under Gradle.
        val candidates = listOf(
            File("src/main/AndroidManifest.xml"),
            File("alarka/src/main/AndroidManifest.xml"),
            File("android/alarka/src/main/AndroidManifest.xml")
        )
        val f = candidates.firstOrNull { it.exists() }
            ?: error("AndroidManifest.xml not found from ${File(".").absolutePath}")
        return f.readText()
    }

    private val forbiddenPermissions = listOf(
        "android.permission.CAMERA",
        "android.permission.RECORD_AUDIO",
        "android.permission.ACCESS_FINE_LOCATION",
        "android.permission.ACCESS_COARSE_LOCATION",
        "android.permission.ACCESS_BACKGROUND_LOCATION",
        "android.permission.READ_SMS",
        "android.permission.RECEIVE_SMS",
        "android.permission.READ_CALL_LOG",
        "android.permission.PACKAGE_USAGE_STATS",
        "android.permission.SYSTEM_ALERT_WINDOW",
        "android.permission.BIND_ACCESSIBILITY_SERVICE",
        "android.permission.BIND_DEVICE_ADMIN",
        "android.permission.QUERY_ALL_PACKAGES"
    )

    @Test
    fun declaresNoCovertCaptureOrTrackingPermissions() {
        val xml = manifestText()
        forbiddenPermissions.forEach { perm ->
            assertFalse(
                "Manifest must not declare surveillance permission $perm",
                xml.contains("\"$perm\"")
            )
        }
    }

    @Test
    fun onlyNormalInternetPermissionIsDeclared() {
        val xml = manifestText()
        val declared = Regex("uses-permission[^>]*android:name=\"([^\"]+)\"")
            .findAll(xml).map { it.groupValues[1] }.toList()
        assertEquals(listOf("android.permission.INTERNET"), declared)
    }

    @Test
    fun backupAndCleartextAreDisabled() {
        val xml = manifestText()
        assertTrue("allowBackup must be false", xml.contains("android:allowBackup=\"false\""))
        assertTrue("usesCleartextTraffic must be false", xml.contains("android:usesCleartextTraffic=\"false\""))
    }
}
