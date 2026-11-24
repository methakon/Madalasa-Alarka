package org.madalasa.madalasa.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import java.time.Instant
import java.time.Duration
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.madalasa.madalasa.ui.theme.ThemeCTokens
import org.madalasa.madalasa.ui.viewmodel.ParentUiState

enum class ShellTab(val label: String) {
    MAP("Map"),
    HISTORY("History"),
    PLACES("Places"),
    SETTINGS("Settings")
}

@Composable
fun ShellScreen(
    uiState: ParentUiState,
    onNavigateToChildSelection: () -> Unit,
    onNavigateToPrivacy: () -> Unit,
    onExplorePremiumPlans: () -> Unit = {},
    onRefresh: () -> Unit = {},
    onAcknowledgeSignal: (String) -> Unit = {},
    syntheticPreview: Boolean = false
) {
    var selectedTab by remember { mutableStateOf(ShellTab.MAP) }

    Scaffold(
        bottomBar = {
            NavigationBar(
                containerColor = ThemeCTokens.PaleWarmSurface
            ) {
                ShellTab.entries.forEach { tab ->
                    NavigationBarItem(
                        selected = selectedTab == tab,
                        onClick = { selectedTab = tab },
                        label = { Text(tab.label) },
                        icon = { Box {} },
                        colors = NavigationBarItemDefaults.colors(
                            selectedTextColor = ThemeCTokens.DeepIndigo,
                            unselectedTextColor = ThemeCTokens.MutedText,
                            indicatorColor = ThemeCTokens.TurmericGold.copy(alpha = 0.3f)
                        )
                    )
                }
            }
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(ThemeCTokens.Parchment)
                .padding(innerPadding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Madālasā — ${selectedTab.label}",
                    style = MaterialTheme.typography.titleMedium,
                    color = ThemeCTokens.DeepIndigo,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f)
                )
            }

            Spacer(modifier = Modifier.height(16.dp))
            if (syntheticPreview) {
                Text("SYNTHETIC DEVELOPMENT PREVIEW · NO LIVE CHILD MONITORING",
                    color = ThemeCTokens.Vermilion,
                    fontWeight = FontWeight.Bold,
                    fontSize = 12.sp)
                Spacer(modifier = Modifier.height(12.dp))
            }

            val child = uiState.children.singleOrNull { it.id == uiState.selectedChildId }
            if (child != null) {
                val loc = uiState.selectedChildLocation?.takeIf { it.childId == child.id }
                val sos = uiState.activeSignals.firstOrNull()
                ChildActivityCard(
                    state = ChildActivityCardState(
                        childId = child.id,
                        alias = child.alias,
                        freeServiceState = child.freeServiceState,
                        queuePosition = child.queuePosition,
                        batteryPercent = null,
                        isCharging = null,
                        locationFreshness = loc?.freshness ?: org.madalasa.madalasa.domain.Freshness.UNAVAILABLE,
                        lastObservedEpochMs = loc?.observedAtEpochMs,
                        hasActiveSos = sos != null,
                        activeSosEventId = sos?.eventId
                    ),
                    onCardClick = onNavigateToChildSelection,
                    onAcknowledgeSos = onAcknowledgeSignal
                )
                Spacer(modifier = Modifier.height(8.dp))
            } else {
                Text("No authorized child selected")
                Spacer(modifier = Modifier.height(8.dp))
            }

            if (child == null && uiState.activeSignals.isNotEmpty()) {
                val sos = uiState.activeSignals.first()
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = ThemeCTokens.Vermilion.copy(alpha = 0.12f)),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(8.dp)
                    ) {
                        Text(
                            text = "EMERGENCY SOS SIGNAL RECEIVED",
                            fontWeight = FontWeight.Bold,
                            color = ThemeCTokens.Vermilion,
                            fontSize = 16.sp
                        )
                        Text(
                            text = "A manual SOS was raised by the child. Tap below to provide explicit human guardian acknowledgement.",
                            style = MaterialTheme.typography.bodySmall,
                            color = ThemeCTokens.Ink
                        )
                        androidx.compose.material3.Button(
                            onClick = { onAcknowledgeSignal(sos.eventId) },
                            colors = androidx.compose.material3.ButtonDefaults.buttonColors(
                                containerColor = ThemeCTokens.Vermilion,
                                contentColor = androidx.compose.ui.graphics.Color.White
                            ),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text("Acknowledge Emergency SOS", fontWeight = FontWeight.Bold)
                        }
                    }
                }
                Spacer(modifier = Modifier.height(8.dp))
            }

            OutlinedButton(onClick = onRefresh) { Text("Refresh authorization and observations") }
            OutlinedButton(onClick = onNavigateToChildSelection) { Text("Choose child") }
            when (selectedTab) {
                ShellTab.MAP -> MapPlaceholderContent(uiState)
                ShellTab.HISTORY -> HistoryContent(uiState)
                ShellTab.PLACES -> PlacesPlaceholderContent()
                ShellTab.SETTINGS -> SettingsPlaceholderContent(uiState, onNavigateToChildSelection, onNavigateToPrivacy, onExplorePremiumPlans)
            }
        }
    }
}

