package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-25: Trip revision history; Figma functional handoff.
 * TODO(INTEGRATION/API): C++ event-time revisions ledger and dedupe receipts
 * TODO(INTEGRATION/GATE): Raw observations immutable; derived revision traceable
 * TODO(INTEGRATION/FAILURE): Late packet; job retries; reordered timestamps
 * Acceptance: Revision reason and timestamp shown.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P25Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-25", title = "Trip revision history", hero = "Why did this trip change?",
        kind = "list", milestone = "M3", requirement = "FR-024/032",
        details = listOf("Version badges", "changed spans", "before/after reasons"),
        action = "Compare versions", modifier = modifier
    )
}
