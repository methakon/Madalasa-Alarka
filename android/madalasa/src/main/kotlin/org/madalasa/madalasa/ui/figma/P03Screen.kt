package org.madalasa.madalasa.ui.figma

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * P-03 / Figma 9:99 — parent account creation form scaffold.
 *
 * This form preserves the actual Figma four-field structure and visual palette
 * while providing responsive native input and clear validation. It does NOT
 * transmit entered data, create a principal, accept official Terms, generate
 * a family, attach a child or impersonate a Google identity provider.
 *
 * TODO(INTEGRATION): verified OIDC parent principal → trusted V2 family binding
 * with server-side idempotency, exact-child scope and accepted legal notices.
 */
enum class AccountDraftGate {
    INCOMPLETE,
    IDENTITY_UNVERIFIED,
    READY_FOR_SERVER_VALIDATION
}

internal fun accountDraftGate(
    name: String,
    email: String,
    acknowledgedPreview: Boolean,
    verifiedIdentity: Boolean
): AccountDraftGate {
    val emailLooksPlausible = Regex("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")
        .matches(email.trim())
    if (name.trim().isEmpty() || !emailLooksPlausible || !acknowledgedPreview) {
        return AccountDraftGate.INCOMPLETE
    }
    if (!verifiedIdentity) return AccountDraftGate.IDENTITY_UNVERIFIED
    return AccountDraftGate.READY_FOR_SERVER_VALIDATION
}