@Composable
private fun MapPlaceholderContent(uiState: ParentUiState) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = ThemeCTokens.PaleWarmSurface),
        shape = RoundedCornerShape(12.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "Child Location Status",
                fontWeight = FontWeight.Bold,
                color = ThemeCTokens.Ink
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text("Map unavailable: no map provider is configured. Verified observations are shown below.")
            val loc = uiState.selectedChildLocation?.takeIf { it.childId == uiState.selectedChildId }
            if (loc != null && loc.latitudeE6 != null && loc.longitudeE6 != null &&
                loc.freshness != org.madalasa.madalasa.domain.Freshness.UNAVAILABLE &&
                loc.freshness != org.madalasa.madalasa.domain.Freshness.UNKNOWN) {
                Text(
                    text = "Freshness: ${loc.freshness}",
                    color = ThemeCTokens.Teal,
                    fontWeight = FontWeight.SemiBold
                )
                ObservationDetails(loc)
                Text(text = loc.accuracyMeters?.let { "Accuracy: $it meters" }
                    ?: "Accuracy not available")
            } else {
                Text(text = "Location unavailable or not yet observed. No coordinates are inferred.")
            }
            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = "Notice: Live location markers reflect last-verified state only; no fabricated real-time motion without fresh observations.",
                fontSize = 11.sp,
                color = ThemeCTokens.MutedText
            )
        }
    }
}

@Composable
private fun HistoryContent(uiState: ParentUiState) {
    Column(verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(12.dp)) {
        Text("Location history · past six hours", fontWeight = FontWeight.Bold)
        val data = uiState.history.data?.takeIf { it.childId == uiState.selectedChildId }
        Text(uiState.history.status)
        if (data != null) {
            if (data.items.isEmpty()) Text("No observations returned in the server's six-hour window.")
            if (data.hasMore) Text("Partial result: server returned its newest 200 observations. Older rows may be omitted; pagination is not available.")
            data.items.forEach { observation ->
                ObservationDetails(observation)
            }
        } else {
            Text("History is unknown or unavailable, not proof that the child stayed in one place.")
        }
        Text("Visible history is not a storage-retention promise. Times depend on the reporting device and server clocks.", fontSize = 12.sp)
    }
}

@Composable
private fun ObservationDetails(loc: org.madalasa.madalasa.domain.VerifiedLocationState) {
    var now by remember { mutableStateOf(System.currentTimeMillis()) }
    androidx.compose.runtime.LaunchedEffect(loc) {
        while (true) {
            now = System.currentTimeMillis()
            kotlinx.coroutines.delay(60_000)
        }
    }
    val observed = loc.observedAtEpochMs
    val age = observed?.let { Duration.between(Instant.ofEpochMilli(it), Instant.ofEpochMilli(now)) }
    Column {
        Text("Observed: ${observed?.let { Instant.ofEpochMilli(it).toString() } ?: "Unknown"}")
        Text("Received: ${loc.ingestedAtEpochMs?.let { Instant.ofEpochMilli(it).toString() } ?: "Unknown"}")
        Text(if (age == null || age.isNegative) "Age unknown · clock may differ"
            else "Observation age: ${age.toMinutes()} minutes · last known, not live")
        // Also age cached observations out while the app stays open. Never extend the server's window.
        if (age != null && !age.isNegative && age <= Duration.ofHours(6) &&
            loc.latitudeE6 != null && loc.longitudeE6 != null) {
            Text("Coordinates: ${loc.latitudeE6 / 1e6}, ${loc.longitudeE6 / 1e6}")
            Text(loc.accuracyMeters?.let { "Accuracy: $it meters" } ?: "Accuracy unknown")
        } else Text("Coordinates hidden: timestamp unknown, clock mismatch, or older than six hours. Refresh.")
    }
}

@Composable
private fun PlacesPlaceholderContent() {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = ThemeCTokens.PaleWarmSurface),
        shape = RoundedCornerShape(12.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(text = "Places & Geofences (Synthetic)", fontWeight = FontWeight.Bold, color = ThemeCTokens.Ink)
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "Places are unavailable. No configured boundaries or geofence alerts have been verified.",
                color = ThemeCTokens.Ink,
                fontSize = 13.sp
            )
        }
    }
}

@Composable
private fun SettingsPlaceholderContent(uiState: ParentUiState, onSelectChild: () -> Unit, onOpenPrivacy: () -> Unit, onExplorePremiumPlans: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = ThemeCTokens.PaleWarmSurface),
        shape = RoundedCornerShape(12.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(text = "Settings & Authority", fontWeight = FontWeight.Bold, color = ThemeCTokens.Ink)
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "Development account: ${uiState.profile?.adultId ?: "Not signed in"}",
                fontSize = 13.sp,
                color = ThemeCTokens.Ink
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "Camera, microphone, and remote media capture are strictly disabled in this release.",
                fontSize = 12.sp,
                color = ThemeCTokens.Vermilion
            )
            Spacer(modifier = Modifier.height(12.dp))
            OutlinedButton(
                onClick = onOpenPrivacy,
                modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)
            ) { Text("Privacy & data") }
            OutlinedButton(
                onClick = onExplorePremiumPlans,
                modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)
            ) { Text("Explore premium plans · ₹99 / ₹999") }
            OutlinedButton(
                onClick = onSelectChild,
                modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)
            ) { Text("Choose child") }
        }
    }
}
