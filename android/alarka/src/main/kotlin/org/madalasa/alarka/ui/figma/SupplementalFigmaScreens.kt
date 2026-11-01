package org.madalasa.alarka.ui.figma

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** Live Figma capability/media screen text transcribed 2026-11-02. Design-only.
 * No real child data, capture, permission grant, pairing or server states are asserted.
 * UI state rows are visibly labeled EXAMPLE and real release flows remain gated.
 */
internal data class SupplementRow(val label: String, val state: String, val detail: String)
internal data class SupplementSpec(
    val id: String, val figmaNode: String, val title: String, val summary: String,
    val section: String, val kind: String, val primaryAction: String,
    val secondaryAction: String, val rows: List<SupplementRow>
)

internal object SupplementalFigmaCatalog {
    val screens: List<SupplementSpec> = listOf(
        SupplementSpec(id = "A-01", figmaNode = "23:3", title = "Welcome to Alarka", summary = "Set up this child device with clear, reviewable permissions.", section = "SETUP 01 / 08", kind = "CAPABILITY", primaryAction = "Start compatibility scan", secondaryAction = "Read privacy summary",
            rows = listOf(
                SupplementRow("Your device, your controls", "READY", "Read disclosures before every permission"),
                SupplementRow("Monitoring stays identifiable", "INFO", "System indicators and notifications remain"),
                SupplementRow("No automatic all-access grant", "INFO", "You can skip optional permissions"),
            )
        ),
        SupplementSpec(id = "A-02", figmaNode = "23:27", title = "Checking this device", summary = "Inspecting hardware and Android capabilities. No media is captured.", section = "SCAN 02 / 08", kind = "CAPABILITY", primaryAction = "View scan results", secondaryAction = "What is scanned?",
            rows = listOf(
                SupplementRow("Hardware discovery", "SCANNING", "Camera, mic, GPS, sensors"),
                SupplementRow("Android environment", "SCANNING", "API level, power, service requirements"),
                SupplementRow("Permission snapshot", "PENDING", "Read current grants, not request them"),
            )
        ),
        SupplementSpec(id = "A-03", figmaNode = "23:51", title = "Compatibility result", summary = "This phone supports some features; others need setup or testing.", section = "SCAN COMPLETE", kind = "CAPABILITY", primaryAction = "Continue to pairing", secondaryAction = "View detailed results",
            rows = listOf(
                SupplementRow("Location and notifications", "SUPPORTED", "Available on this phone"),
                SupplementRow("Camera and microphone", "NOT_GRANTED", "Hardware found; access not granted"),
                SupplementRow("Screen sharing", "CONDITIONAL", "Supported; fresh consent per session"),
                SupplementRow("Managed controls", "UNSUPPORTED", "Standard device, not device owner"),
            )
        ),
        SupplementSpec(id = "A-04", figmaNode = "23:78", title = "Feature details", summary = "A device can support a feature that is not currently usable.", section = "DEVICE REPORT · v1", kind = "CAPABILITY", primaryAction = "Pair to share report", secondaryAction = "Re-run scan",
            rows = listOf(
                SupplementRow("Rear camera · detected", "NOT_GRANTED", "Permission not granted"),
                SupplementRow("Microphone · detected", "RESEARCH", "Research feature: release disabled"),
                SupplementRow("GPS · detected", "SETUP", "Background location not yet approved"),
                SupplementRow("Shared photos", "PARTIAL", "Android may limit to selected photos"),
            )
        ),
        SupplementSpec(id = "A-05", figmaNode = "23:105", title = "Secure device pairing", summary = "Link this child phone to the correct family before uploading status.", section = "PAIRING 03 / 08", kind = "CAPABILITY", primaryAction = "Verify and pair device", secondaryAction = "Scan a pairing QR",
            rows = listOf(
                SupplementRow("One-time pairing code", "REQUIRED", "Expires and cannot be reused"),
                SupplementRow("Device identity", "SECURE", "Hardware-backed Keystore key where available"),
                SupplementRow("Report upload", "WAITING", "Only after signed enrollment succeeds"),
            )
        ),
        SupplementSpec(id = "A-06", figmaNode = "23:129", title = "Before permissions", summary = "We explain each request and confirm the actual Android result.", section = "PERMISSIONS 04 / 08", kind = "CAPABILITY", primaryAction = "Review first request", secondaryAction = "Skip nonessential steps",
            rows = listOf(
                SupplementRow("Location", "NEXT", "For the approved child-safety feature"),
                SupplementRow("Notifications", "PLANNED", "Keep active monitoring visible"),
                SupplementRow("Usage and media", "LATER", "Separate optional or policy-gated steps"),
            )
        ),
        SupplementSpec(id = "A-07", figmaNode = "23:153", title = "Location while using", summary = "First allow foreground location. Background is a separate step.", section = "LOCATION 1 / 2", kind = "CAPABILITY", primaryAction = "Open Android location prompt", secondaryAction = "Not now",
            rows = listOf(
                SupplementRow("Location access", "ACTION_REQUIRED", "Android system prompt required"),
                SupplementRow("Choose precise or approximate", "CHOICE", "Your choice changes reported accuracy"),
                SupplementRow("Current state", "NOT_GRANTED", "Not granted; tracking is not active"),
            )
        ),
        SupplementSpec(id = "A-08", figmaNode = "23:177", title = "Background location", summary = "Only after foreground location is granted, when approved for this use.", section = "LOCATION 2 / 2", kind = "CAPABILITY", primaryAction = "Open location settings", secondaryAction = "Keep limited access",
            rows = listOf(
                SupplementRow("Foreground location", "GRANTED", "Granted · last verified just now"),
                SupplementRow("Background location", "ACTION_REQUIRED", "Android settings step is required"),
                SupplementRow("Safety and privacy", "RESEARCH", "This feature stays OFF until legal/Play gates pass"),
            )
        ),
        SupplementSpec(id = "A-09", figmaNode = "23:201", title = "Monitoring notifications", summary = "A visible notification identifies Alarka while monitoring runs.", section = "NOTIFICATIONS", kind = "CAPABILITY", primaryAction = "Allow notifications", secondaryAction = "Learn why this matters",
            rows = listOf(
                SupplementRow("System notification access", "ACTION_REQUIRED", "Android may request permission"),
                SupplementRow("Persistent monitoring notice", "REQUIRED", "Identifiable, not disguised"),
                SupplementRow("Notification channels", "INFO", "Visible status and change notices"),
            )
        ),
        SupplementSpec(id = "A-10", figmaNode = "23:225", title = "Usage access", summary = "Usage insights need separate permission in Android Settings.", section = "SPECIAL ACCESS", kind = "CAPABILITY", primaryAction = "Open Usage Access settings", secondaryAction = "Skip this optional feature",
            rows = listOf(
                SupplementRow("Usage Access", "ACTION_REQUIRED", "Not a regular runtime dialog"),
                SupplementRow("Report availability", "RESEARCH", "Conditional on legal approval"),
                SupplementRow("After you return", "VERIFY", "We verify the Settings result"),
            )
        ),
        SupplementSpec(id = "A-11", figmaNode = "23:249", title = "Choose media access", summary = "Android may allow all, selected, or no photos and videos.", section = "MEDIA ACCESS", kind = "CAPABILITY", primaryAction = "Choose authorised media", secondaryAction = "Keep media off",
            rows = listOf(
                SupplementRow("Photos and videos", "PARTIAL", "Select permitted items only"),
                SupplementRow("Audio library", "NOT_GRANTED", "Separate shared-audio permission"),
                SupplementRow("Private app files", "UNSUPPORTED", "Not accessible to Alarka"),
                SupplementRow("Documents and folders", "ACTION_REQUIRED", "Use Android system document picker"),
            )
        ),
        SupplementSpec(id = "A-12", figmaNode = "23:276", title = "Microphone permission", summary = "For authorised one-way audio research, where legally approved.", section = "MEDIA · RESEARCH", kind = "CAPABILITY", primaryAction = "View permission explanation", secondaryAction = "Leave this feature disabled",
            rows = listOf(
                SupplementRow("Microphone hardware", "SUPPORTED", "Detected on device"),
                SupplementRow("Android microphone access", "NOT_GRANTED", "Permission not granted yet"),
                SupplementRow("Remote startup", "CONDITIONAL", "May be restricted in standard mode"),
                SupplementRow("Public release", "RESEARCH", "Not enabled in this build"),
            )
        ),
        SupplementSpec(id = "A-13", figmaNode = "24:2", title = "Camera access · Research", summary = "Camera use is not enabled in the public Alarka build.", section = "MEDIA · RESEARCH", kind = "CAPABILITY", primaryAction = "Understand camera conditions", secondaryAction = "Skip and continue",
            rows = listOf(
                SupplementRow("Front and rear cameras", "SUPPORTED", "Detected hardware (not yet opened)"),
                SupplementRow("Camera permission", "NOT_GRANTED", "Requires a separate approved workflow"),
                SupplementRow("Background startup", "CONDITIONAL", "May be refused by Android"),
                SupplementRow("Release gate", "RESEARCH", "OS tests, counsel and Play required"),
            )
        ),
        SupplementSpec(id = "A-14", figmaNode = "24:29", title = "Managed-device mode", summary = "Device-owner controls require genuine separate enrollment.", section = "DEVICE MANAGEMENT", kind = "CAPABILITY", primaryAction = "View managed setup guide", secondaryAction = "Continue standard setup",
            rows = listOf(
                SupplementRow("Current enrollment", "STANDARD", "Ordinary standard app installation"),
                SupplementRow("Device owner", "UNSUPPORTED", "Not provisioned; permissions cannot upgrade it"),
                SupplementRow("Restricted controls", "CONDITIONAL", "Only available in tested managed mode"),
            )
        ),
        SupplementSpec(id = "A-15", figmaNode = "24:53", title = "Screen-sharing consent", summary = "Android requires fresh system approval for every session.", section = "SCREEN VIEW · ON DEMAND", kind = "CAPABILITY", primaryAction = "See how session consent works", secondaryAction = "Continue without screen share",
            rows = listOf(
                SupplementRow("Device support", "SUPPORTED", "Android MediaProjection available"),
                SupplementRow("Permanent grant", "UNSUPPORTED", "Not possible during setup"),
                SupplementRow("New capture request", "ACTION_REQUIRED", "Needs Android system prompt"),
                SupplementRow("Protected content", "CONDITIONAL", "Some screens remain blocked"),
            )
        ),
        SupplementSpec(id = "A-16", figmaNode = "24:80", title = "Android decision received", summary = "A dialog was completed. Alarka verifies the actual OS result.", section = "GRANT CHECK 05 / 08", kind = "CAPABILITY", primaryAction = "Verify permission now", secondaryAction = "Check again later",
            rows = listOf(
                SupplementRow("Permission request returned", "VERIFY", "Result is read from Android"),
                SupplementRow("Access granted", "PENDING", "Only mark granted after API check"),
                SupplementRow("Operational readiness", "CONDITIONAL", "Requires additional service-context tests"),
            )
        ),
        SupplementSpec(id = "A-17", figmaNode = "24:104", title = "Permission declined", summary = "Continue with other features. Nothing is secretly enabled.", section = "GRANT CHECK 05 / 08", kind = "CAPABILITY", primaryAction = "Review what requires access", secondaryAction = "Continue without microphone",
            rows = listOf(
                SupplementRow("Microphone access", "DENIED", "Not granted by Android"),
                SupplementRow("Other device features", "SUPPORTED", "Remain unaffected where independent"),
                SupplementRow("Next request", "ACTION_REQUIRED", "Explain reason; respect repeated denial"),
            )
        ),
        SupplementSpec(id = "A-18", figmaNode = "24:128", title = "Selected photos only", summary = "Some shared photos are accessible; the rest remain private.", section = "MEDIA SCOPE CHECK", kind = "CAPABILITY", primaryAction = "Review selected media", secondaryAction = "Keep current selection",
            rows = listOf(
                SupplementRow("Selected photos/videos", "PARTIAL", "Only user-selected media visible"),
                SupplementRow("All gallery items", "NOT_GRANTED", "Not granted"),
                SupplementRow("Private app data", "UNSUPPORTED", "Protected by Android"),
                SupplementRow("Change selection", "ACTION_REQUIRED", "Open supported Android picker"),
            )
        ),
        SupplementSpec(id = "A-19", figmaNode = "24:155", title = "Permission confirmed", summary = "This grant was verified on Alarka and is syncing to Madalasa.", section = "SYNC 06 / 08", kind = "CAPABILITY", primaryAction = "Check synchronization", secondaryAction = "See verified grants",
            rows = listOf(
                SupplementRow("Notification permission", "GRANTED", "Granted at latest local check"),
                SupplementRow("Device report revision", "SYNCING", "Revision 18 · pending server receipt"),
                SupplementRow("Parent app state", "WAITING", "Wait for authenticated server ACK"),
            )
        ),
        SupplementSpec(id = "A-20", figmaNode = "24:179", title = "Setup complete", summary = "You can close this screen. Android remains in control of permissions.", section = "DONE 08 / 08", kind = "CAPABILITY", primaryAction = "Finish and close setup", secondaryAction = "Review permissions",
            rows = listOf(
                SupplementRow("Secure pairing", "GRANTED", "Child device enrolled and signed"),
                SupplementRow("Capabilities saved", "SYNCED", "Verified report received by server"),
                SupplementRow("Some features conditional", "CONDITIONAL", "See details in Madalasa dashboard"),
                SupplementRow("Monitoring visibility", "INFO", "Icon and required notice remain"),
            )
        ),
        SupplementSpec(id = "A-21", figmaNode = "24:206", title = "Access changed in Settings", summary = "A permission was revoked. Alarka reports this on its next valid check.", section = "STATE CHANGE", kind = "CAPABILITY", primaryAction = "Review access controls", secondaryAction = "Close Alarka",
            rows = listOf(
                SupplementRow("Microphone", "REVOKED", "Android access disabled"),
                SupplementRow("Active listening session", "STOPPED", "Must stop when permission removed"),
                SupplementRow("Parent report", "SYNCING", "Waiting to synchronize new revision"),
                SupplementRow("Other features", "INFO", "Retain independent permissions"),
            )
        ),
        SupplementSpec(id = "A-22", figmaNode = "24:233", title = "Re-enable a permission", summary = "Android's own Settings screen handles the actual approval.", section = "PERMISSION RESTORE", kind = "CAPABILITY", primaryAction = "Open camera permission settings", secondaryAction = "Leave disabled",
            rows = listOf(
                SupplementRow("Camera", "REVOKED", "Permission revoked"),
                SupplementRow("Reapproval process", "ACTION_REQUIRED", "Open approved Android Settings action"),
                SupplementRow("After returning", "VERIFY", "Recheck OS state and upload newer revision"),
            )
        ),
        SupplementSpec(id = "A-23", figmaNode = "24:257", title = "Offline changes queued", summary = "The phone cannot confirm updates to the server yet.", section = "NETWORK UNAVAILABLE", kind = "CAPABILITY", primaryAction = "Retry secure sync", secondaryAction = "View offline explanation",
            rows = listOf(
                SupplementRow("Local permission state", "VERIFIED_LOCAL", "Latest check retained on device"),
                SupplementRow("Server version", "STALE", "Earlier reported state may be stale"),
                SupplementRow("Synchronization", "RETRY", "Retry with bounded, idempotent jobs"),
                SupplementRow("Parent device", "INFO", "Must display last confirmed timestamp"),
            )
        ),
        SupplementSpec(id = "A-24", figmaNode = "24:284", title = "Your monitoring controls", summary = "View Alarka's current access and who is allowed to see reports.", section = "TRANSPARENCY CENTER", kind = "CAPABILITY", primaryAction = "Review Android permissions", secondaryAction = "Close settings",
            rows = listOf(
                SupplementRow("Current permissions", "REVIEW", "View/revoke in Android Settings"),
                SupplementRow("Active sensor session", "INFO", "Shown with Android privacy indicators"),
                SupplementRow("Approved guardians", "REVIEW", "Verified child-specific family access"),
                SupplementRow("Activity and event history", "REVIEW", "Safe redacted status changes only"),
            )
        )
    )
    fun find(id: String): SupplementSpec? = screens.firstOrNull { it.id == id }
}