@Composable
fun P03Screen(
    modifier: Modifier = Modifier,
    onBack: (() -> Unit)? = null
) {
    val ink = Color(0xFF25474B)
    val muted = Color(0xFF6B8585)
    val teal = Color(0xFF087E83)
    var displayName by rememberSaveable { mutableStateOf("") }
    var email by rememberSaveable { mutableStateOf("") }
    var understoodPreview by rememberSaveable { mutableStateOf(false) }
    var showTermsInfo by remember { mutableStateOf(false) }
    val formStatus = accountDraftGate(displayName, email, understoodPreview, false)

    Column(
        modifier.fillMaxSize().background(Color(0xFFF9FBFB))
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 17.dp, vertical = 11.dp),
        verticalArrangement = Arrangement.spacedBy(0.dp)
    ) {
        Surface(color = Color(0xFFEBF5F4), shape = RoundedCornerShape(9.dp),
            modifier = Modifier.fillMaxWidth().height(35.dp)) {
            Row(Modifier.padding(horizontal = 12.dp),
                verticalAlignment = Alignment.CenterVertically) {
                Text("MADALASA", color = Color(0xFF3F5C61), fontSize = 11.sp,
                    fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.weight(1f))
                Text("ACCOUNT", color = Color(0xFF3F5C61), fontSize = 11.sp)
            }
        }
        Spacer(Modifier.height(20.dp))
        Text("Create account", color = Color(0xFF164950),
            fontSize = 20.sp, fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(horizontal = 4.dp))
        Spacer(Modifier.height(11.dp))
        Text("Parent APP    P-03    M1    FR-001",
            color = muted, fontSize = 10.sp, modifier = Modifier.padding(horizontal = 4.dp))
        Spacer(Modifier.height(28.dp))
        Surface(color = Color(0xFFDDF2EC), shape = RoundedCornerShape(17.dp),
            modifier = Modifier.fillMaxWidth().heightIn(min = 124.dp)) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.SpaceBetween) {
                Text("Create your parent account", color = Color(0xFF116E71),
                    fontSize = 16.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(25.dp))
                Text("FORM • M1 • FUNCTIONAL CONCEPT",
                    color = Color(0xFF3B7775), fontSize = 10.sp)
            }
        }
        Spacer(Modifier.height(17.dp))

        CreateAccountCard("Name", emphasized = true) {
            OutlinedTextField(
                value = displayName,
                onValueChange = { displayName = it.take(120) },
                singleLine = true,
                label = { Text("Display name") },
                modifier = Modifier.fillMaxWidth()
            )
        }
        Spacer(Modifier.height(10.dp))

        CreateAccountCard("Email") {
            OutlinedTextField(
                value = email,
                onValueChange = { email = it.take(254) },
                singleLine = true,
                label = { Text("Email (local draft)") },
                modifier = Modifier.fillMaxWidth()
            )
            Text("Not sent or stored by a server in this build.",
                color = muted, fontSize = 11.sp)
        }
        Spacer(Modifier.height(10.dp))

        CreateAccountCard("Password or Google") {
            Text(
                "No password field is offered until secure identity onboarding is connected. " +
                    "Google identity requires the Android credential flow and server verification.",
                color = ink, fontSize = 12.sp, lineHeight = 17.sp
            )
        }
        Spacer(Modifier.height(10.dp))

        CreateAccountCard("Terms and privacy") {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Checkbox(
                    checked = understoodPreview,
                    onCheckedChange = { understoodPreview = it }
                )
                Text(
                    "I understand this is only a local UI draft, not legal consent.",
                    color = ink, fontSize = 12.sp, lineHeight = 17.sp,
                    modifier = Modifier.weight(1f)
                )
            }
            OutlinedButton(
                onClick = { showTermsInfo = true },
                modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)
            ) { Text("Read preview disclosure") }
        }
        Spacer(Modifier.height(12.dp))

        Button(
            onClick = {}, enabled = false,
            modifier = Modifier.fillMaxWidth().heightIn(min = 50.dp),
            shape = RoundedCornerShape(14.dp),
            colors = ButtonDefaults.buttonColors(
                disabledContainerColor = teal, disabledContentColor = Color.White
            )
        ) {
            Text("Create account", fontSize = 14.sp, fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(12.dp))
        Text(
            when (formStatus) {
                AccountDraftGate.INCOMPLETE ->
                    "Draft incomplete. Enter a name and valid email, then review the disclosure."
                AccountDraftGate.IDENTITY_UNVERIFIED ->
                    "Draft is complete locally; identity has NOT been verified. Account creation stays disabled."
                AccountDraftGate.READY_FOR_SERVER_VALIDATION ->
                    "Server-side verification is still required."
            },
            color = Color(0xFFB73527), fontSize = 12.sp, lineHeight = 17.sp
        )
        Text("No account or family has been created.", color = muted, fontSize = 11.sp)
        if (onBack != null) {
            TextButton(onClick = onBack, modifier = Modifier.fillMaxWidth()) {
                Text("Back to sign in")
            }
        }
    }

    if (showTermsInfo) {
        AlertDialog(
            onDismissRequest = { showTermsInfo = false },
            title = { Text("Account privacy and terms") },
            text = {
                Text(
                    "This is a development screen, not final contractual consent. " +
                        "Official terms, child-data purposes and guardian verification " +
                        "must be presented and accepted in the authenticated onboarding flow."
                )
            },
            confirmButton = {
                TextButton(onClick = { showTermsInfo = false }) { Text("Close") }
            }
        )
    }
}

@Composable
private fun CreateAccountCard(
    title: String,
    emphasized: Boolean = false,
    content: @Composable () -> Unit
) {
    Surface(
        color = if (emphasized) Color(0xFFECF7F4) else Color.White,
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth().heightIn(min = 70.dp)
    ) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.width(5.dp).height(62.dp).background(
                if (emphasized) Color(0xFF087E83) else Color(0xFFB8DAD1),
                RoundedCornerShape(2.dp)
            ))
            Column(
                Modifier.weight(1f).padding(horizontal = 12.dp, vertical = 9.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Text(title, color = Color(0xFF25474B), fontSize = 12.sp,
                    fontWeight = if (emphasized) FontWeight.Bold else FontWeight.Medium)
                content()
            }
        }
    }
}
