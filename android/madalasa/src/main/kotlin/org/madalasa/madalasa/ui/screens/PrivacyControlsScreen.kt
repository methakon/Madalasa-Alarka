package org.madalasa.madalasa.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.madalasa.madalasa.ui.theme.ThemeCTokens

/** Figma PRIV-UI-01..04 (nodes 159:3/22/41/60), 2026-11-02.
 * All API-backed privacy states are UNKNOWN. The Figma example child, approved
 * grants and completed deletions are not rendered as real account information.
 */
enum class ParentPrivacyPage(val route: String, val figmaNode: String, val title: String) {
    OVERVIEW("privacy/overview", "159:3", "Privacy & data"),
    GUARDIANS("privacy/guardians", "159:22", "People who can view"),
    HISTORY("privacy/history", "159:41", "History visibility"),
    REQUESTS("privacy/requests", "159:60", "Export or delete data");

    companion object {
        fun fromRoute(route: String?): ParentPrivacyPage? =
            entries.firstOrNull { it.route == route }
    }
}

data class ParentPrivacyRow(
    val heading: String, val detail: String, val destination: ParentPrivacyPage? = null, val grantId: String? = null
)

/** Read-only UI model until exact-child server authorization and privacy APIs exist. */
internal fun parentPrivacyRows(page: ParentPrivacyPage): List<ParentPrivacyRow> = when (page) {
    ParentPrivacyPage.OVERVIEW -> listOf(
        ParentPrivacyRow("Sharing status", "Not verified: device permission, guardian authority and server policy are separate checks."),
        ParentPrivacyRow("Location history", "Free-plan policy: at most the last 6 hours, subject to authorized data availability.", ParentPrivacyPage.HISTORY),
        ParentPrivacyRow("Manage access", "Guardians, exact-child scopes, expiry and revocation.", ParentPrivacyPage.GUARDIANS),
        ParentPrivacyRow("Data requests", "Export, deletion, progress and legal holds.", ParentPrivacyPage.REQUESTS)
    )
    ParentPrivacyPage.GUARDIANS -> listOf(
        ParentPrivacyRow("Primary guardian", "Identity, role, scope and server approval are not loaded."),
        ParentPrivacyRow("Invited guardian", "Unknown. Invitations never grant access before acceptance and approval."),
        ParentPrivacyRow("Guardian expiry", "Unknown until retrieved from this child's server grant."),
        ParentPrivacyRow("Revocation confirmation", "No revocation submitted. Verified server revocation fences access; an offline device may sync later.")
    )
    ParentPrivacyPage.HISTORY -> listOf(
        ParentPrivacyRow("Available to view", "Free-tier maximum: past 6 hours. Current entitlement and actual records are unverified."),
        ParentPrivacyRow("Older history", "Requires an authorized, paid server entitlement and lawfully retained records."),
        ParentPrivacyRow("Data storage", "History visibility differs from server retention; indefinite retention is not authorized."),
        ParentPrivacyRow("Report timestamp", "Unknown. Last observation may be stale or approximate, not a live location.")
    )
    ParentPrivacyPage.REQUESTS -> listOf(
        ParentPrivacyRow("Export request", "Secure download requires identity recheck, child-specific scope and server processing."),
        ParentPrivacyRow("Deletion request", "Requires an authenticated request, authorization fence and deletion of eligible data."),
        ParentPrivacyRow("Request progress", "No request submitted. Backup processing and legal holds require verified server status."),
        ParentPrivacyRow("Safety check", "Do not claim completion until confirmed. Old offline uploads must not resurrect deleted data.")
    )
}

