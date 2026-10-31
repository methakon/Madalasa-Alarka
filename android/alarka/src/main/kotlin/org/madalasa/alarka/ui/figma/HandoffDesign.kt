package org.madalasa.alarka.ui.figma

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** 360x713 Figma handoff phone frame translated to responsive native Compose.
 * Figma source node P-01 9:3: insets 17/21dp, status 35dp, focus 124dp,
 * four 70dp rows and 50dp primary action. Matches source wireframe semantics.
 * TODO(VISUAL_QA): verify per-frame screenshots, font scaling and small devices.
 */
@Composable
internal fun HandoffDesign(
    id: String, title: String, hero: String, kind: String,
    milestone: String, requirement: String, details: List<String>,
    action: String, modifier: Modifier = Modifier
) {
    val parchment = Color(0xFFFFF7E7)
    val teal = Color(0xFF087E83)
    val darkTeal = Color(0xFF164950)
    val vermilion = Color(0xFFB73527)
    val muted = Color(0xFF6B8585)
    val segments = details.take(4).toMutableList()
    while (segments.size < 4) segments.add("State and detail for this view")
    Column(
        modifier = modifier.fillMaxSize().background(parchment)
            .verticalScroll(rememberScrollState()).padding(horizontal = 17.dp, vertical = 11.dp),
        verticalArrangement = Arrangement.spacedBy(0.dp)
    ) {
        // OS owns the real Android status bar; this is Figma's non-functional strip.
        Surface(color = Color(0xFFEBF5F4), shape = RoundedCornerShape(9.dp),
            modifier = Modifier.fillMaxWidth().height(35.dp)) {
            Row(Modifier.padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("DESIGN PREVIEW", color = Color(0xFF3F5C61), fontSize = 11.sp)
                Spacer(Modifier.weight(1f))
                Text("●  ▰", color = Color(0xFF3F5C61), fontSize = 12.sp)
            }
        }
        Spacer(Modifier.height(20.dp))
        Text(title, color = darkTeal, fontSize = 20.sp, fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(horizontal = 4.dp))
        Spacer(Modifier.height(11.dp))
        Text("${if (id.startsWith("P")) "Parent" else "Child"} APP    ${id}    ${milestone}    ${requirement}",
            fontSize = 10.sp, color = muted, modifier = Modifier.padding(horizontal = 4.dp))
        Spacer(Modifier.height(28.dp))
        Surface(modifier = Modifier.fillMaxWidth().heightIn(min = 124.dp),
            color = Color(0xFFFCE8CD), shape = RoundedCornerShape(17.dp)) {
            Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                Text(hero, fontSize = 16.sp, lineHeight = 21.sp, color = Color(0xFF116E71),
                    fontWeight = FontWeight.Bold)
                Text("${kind.uppercase()} • ${milestone}",
                    fontSize = 10.sp, color = Color(0xFF3B7775))
                }
                ThemeCArtwork(id)
            }
        }
        Spacer(Modifier.height(17.dp))
        segments.forEachIndexed { index, item ->
            Row(
                modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp)
                    .heightIn(min = 70.dp).background(
                        if (index == 0) Color(0xFFECF7F4) else Color.White,
                        RoundedCornerShape(12.dp)
                    ),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(Modifier.width(5.dp).height(62.dp)
                    .background(vermilion, RoundedCornerShape(2.dp)))
                Text(item, color = Color(0xFF25474B), fontSize = 12.sp,
                    lineHeight = 17.sp,
                    fontWeight = if (index == 0) FontWeight.Bold else FontWeight.Normal,
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp))
            }
        }
        Spacer(Modifier.height(12.dp))
        Button(
            enabled = false,
            onClick = { /* TODO(INTEGRATION): bind reviewed flow and authorized action */ },
            modifier = Modifier.fillMaxWidth().heightIn(min = 50.dp),
            shape = RoundedCornerShape(14.dp),
            colors = ButtonDefaults.buttonColors(
                disabledContainerColor = teal, disabledContentColor = Color.White)
        ) {
            Text(action, fontSize = 14.sp, fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(12.dp))
        Text("UI prototype · service and permissions inactive", color = muted, fontSize = 10.sp)
    }
}
