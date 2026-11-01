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
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
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

/**
 * P-02 / Figma 9:51. Native Compose sign-in screen with explicit unconfigured
 * authentication state. The repository has a trusted *backend* OIDC contract,
 * but the Android Credential Manager and verified exchange have not been wired;
 * a mock parent session must never be labeled Google authentication.
 *
 * No email/password, Google token, guardian identity or child data is submitted
 * from this screen. The synthetic-demo action is separate and explicitly labeled.
 */
enum class SignInIssue {
    NOT_STARTED,
    CANCELLED,
    OFFLINE,
    TOKEN_EXPIRED
}

internal fun signInStateDescription(issue: SignInIssue): String = when (issue) {
    SignInIssue.NOT_STARTED ->
        "No verified session. Google identity alone does not confirm guardian authority."
    SignInIssue.CANCELLED ->
        "Sign-in cancelled. No session was created."
    SignInIssue.OFFLINE ->
        "Unable to connect. Check connectivity before retrying verified sign-in."
    SignInIssue.TOKEN_EXPIRED ->
        "The identity token expired. A new verified sign-in is required."
}

internal fun canStartGoogleSignIn(
    credentialManagerReady: Boolean,
    verifiedOidcExchangeReady: Boolean
): Boolean = credentialManagerReady && verifiedOidcExchangeReady

@Composable
fun P02Screen(
    modifier: Modifier = Modifier,
    onSyntheticContinue: (() -> Unit)? = null,
    onBack: (() -> Unit)? = null,
    onExploreAccountSetup: (() -> Unit)? = null,
    issue: SignInIssue = SignInIssue.NOT_STARTED
) {
    val teal = Color(0xFF087E83)
    val ink = Color(0xFF25474B)
    val muted = Color(0xFF6B8585)
    val darkTeal = Color(0xFF164950)
    var showRecovery by remember { mutableStateOf(false) }

    Column(
        modifier = modifier.fillMaxSize().background(Color(0xFFF9FBFB))
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 17.dp, vertical = 11.dp),
        verticalArrangement = Arrangement.spacedBy(0.dp)
    ) {
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
                    "MADALASA", color = Color(0xFF3F5C61),
                    fontSize = 11.sp, fontWeight = FontWeight.SemiBold
                )
                Spacer(Modifier.weight(1f))
                Text("SIGN IN", color = Color(0xFF3F5C61), fontSize = 11.sp)
            }
        }
        Spacer(Modifier.height(20.dp))
        Text("Sign in", color = darkTeal, fontSize = 20.sp, fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(horizontal = 4.dp))
        Spacer(Modifier.height(11.dp))
        Text("Parent APP    P-02    M1    FR-001", color = muted, fontSize = 10.sp,
            modifier = Modifier.padding(horizontal = 4.dp))
        Spacer(Modifier.height(28.dp))

        Surface(
            modifier = Modifier.fillMaxWidth().heightIn(min = 124.dp),
            color = Color(0xFFDDF2EC), shape = RoundedCornerShape(17.dp)
        ) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.SpaceBetween) {
                Text("Welcome back", color = Color(0xFF116E71),
                    fontSize = 16.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(25.dp))
                Text("AUTH • M1 • FUNCTIONAL CONCEPT",
                    color = Color(0xFF3B7775), fontSize = 10.sp)
            }
        }
        Spacer(Modifier.height(17.dp))

        SignInCard("Email sign-in area", emphasized = true) {
            OutlinedTextField(
                value = "",
                onValueChange = {},
                enabled = false,
                modifier = Modifier.fillMaxWidth(),
                label = { Text("Email (not configured)") },
                singleLine = true
            )
            Text("Email sign-in is unavailable in this build. No address is stored.",
                fontSize = 11.sp, color = muted)
        }
        Spacer(Modifier.height(10.dp))
        SignInCard("Google identity button") {
            Text(
                "Android Credential Manager and verified server OIDC exchange are pending.",
                fontSize = 12.sp, color = ink
            )
        }
        Spacer(Modifier.height(10.dp))
        SignInCard("Recovery link") {
            OutlinedButton(
                onClick = { showRecovery = true },
                modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)
            ) { Text("Sign-in recovery information") }
        }
        Spacer(Modifier.height(10.dp))
        SignInCard("Authentication status") {
            Text(signInStateDescription(issue), fontSize = 12.sp,
                color = ink, lineHeight = 17.sp)
        }
        Spacer(Modifier.height(12.dp))

        // A visually accurate Figma primary action cannot assert a real OIDC flow.
        Button(
            onClick = {},
            enabled = canStartGoogleSignIn(false, false),
            modifier = Modifier.fillMaxWidth().heightIn(min = 50.dp),
            shape = RoundedCornerShape(14.dp),
            colors = ButtonDefaults.buttonColors(
                disabledContainerColor = teal, disabledContentColor = Color.White
            )
        ) {
            Text("Continue with Google", fontSize = 14.sp, fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(12.dp))
        if (onSyntheticContinue != null) {
            OutlinedButton(
                onClick = onSyntheticContinue,
                modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)
            ) {
                Text("Continue with synthetic demo")
            }
            Text(
                "DEVELOPMENT ONLY · This is not Google Sign-In or a verified guardian session.",
                color = Color(0xFFB73527), fontSize = 11.sp, lineHeight = 16.sp
            )
        } else {
            Text("UI preview · verified identity provider is not connected.",
                color = muted, fontSize = 10.sp)
        }
        if (onExploreAccountSetup != null) {
            OutlinedButton(
                onClick = onExploreAccountSetup,
                modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)
            ) { Text("Explore account setup (preview)") }
        }
        if (onBack != null) {
            TextButton(onClick = onBack, modifier = Modifier.fillMaxWidth()) {
                Text("Back to welcome")
            }
        }
    }

    if (showRecovery) {
        AlertDialog(
            onDismissRequest = { showRecovery = false },
            title = { Text("Sign-in recovery") },
            text = {
                Text(
                    "No account recovery request was made. When identity integration is available, " +
                        "recovery must use the verified account provider without exposing credentials."
                )
            },
            confirmButton = {
                TextButton(onClick = { showRecovery = false }) { Text("Close") }
            }
        )
    }
}

@Composable
private fun SignInCard(
    title: String,
    emphasized: Boolean = false,
    content: @Composable () -> Unit
) {
    Surface(
        color = if (emphasized) Color(0xFFECF7F4) else Color.White,
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth().heightIn(min = 70.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                Modifier.width(5.dp).height(62.dp).background(
                    if (emphasized) Color(0xFF087E83) else Color(0xFFB8DAD1),
                    RoundedCornerShape(2.dp)
                )
            )
            Column(
                modifier = Modifier.weight(1f).padding(horizontal = 12.dp, vertical = 9.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Text(
                    title, color = Color(0xFF25474B), fontSize = 12.sp,
                    fontWeight = if (emphasized) FontWeight.Bold else FontWeight.Medium
                )
                content()
            }
        }
    }
}
