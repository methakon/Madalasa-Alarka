package org.madalasa.alarka.ui.figma

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

/**
 * C-02 Theme C monitoring transparency, Figma 52:337.
 * The privacy summary remains visible even when monitoring/capture is disabled.
 * Actual guardian identity, permission status and child disclosures require
 * authorized device and backend evidence; no sample claim is presented as live.
 */
@Composable
fun C02Screen(modifier: Modifier = Modifier) {
    val ink = Color(0xFF292A31)
    val teal = Color(0xFF28756C)
    val red = Color(0xFFB73527)
    val sections = listOf(
        "Location observations" to "Visible monitoring when permitted; current location access is not verified here.",
        "Approved adults" to "View verified child-specific guardian grants when connected.",
        "Permissions can change" to "Android Settings determines which app permissions exist.",
        "Check-in and safety" to "Delivery requires a server-confirmed acknowledgement, not a sent notification."
    )
    Column(modifier.fillMaxSize().background(Color(0xFFFFF7E7))
        .verticalScroll(rememberScrollState()).padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("❀ ALARKA / MONITORING TRANSPARENCY", color = red,
            fontSize = 12.sp, fontWeight = FontWeight.Bold)
        Text("What my device shares", color = ink, fontSize = 23.sp, fontWeight = FontWeight.Bold)
        Text("No monitoring grant, current guardian list or sensor feed is asserted in this prototype.",
            fontSize = 12.sp, color = red)
        sections.forEach { (name, detail) ->
            Surface(shape = RoundedCornerShape(16.dp), color = Color(0xFFFFFDF7),
                modifier = Modifier.fillMaxWidth()) {
                Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(name, fontSize = 15.sp, fontWeight = FontWeight.Bold, color = teal)
                    Text(detail, fontSize = 13.sp, lineHeight = 20.sp, color = ink)
                }
            }
        }
        Button(onClick = {}, enabled = false, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) {
            Text("View enabled monitoring")
        }
        Text("Nothing here enables secret camera or microphone access.",
            fontSize = 12.sp, color = red)
        Text("Figma 52:337 · Static UI handoff, pending API + visual QA",
            fontSize = 11.sp, color = ink)
    }
}
