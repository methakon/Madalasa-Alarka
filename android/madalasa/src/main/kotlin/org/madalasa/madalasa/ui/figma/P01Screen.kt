package org.madalasa.madalasa.ui.figma

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.weight
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.madalasa.madalasa.ui.theme.ThemeCTokens

/** Figma 9:3 / P-01: user-visible welcome and role selection.
 *
 * The Figma frame is an editable 360x713 visual concept with a status strip,
 * hero, four information rows and a primary CTA. This implementation preserves
 * its palette, hierarchy, card geometry and spacing while replacing placeholder
 * text with truthful local information and real user-initiated navigation.
 *
 * No account, child, permission, location, monitoring session or API request
 * is created by this composable. Child app installation is a separate workflow.
 */
enum class WelcomeRole {
    PARENT,
    CHILD_COMPANION
}

enum class WelcomeInformation {
    PRIVACY,
    SUPPORT,
    LANGUAGE
}

internal fun canStartParentSetup(role: WelcomeRole, actionAvailable: Boolean): Boolean =
    role == WelcomeRole.PARENT && actionAvailable

internal fun welcomeInformationHeading(kind: WelcomeInformation): String = when (kind) {
    WelcomeInformation.PRIVACY -> "Privacy and transparency"
    WelcomeInformation.SUPPORT -> "Help and support"
    WelcomeInformation.LANGUAGE -> "Language"
}

internal fun welcomeInformationDetail(kind: WelcomeInformation): String = when (kind) {
    WelcomeInformation.PRIVACY ->
        "This welcome screen does not collect your location or a child's data. " +
            "Child monitoring, guardian sharing and permissions require separate visible steps " +
            "and verified authority. This summary is not the complete privacy policy."
    WelcomeInformation.SUPPORT ->
        "Support is being built into Madalasa. No help request has been submitted " +
            "and no emergency response is dispatched from this screen."
    WelcomeInformation.LANGUAGE ->
        "English is the only available interface language in this build. " +
            "Additional translations are planned but not yet selectable."
}

