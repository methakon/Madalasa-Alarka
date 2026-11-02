package org.madalasa.madalasa.ui.figma

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
        SupplementSpec(id = "P-01", figmaNode = "25:2", title = "Child device connecting", summary = "Pairing must complete before this phone can trust device reports.", section = "PAIRING STATUS", kind = "CAPABILITY", primaryAction = "Check device pairing", secondaryAction = "Open setup instructions",
            rows = listOf(
                SupplementRow("Pairing code submitted", "PENDING", "Waiting for device-bound identity proof"),
                SupplementRow("Child hardware report", "UNKNOWN", "Not received from verified Alarka"),
                SupplementRow("Protected features", "INFO", "Do not display green before verified report"),
            )
        ),
        SupplementSpec(id = "P-02", figmaNode = "25:26", title = "Device overview", summary = "Last device report received from Alarka · just now.", section = "DEVICE OVERVIEW · R18", kind = "CAPABILITY", primaryAction = "Open compatibility list", secondaryAction = "Request fresh check",
            rows = listOf(
                SupplementRow("Compatible features", "SUPPORTED", "6 supported on this phone"),
                SupplementRow("Permissions approved", "GRANTED", "3 granted by Android"),
                SupplementRow("Limited / conditional", "CONDITIONAL", "2 need context or later approval"),
                SupplementRow("Not available", "UNSUPPORTED", "1 unsupported or disabled"),
            )
        ),
        SupplementSpec(id = "P-03", figmaNode = "25:53", title = "Feature compatibility", summary = "Tap a feature to understand exactly what works on this phone.", section = "CAPABILITY SNAPSHOT", kind = "CAPABILITY", primaryAction = "See all features", secondaryAction = "Last verified 00:19 IST",
            rows = listOf(
                SupplementRow("Location", "CONDITIONAL", "Hardware supported · use gated by policy"),
                SupplementRow("Monitoring notification", "GRANTED", "Enabled and reported recently"),
                SupplementRow("Microphone", "RESEARCH", "Hardware present · capture not released"),
                SupplementRow("Screen viewing", "ACTION_REQUIRED", "Needs new Android consent each time"),
            )
        ),
        SupplementSpec(id = "P-04", figmaNode = "25:80", title = "Setup progress", summary = "Alarka sends a verified revision after each approved permission.", section = "SETUP PROGRESS · 4 / 8", kind = "CAPABILITY", primaryAction = "View next child step", secondaryAction = "Refresh report",
            rows = listOf(
                SupplementRow("Hardware scan", "SYNCED", "Uploaded and authenticated"),
                SupplementRow("Foreground location", "PENDING", "Awaiting OS grant"),
                SupplementRow("Notifications", "GRANTED", "Android approval confirmed"),
                SupplementRow("Background location", "CONDITIONAL", "Requires separate later Settings flow"),
            )
        ),
        SupplementSpec(id = "P-05", figmaNode = "25:107", title = "Access granted", summary = "Alarka confirmed this OS permission and the server accepted it.", section = "GRANT CHANGE · VERIFIED", kind = "CAPABILITY", primaryAction = "Open feature status", secondaryAction = "Review change history",
            rows = listOf(
                SupplementRow("Notifications", "GRANTED", "Permission granted"),
                SupplementRow("Device revision", "SYNCED", "18 accepted; report from 00:19"),
                SupplementRow("Feature operational state", "CONDITIONAL", "App notification delivery still device-dependent"),
            )
        ),
        SupplementSpec(id = "P-06", figmaNode = "25:131", title = "Permission disabled", summary = "The child phone reported a real Android permission revocation.", section = "ACCESS CHANGE · ALERT", kind = "CAPABILITY", primaryAction = "See steps to restore", secondaryAction = "Dismiss notice",
            rows = listOf(
                SupplementRow("Microphone", "REVOKED", "Permission revoked at device"),
                SupplementRow("Live listening", "STOPPED", "Unavailable; stop any in-progress session"),
                SupplementRow("Latest verification", "VERIFIED", "00:19 · device report revision 19"),
                SupplementRow("Other enabled features", "INFO", "Continue independently where allowed"),
            )
        ),
        SupplementSpec(id = "P-07", figmaNode = "25:158", title = "Denied or unsupported?", summary = "These are different reasons and need different next actions.", section = "FEATURE TROUBLESHOOT", kind = "CAPABILITY", primaryAction = "View recommended action", secondaryAction = "Inspect device compatibility",
            rows = listOf(
                SupplementRow("Camera · permission denied", "DENIED", "Can review Alarka's Android Settings"),
                SupplementRow("Device owner control", "UNSUPPORTED", "Phone is standard mode"),
                SupplementRow("Microphone · public build", "RESEARCH", "Media research disabled pending approvals"),
            )
        ),
        SupplementSpec(id = "P-08", figmaNode = "25:182", title = "Temporary access", summary = "Android grants can expire. Confirm before relying on the feature.", section = "ONE-TIME PERMISSION", kind = "CAPABILITY", primaryAction = "View access duration", secondaryAction = "Review Android permissions",
            rows = listOf(
                SupplementRow("Camera", "TEMPORARY", "Only this time was selected"),
                SupplementRow("After Alarka stops", "CONDITIONAL", "The grant may no longer be usable"),
                SupplementRow("Current feature availability", "PENDING", "Not guaranteed until new verified execution"),
            )
        ),
        SupplementSpec(id = "P-09", figmaNode = "25:206", title = "Partial media access", summary = "Alarka can only access the media that was actually shared.", section = "MEDIA SCOPE", kind = "CAPABILITY", primaryAction = "How to change selection", secondaryAction = "Show authorised scopes",
            rows = listOf(
                SupplementRow("Shared photos", "PARTIAL", "User-selected gallery items only"),
                SupplementRow("All photos", "DENIED", "Not authorised"),
                SupplementRow("Documents", "NOT_GRANTED", "No folder access granted"),
                SupplementRow("Private app files", "UNSUPPORTED", "Protected by Android"),
            )
        ),
        SupplementSpec(id = "P-10", figmaNode = "25:233", title = "Remote camera conditions", summary = "Hardware and permission can be ready while remote start is restricted.", section = "CONDITIONAL MEDIA · P3", kind = "CAPABILITY", primaryAction = "Explain unavailable reason", secondaryAction = "Read compatibility conditions",
            rows = listOf(
                SupplementRow("Front and rear camera", "SUPPORTED", "Hardware found on this phone"),
                SupplementRow("Android permission", "GRANTED", "Granted during approved test mode"),
                SupplementRow("Background session start", "CONDITIONAL", "Standard-mode Android restriction"),
                SupplementRow("Commercial availability", "RESEARCH", "Disabled until release approval"),
            )
        ),
        SupplementSpec(id = "P-11", figmaNode = "25:260", title = "Screen request approval", summary = "Each new Android screen-sharing session needs device-user approval.", section = "ON-DEMAND SCREEN VIEW", kind = "CAPABILITY", primaryAction = "Send consent request", secondaryAction = "Cancel request",
            rows = listOf(
                SupplementRow("Android MediaProjection", "SUPPORTED", "Feature supported in eligible workflows"),
                SupplementRow("New session consent", "ACTION_REQUIRED", "Needed on Alarka's phone"),
                SupplementRow("Protected screens", "CONDITIONAL", "Some content cannot be shared"),
            )
        ),
        SupplementSpec(id = "P-12", figmaNode = "25:284", title = "Managed-mode requirement", summary = "Some controls work only on a properly provisioned device owner.", section = "DEVICE MODE", kind = "CAPABILITY", primaryAction = "View enrollment conditions", secondaryAction = "Use standard features",
            rows = listOf(
                SupplementRow("Current Alarka mode", "STANDARD", "STANDARD · normal installation"),
                SupplementRow("Device-owner status", "UNSUPPORTED", "Not enrolled as device owner"),
                SupplementRow("Managed controls", "CONDITIONAL", "Unavailable until separate enrollment"),
            )
        ),
        SupplementSpec(id = "P-13", figmaNode = "26:2", title = "Alarka is offline", summary = "No fresh report has arrived. The cause cannot yet be determined.", section = "DEVICE STATUS", kind = "CAPABILITY", primaryAction = "Retry when connected", secondaryAction = "See last verified report",
            rows = listOf(
                SupplementRow("Last contact", "STALE", "26 minutes ago · reported by server"),
                SupplementRow("Microphone permission", "UNKNOWN", "Previously granted; current state unknown"),
                SupplementRow("New camera request", "WAITING", "Do not attempt until reachable"),
                SupplementRow("Next action", "ACTION_REQUIRED", "Check child phone connectivity"),
            )
        ),
        SupplementSpec(id = "P-14", figmaNode = "26:29", title = "Status needs recheck", summary = "The device is online, but permission details are older than our freshness limit.", section = "STALE CAPABILITY", kind = "CAPABILITY", primaryAction = "Request fresh capability scan", secondaryAction = "Continue with known-safe features",
            rows = listOf(
                SupplementRow("Report version", "STALE", "R17 · last verified yesterday"),
                SupplementRow("New permission claim", "UNKNOWN", "No device-backed confirmation yet"),
                SupplementRow("Refresh process", "PENDING", "Send authenticated sync request"),
            )
        ),
        SupplementSpec(id = "P-15", figmaNode = "26:53", title = "Status restored", summary = "The child phone sent a newer signed capability report.", section = "DEVICE SYNC RESTORED", kind = "CAPABILITY", primaryAction = "View latest capabilities", secondaryAction = "Open change history",
            rows = listOf(
                SupplementRow("Device report", "SYNCED", "Revision 19 accepted by server"),
                SupplementRow("Notification permission", "GRANTED", "Still granted"),
                SupplementRow("Camera", "CONDITIONAL", "Permission granted; remote start conditional"),
                SupplementRow("Parent dashboard", "VERIFIED", "Updated after server version 19"),
            )
        ),
        SupplementSpec(id = "P-16", figmaNode = "26:80", title = "Permission change history", summary = "Only verified, privacy-safe state changes are shown.", section = "EVENT LOG", kind = "CAPABILITY", primaryAction = "View event details", secondaryAction = "Privacy and retention policy",
            rows = listOf(
                SupplementRow("00:19 · Location changed", "VERIFIED", "Foreground precise -> approximate"),
                SupplementRow("00:12 · Microphone revoked", "REVOKED", "Reported by authenticated Alarka"),
                SupplementRow("00:05 · Notifications granted", "GRANTED", "Server acknowledged version 18"),
                SupplementRow("Yesterday · Scan completed", "INFO", "Device hardware inventory refreshed"),
            )
        ),
        SupplementSpec(id = "P-17", figmaNode = "26:107", title = "How to enable location", summary = "The next step happens on the Alarka device, not from Madalasa.", section = "RECOMMENDED ACTION", kind = "CAPABILITY", primaryAction = "Send setup instructions", secondaryAction = "Keep this feature disabled",
            rows = listOf(
                SupplementRow("What is missing", "NOT_GRANTED", "Background location scope"),
                SupplementRow("Why it matters", "CONDITIONAL", "May affect approved location features"),
                SupplementRow("Safe instructions", "ACTION_REQUIRED", "Open Alarka > permissions > Android Settings"),
                SupplementRow("After approval", "PENDING", "Alarka rechecks and publishes fresh report"),
            )
        ),
        SupplementSpec(id = "P-18", figmaNode = "26:134", title = "Guardian access check", summary = "Not every family member can see every device capability.", section = "CHILD-SCOPED ACCESS", kind = "CAPABILITY", primaryAction = "Review family permissions", secondaryAction = "Close details",
            rows = listOf(
                SupplementRow("Family owner", "GRANTED", "May manage documented child settings"),
                SupplementRow("Pickup-only guardian", "UNSUPPORTED", "No sensor/media permission controls"),
                SupplementRow("Access revoked", "REVOKED", "Stop streams and redact sensitive status"),
            )
        ),
        SupplementSpec(id = "P-19", figmaNode = "26:158", title = "Report version conflict", summary = "A delayed update was rejected; the newest state remains authoritative.", section = "SYNC CONFLICT", kind = "CAPABILITY", primaryAction = "Request current report", secondaryAction = "Show diagnostic request ID",
            rows = listOf(
                SupplementRow("Server has revision", "VERIFIED", "19 (newer)"),
                SupplementRow("Incoming revision", "DENIED", "17 (older) · ignored"),
                SupplementRow("Client dashboard", "GRANTED", "No rollback to stale green status"),
                SupplementRow("Next step", "ACTION_REQUIRED", "Ask Alarka for a fresh report"),
            )
        ),
        SupplementSpec(id = "P-20", figmaNode = "26:185", title = "Privacy switch disabled", summary = "Android's global microphone control is currently off.", section = "DEVICE SENSOR CONTEXT", kind = "CAPABILITY", primaryAction = "Explain child-device action", secondaryAction = "Stop attempting this session",
            rows = listOf(
                SupplementRow("Microphone hardware", "SUPPORTED", "Present and supported"),
                SupplementRow("App-level permission", "GRANTED", "Previously granted"),
                SupplementRow("OS-level sensor control", "CONDITIONAL", "Unavailable while privacy switch is off"),
                SupplementRow("Parent request outcome", "DENIED", "Sensor cannot run in this context"),
            )
        ),
        SupplementSpec(id = "P-21", figmaNode = "26:212", title = "Approval reversed", summary = "The Android permission was disabled after an earlier grant.", section = "DEVICE REVOCATION", kind = "CAPABILITY", primaryAction = "View reapproval instructions", secondaryAction = "Review status history",
            rows = listOf(
                SupplementRow("Previously reported", "INFO", "Camera access granted at 00:10"),
                SupplementRow("Latest device check", "REVOKED", "Permission now revoked at 00:19"),
                SupplementRow("Server synchronization", "SYNCED", "Revision 20 securely accepted"),
                SupplementRow("Parent status", "VERIFIED", "Changed to unavailable · reason shown"),
            )
        ),
        SupplementSpec(id = "P-22", figmaNode = "26:239", title = "Full compatibility details", summary = "Every feature is a combination of five independent checks.", section = "EXPLAIN STATUS", kind = "CAPABILITY", primaryAction = "See latest device checks", secondaryAction = "What do colors mean?",
            rows = listOf(
                SupplementRow("Device support", "SUPPORTED", "Hardware/API compatibility result"),
                SupplementRow("Permission scope", "PARTIAL", "Denied / selected / granted / temporary"),
                SupplementRow("Execution context", "CONDITIONAL", "Android service/start eligibility"),
                SupplementRow("Release and freshness", "RESEARCH", "Approved + last current verified report"),
            )
        ),
        SupplementSpec(id = "PA-01", figmaNode = "32:3", title = "Media activity", summary = "History for authorized child devices", section = "MEDIA ACTIVITY  •  SAMPLE DATA", kind = "MEDIA", primaryAction = "", secondaryAction = "1–20 of 61   ‹ Previous   Next ›",
            rows = listOf(
                SupplementRow("Audio · Live viewed", "COMPLETE", "Child A • 27 Oct 10:42 • COMPLETE   ·   02:35 · Viewed only"),
                SupplementRow("Image · Snapshot", "SAVED", "Child B • 27 Oct 09:15 • SAVED   ·   File 1.4 MB · Parent saved"),
                SupplementRow("Video · Request failed", "FAILED", "Child A • 26 Oct 20:10 • FAILED   ·   Camera already in use"),
            )
        ),
        SupplementSpec(id = "PA-02", figmaNode = "32:29", title = "Choose a child", summary = "Select a child from your family", section = "MEDIA ACTIVITY  •  SAMPLE DATA", kind = "MEDIA", primaryAction = "", secondaryAction = "Only children you are allowed to view",
            rows = listOf(
                SupplementRow("All my children", "INFO", "3 permitted linked devices • INFO   ·   SELECTED"),
                SupplementRow("Child A • CH-••17", "INFO", "Madalasa family member • INFO   ·   OPTION"),
                SupplementRow("Child B • CH-••42", "INFO", "Madalasa family member • INFO   ·   OPTION"),
                SupplementRow("Child C • CH-••63", "INFO", "Madalasa family member • INFO   ·   OPTION"),
            )
        ),
        SupplementSpec(id = "PA-03", figmaNode = "32:59", title = "Date range", summary = "Choose the time period to review", section = "MEDIA ACTIVITY  •  SAMPLE DATA", kind = "MEDIA", primaryAction = "", secondaryAction = "Apply dates     •     Reset last 7 days",
            rows = listOf(
                SupplementRow("From date · included", "INFO", "20 Oct 2026 · 00:00 local • INFO   ·   FIELD"),
                SupplementRow("To date · included in UI", "INFO", "27 Oct 2026 · 23:59 local • INFO   ·   FIELD"),
                SupplementRow("Server interval", "INFO", "UTC [from inclusive, to exclusive) • INFO   ·   INFO"),
                SupplementRow("Retention boundary", "INFO", "Earlier records may be unavailable • INFO   ·   INFO"),
            )
        ),
        SupplementSpec(id = "PA-04", figmaNode = "32:89", title = "Filter results", summary = "Narrow by media, outcome and action", section = "MEDIA ACTIVITY  •  SAMPLE DATA", kind = "MEDIA", primaryAction = "", secondaryAction = "Apply filters   •   Clear all",
            rows = listOf(
                SupplementRow("Media types", "INFO", "Audio / Image / AV video / Screen • INFO   ·   CHOICE"),
                SupplementRow("Operation", "INFO", "Live viewed / Snapshot / Record • INFO   ·   CHOICE"),
                SupplementRow("Result", "INFO", "Viewed / Saved / Failed / Cancelled • INFO   ·   CHOICE"),
                SupplementRow("Failure reason", "INFO", "Camera busy / Permission / Connection • INFO   ·   CHOICE"),
            )
        ),
        SupplementSpec(id = "PA-05", figmaNode = "32:119", title = "Session details", summary = "Audio was viewed; no file saved on server", section = "MEDIA ACTIVITY  •  SAMPLE DATA", kind = "MEDIA", primaryAction = "", secondaryAction = "Back to media history",
            rows = listOf(
                SupplementRow("Requested by", "INFO", "Your guardian account • INFO   ·   INFO"),
                SupplementRow("Session started", "INFO", "27 Oct 2026 · 10:42:03 • INFO   ·   VERIFIED"),
                SupplementRow("Active duration", "INFO", "02 min 35 sec • INFO   ·   VERIFIED"),
                SupplementRow("Saved file size", "INFO", "Not applicable to live viewing • INFO   ·   N/A"),
                SupplementRow("Network bytes", "INFO", "Measured separately; not file size • INFO   ·   INFO"),
            )
        ),
        SupplementSpec(id = "PA-06", figmaNode = "32:153", title = "Saved recording details", summary = "Parent phone confirmed a local save", section = "MEDIA ACTIVITY  •  SAMPLE DATA", kind = "MEDIA", primaryAction = "", secondaryAction = "Back to media history",
            rows = listOf(
                SupplementRow("Parent save receipt", "INFO", "Received for this session • INFO   ·   VERIFIED"),
                SupplementRow("Recording duration", "INFO", "01 min 15 sec • INFO   ·   VERIFIED"),
                SupplementRow("Local file size", "INFO", "24.6 MB at save time • INFO   ·   VERIFIED"),
                SupplementRow("Storage location", "INFO", "Encrypted parent device (not VPS) • INFO   ·   INFO"),
                SupplementRow("File now exists?", "INFO", "Not confirmed after initial save • INFO   ·   UNKNOWN"),
            )
        ),
        SupplementSpec(id = "PA-07", figmaNode = "32:187", title = "Why did it fail?", summary = "Reason verified by the reporting device", section = "Reason source: Android / DEVICE_OS", kind = "MEDIA", primaryAction = "", secondaryAction = "Return to activity",
            rows = listOf(
                SupplementRow("OS reason", "INFO", "CAMERA_IN_USE • INFO   ·   FAILED"),
                SupplementRow("Evidence", "INFO", "Android camera exception code • INFO   ·   VERIFIED"),
                SupplementRow("Duration / file size", "INFO", "Not applicable · capture never started • INFO   ·   N/A"),
                SupplementRow("Safe next action", "INFO", "Retry once device camera is available • INFO   ·   INFO"),
                SupplementRow("Another example", "INFO", "Audio unavailable: cause may be unknown • INFO   ·   UNKNOWN"),
            )
        ),
        SupplementSpec(id = "PA-08", figmaNode = "32:221", title = "No matching activity", summary = "There were no records for these filters", section = "MEDIA ACTIVITY  •  SAMPLE DATA", kind = "MEDIA", primaryAction = "", secondaryAction = "Clear filters  •  Back",
            rows = listOf(
                SupplementRow("No matching records", "INFO", "This is not a missing permission • INFO   ·   EMPTY"),
                SupplementRow("Try a broader range", "INFO", "Choose another date or media type • INFO   ·   INFO"),
                SupplementRow("Media feature availability", "INFO", "Release-gated; no activity may be expected • INFO   ·   INFO"),
            )
        ),
        SupplementSpec(id = "PA-09", figmaNode = "32:247", title = "Historical activity offline", summary = "Stored event history remains accessible", section = "MEDIA ACTIVITY  •  SAMPLE DATA", kind = "MEDIA", primaryAction = "", secondaryAction = "Refresh history   •   See last confirmed",
            rows = listOf(
                SupplementRow("Alarka status", "INFO", "Offline since 10:42 • INFO   ·   STALE"),
                SupplementRow("Last verified session", "INFO", "26 Oct · Audio · Viewed only • INFO   ·   VERIFIED"),
                SupplementRow("Current camera state", "INFO", "Cannot verify while device is offline • INFO   ·   UNKNOWN"),
                SupplementRow("New events", "INFO", "May synchronize later when device runs • INFO   ·   PENDING"),
            )
        ),
        SupplementSpec(id = "PA-10", figmaNode = "32:277", title = "Browse more activity", summary = "Server-side pagination keeps history manageable", section = "MEDIA ACTIVITY  •  SAMPLE DATA", kind = "MEDIA", primaryAction = "", secondaryAction = "Page 2   ‹ Previous     Next ›",
            rows = listOf(
                SupplementRow("Audio · Live viewed", "COMPLETE", "Child B • 21 Oct 20:10 • COMPLETE   ·   02:10 · Viewed only"),
                SupplementRow("Image · Capture failed", "FAILED", "Child B • 21 Oct 15:05 • FAILED   ·   Background start blocked"),
                SupplementRow("Video + Audio · Saved", "SAVED", "Child B • 20 Oct 16:33 • SAVED   ·   04:28 · File 86.5 MB"),
            )
        ),
        SupplementSpec(id = "PA-11", figmaNode = "32:303", title = "Access not available", summary = "Your role cannot view this child's records", section = "Guardian scope required", kind = "MEDIA", primaryAction = "", secondaryAction = "Return to family overview",
            rows = listOf(
                SupplementRow("Child-specific authorization", "INFO", "No active guardian scope • INFO   ·   DENIED"),
                SupplementRow("Data visibility", "INFO", "No results or identifiers returned • INFO   ·   PROTECTED"),
                SupplementRow("Next step", "INFO", "Ask the family owner to review access • INFO   ·   INFO"),
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
        Text(if (spec.kind == "MEDIA") "MADALASA / MEDIA ACTIVITY" else "MADALASA" + " / CAPABILITY GUIDE",
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
