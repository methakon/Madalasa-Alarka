package org.madalasa.alarka.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.ui.platform.LocalContext
import android.content.pm.ApplicationInfo
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.madalasa.alarka.service.EnrollmentResult
import org.madalasa.alarka.service.ManualSosStage
import org.madalasa.alarka.service.ManualSosState
import org.madalasa.uicommon.APButton
import org.madalasa.uicommon.APTopBar
import org.madalasa.uicommon.ThemeCColors

@Composable
fun AccountInfoScreen(
    enrollmentResult: EnrollmentResult?,
    sosState: ManualSosState? = null,
    isOfflineMode: Boolean = false,
    onTriggerSos: () -> Unit = {},
    onRetrySos: () -> Unit = {},
    onAcknowledgeSos: () -> Unit = {},
    onToggleOffline: () -> Unit = {},
    onResetSos: () -> Unit = {},
    onResetPairing: () -> Unit = {},
    onNavigateHome: () -> Unit = {},
    modifier: Modifier = Modifier
) {
    val scrollState = rememberScrollState()
    val context = LocalContext.current
    val isDebugPreview = (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(16.dp)
            .verticalScroll(scrollState),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        APTopBar(
            title = "Account Information",
            subtitle = "Child identity and emergency safety controls"
        )

        // This is a local-only animation, NOT an emergency alert. Hide from release.
        if (isDebugPreview) Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = ThemeCColors.Surface
            ),
            shape = RoundedCornerShape(12.dp)
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    text = "SOS — LOCAL SIMULATION ONLY",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = ThemeCColors.Critical
                )

                Text(
                    text = "Development preview. No SOS is sent, no notification is delivered, no guardian is contacted, and no offline SOS is saved. Never rely on this demo in an emergency.",
                    style = MaterialTheme.typography.bodySmall,
                    color = ThemeCColors.Ink.copy(alpha = 0.8f)
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Simulate Offline Outage (demo only)",
                        style = MaterialTheme.typography.bodyMedium
                    )
                    Switch(
                        checked = isOfflineMode,
                        onCheckedChange = { onToggleOffline() }
                    )
                }

                if (sosState == null) {
                    Button(
                        onClick = onTriggerSos,
                        colors = ButtonDefaults.buttonColors(
                            containerColor = ThemeCColors.Critical,
                            contentColor = Color.White
                        ),
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(52.dp),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text(
                            text = "SIMULATE SOS — NO ALERT SENT",
                            fontWeight = FontWeight.Bold,
                            fontSize = 16.sp
                        )
                    }
                } else {
                    val (stageColor, stageText, stageDesc) = when (sosState.stage) {
                        ManualSosStage.LOCAL_QUEUED -> Triple(
                            Color(0xFFE65100),
                            "LOCAL_QUEUED",
                            "Simulated event created in memory only; no durable queue."
                        )
                        ManualSosStage.SENDING -> Triple(
                            ThemeCColors.Indigo,
                            "SENDING",
                            "Simulating a send; no network request occurs."
                        )
                        ManualSosStage.SERVER_ACCEPTED -> Triple(
                            ThemeCColors.Teal,
                            "SERVER_ACCEPTED",
                            "Simulated acceptance only. Backend not contacted."
                        )
                        ManualSosStage.NOTIFICATION_DELIVERED -> Triple(
                            ThemeCColors.Indigo,
                            "NOTIFICATION_DELIVERED",
                            "Simulated delivery only. No guardian phone contacted."
                        )
                        ManualSosStage.GUARDIAN_SIMULATED ACK -> Triple(
                            Color(0xFF2E7D32),
                            "GUARDIAN_SIMULATED ACK",
                            "Simulated acknowledgment only. No guardian confirmed anything."
                        )
                        ManualSosStage.DELIVERY_FAILED -> Triple(
                            ThemeCColors.Critical,
                            "DELIVERY_FAILED",
                            "Simulated failure only. Nothing saved durably; closing app loses event."
                        )
                        ManualSosStage.AUTHORIZATION_REVOKED -> Triple(
                            Color.Gray,
                            "AUTHORIZATION_REVOKED",
                            "Device pairing or consent was revoked."
                        )
                    }

                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(stageColor.copy(alpha = 0.12f), RoundedCornerShape(8.dp))
                            .padding(12.dp)
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Text(
                                    text = "DEMO ONLY: $stageText",
                                    fontWeight = FontWeight.Bold,
                                    color = stageColor
                                )
                                Text(
                                    text = if (sosState.guardianHasAcknowledged) "SIMULATED ACK" else "UNSIMULATED ACK",
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = if (sosState.guardianHasAcknowledged) Color(0xFF2E7D32) else Color.Gray
                                )
                            }
                            Text(
                                text = stageDesc,
                                style = MaterialTheme.typography.bodySmall,
                                color = ThemeCColors.Ink
                            )
                        }
                    }

                    if (sosState.stage == ManualSosStage.DELIVERY_FAILED) {
                        Button(
                            onClick = onRetrySos,
                            colors = ButtonDefaults.buttonColors(
                                containerColor = ThemeCColors.Gold,
                                contentColor = ThemeCColors.Ink
                            ),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text("Simulate Retry (local only)", fontWeight = FontWeight.Bold)
                        }
                    }

                    if (sosState.stage == ManualSosStage.SERVER_ACCEPTED ||
                        sosState.stage == ManualSosStage.NOTIFICATION_DELIVERED) {
                        OutlinedButton(
                            onClick = onAcknowledgeSos,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text("Simulate ACK (local only)", color = ThemeCColors.Indigo)
                        }
                    }

                    if (sosState.guardianHasAcknowledged || sosState.stage == ManualSosStage.DELIVERY_FAILED) {
                        OutlinedButton(
                            onClick = onResetSos,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text("Reset SOS State")
                        }
                    }
                }
            }
        }

        // Device Pseudonym & Association
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = ThemeCColors.Surface
            ),
            shape = RoundedCornerShape(12.dp)
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    text = "Device Pseudonym & Association",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
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