@Composable
fun P01Screen(
    modifier: Modifier = Modifier,
    onStartParentSetup: (() -> Unit)? = null
) {
    val ink = Color(0xFF25474B)
    val muted = Color(0xFF6B8585)
    val border = Color(0xFFB4CDCC)
    val teal = Color(0xFF087E83)
    val deepTeal = Color(0xFF164950)
    val red = ThemeCTokens.Vermilion
    var role by remember { mutableStateOf(WelcomeRole.PARENT) }
    var info by remember { mutableStateOf<WelcomeInformation?>(null) }

    Column(
        modifier = modifier.fillMaxSize()
            .background(ThemeCTokens.Parchment)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 17.dp, vertical = 11.dp),
        verticalArrangement = Arrangement.spacedBy(0.dp)
    ) {
        // Display app branding, not forged Android OS time or privacy indicators.
        Surface(
            color = Color(0xFFEBF5F4),
            shape = RoundedCornerShape(9.dp),
            modifier = Modifier.fillMaxWidth().height(35.dp)
        ) {
            Row(
                Modifier.padding(horizontal = 12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    "MADALASA",
                    color = Color(0xFF3F5C61),
                    fontSize = 11.sp,
                    fontWeight = FontWeight.SemiBold
                )
                Spacer(Modifier.weight(1f))
                Text("WELCOME", color = Color(0xFF3F5C61), fontSize = 11.sp)
            }
        }

        Spacer(Modifier.height(20.dp))
        Text(
            "Welcome", color = deepTeal, fontSize = 20.sp,
            fontWeight = FontWeight.Bold, modifier = Modifier.padding(horizontal = 4.dp)
        )
        Spacer(Modifier.height(11.dp))
        Text(
            "Parent APP    P-01    M1    FR-001/041",
            color = muted, fontSize = 10.sp, modifier = Modifier.padding(horizontal = 4.dp)
        )
        Spacer(Modifier.height(28.dp))

        Surface(
            color = Color(0xFFFCE8CD),
            shape = RoundedCornerShape(17.dp),
            modifier = Modifier.fillMaxWidth().heightIn(min = 124.dp)
        ) {
            Column(
                Modifier.padding(16.dp),
                verticalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    "Family safety, transparently",
                    fontSize = 16.sp, lineHeight = 21.sp,
                    color = Color(0xFF116E71), fontWeight = FontWeight.Bold
                )
                Spacer(Modifier.height(25.dp))
                Text(
                    "AUTH • M1 • FUNCTIONAL CONCEPT",
                    color = Color(0xFF3B7775), fontSize = 10.sp
                )
            }
        }
        Spacer(Modifier.height(17.dp))

        WelcomeCard(
            title = "Parent or Child entry",
            emphasis = true
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(
                    selected = role == WelcomeRole.PARENT,
                    onClick = { role = WelcomeRole.PARENT },
                    label = { Text("Parent") },
                    modifier = Modifier.heightIn(min = 48.dp)
                )
                FilterChip(
                    selected = role == WelcomeRole.CHILD_COMPANION,
                    onClick = { role = WelcomeRole.CHILD_COMPANION },
                    label = { Text("Child companion") },
                    modifier = Modifier.heightIn(min = 48.dp)
                )
            }
        }
        Spacer(Modifier.height(10.dp))

        WelcomeCard(title = "Privacy, support and language") {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(3.dp)
            ) {
                WelcomeLink("Privacy", Modifier.weight(1f)) {
                    info = WelcomeInformation.PRIVACY
                }
                WelcomeLink("Support", Modifier.weight(1f)) {
                    info = WelcomeInformation.SUPPORT
                }
                WelcomeLink("English", Modifier.weight(1f)) {
                    info = WelcomeInformation.LANGUAGE
                }
            }
        }
        Spacer(Modifier.height(10.dp))

        WelcomeCard(title = "What happens next") {
            Text(
                if (role == WelcomeRole.PARENT)
                    "Start guardian setup and review authorization before any child is paired."
                else
                    "Alarka is a separate child-device companion app. " +
                        "This parent app cannot grant its Android permissions.",
                color = ink, fontSize = 12.sp, lineHeight = 17.sp
            )
        }
        Spacer(Modifier.height(10.dp))

        WelcomeCard(title = "You stay in control") {
            Text(
                "No child account, tracking or media recording starts on this page. " +
                    "Permissions are controlled on the device.",
                color = ink, fontSize = 12.sp, lineHeight = 17.sp
            )
        }
        Spacer(Modifier.height(12.dp))

        Button(
            enabled = canStartParentSetup(role, onStartParentSetup != null),
            onClick = { onStartParentSetup?.invoke() },
            modifier = Modifier.fillMaxWidth().heightIn(min = 50.dp),
            shape = RoundedCornerShape(14.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = teal,
                disabledContainerColor = teal.copy(alpha = 0.6f),
                disabledContentColor = Color.White
            )
        ) {
            Text("Start parent setup", fontWeight = FontWeight.Bold, fontSize = 14.sp)
        }
        if (role == WelcomeRole.CHILD_COMPANION) {
            Text(
                "Switch to Parent to continue here. Install and open Alarka separately " +
                    "on the child-device test phone when authorized.",
                color = muted, fontSize = 12.sp, lineHeight = 18.sp,
                modifier = Modifier.padding(top = 10.dp)
            )
        }
        Spacer(Modifier.height(12.dp))
        Text(
            "No monitoring, permission change or network request on this screen.",
            color = muted, fontSize = 10.sp
        )
    }

    info?.let { selection ->
        AlertDialog(
            onDismissRequest = { info = null },
            title = { Text(welcomeInformationHeading(selection)) },
            text = { Text(welcomeInformationDetail(selection)) },
            confirmButton = {
                TextButton(onClick = { info = null }) { Text("Close") }
            }
        )
    }
}

@Composable
private fun WelcomeLink(
    title: String,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    OutlinedButton(
        onClick = onClick,
        modifier = modifier.heightIn(min = 48.dp),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 4.dp)
    ) {
        Text(title, maxLines = 1, fontSize = 11.sp)
    }
}

@Composable
private fun WelcomeCard(
    title: String,
    emphasis: Boolean = false,
    content: @Composable () -> Unit
) {
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = if (emphasis) Color(0xFFECF7F4) else Color.White,
        modifier = Modifier.fillMaxWidth().heightIn(min = 70.dp)
            .border(0.dp, Color.Transparent, RoundedCornerShape(12.dp))
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth()
        ) {
            Surface(
                color = ThemeCTokens.Vermilion,
                shape = RoundedCornerShape(2.dp),
                modifier = Modifier.padding(vertical = 4.dp).heightIn(min = 62.dp)
                    .weight(0.015f)
            ) {}
            Column(
                modifier = Modifier.weight(1f).padding(horizontal = 12.dp, vertical = 9.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Text(
                    title, color = Color(0xFF25474B), fontSize = 12.sp,
                    fontWeight = if (emphasis) FontWeight.Bold else FontWeight.SemiBold
                )
                content()
            }
        }
    }
}
