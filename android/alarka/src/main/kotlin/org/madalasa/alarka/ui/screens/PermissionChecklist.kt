package org.madalasa.alarka.ui.screens

import android.Manifest
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.madalasa.alarka.service.DeviceCapabilityReport
import org.madalasa.uicommon.ThemeCColors

data class PermissionChecklistItem(
    val id: String,
    val title: String,
    val isHardwareDetected: Boolean,
    val isPermissionGranted: Boolean,
    val statusText: String,
    val explanation: String
)

object PermissionChecklistEvaluator {
    fun buildChecklist(report: DeviceCapabilityReport?): List<PermissionChecklistItem> {
        val items = mutableListOf<PermissionChecklistItem>()

        // 1. Precise/Approximate Location
        val hasLocationHardware = report?.hasGpsHardware == true || report?.hasNetworkLocationHardware == true
        val hasFine = report?.permissionsGranted?.contains(Manifest.permission.ACCESS_FINE_LOCATION) == true
        val hasCoarse = report?.permissionsGranted?.contains(Manifest.permission.ACCESS_COARSE_LOCATION) == true
        val locationGranted = hasFine || hasCoarse
        items.add(
            PermissionChecklistItem(
                id = "location",
                title = "Location (Fine / Coarse)",
                isHardwareDetected = hasLocationHardware,
                isPermissionGranted = locationGranted,
                statusText = when {
                    report == null -> "Unknown — scan pending"
                    hasFine -> "Fine location granted · feature OFF pending pairing"
                    hasCoarse -> "Approximate location granted · feature OFF pending pairing"
                    else -> "Not granted · feature OFF"
                },
                explanation = if (hasLocationHardware && !locationGranted) {
                    "Hardware GPS is detected on this device, but OS permission has NOT been granted."
                } else if (locationGranted) {
                    "Permission granted by OS. Monitoring remains OFF until verified parent pairing."
                } else {
                    "No location hardware or grants available."
                }
            )
        )

        // 2. Background Location (Android 10+ / API 29+)
        val hasBgLocation = report?.permissionsGranted?.contains(Manifest.permission.ACCESS_BACKGROUND_LOCATION) == true
        items.add(
            PermissionChecklistItem(
                id = "background_location",
                title = "Background Location Access",
                isHardwareDetected = hasLocationHardware,
                isPermissionGranted = hasBgLocation,
                statusText = if (hasBgLocation) "Granted by user" else "Not granted",
                explanation = "Requires two-step consent: foreground permission first, then separate background setting on Android 10+."
            )
        )

        // 3. Persistent Notifications (Android 13+ / API 33+)
        val api = report?.osVersion ?: 0
        val notifGranted = if (api >= 33) {
            report?.permissionsGranted?.contains(Manifest.permission.POST_NOTIFICATIONS) == true
        } else {
            report?.notificationsEnabled == true
        }
        items.add(
            PermissionChecklistItem(
                id = "notifications",
                title = "Notification Visibility",
                isHardwareDetected = true,
                isPermissionGranted = notifGranted,
                statusText = if (notifGranted) "Enabled" else "Disabled / Not granted",
                explanation = "Ensures an honest, visible ongoing notification is shown whenever active monitoring occurs."
            )
        )

        // 4. Activity Recognition
        items.add(
            PermissionChecklistItem(
                id = "activity_recognition",
                title = "Physical Activity Recognition",
                isHardwareDetected = false,
                isPermissionGranted = false,
                statusText = "Not requested in this build",
                explanation = "Sensor-assisted automatic movement classification is deferred in Free V1."
            )
        )

        // 5. Covert Recording (Camera / Mic)
        val hasCameraOrMic = report?.hasCameraHardware == true || report?.hasMicrophoneHardware == true
        items.add(
            PermissionChecklistItem(
                id = "covert_capture",
                title = "Covert Microphone / Camera Capture",
                isHardwareDetected = hasCameraOrMic,
                isPermissionGranted = false,
                statusText = "Strictly Prohibited & Inactive",
                explanation = "Zero audio/video surveillance or covert recording in Free V1."
            )
        )

        return items
    }
}

@Composable
fun PermissionChecklistView(
    items: List<PermissionChecklistItem>,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        items.forEach { item ->
            PermissionChecklistRow(item = item)
        }
    }
}

@Composable
fun PermissionChecklistRow(
    item: PermissionChecklistItem,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = item.title,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold
            )
            Text(
                text = if (item.isPermissionGranted) "✓ Granted" else "✗ Not granted",
                style = MaterialTheme.typography.labelSmall,
                color = if (item.isPermissionGranted) ThemeCColors.Leaf else ThemeCColors.Vermilion,
                fontWeight = FontWeight.Bold
            )
        }
        Text(
            text = item.statusText,
            style = MaterialTheme.typography.bodySmall,
            color = ThemeCColors.Indigo
        )
        Text(
            text = item.explanation,
            style = MaterialTheme.typography.labelSmall,
            color = Color.Gray,
            fontSize = 11.sp
        )
    }
}
