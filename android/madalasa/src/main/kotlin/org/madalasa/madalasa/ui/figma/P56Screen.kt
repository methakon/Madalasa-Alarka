package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-56: Authorized file access; Figma functional handoff.
 * TODO(INTEGRATION/API): Child ACTION_OPEN_DOCUMENT/MediaStore; bounded metadata receipt
 * TODO(INTEGRATION/GATE): No blanket remote browsing or covert extraction; OS/Play rules apply
 * TODO(INTEGRATION/FAILURE): Picker canceled; file moved; access revoked
 * Acceptance: Only user-selected authorized files can be transferred.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P56Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-56", title = "Authorized file access", hero = "Choose files visibly on child device",
        kind = "form", milestone = "P2", requirement = "FR-008",
        details = listOf("Supported SAF picker", "local consent", "selected file list"),
        action = "Request user-authorized selection", modifier = modifier
    )
}