/** Pure Compose preview; unlike the production NavHost this cannot execute remote actions. */
@Composable
internal fun SupplementalFigmaScreen(
    spec: SupplementSpec,
    onNextDesign: () -> Unit,
    modifier: Modifier = Modifier
) {
    val ink = Color(0xFF17303B)
    val teal = Color(0xFF0D7A7D)
    val subtle = Color(0xFF6B828C)
    val edge = Color(0xFFD6E3E5)
    val bg = Color(0xFFF6F9FA)
    var showExplanation by remember(spec.id) { mutableStateOf(false) }
    Column(
        modifier = modifier.fillMaxSize().background(bg).verticalScroll(rememberScrollState())
            .padding(horizontal = 22.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(13.dp)
    ) {
        Text(if (spec.kind == "MEDIA") "MADALASA / MEDIA ACTIVITY" else "ALARKA" + " / CAPABILITY GUIDE",
            color = teal, fontSize = 11.sp, fontWeight = FontWeight.Bold)
        Text(spec.title, color = ink, fontSize = 25.sp, fontWeight = FontWeight.Bold)
        Text(spec.summary, color = subtle, fontSize = 13.sp, lineHeight = 19.sp)
        Surface(color = Color(0xFFF0FAF9), shape = RoundedCornerShape(14.dp),
            modifier = Modifier.fillMaxWidth().border(1.dp, edge, RoundedCornerShape(14.dp))) {
            Text(spec.section, modifier = Modifier.padding(12.dp), color = teal,
                fontSize = 12.sp, fontWeight = FontWeight.Bold)
        }
        spec.rows.forEach { row ->
            Surface(color = Color.White, shape = RoundedCornerShape(14.dp),
                modifier = Modifier.fillMaxWidth().border(1.dp, edge, RoundedCornerShape(14.dp))) {
                Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(row.label, color = ink, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                    Text("EXAMPLE · " + row.state + " · " + row.detail,
                        color = if (row.state in setOf("DENIED", "REVOKED", "FAILED"))
                            Color(0xFFB73527) else teal, fontSize = 12.sp, lineHeight = 17.sp)
                }
            }
        }
        if (spec.primaryAction.isNotBlank()) {
            Button(onClick = {}, enabled = false, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(disabledContainerColor = teal, disabledContentColor = Color.White)) {
                Text(spec.primaryAction, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
            }
        }
        if (spec.secondaryAction.isNotBlank()) {
            Text(spec.secondaryAction, color = teal, modifier = Modifier.clickable { showExplanation = !showExplanation }
                .padding(vertical = 4.dp), fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
        }
        if (showExplanation) {
            Text("Design illustration only. Device reports must be signed, authorized, fresh and server-confirmed; " +
                "a hardware feature or Android permission alone does not authorize child monitoring.",
                color = ink, fontSize = 13.sp)
        }
        OutlinedButton(onClick = onNextDesign, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) {
            Text("Next design")
        }
        Text("DEBUG DESIGN · " + spec.id + " · Figma node " + spec.figmaNode +
            " · No backend, capture or OS permission actions",
            color = subtle, fontSize = 10.sp, lineHeight = 15.sp)
    }
}
