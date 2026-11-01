package org.madalasa.alarka.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import org.madalasa.uicommon.APButton
import org.madalasa.uicommon.APTopBar
import org.madalasa.uicommon.ThemeCColors

@Composable
fun TransparencyDisclosureScreen(
    isAcknowledged: Boolean,
    onAcknowledge: () -> Unit,
    onNavigateNext: () -> Unit,
    onReadPrivacy: () -> Unit,
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
            title = "Alarka Child Companion",
            subtitle = "Transparency & Mutual Awareness Disclosure"
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
                    text = "Child Privacy & Rights Charter",
                    style = MaterialTheme.typography.titleMedium,
                    color = ThemeCColors.Indigo
                )

                Text(
                    text = "1. Exact-Child Pairing: This app connects exclusively to verified guardians approved for this exact child. No public or shared family directory exists.",
                    style = MaterialTheme.typography.bodyMedium
                )

                Text(
                    text = "2. No Hidden Surveillance: Covert camera capture, ambient microphone recording, screen scraping, and keylogging are strictly prohibited by architecture and code.",
                    style = MaterialTheme.typography.bodyMedium
                )

                Text(
                    text = "3. Visible Protection: Whenever child companion services are operational, a prominent, persistent Android system notification is visible on this device.",
                    style = MaterialTheme.typography.bodyMedium
                )

                Text(
                    text = "4. Local Device Checks: Hardware and app-permission status may be inspected on this device. This screen does not collect or transmit GPS, audio, camera or private files; backend pairing and monitoring remain development-gated.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = ThemeCColors.Teal
                )
            }
        }

        OutlinedButton(onClick = onReadPrivacy, modifier = Modifier.fillMaxWidth()) {
            Text("Monitoring information & privacy controls")
        }

        if (!isAcknowledged) {
            APButton(
                label = "I Understand & Agree",
                onClick = onAcknowledge
            )
        } else {
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = ThemeCColors.Leaf.copy(alpha = 0.15f)
                )
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        text = "Disclosure acknowledged. Device setup may proceed.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = ThemeCColors.Leaf
                    )
                }
            }

            APButton(
                label = "Continue to Device Pairing",
                onClick = onNavigateNext
            )
        }
    }
}
