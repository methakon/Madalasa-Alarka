package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-47: Family seats; Figma functional handoff.
 * TODO(INTEGRATION/API): Play product family_children_N + backend verified seats
 * TODO(INTEGRATION/GATE): Owner approves every capacity change and Play price; OWNER DECISION: no automatic renewal, no trial reset, founding first 1,008 paying families and approved retention gates
 * TODO(INTEGRATION/FAILURE): Upgrade pending; mismatch; downgrade deferred
 * Acceptance: Assignments cannot exceed verified seats. Confirm expiry-to-free six-hour history and reduced GPS; prepaid explicit confirmation; X close does not end trial.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P47Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-47", title = "Family seats", hero = "One seat for each enrolled child",
        kind = "billing", milestone = "M7", requirement = "FR-012",
        details = listOf("Capacity N", "assigned children", "add/remove", "guardians free"),
        action = "Change family capacity", modifier = modifier
    )
}
