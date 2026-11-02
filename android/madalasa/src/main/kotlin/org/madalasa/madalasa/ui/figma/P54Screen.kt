package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-54: Cancel/manage subscription; Figma functional handoff.
 * TODO(INTEGRATION/API): Deep link to store management and verified expiry receipt
 * TODO(INTEGRATION/GATE): No automatic renewal; deletion and billing verification separate; legacy auto-renew (if ever issued) needs explicit cancellation check
 * TODO(INTEGRATION/FAILURE): Play unavailable; mismatch; paid until date
 * Acceptance: Never charge at expiry or on feature access; free status after expiry.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P54Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-54", title = "Cancel/manage subscription", hero = "Manage prepaid access and view expiry",
        kind = "billing", milestone = "M7", requirement = "FR-012",
        details = listOf("Verified current prepaid entitlement, expiry, one-time top up or purchase, receipts", "no auto-renew toggle"),
        action = "Purchase another prepaid term only with explicit confirmation", modifier = modifier
    )
}
