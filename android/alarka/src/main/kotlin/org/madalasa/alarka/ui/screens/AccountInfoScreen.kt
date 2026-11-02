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
import org.madalasa.alarka.service.EnrollmentResult
import org.madalasa.uicommon.APButton
import org.madalasa.uicommon.APTopBar
import org.madalasa.uicommon.ThemeCColors

@Composable
fun AccountInfoScreen(
    enrollmentResult: EnrollmentResult?,
    onResetPairing: () -> Unit,
    onNavigateHome: () -> Unit,
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
            title = "Account Information",
            subtitle = "Child identity and paired guardian roster"
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
                    text = "Device Pseudonym & Association",
                    style = MaterialTheme.typography.titleMedium
                )

                InfoRow(
                    label = "Device Pseudonym",
                    value = enrollmentResult?.devicePseudonym ?: "Not Enrolled (Standby)"
                )
                InfoRow(
                    label = "Paired Guardian",
                    value = enrollmentResult?.guardianAlias ?: "None"
                )
                InfoRow(
                    label = "Pairing Architecture",
                    value = "Exact-Child Scoped (V2)"
                )
            }
        }

        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = ThemeCColors.Parchment
            )
        ) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = "Emergency Protocol",
                    style = MaterialTheme.typography.titleSmall,
                    color = ThemeCColors.Critical
                )
                Text(
                    text = "In an emergency, child devices can broadcast an SOS packet directly through Drogon VPS signaling to verified guardians.",
                    style = MaterialTheme.typography.bodySmall
                )
            }
        }

        if (enrollmentResult != null && enrollmentResult.success) {
            APButton(
                label = "Reset / Unpair Device",
                onClick = onResetPairing
            )
        }

        APButton(
            label = "Back to Transparency Disclosure",
            onClick = onNavigateHome
        )
    }
}

@Composable
private fun InfoRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label, style = MaterialTheme.typography.bodyMedium)
        Text(value, style = MaterialTheme.typography.bodyMedium, color = ThemeCColors.Indigo)
    }
}
