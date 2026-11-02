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

/** Native Compose versions of Figma Theme C family-sharing samples. No operational
 * authorization, subscription or viewer lease is implied. All displayed data is illustrative.
 * Content refs: 81:179/201, 84:179/201/221/242/263 and 89:180.
 */
internal data class SharingDesign(val id: String, val figmaNode: String,
    val title: String, val content: List<String>)
internal object ThemeCSharingCatalog {
    val screens = listOf(
        SharingDesign(id = "P-47", figmaNode = "81:179", title = "Family plan & child coverage", content = listOf("1 payer · child-specific co-parent access", "A co-parent sees only explicitly shared children after invitation, acceptance and applicable consent review.", "Parent A    ·    Primary payer", "Parent B · Child A invite awaiting acceptance", "Manage child-specific access →", "Select children for paid access", "1 of 2 eligible children selected", "☑  Child A    Paid · expires 27 Nov", "☐  Child B    Free · recent 6h history", "₹50 / month · Founding family", "1 prepaid child seat · No automatic renewal", "Only Parent A can manage purchases", "Review one-time Play payment →", "New spouses and other children are never shared automatically.")),
        SharingDesign(id = "P-49", figmaNode = "81:201", title = "Covered by your family plan", content = listOf("✓  Child A · Super Access active", "Covered by your family’s prepaid plan", "Expires 27 November · No auto-renew", "Parent A purchased the child seat.", "Example: you were approved for Child A only.", "You do not need to subscribe again.", "Location & alerts     Allowed", "Media requests         Requires approval", "Other children · Hidden without separate permission", "Other children remain private", "No other child name, location or status is disclosed here.", "View shared family access →", "Only the payer can approve a new Play purchase.")),
        SharingDesign(id = "SH-01", figmaNode = "84:179", title = "Choose children to share", content = listOf("Paid coverage ≠ parental sharing", "Choose exactly which child a co-parent can view.", "☑  Child A · Paid seat assigned", "Parent A (payer): Full approved access", "☐ Share Child A with Parent B · invite", "☐  Child B · Free", "No automatic sharing across relationships.", "Parent B: Not authorized · Hidden", "Child-specific invitation and review", "Google login verifies identity, not parental authority. Separate legal consent checks may apply.", "Invite Parent B for Child A", "Design preview · private child-scoped invites", "Home        Children        Family        Plans")),
        SharingDesign(id = "SH-02", figmaNode = "84:201", title = "Invite a co-parent for this child", content = listOf("Accept invitation and confirm authority", "Invitation covers Child A only. Access requires acceptance and applicable legal/consent approval.", "✓  Google account identity confirmed", "!   Child A invite pending acceptance/review", "×  Child access not yet granted", "Each child requires separate approval", "An unrelated spouse or co-parent must never see other children's locations.", "No Google Family Link role lookup is required. Legal parental authority remains a separate check.", "Back to child selection", "Design preview · child-specific invitation flow", "Home        Children        Family        Plans")),
        SharingDesign(id = "SH-03", figmaNode = "84:221", title = "One screen in use", content = listOf("Child A · 1 / 1 active screen", "Included in the existing prepaid child plan", "Another approved parent is viewing", "A second premium live monitoring screen is not available in your current plan.", "Active premium viewer: Parent A", "Only Child A · device session protected", "Settings and safety notices remain accessible.", "Request takeover from Parent A", "+1 extra screen · ₹100 / 100 days", "Close a live screen to release its slot; switching app tabs doesn't consume another.", "Design preview · Google parent verification not connected", "Home        Children        Family        Plans")),
        SharingDesign(id = "SH-04", figmaNode = "84:242", title = "Add a simultaneous screen", content = listOf("+1 live monitoring screen", "₹100 · candidate price", "100 days from activation · no auto-renew", "+30 min audio + video combined", "One shared pool for Child A; not 30 minutes each.", "Assigned only to selected Child A", "Valid for 100 days even if the main plan expires.", "Extra media remains unavailable until Android/Play/legal approval.", "Premium use pauses if the main plan expires; your add-on remains valid until day 100.", "Play SKU and checkout not configured", "Preview one-time Play checkout", "Design preview · Google parent verification not connected", "Home        Children        Family        Plans")),
        SharingDesign(id = "SH-05", figmaNode = "84:263", title = "Your approved children", content = listOf("Child A · Covered by prepaid plan", "Parent A (payer) + explicitly approved adult for Child A", "Current capacity: 1 premium screen", "Other children · Not visible", "Unshared children have no visible name, location, device details or status.", "Audio 60 min · Video 20 min / paid month", "Shared among authorized parents only when media enabled.", "Live capture is conditional", "No background permission is implied by payment or guardian status.", "Manage child-specific access", "Design preview · private child-only grants", "Home        Children        Family        Plans")),
        SharingDesign(id = "SH-06", figmaNode = "89:180", title = "Your extra screen is saved", content = listOf("100-day add-on · Active validity", "Day 42 of 100 · 58 days remaining", "₹100 paid once · no auto-renew", "Premium viewing temporarily paused", "Your primary child plan expired. The extra-screen add-on has NOT been cancelled.", "+1 simultaneous premium screen", "Remaining extra A/V balance: 30 minutes", "Benefits resume if you manually renew Child A's base plan before the add-on expires.", "Review main prepaid renewal →", "Free live tracking remains available. Renewing does not change the original 100-day end date.", "Home      Children      Family      Plans"))
    )
}

