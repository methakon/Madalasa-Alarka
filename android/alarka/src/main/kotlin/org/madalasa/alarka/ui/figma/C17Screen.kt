package org.madalasa.alarka.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** C-17: Access withdrawn; Figma functional handoff.
 * TODO(INTEGRATION/API): Revocation epoch, device stream invalidation, tombstone reconciliation
 * TODO(INTEGRATION/GATE): Stop new unauthorized sharing and queued retries
 * TODO(INTEGRATION/FAILURE): Old data cached; device offline; revoked token
 * Acceptance: Server denies revoked principal even across restore.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun C17Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "C-17", title = "Access withdrawn", hero = "What happens after access is revoked?",
        kind = "privacy", milestone = "M6", requirement = "FR-013/022",
        details = listOf("Who was removed", "current data permission", "next sync rights"),
        action = "Review access details", modifier = modifier
    )
}
