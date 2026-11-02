package org.madalasa.madalasa.ui.figma

import androidx.compose.foundation.background
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

/** Eight parent Theme C Figma functional sample screens. Illustrative design,
 * not server-confirmed observations, Play products or permission/capture authority.
 * Parent routes use these in the debug design gallery; production keeps verified state.
 */
internal data class ThemeCScreenSpec(val id: String, val figmaNode: String,
    val figmaName: String, val text: List<String>)
internal object ThemeCFunctionalCatalog {
    val screens: List<ThemeCScreenSpec> = listOf(
        ThemeCScreenSpec("P-05", "52:164", "P-05 / Theme C / Home and map", listOf("❀  MADALASA   /   HOME AND MAP", "✦ Super Access · 47h left", "×", "CHILD A  •  HOME", "Schematic only", "Child A · At Home", "Last observed: 2 min ago · accuracy ±25 m", "Your family tools", "⌂ Places", "♧ Family", "♜ Alerts", "Location is a device observation, not continuous proof of presence.", "Home       Timeline       Places       Family")),
        ThemeCScreenSpec("P-15", "52:192", "P-15 / Theme C / Daily activity", listOf("❀  MADALASA   /   DAILY ACTIVITY", "✦ Super Access · 47h left", "×", "Today's timeline", "Observed travel · 17:41–18:00", "Walk 0.2 km · Ride 0.6 km · partial confidence", "Home arrival · 18:00", "Named-place match · last device fix 18:02", "Battery notification", "Battery was below 10% at 20:28", "Application usage", "Permission and child-purpose approval required", "Free plan: most recent 6h visible · older lawful records require paid access.", "Home       Timeline       Places       Family")),
        ThemeCScreenSpec("P-24", "52:212", "P-24 / Theme C / Trip detail", listOf("❀  MADALASA   /   TRIP DETAIL", "Route 17:41 → 18:00", "CHILD A  •  HOME", "Schematic only", "●  17:41   START · observed", "│  Walk   0.2 km · 14 min", "●  17:55   mode inferred", "│  Ride   0.6 km · 4 min", "●  18:00   HOME · observed", "Accuracy", "Leg types inferred; observations and missing GPS gaps are shown.", "Parent feedback: Was this reconstruction useful? ☆ ☆ ☆ ☆ ☆", "Home       Timeline       Places       Family")),
        ThemeCScreenSpec("P-28", "52:237", "P-28 / Theme C / Places and alerts", listOf("❀  MADALASA   /   PLACES AND ALERTS", "Places & notifications", "⌂ Home", "● ON", "Enter + exit alerts ON", "▣ School", "○ OFF", "Notifications OFF", "❀ Grandma's house", "○ OFF", "Notifications OFF", "⌖ Market", "○ OFF", "Notifications OFF", "+ Add a named place", "Alerts can be delayed by location quality, permissions or network.", "Home       Timeline       Places       Family")),
        ThemeCScreenSpec("P-39", "52:263", "P-39 / Theme C / Family and guardians", listOf("❀  MADALASA   /   FAMILY AND GUARDIANS", "Family & guardians", "Add an approved guardian", "Choose the child, permissions and access expiration.", "Add a child", "Pair Alarka using a short-lived verified code or QR.", "Current access", "Family owner · Child A · approved guardians", "Share the app — not child data", "Copy app link    ·    App-install QR", "Inviting guardians, sharing an app, and pairing a child's device are separate flows.", "Manage child-specific access", "Home       Timeline       Places       Family")),
        ThemeCScreenSpec("P-48", "52:281", "P-48 / Theme C / Prepaid plans", listOf("❀  MADALASA   /   PREPAID PLANS", "✦ Super Access · 47h left", "×", "Choose prepaid access", "Public · ₹99 / month", "Or ₹999/year per paid child · only pay when you choose", "Founding · ₹50 / month", "Or ₹500/year for eligible first 1,008 paying families", "No automatic renewal", "When time ends, free live tracking continues with 6h visible history.", "1 child seat · select period", "Check actual Play amount, taxes and eligibility before payment.", "Review one-time Play payment", "Not a binding price quote. Google Play verifies prepaid catalog and offers.", "Home       Timeline       Places       Family")),
        ThemeCScreenSpec("P-58", "52:303", "P-58 / Theme C / Audio capability", listOf("❀  MADALASA   /   AUDIO CAPABILITY", "Sound around the child", "❀     ∿  ∿  ∿  ∿     ❀", "Trial balance · 5 minutes", "Paid Balanced: 60 min/month · up to 5 min per paid session", "Capture not available", "Media requires separate Android, legal, child-safety and Play approval.", "Review capability requirements", "No hidden listening. No quota deducted when OS rejects an attempt.", "Home       Timeline       Places       Family")),
        ThemeCScreenSpec("P-31", "52:317", "P-31 / Theme C / Usage overview", listOf("❀  MADALASA   /   USAGE OVERVIEW", "Device usage overview", "Yesterday        Today        Week", "Social  ·  Study  ·  Other", "Per-app details", "Observed foreground usage where permission and law allow.", "App restrictions", "Managed/eligible devices only. Not universal on Android.", "Unknown coverage is not zero usage.", "Home       Timeline       Places       Family"))
    )
    fun find(id: String): ThemeCScreenSpec = screens.first { it.id == id }
}

@Composable
internal fun ThemeCFunctionalScreen(spec: ThemeCScreenSpec, modifier: Modifier = Modifier) {
    val ink = Color(0xFF292A31)
    val parchment = Color(0xFFFFF7E7)
    val teal = Color(0xFF28756C)
    val red = Color(0xFFB73527)
    val indigo = Color(0xFF233F69)
    Column(modifier.fillMaxSize().background(parchment).verticalScroll(rememberScrollState())
        .padding(horizontal = 18.dp, vertical = 20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(spec.text.firstOrNull() ?: "MADALASA", color = red,
            fontSize = 13.sp, fontWeight = FontWeight.Bold)
        Text("Figma design example · not live child information", color = indigo,
            fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
        spec.text.drop(1).filterNot { it == "×" || it.startsWith("Home       Timeline") }
            .forEachIndexed { index, line ->
                when {
                    line.startsWith("✦ Super Access") -> {
                        Surface(color = Color(0xFFF0E8CE), shape = RoundedCornerShape(18.dp)) {
                            Text(line + " · sample countdown", Modifier.padding(12.dp),
                                color = indigo, fontWeight = FontWeight.SemiBold)
                        }
                    }
                    line.startsWith("Review ") || line.startsWith("Manage ") ||
                        line.startsWith("+ Add ") -> {
                        Button(onClick = {}, enabled = false, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp),
                            colors = ButtonDefaults.buttonColors(
                                disabledContainerColor = indigo, disabledContentColor = Color.White)) {
                            Text(line, fontSize = 14.sp)
                        }
                    }
                    else -> {
                        Surface(color = if (index % 4 == 0) Color(0xFFE7F1E9) else Color(0xFFFFFDF7),
                            shape = RoundedCornerShape(14.dp), modifier = Modifier.fillMaxWidth()) {
                            Row(Modifier.padding(horizontal = 14.dp, vertical = 12.dp),
                                horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                if (index % 4 == 0) ThemeCArtwork(spec.id)
                                Text(line, color = if (index % 4 == 0) teal else ink,
                                    style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
                            }
                        }
                    }
                }
            }
        Text("Figma node: " + spec.figmaNode + " · no new OS permissions or purchases",
            fontSize = 11.sp, color = indigo)
    }
}
