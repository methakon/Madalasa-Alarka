package org.madalasa.alarka.ui.screens

import android.Manifest
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
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

                StatusRow(
                    permission = "Location (Fine/Coarse)",
                    status = when {
                        report == null -> "Unknown — scan pending"
                        report.permissionsGranted.contains(Manifest.permission.ACCESS_FINE_LOCATION) -> "Fine grant present · feature OFF pending approval"
                        report.permissionsGranted.contains(Manifest.permission.ACCESS_COARSE_LOCATION) -> "Approximate grant present · feature OFF pending approval"
                        else -> "Not granted · feature OFF"
                    },
                    color = ThemeCColors.Teal
                )
                StatusRow(
                    permission = "Activity Recognition",
                    status = "Not requested in this build",
                    color = ThemeCColors.Teal
                )
                StatusRow(
                    permission = "Persistent Notification",
                    status = "No active background monitoring service",
                    color = ThemeCColors.Indigo
                )
                StatusRow(
                    permission = "Covert Capture / Recording",
                    status = "Strictly Prohibited",
                    color = ThemeCColors.Leaf
                )
            }
        }

        Text("Hardware presence and Android permission do not authorize monitoring. " +
            "No location, microphone, camera or usage data is collected by this screen.",
            style = MaterialTheme.typography.bodySmall)
        OutlinedButton(onClick = onRefresh, modifier = Modifier.fillMaxWidth()) {
            Text("Refresh local Android status")
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
