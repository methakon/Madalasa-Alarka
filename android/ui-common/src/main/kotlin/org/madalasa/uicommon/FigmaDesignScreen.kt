package org.madalasa.uicommon

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp

/**
 * Read-only, type-aware design layout for all Figma handoff screens.
 *
 * TODO(INTEGRATION) per screen:
 * - nav: route callback must come from the owning app's navigation controller
 * - state: ViewModel/repository must supply server-authorized values; never use fake success
 * - API: see spec.apiHook; server authorization is independently enforced
 * - device: OS permission handling must be a foreground, user-driven workflow
 * - privacy: no monitoring, billing or media functionality is activated here
 *
 * These composables deliberately do not pretend a screen is functional.
 * A real CTA stays disabled until a reviewed implementation binds it.
 */
@Composable
fun FigmaDesignScreen(spec: FigmaScreenSpec, modifier: Modifier = Modifier) {
    val colors = MaterialTheme.colorScheme
    Column(
        modifier = modifier.fillMaxSize().background(colors.background)
            .verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(if (spec.actor == AppActor.PARENT) "MADALASA" else "ALARKA",
                style = MaterialTheme.typography.labelLarge, color = colors.primary)
            Spacer(Modifier.weight(1f))
            Surface(shape = RoundedCornerShape(20.dp), color = colors.surfaceVariant) {
                Text(spec.id.value, Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                    style = MaterialTheme.typography.labelMedium)
            }
        }
        Text(spec.title, style = MaterialTheme.typography.headlineMedium,
            color = colors.onBackground, fontWeight = FontWeight.SemiBold)
        Text(spec.headline, style = MaterialTheme.typography.bodyLarge, color = colors.onBackground)
        ScreenVisual(spec)
        Text("On this screen", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        spec.content.split(';').map { it.trim() }.filter(String::isNotEmpty).forEach { part ->
            Surface(color = colors.surface, shape = RoundedCornerShape(16.dp),
                modifier = Modifier.fillMaxWidth()) {
                Row(Modifier.padding(16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.size(8.dp).background(colors.secondary, RoundedCornerShape(50)))
                    Text(part, modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)
                }
            }
        }
        APStatusPanel("Feature connection pending",
            "Visual design only. No account, device, location or subscription state has been fetched.")
        Button(onClick = { /* TODO(INTEGRATION): connect authorized action: spec.apiHook */ },
            enabled = false, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) {
            Text(spec.primaryAction, maxLines = 2, overflow = TextOverflow.Ellipsis)
        }
        Text("Expected unavailable state: ${spec.failureState}",
            style = MaterialTheme.typography.labelSmall, color = colors.onSurfaceVariant)
        Text("Privacy and OS gate: ${spec.securityGate}",
            style = MaterialTheme.typography.labelSmall, color = colors.onSurfaceVariant)
    }
}

@Composable
private fun ScreenVisual(spec: FigmaScreenSpec) {
    val colors = MaterialTheme.colorScheme
    when (spec.screenType) {
        "map" -> DesignPanel("Map preview", "No location available · last observation unknown") {
            Box(Modifier.fillMaxWidth().height(176.dp).background(colors.surfaceVariant,
                RoundedCornerShape(12.dp)), contentAlignment = Alignment.Center) {
                Text("Map not connected", color = colors.onSurfaceVariant)
            }
        }
        "metrics", "usage" -> DesignPanel("Evidence overview", "No verified observations available") {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf("Unknown", "Not reported", "Unavailable").forEach { item ->
                    Surface(color = colors.surfaceVariant, shape = RoundedCornerShape(8.dp),
                        modifier = Modifier.weight(1f)) {
                        Text(item, Modifier.padding(9.dp), style = MaterialTheme.typography.labelSmall)
                    }
                }
            }
        }
        "permission", "managed", "privacy" ->
            DesignPanel("Transparency & permissions", "Status must come from Android and verified server evidence") {
                Text("No permissions requested by this preview.",
                    style = MaterialTheme.typography.bodyMedium, color = colors.secondary)
            }
        "billing" -> DesignPanel("Plan information", "Pricing and eligibility require Play verification") {
            Text("No purchase is initiated.", style = MaterialTheme.typography.bodyMedium)
        }
        "code", "auth", "form", "wizard" ->
            DesignPanel("Setup preview", "Inputs and identity exchange are disabled in design mode") {
                OutlinedTextField(value = "", onValueChange = {}, enabled = false,
                    label = { Text("Not connected") }, modifier = Modifier.fillMaxWidth())
            }
        "alerts", "offline", "commands" ->
            DesignPanel("Current state", "No alerts or commands have been received") {
                Text("Delivery, acknowledgement and retries are not simulated as successful.",
                    style = MaterialTheme.typography.bodyMedium)
            }
        else -> DesignPanel("Information", "No authorized records loaded") {
            Text("A future ViewModel will expose loading, empty, denied and offline states.",
                style = MaterialTheme.typography.bodyMedium)
        }
    }
}

@Composable
private fun DesignPanel(title: String, description: String,
    content: @Composable ColumnScope.() -> Unit) {
    Card(modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(20.dp)) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            Text(description, style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant)
            content()
        }
    }
}
