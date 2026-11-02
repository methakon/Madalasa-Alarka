package org.madalasa.alarka.ui.screens

import android.Manifest
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.madalasa.alarka.service.DeviceCapabilityReport
import org.madalasa.alarka.service.ServerConsentStatus
import org.madalasa.uicommon.ThemeCColors

/**
 * Figma PRIV-UI-05/06, nodes 159:79 and 159:98.
 * No monitoring, permissions, status upload or remote capture is started here.
 * The only platform operation is an explicit user-initiated app Settings link.
 */
enum class ChildPrivacyPage(val route: String, val nodeId: String) {
    TRANSPARENCY("privacy/transparency", "159:79"),
    LOCATION_UNAVAILABLE("privacy/location_unavailable", "159:98");

    companion object {
        fun fromRoute(route: String?): ChildPrivacyPage? =
            entries.firstOrNull { it.route == route }
    }
}

internal enum class LocationGrantState {
    UNKNOWN, FINE_GRANTED, APPROXIMATE_GRANTED, NOT_GRANTED
}

/** A missing app grant is not proof of an explicit user denial. */
internal fun locationGrantState(report: DeviceCapabilityReport?): LocationGrantState = when {
    report == null -> LocationGrantState.UNKNOWN
    Manifest.permission.ACCESS_FINE_LOCATION in report.permissionsGranted ->
        LocationGrantState.FINE_GRANTED
    Manifest.permission.ACCESS_COARSE_LOCATION in report.permissionsGranted ->
        LocationGrantState.APPROXIMATE_GRANTED
    else -> LocationGrantState.NOT_GRANTED
}

internal fun locationGrantDescription(report: DeviceCapabilityReport?): String =
    when (locationGrantState(report)) {
        LocationGrantState.UNKNOWN -> "UNKNOWN · No current Android permission snapshot"
        LocationGrantState.FINE_GRANTED -> "GRANTED · Precise Android app grant; monitoring remains disabled"
        LocationGrantState.APPROXIMATE_GRANTED -> "PARTIAL · Approximate Android app grant; monitoring remains disabled"
        LocationGrantState.NOT_GRANTED -> "NOT GRANTED · May be unrequested or denied; not bypassed"
    }

internal data class ChildPrivacyRow(val title: String, val value: String)

internal fun childPrivacyRows(
    page: ChildPrivacyPage,
    report: DeviceCapabilityReport?,
    server: ServerConsentStatus? = null
): List<ChildPrivacyRow> = when (page) {
    ChildPrivacyPage.TRANSPARENCY -> listOf(
        ChildPrivacyRow("Active purposes", if (server == null) "UNKNOWN · No server consent status verified." else
            "Server consent · core=${server.coreConsent}, location=${server.locationConsent}, usage=${server.usageConsent}, media=${server.mediaConsent}"),
        ChildPrivacyRow("Device permissions", locationGrantDescription(report)),
        ChildPrivacyRow("Policy status", if (server == null) "UNKNOWN · No signed purpose-policy version or server acknowledgment." else
            "Server: collection authorized=${server.collectionAuthorized}; device permissions checked separately."),
        ChildPrivacyRow("Privacy controls", "Review Android permissions, sharing status and help.")
    )
    ChildPrivacyPage.LOCATION_UNAVAILABLE -> listOf(
        ChildPrivacyRow("What is affected", "GPS observations cannot be shared by this UI. Location collection is disabled."),
        ChildPrivacyRow("Current status", locationGrantDescription(report)),
        ChildPrivacyRow("What to do", "Review this app's Android permissions in Settings. Nothing is silently enabled."),
        ChildPrivacyRow("Offline behavior", "Queued events must never bypass revoked permission, purpose or device authorization.")
    )
}

@Composable
fun ChildPrivacyScreen(
    page: ChildPrivacyPage,
    report: DeviceCapabilityReport?,
    onBack: () -> Unit,
    onShowLocationUnavailable: () -> Unit,
    onOpenAndroidSettings: () -> Unit,
    modifier: Modifier = Modifier,
    openSettingsEnabled: Boolean = true,
    serverStatus: ServerConsentStatus? = null,
    serverError: String? = null
) {
    val ink = ThemeCColors.Ink
    val red = ThemeCColors.Vermilion
    val indigo = ThemeCColors.Indigo
    val muted = Color(0xFF6D6A65)
    val label = if (page == ChildPrivacyPage.TRANSPARENCY)
        "CHILD DEVICE · VISIBLE" else "CHILD DEVICE · PERMISSION STATUS"
    val title = if (page == ChildPrivacyPage.TRANSPARENCY)
        "Monitoring information" else "Location unavailable"
    val subtitle = if (page == ChildPrivacyPage.TRANSPARENCY)
        "Controller: guardian not verified" else
        "Android location permission or authorized policy is unavailable"

    Column(
        modifier.fillMaxSize().background(ThemeCColors.Parchment)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        TextButton(onClick = onBack, modifier = Modifier.heightIn(min = 48.dp)) {
            Text("‹ Back", color = indigo)
        }
        Text(label, color = red, fontSize = 12.sp, fontWeight = FontWeight.Bold)
        Text(title, color = ink, fontSize = 26.sp, fontWeight = FontWeight.Bold)
        Text(subtitle, color = muted, fontSize = 14.sp)

        childPrivacyRows(page, report, serverStatus).forEachIndexed { index, row ->
            val isPermission = row.title == "Device permissions" || row.title == "What to do"
            Surface(
                modifier = Modifier.fillMaxWidth().heightIn(min = 80.dp)
                    .clickable(enabled = isPermission && openSettingsEnabled) { onOpenAndroidSettings() },
                shape = RoundedCornerShape(12.dp),
                color = if (index == 0) Color(0xFFF2E6D2) else Color.White
            ) {
                Column(
                    Modifier.padding(horizontal = 12.dp, vertical = 14.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(row.title, color = indigo, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                    Text(row.value, color = ink, fontSize = 13.sp, lineHeight = 19.sp)
                }
            }
        }
        if (page == ChildPrivacyPage.TRANSPARENCY) {
            OutlinedButton(
                onClick = onShowLocationUnavailable,
                modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)
            ) { Text("View location-unavailable guidance") }
        }
        OutlinedButton(
            onClick = onOpenAndroidSettings,
            enabled = openSettingsEnabled,
            modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)
        ) { Text("Review Android app permissions") }

        Surface(color = Color(0xFFF2E6D2), shape = RoundedCornerShape(12.dp)) {
            Column(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 14.dp),
                verticalArrangement = Arrangement.spacedBy(5.dp)) {
                Text("SPECIFIED — no live child monitoring enabled by this screen",
                    color = red, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                Text("Figma " + page.nodeId + " · PRIVACY_CONTROLS_V0_TECHNICAL_AND_UI_SPEC_2026-11-02.md",
                    color = muted, fontSize = 11.sp, lineHeight = 15.sp)
                Text(serverError ?: "An Android app grant is not a verified guardian policy; permission removal always wins.",
                    color = muted, fontSize = 11.sp)
            }
        }
    }
}