@Composable
internal fun ThemeCSharingScreen(
    design: SharingDesign, onNextDesign: () -> Unit, modifier: Modifier = Modifier
) {
    val parchment = Color(0xFFFFF7E7)
    val ink = Color(0xFF292A31)
    val vermilion = Color(0xFFB73527)
    val teal = Color(0xFF28756C)
    val muted = Color(0xFF657078)
    Column(modifier.fillMaxSize().background(parchment)
        .verticalScroll(rememberScrollState()).padding(horizontal = 18.dp, vertical = 24.dp),
        verticalArrangement = Arrangement.spacedBy(11.dp)) {
        Text("✦ MADALASA / FAMILY ACCESS", color = vermilion,
            fontSize = 12.sp, fontWeight = FontWeight.Bold)
        Text(design.title, color = ink, fontSize = 23.sp, fontWeight = FontWeight.Bold)
        Text("DESIGN EXAMPLE · NOT YOUR ACCOUNT", color = vermilion,
            style = MaterialTheme.typography.labelMedium)
        design.content.forEachIndexed { index, message ->
            val isAction = message.startsWith("Review ") || message.startsWith("Invite ") ||
                message.startsWith("Request ") || message.startsWith("Manage ") ||
                message.startsWith("Preview ") || message.startsWith("View ")
            if (isAction) {
                Button(onClick = {}, enabled = false, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp),
                    colors = ButtonDefaults.buttonColors(disabledContainerColor = vermilion,
                        disabledContentColor = Color.White), shape = RoundedCornerShape(14.dp)) {
                    Text(message, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                }
            } else {
                val surface = when {
                    index % 5 == 0 -> Color(0xFFE7F1E9)
                    index % 5 == 1 -> Color(0xFFF2EBDB)
                    else -> Color(0xFFFFFDF7)
                }
                Surface(modifier = Modifier.fillMaxWidth(), color = surface,
                    shape = RoundedCornerShape(16.dp)) {
                    Text(message, Modifier.padding(horizontal = 14.dp, vertical = 13.dp),
                        color = if (index % 5 == 0) teal else ink,
                        fontSize = if (index % 5 == 0) 15.sp else 13.sp, lineHeight = 20.sp,
                        fontWeight = if (index % 5 == 0) FontWeight.Bold else FontWeight.Normal)
                }
            }
        }
        OutlinedButton(onClick = onNextDesign, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) {
            Text("Next design")
        }
        Text("Figma " + design.figmaNode + " · Theme C preview only; billing and sharing disabled",
            color = muted, fontSize = 11.sp)
    }
}
