package org.madalasa.alarka.ui.screens

import android.Manifest
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import org.madalasa.alarka.service.AndroidLocationSetupPlan
import org.madalasa.alarka.service.LocationSetupAction
import org.madalasa.alarka.service.AlarkaSensor
import org.madalasa.alarka.service.OptionalHardwareModulePolicy
import org.madalasa.alarka.service.ModuleReadiness
import org.madalasa.alarka.service.DeviceCapabilityReport
import org.madalasa.uicommon.APButton
import org.madalasa.uicommon.APTopBar
import org.madalasa.uicommon.ThemeCColors

@Composable
fun PermissionsScreen(
    report: DeviceCapabilityReport?,
    onNavigateNext: () -> Unit,
    onRefresh: () -> Unit,
    onViewCapabilityGuide: () -> Unit,
    onViewPrivacy: () -> Unit,
    permissionPlan: AndroidLocationSetupPlan? = null,
    pairedForOptionalModules: Boolean = false,
    onRequestForegroundLocation: () -> Unit = {},
    onRequestBackgroundLocation: () -> Unit = {},
    onRequestNotifications: () -> Unit = {},
    onOpenLocationSettings: () -> Unit = {},
    onOpenAppSettings: () -> Unit = {},
    onOpenNotificationSettings: () -> Unit = {},
    modifier: Modifier = Modifier
) {
    val scrollState = rememberScrollState()

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(16.dp)
            .verticalScroll(scrollState),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        APTopBar(
            title = "Permissions & Status",
            subtitle = "Read-only Android hardware and app-grant snapshot"
        )

        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = ThemeCColors.Surface
            )
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    text = "Hardware & Capability Audit",
                    style = MaterialTheme.typography.titleMedium
                )

                CapabilityRow(
                    label = "Target Platform SDK",
                    value = report?.let { "Android API ${it.osVersion}" } ?: "Unknown"
                )
                CapabilityRow(
                    label = "GPS Hardware Present",
                    value = when (report?.hasGpsHardware) { true -> "Detected"; false -> "Not detected"; null -> "Unknown" }
                )
                CapabilityRow(
                    label = "Bluetooth Low Energy",
                    value = when (report?.hasBleHardware) { true -> "Detected"; false -> "Not detected"; null -> "Unknown" }
                )
                CapabilityRow("Camera hardware", when (report?.hasCameraHardware) {
                    true -> "Detected"; false -> "Not detected"; null -> "Unknown"
                })
                CapabilityRow("Microphone hardware", when (report?.hasMicrophoneHardware) {
                    true -> "Detected"; false -> "Not detected"; null -> "Unknown"
                })
            }
        }

        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = ThemeCColors.Surface)
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Text("Optional hardware inventory",style=MaterialTheme.typography.titleMedium)
                Text(
                    "Missing hardware disables only that optional function. " +
                        "The diagnostic does not read motion samples, sound, video or location.",
                    style=MaterialTheme.typography.bodySmall
                )
                val sensors = listOf(
                    "Accelerometer" to AlarkaSensor.ACCELEROMETER,
                    "Gyroscope" to AlarkaSensor.GYROSCOPE,
                    "Proximity" to AlarkaSensor.PROXIMITY,
                    "Ambient light" to AlarkaSensor.AMBIENT_LIGHT,
                    "Linear acceleration" to AlarkaSensor.LINEAR_ACCELERATION,
                    "Gravity" to AlarkaSensor.GRAVITY,
                    "Rotation vector" to AlarkaSensor.ROTATION_VECTOR,
                    "Magnetic / compass" to AlarkaSensor.MAGNETOMETER,
                    "Barometer" to AlarkaSensor.BAROMETER,
                    "Step detector" to AlarkaSensor.STEP_DETECTOR,
                    "Step counter" to AlarkaSensor.STEP_COUNTER,
                    "Significant motion" to AlarkaSensor.SIGNIFICANT_MOTION
                )
                sensors.forEach { (label,key) ->
                    CapabilityRow(label,when {
                        report == null -> "Unknown"
                        report.hardware.sensorPresent(key) -> "Available"
                        else -> "Not present"
                    })
                }
                CapabilityRow("GPS hardware", if(report?.hasGpsHardware==true) "Detected" else
                    if(report==null) "Unknown" else "Not present")
                CapabilityRow("Network location", if(report?.hasNetworkLocationHardware==true) "Detected" else
                    if(report==null) "Unknown" else "Not present")
                CapabilityRow("GPS provider enabled",
                    report?.hardware?.gpsProviderEnabled?.let { if(it) "Yes" else "No" } ?: "Unknown")
                CapabilityRow("Network provider enabled",
                    report?.hardware?.networkProviderEnabled?.let { if(it) "Yes" else "No" } ?: "Unknown")
                CapabilityRow("GNSS constellations",
                    report?.hardware?.gnssObservation?.name?.replace('_',' ') ?: "Unknown")
                Text(
                    "GPS / Galileo / GLONASS / BeiDou / QZSS / NavIC (IRNSS) cannot be " +
                        "certified from a hardware flag. Satellite observations require " +
                        "separate permission and approved, visible GNSS use.",
                    style=MaterialTheme.typography.bodySmall
                )
                CapabilityRow("Battery",
                    report?.hardware?.batteryPercentage?.let { "$it%" }
                        ?: if(report?.hardware?.batteryPresent==false) "No battery" else "Unknown")
                CapabilityRow("Charging",report?.hardware?.batteryCharging?.let {
                    if(it) "Yes" else "No"
                } ?: "Unknown")
                CapabilityRow("Power saving",report?.hardware?.powerSaving?.let {
                    if(it) "Enabled" else "Off"
                } ?: "Unknown")
                if(report!=null) {
                    Text("Module readiness (no monitoring started)",
                        style=MaterialTheme.typography.titleSmall)
                    OptionalHardwareModulePolicy.evaluate(
                        report, paired=pairedForOptionalModules
                    ).forEach { decision ->
                        CapabilityRow(
                            decision.module.name.replace('_',' '),
                            when(decision.readiness) {
                                ModuleReadiness.HARDWARE_MISSING -> "Unavailable"
                                ModuleReadiness.PERMISSION_NOT_DECLARED -> "Not in this build"
                                ModuleReadiness.PERMISSION_REQUIRED -> "Permission needed"
                                ModuleReadiness.AWAITING_PARENT_PAIRING -> "Pairing required"
                                ModuleReadiness.DISABLED_BY_RELEASE_POLICY -> "Feature disabled"
                                ModuleReadiness.AVAILABLE_FOR_APPROVED_SETUP -> "Setup eligible"
                                ModuleReadiness.HARDWARE_DIAGNOSTIC_ONLY -> "Local status only"
                            }
                        )
                    }
                }
                Text(
                    "Motion-only fall detection is not reliable enough to declare an " +
                        "emergency. Manual SOS remains independent of these sensors; " +
                        "SOS reporting still needs verified service authorization.",
                    style=MaterialTheme.typography.bodySmall
                )
            }
        }

        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = ThemeCColors.Surface
            )
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    text = "Permission Grants & Boundary Status",
                    style = MaterialTheme.typography.titleMedium
                )

                val checklistItems = PermissionChecklistEvaluator.buildChecklist(report)
                PermissionChecklistView(items = checklistItems)
            }
        }

        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = ThemeCColors.Surface)
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Text("Android 10–16 compatibility result",
                    style = MaterialTheme.typography.titleMedium)
                Text(
                    permissionPlan?.action?.name?.replace('_', ' ') ?: "Not evaluated",
                    color = ThemeCColors.Indigo
                )
                Text(
                    permissionPlan?.explanation
                        ?: "Refresh local status and verify parent authorization.",
                    style = MaterialTheme.typography.bodySmall
                )
                Text(
                    "Monitoring does not start from this screen. A valid parent pairing, " +
                        "admitted child slot, lawful consent, Android grants and a visible " +
                        "ongoing notification are separately required.",
                    style = MaterialTheme.typography.bodySmall
                )
                when (permissionPlan?.action) {
                    LocationSetupAction.REQUEST_FOREGROUND_LOCATION ->
                        OutlinedButton(
                            onClick = onRequestForegroundLocation,
                            modifier = Modifier.fillMaxWidth()
                        ) { Text("Request location while using the app") }
                    LocationSetupAction.REQUEST_BACKGROUND_LOCATION_ANDROID_10 ->
                        OutlinedButton(
                            onClick = onRequestBackgroundLocation,
                            modifier = Modifier.fillMaxWidth()
                        ) { Text("Request background location separately") }
                    LocationSetupAction.OPEN_BACKGROUND_LOCATION_SETTINGS ->
                        OutlinedButton(
                            onClick = onOpenAppSettings,
                            modifier = Modifier.fillMaxWidth()
                        ) { Text("Review Android app settings") }
                    LocationSetupAction.REQUEST_NOTIFICATION_PERMISSION ->
                        OutlinedButton(
                            onClick = onRequestNotifications,
                            modifier = Modifier.fillMaxWidth()
                        ) { Text("Request monitoring notification permission") }
                    LocationSetupAction.ENABLE_SYSTEM_LOCATION ->
                        OutlinedButton(
                            onClick = onOpenLocationSettings,
                            modifier = Modifier.fillMaxWidth()
                        ) { Text("Open Android location settings") }
                    LocationSetupAction.OPEN_NOTIFICATION_SETTINGS ->
                        OutlinedButton(
                            onClick = onOpenNotificationSettings,
                            modifier = Modifier.fillMaxWidth()
                        ) { Text("Open Android notification settings") }
                    else -> Unit
                }
            }
        }

        Text("Hardware presence and Android permission do not authorize monitoring. " +
            "No location, microphone, camera or usage data is collected by this screen.",
            style = MaterialTheme.typography.bodySmall)
        OutlinedButton(onClick = onRefresh, modifier = Modifier.fillMaxWidth()) {
            Text("Refresh local Android status")
        }
        OutlinedButton(onClick = onViewPrivacy, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) {
            Text("Monitoring information & privacy")
        }
        OutlinedButton(onClick = onViewCapabilityGuide, modifier = Modifier.fillMaxWidth()) {
            Text("View compatibility guide (design examples)")
        }

        APButton(
            label = "Check Connectivity Status",
            onClick = onNavigateNext
        )
    }
}

@Composable
private fun CapabilityRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label, style = MaterialTheme.typography.bodyMedium)
        Text(value, style = MaterialTheme.typography.bodyMedium, color = ThemeCColors.Indigo)
    }
}

@Composable
private fun StatusRow(permission: String, status: String, color: androidx.compose.ui.graphics.Color) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        Text(permission, style = MaterialTheme.typography.bodyMedium)
        Text(status, style = MaterialTheme.typography.bodySmall, color = color)
    }
}
