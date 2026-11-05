package org.madalasa.alarka

import android.Manifest
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.widget.*
import androidx.activity.ComponentActivity
import androidx.lifecycle.Lifecycle
import org.madalasa.alarka.service.KeystoreDeviceSessionStore
import org.madalasa.alarka.service.LabLocationService

/** Separate debug launcher; opening it NEVER grants permission or starts collection. */
class LabLocationActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL; setPadding(24, 24, 24, 24)
        }
        val status = TextView(this).apply { text = "Capture OFF. Adult-owner lab only. No media capture.\n" +
            "Pair first in Alarka using a guardian-issued code and the configured HTTPS API.\n" +
            "Precise location is optional. Background permission is not requested.\n" +
            "Offline/unknown authority stops collection; queued records remain encrypted.\n" +
            "Permission or authority revocation invalidates this local lab session." }
        layout.addView(status)
        val consent = CheckBox(this).apply {
            text = "I am the adult device owner and explicitly opt in to this visible location lab session"
            setChecked(false)
        }
        layout.addView(consent)
        fun button(label: String, action: () -> Unit) {
            layout.addView(Button(this).apply { text = label; setOnClickListener { action() } })
        }
        button("Open Alarka pairing") { startActivity(Intent(this, MainActivity::class.java)) }
        button("Request Android location and notification permissions") {
            if (!consent.isChecked) { status.text = "Adult lab opt-in is required first." }
            else {
                val permissions = mutableListOf(Manifest.permission.ACCESS_COARSE_LOCATION,
                    Manifest.permission.ACCESS_FINE_LOCATION)
                if (Build.VERSION.SDK_INT >= 33) permissions.add(Manifest.permission.POST_NOTIFICATIONS)
                requestPermissions(permissions.toTypedArray(), 1210)
            }
        }
        button("Start visible adult location lab") {
            if (!resources.getBoolean(R.bool.alarka_location_lab_enabled)) {
                status.text = "Capture OFF: this debug binary was built without the explicit lab gate."
            } else if (!consent.isChecked || !lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) {
                status.text = "Open this screen and explicitly opt in first."
            } else if (KeystoreDeviceSessionStore(this).currentSession() == null) {
                status.text = "Capture OFF: complete real HTTPS enrollment first; preview identity is not accepted."
            } else {
                try {
                    startForegroundService(Intent(this, LabLocationService::class.java)
                        .putExtra(LabLocationService.OPT_IN, true))
                    status.text = "Start requested, NOT proof of collection. Verify the ongoing notification and server receipt."
                } catch (_: RuntimeException) { status.text = "Android refused start. Capture OFF; no automatic retry." }
            }
        }
        button("Stop location lab") {
            stopService(Intent(this, LabLocationService::class.java))
            consent.isChecked = false
            status.text = "Capture OFF. Local encrypted pending records are retained; no automatic restart."
        }
        setContentView(ScrollView(this).apply { addView(layout) })
    }
}