@Composable
fun ParentPrivacyScreen(
    page: ParentPrivacyPage,
    hasSelectedChild: Boolean,
    onBack: () -> Unit,
    onNavigate: (ParentPrivacyPage) -> Unit,
    modifier: Modifier = Modifier,
    verifiedRows: List<ParentPrivacyRow>? = null,
    apiStatus: String = "UNKNOWN / API NOT CONNECTED",
    onRevokeGrant: ((String) -> Unit)? = null
) {
    var pendingRevoke by remember { mutableStateOf<String?>(null) }
    val ink = ThemeCTokens.Ink
    val red = ThemeCTokens.Vermilion
    val indigo = ThemeCTokens.DeepIndigo
    val hint = Color(0xFF6D6A65)
    val heading = when (page) {
        ParentPrivacyPage.OVERVIEW -> "PARENT · CHILD-SCOPED"
        ParentPrivacyPage.GUARDIANS -> "PARENT · ACCESS"
        ParentPrivacyPage.HISTORY -> "PARENT · HISTORY"
        ParentPrivacyPage.REQUESTS -> "PARENT · PRIVACY REQUEST"
    }

    Column(
        modifier.fillMaxSize().background(ThemeCTokens.Parchment)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        TextButton(onClick = onBack, modifier = Modifier.heightIn(min = 48.dp)) {
            Text("‹ Back", color = indigo)
        }
        Text(heading, fontSize = 12.sp, fontWeight = FontWeight.Bold, color = red)
        Text(page.title, fontSize = 26.sp, fontWeight = FontWeight.Bold, color = ink)
        Text(
            if (hasSelectedChild) "Selected child · privacy status awaiting verification"
            else "No child selected · select an authorized child first",
            color = hint, fontSize = 14.sp
        )
        (verifiedRows ?: parentPrivacyRows(page)).forEachIndexed { index, row ->
            Surface(
                modifier = Modifier.fillMaxWidth().heightIn(min = 80.dp)
                    .clickable(enabled = row.destination != null) {
                        row.destination?.let(onNavigate)
                    },
                color = if (index == 0) Color(0xFFF2E6D2) else Color.White,
                shape = RoundedCornerShape(12.dp)
            ) {
                Column(Modifier.padding(horizontal = 12.dp, vertical = 14.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(Modifier.fillMaxWidth()) {
                        Text(row.heading, fontSize = 16.sp, fontWeight = FontWeight.Bold,
                            color = indigo, modifier = Modifier.weight(1f))
                        if (row.destination != null) Text("›", color = indigo, fontSize = 18.sp)
                    }
                    Text(row.detail, fontSize = 13.sp, lineHeight = 19.sp, color = ink)
                    if (row.grantId != null && onRevokeGrant != null) {
                        TextButton(onClick = { pendingRevoke = row.grantId },
                            modifier = Modifier.heightIn(min = 48.dp)) {
                            Text("Revoke this grant", color = red)
                        }
                    }
                }
            }
        }
        if (page == ParentPrivacyPage.REQUESTS) {
            Button(onClick = {}, enabled = false,
                modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) {
                Text("Request export · unavailable")
            }
            Button(onClick = {}, enabled = false,
                modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) {
                Text("Request deletion · unavailable")
            }
            Text("No export or deletion request has been sent. The authenticated privacy API is not connected.",
                fontSize = 12.sp, color = red)
        }
        Surface(color = Color(0xFFF2E6D2), shape = RoundedCornerShape(12.dp)) {
            Column(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 14.dp),
                verticalArrangement = Arrangement.spacedBy(5.dp)) {
                Text("SPECIFIED — no live child monitoring enabled by this screen",
                    color = red, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                Text("Figma " + page.figmaNode + " · PRIVACY_CONTROLS_V0_TECHNICAL_AND_UI_SPEC_2026-11-02.md",
                    color = hint, fontSize = 11.sp, lineHeight = 15.sp)
                Text("State: " + apiStatus + ". History, deletion and server acknowledgement require separate verification.",
                    color = hint, fontSize = 11.sp)
            }
        }
    }
    if (pendingRevoke != null) {
        AlertDialog(
            onDismissRequest = { pendingRevoke = null },
            title = { Text("Revoke guardian access?") },
            text = { Text("This removes this specific child grant at the server. An offline device may receive updated policy later.") },
            confirmButton = {
                TextButton(onClick = {
                    pendingRevoke?.let { onRevokeGrant?.invoke(it) }
                    pendingRevoke = null
                }) { Text("Revoke", color = red) }
            },
            dismissButton = {
                TextButton(onClick = { pendingRevoke = null }) { Text("Cancel") }
            }
        )
    }

}
