package org.madalasa.madalasa.ui.figma

import android.app.Activity
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
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch
import org.madalasa.madalasa.api.GoogleHandoffFailure
import org.madalasa.madalasa.api.GoogleHandoffResult
import org.madalasa.madalasa.api.GoogleParentConfiguration
import org.madalasa.madalasa.api.GoogleParentCredentialFlow
import org.madalasa.madalasa.api.VerifiedParentSession
import org.madalasa.madalasa.api.googleHandoffMessage

/**
 * P-04 / live Figma 9:147. Native Google Account handoff.
 * A real Google account chooser is shown ONLY when its development config
 * (web OAuth client ID + HTTPS backend origin) and an accepting session sink
 * exist. An accepted Google ID token is exchanged with the existing Drogon
 * POST /v1/auth/parent/google endpoint; local account choices are NEVER
 * treated as guardian authority or child-monitoring consent.
 */
internal fun canLaunchGoogleAccountChooser(
    configuration: GoogleParentConfiguration?,
    sinkAvailable: Boolean,
    activityAvailable: Boolean,
    busy: Boolean
): Boolean = configuration?.isConfigured() == true &&
    sinkAvailable && activityAvailable && !busy

@Composable
fun P04Screen(
    modifier: Modifier = Modifier,
    configuration: GoogleParentConfiguration? = null,
    onVerifiedSession: ((VerifiedParentSession) -> Boolean)? = null,
    onNewAttempt: () -> Unit = {},
    onBack: (() -> Unit)? = null
) {
    val ink = Color(0xFF25474B)
    val muted = Color(0xFF6B8585)
    val teal = Color(0xFF087E83)
    val darkTeal = Color(0xFF164950)
    val context = LocalContext.current
    val activity = context as? Activity
    val scope = rememberCoroutineScope()
    val credentialFlow = remember { GoogleParentCredentialFlow() }
    var busy by remember { mutableStateOf(false) }
    var state by remember { mutableStateOf<GoogleHandoffResult?>(null) }
    var showGuardianNotice by remember { mutableStateOf(false) }

    val configured = canLaunchGoogleAccountChooser(
        configuration = configuration,
        sinkAvailable = onVerifiedSession != null,
        activityAvailable = activity != null,
        busy = busy
    )
    val accepted = state as? GoogleHandoffResult.Accepted
    val lastFailure = (state as? GoogleHandoffResult.Denied)?.reason

    Column(
        modifier = modifier.fillMaxSize().background(Color(0xFFF9FBFB))
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
                Text("GOOGLE", color = Color(0xFF3F5C61), fontSize = 11.sp)
            }
        }
        Spacer(Modifier.height(20.dp))
        Text("Google account handoff", color = darkTeal, fontSize = 20.sp,
            fontWeight = FontWeight.Bold, modifier = Modifier.padding(horizontal = 4.dp))
        Spacer(Modifier.height(11.dp))
        Text("Parent APP    P-04    M1    FR-001",
            color = muted, fontSize = 10.sp, modifier = Modifier.padding(horizontal = 4.dp))
        Spacer(Modifier.height(28.dp))
        Surface(color = Color(0xFFDDF2EC), shape = RoundedCornerShape(17.dp),
            modifier = Modifier.fillMaxWidth().heightIn(min = 124.dp)) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.SpaceBetween) {
                Text("Choose a Google account", color = Color(0xFF116E71),
                    fontSize = 16.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(25.dp))
                Text("AUTH • M1 • FUNCTIONAL CONCEPT",
                    color = Color(0xFF3B7775), fontSize = 10.sp)
            }
        }
        Spacer(Modifier.height(17.dp))

        GoogleHandoffCard("Account chooser", emphasized = true) {
            Text(
                "Google Credential Manager shows the device's account chooser after you tap Continue.",
                color = ink, fontSize = 12.sp, lineHeight = 17.sp
            )
        }
        Spacer(Modifier.height(10.dp))
        GoogleHandoffCard("Profile indicator") {
            Text(
                if (accepted != null) {
                    "Verified Google identity: " + accepted.displayLabel +
                        ". Child-specific guardian access is NOT yet verified."
                } else {
                    "No server-verified Google account selected."
                },
                color = ink, fontSize = 12.sp, lineHeight = 17.sp
            )
        }
        Spacer(Modifier.height(10.dp))
        GoogleHandoffCard("Guardian disclosure") {
            Text(
                "Google login establishes identity, not a lawful guardian relationship or child-data consent.",
                color = ink, fontSize = 12.sp, lineHeight = 17.sp
            )
            OutlinedButton(
                onClick = { showGuardianNotice = true },
                modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)
            ) { Text("What can a guardian access?") }
        }
        Spacer(Modifier.height(10.dp))
        GoogleHandoffCard("Verification status") {
            Text(
                when {
                    busy -> "Waiting for Google account selection and server verification…"
                    accepted != null -> "Identity accepted by development server. Child access is pending authorization."
                    lastFailure != null -> googleHandoffMessage(lastFailure)
                    !configured -> googleHandoffMessage(GoogleHandoffFailure.NOT_CONFIGURED)
                    else -> "Ready to open Android's Google account chooser."
                },
                color = ink, fontSize = 12.sp, lineHeight = 17.sp
            )
        }
        Spacer(Modifier.height(12.dp))

        Button(
            onClick = {
                val validActivity = activity
                val validConfig = configuration
                val sink = onVerifiedSession
                if (validActivity != null && validConfig != null && sink != null && !busy) {
                    onNewAttempt() // A different account must not inherit a previous session.
                    state = null
                    busy = true
                    scope.launch {
                        try {
                            when (val result = credentialFlow.chooseAndExchange(validActivity, validConfig)) {
                                is GoogleHandoffResult.Accepted -> {
                                    state = if (sink(result.session)) {
                                        result
                                    } else {
                                        GoogleHandoffResult.Denied(GoogleHandoffFailure.SERVER_REJECTED)
                                    }
                                }
                                is GoogleHandoffResult.Denied -> state = result
                            }
                        } finally {
                            busy = false
                        }
                    }
                }
            },
            enabled = configured,
            modifier = Modifier.fillMaxWidth().heightIn(min = 50.dp),
            shape = RoundedCornerShape(14.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = teal,
                disabledContainerColor = teal.copy(alpha = 0.7f),
                disabledContentColor = Color.White
            )
        ) {
            if (busy) {
                CircularProgressIndicator(
                    modifier = Modifier.height(18.dp).width(18.dp),
                    strokeWidth = 2.dp,
                    color = Color.White
                )
            } else {
                Text("Continue securely", fontSize = 14.sp, fontWeight = FontWeight.Bold)
            }
        }

        Spacer(Modifier.height(12.dp))
        Text(
            "No child's data is displayed by this identity screen. A server session is not guardian proof.",
            color = muted, fontSize = 11.sp, lineHeight = 17.sp
        )
        if (onBack != null) {
            TextButton(onClick = onBack, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) {
                Text("Back to sign in")
            }
        }
    }

    if (showGuardianNotice) {
        AlertDialog(
            onDismissRequest = { showGuardianNotice = false },
            title = { Text("Identity is not guardian authority") },
            text = {
                Text(
                    "The development server verifies Google's ID token and issues a short-lived " +
                        "parent session. Child access additionally requires a live family membership, " +
                        "a child-scoped guardian grant and applicable permissions and legal authority. " +
                        "Selecting a Google account never grants these automatically."
                )
            },
            confirmButton = {
                TextButton(onClick = { showGuardianNotice = false }) { Text("Close") }
            }
        )
    }
}

@Composable
private fun GoogleHandoffCard(
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
