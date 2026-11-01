package org.madalasa.madalasa.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
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
    onNavigateToPrivacy: () -> Unit
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

            when (selectedTab) {
                ShellTab.MAP -> MapPlaceholderContent(uiState)
                ShellTab.HISTORY -> HistoryPlaceholderContent()
                ShellTab.PLACES -> PlacesPlaceholderContent()
                ShellTab.SETTINGS -> SettingsPlaceholderContent(uiState, onNavigateToChildSelection, onNavigateToPrivacy)
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
            val loc = uiState.selectedChildLocation
            if (loc != null) {
                Text(
                    text = "Freshness: ${loc.freshness}",
                    color = ThemeCTokens.Teal,
                    fontWeight = FontWeight.SemiBold
                )
                Text(text = "Coordinates: ${(loc.latitudeE6 ?: 0) / 1e6}, ${(loc.longitudeE6 ?: 0) / 1e6}")
                Text(text = "Accuracy: ${loc.accuracyMeters ?: 0f} meters")
            } else {
                Text(text = "No location telemetry reported yet (Synthetic Seam)")
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
private fun HistoryPlaceholderContent() {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = ThemeCTokens.PaleWarmSurface),
        shape = RoundedCornerShape(12.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(text = "Route History (Synthetic)", fontWeight = FontWeight.Bold, color = ThemeCTokens.Ink)
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "Free-plan policy permits at most the past 6 hours of authorized history. Actual available observations, legal retention and paid entitlements require server verification.",
                color = ThemeCTokens.Ink,
                fontSize = 13.sp
            )
        }
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
                text = "Configured boundaries: Home (Synthetic), School (Synthetic). Geofence entry/exit alerts are processed asynchronously.",
                color = ThemeCTokens.Ink,
                fontSize = 13.sp
            )
        }
    }
}

@Composable
private fun SettingsPlaceholderContent(uiState: ParentUiState, onSelectChild: () -> Unit, onOpenPrivacy: () -> Unit) {
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
                onClick = onSelectChild,
                modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)
            ) { Text("Choose child") }
        }
    }
}
