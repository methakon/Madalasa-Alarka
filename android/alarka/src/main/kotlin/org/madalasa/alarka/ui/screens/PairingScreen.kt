package org.madalasa.alarka.ui.screens

import android.content.pm.ApplicationInfo
import androidx.compose.ui.platform.LocalContext
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import org.madalasa.alarka.service.EnrollmentResult
import org.madalasa.uicommon.APButton
import org.madalasa.uicommon.APStatusPanel
import org.madalasa.uicommon.APTopBar
import org.madalasa.uicommon.ThemeCColors

@Composable
fun PairingScreen(
    pairingCode: String,
    suggestedCode: String,
    isEnrolling: Boolean,
    enrollmentResult: EnrollmentResult?,
    errorMessage: String?,
    onCodeChange: (String) -> Unit,
    onSubmit: () -> Unit,
    onNavigateNext: () -> Unit,
    modifier: Modifier = Modifier
) {
    val scrollState = rememberScrollState()
    val context = LocalContext.current
    val syntheticPreview =
        context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(16.dp)
            .verticalScroll(scrollState),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        APTopBar(
            title = "Device Pairing",
            subtitle = "Pair Alarka child companion with Madalasa parent app"
        )

        if (enrollmentResult != null && enrollmentResult.success) {
            APStatusPanel(
                title = if (syntheticPreview) "Synthetic Pairing Preview" else "Device Enrollment Verified",
                detail = if (syntheticPreview)
                    "Mock-only pairing succeeded. No live guardian connection, monitoring or server proof was established."
                else "Verified device enrollment received.",
                actionLabel = "Proceed to Permission & Status",
                onAction = onNavigateNext
            )
        } else {
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
                        text = "Pairing Challenge Code",
                        style = MaterialTheme.typography.titleMedium
                    )

                    Text(
                        text = "Enter the 6-digit challenge code shown on your parent or guardian's Madalasa screen to initiate mutual cryptographic verification.",
                        style = MaterialTheme.typography.bodyMedium
                    )

                    OutlinedTextField(
                        value = pairingCode,
                        onValueChange = onCodeChange,
                        label = { Text("Challenge Code (e.g., $suggestedCode)") },
                        placeholder = { Text(suggestedCode) },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true
                    )

                    if (errorMessage != null) {
                        Text(
                            text = errorMessage,
                            style = MaterialTheme.typography.bodySmall,
                            color = ThemeCColors.Critical
                        )
                    }
                }
            }

            if (isEnrolling) {
                CircularProgressIndicator()
            } else {
                APButton(
                    label = "Submit Pairing Challenge",
                    onClick = onSubmit
                )
            }

            if (syntheticPreview) {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(
                        containerColor = ThemeCColors.Parchment
                    )
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(
                            text = "Synthetic test only: $suggestedCode or 123456. This is NOT cryptographic enrollment.",
                            style = MaterialTheme.typography.bodySmall,
                            color = ThemeCColors.Ink.copy(alpha = 0.7f)
                        )
                    }
                }
            } else {
                Text(
                    "Real device pairing is disabled until server proof-of-possession and guardian authorization are verified.",
                    style = MaterialTheme.typography.bodySmall,
                    color = ThemeCColors.Critical
                )
            }
        }
    }
}
