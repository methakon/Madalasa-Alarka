package org.madalasa.alarka.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import org.madalasa.uicommon.APButton
import org.madalasa.uicommon.APTopBar
import org.madalasa.uicommon.ThemeCColors

@Composable
fun ConnectivityScreen(
    connectivityStatus: String,
    onNavigateNext: () -> Unit,
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
            title = "Connectivity & Signaling",
            subtitle = "Network connectivity and VPS signaling channel status"
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
                    text = "Signaling Channel Status",
                    style = MaterialTheme.typography.titleMedium
                )

                ConnectivityItem(
                    label = "Channel Status",
                    value = connectivityStatus
                )
                ConnectivityItem(
                    label = "Signaling Server",
                    value = "api.berhampore.in (Synthetic Endpoint)"
                )
                ConnectivityItem(
                    label = "WebRTC / ICE State",
                    value = "Ready / Standby"
                )
                ConnectivityItem(
                    label = "Heartbeat Interval",
                    value = "60s (Design Contract)"
                )
            }
        }

        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = ThemeCColors.Parchment
            )
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    text = "Signaling architecture: WebSocket/HTTPS to Drogon C++20 backend with direct P2P data channel fallback. No full-device VPN required.",
                    style = MaterialTheme.typography.bodySmall,
                    color = ThemeCColors.Ink.copy(alpha = 0.8f)
                )
            }
        }

        APButton(
            label = "View Account Information",
            onClick = onNavigateNext
        )
    }
}

@Composable
private fun ConnectivityItem(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label, style = MaterialTheme.typography.bodyMedium)
        Text(value, style = MaterialTheme.typography.bodyMedium, color = ThemeCColors.Teal)
    }
}
