package org.madalasa.madalasa.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.madalasa.madalasa.domain.Freshness
import org.madalasa.madalasa.ui.theme.ThemeCTokens

data class ChildActivityCardState(
    val childId: String,
    val alias: String,
    val freeServiceState: String = "UNAVAILABLE",
    val queuePosition: Long? = null,
    val batteryPercent: Int? = null,
    val isCharging: Boolean? = null,
    val locationFreshness: Freshness = Freshness.UNAVAILABLE,
    val lastObservedEpochMs: Long? = null,
    val hasActiveSos: Boolean = false,
    val activeSosEventId: String? = null
) {
    fun batteryDisplay(): String = formatBattery(batteryPercent, isCharging)

    fun serviceStatusDisplay(): String = formatServiceStatus(freeServiceState, queuePosition)

    fun locationDisplay(nowEpochMs: Long = System.currentTimeMillis()): String =
        formatLocationStatus(locationFreshness, lastObservedEpochMs, nowEpochMs)

    companion object {
        fun formatBattery(batteryPercent: Int?, isCharging: Boolean?): String {
            return if (batteryPercent != null && batteryPercent in 0..100) {
                "$batteryPercent% ${if (isCharging == true) "⚡ Charging" else "🔋"}"
            } else {
                "Battery telemetry unavailable"
            }
        }

        fun formatServiceStatus(freeServiceState: String, queuePosition: Long?): String {
            return when (freeServiceState) {
                "ADMITTED" -> "Active · Free Tier"
                "QUEUED" -> "Waitlisted (#${queuePosition ?: "?"} in queue of 108)"
                else -> "Service unavailable"
            }
        }

        fun formatLocationStatus(
            freshness: Freshness,
            lastObservedEpochMs: Long?,
            nowEpochMs: Long = System.currentTimeMillis()
        ): String {
            return when (freshness) {
                Freshness.VERIFIED_CURRENT -> {
                    val ageMins = lastObservedEpochMs?.let {
                        val diff = (nowEpochMs - it) / 60_000
                        if (diff >= 0) diff else null
                    }
                    if (ageMins != null) "Verified current · ${ageMins}m ago" else "Verified current"
                }
                Freshness.DELAYED -> {
                    val ageMins = lastObservedEpochMs?.let { (nowEpochMs - it) / 60_000 }
                    if (ageMins != null && ageMins >= 0) "Delayed update · ${ageMins}m ago" else "Delayed update"
                }
                Freshness.LAST_KNOWN -> {
                    val ageMins = lastObservedEpochMs?.let { (nowEpochMs - it) / 60_000 }
                    if (ageMins != null && ageMins >= 0) "Last known · ${ageMins}m ago" else "Last known location"
                }
                Freshness.UNKNOWN, Freshness.UNAVAILABLE -> {
                    "Location unavailable · No coordinates inferred"
                }
            }
        }
    }
}

@Composable
fun ChildActivityCard(
    state: ChildActivityCardState,
    modifier: Modifier = Modifier,
    onCardClick: () -> Unit = {},
    onAcknowledgeSos: (String) -> Unit = {}
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .clickable(onClick = onCardClick),
        colors = CardDefaults.cardColors(containerColor = ThemeCTokens.PaleWarmSurface),
        shape = RoundedCornerShape(12.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // SOS Emergency Banner if active
            if (state.hasActiveSos && state.activeSosEventId != null) {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = ThemeCTokens.Vermilion.copy(alpha = 0.15f)),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Column(
                        modifier = Modifier.padding(12.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Text(
                            text = "EMERGENCY SOS ACTIVE",
                            fontWeight = FontWeight.Bold,
                            color = ThemeCTokens.Vermilion,
                            fontSize = 14.sp
                        )
                        Text(
                            text = "A manual SOS was raised by ${state.alias}. Tap below to acknowledge.",
                            style = MaterialTheme.typography.bodySmall,
                            color = ThemeCTokens.Ink
                        )
                        Button(
                            onClick = { onAcknowledgeSos(state.activeSosEventId) },
                            colors = ButtonDefaults.buttonColors(
                                containerColor = ThemeCTokens.Vermilion,
                                contentColor = Color.White
                            ),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text("Acknowledge SOS", fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }

            // Header: Child alias and service admission status
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = state.alias,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = ThemeCTokens.DeepIndigo
                )
                Text(
                    text = state.serviceStatusDisplay(),
                    style = MaterialTheme.typography.labelMedium,
                    color = if (state.freeServiceState == "ADMITTED") ThemeCTokens.Teal else ThemeCTokens.TurmericGold,
                    fontWeight = FontWeight.SemiBold
                )
            }

            // Battery and Telemetry Status
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = "Device Battery:",
                    style = MaterialTheme.typography.bodySmall,
                    color = ThemeCTokens.MutedText
                )
                Text(
                    text = state.batteryDisplay(),
                    style = MaterialTheme.typography.bodySmall,
                    fontWeight = FontWeight.Medium,
                    color = ThemeCTokens.Ink
                )
            }

            // Location & Freshness Status
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = "Location State:",
                    style = MaterialTheme.typography.bodySmall,
                    color = ThemeCTokens.MutedText
                )
                Text(
                    text = state.locationDisplay(),
                    style = MaterialTheme.typography.bodySmall,
                    fontWeight = FontWeight.Medium,
                    color = when (state.locationFreshness) {
                        Freshness.VERIFIED_CURRENT -> ThemeCTokens.Teal
                        Freshness.DELAYED -> ThemeCTokens.TurmericGold
                        else -> ThemeCTokens.MutedText
                    }
                )
            }

            Spacer(modifier = Modifier.height(4.dp))

            // Honest privacy & capability disclosure
            Text(
                text = "Notice: Free V1 shows verified positions only. Battery and location update via scheduled sync; no continuous covert tracking.",
                style = MaterialTheme.typography.labelSmall,
                color = ThemeCTokens.MutedText,
                fontSize = 11.sp
            )
        }
    }
}
