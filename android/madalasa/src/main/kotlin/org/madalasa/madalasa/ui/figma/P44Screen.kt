package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-44: Account and child deletion; Figma functional handoff.
 * TODO(INTEGRATION/API): Deletion job + tombstone; revoke epochs; offline queue cutoff
 * TODO(INTEGRATION/GATE): Keep data-subject rights available after plan expires; OWNER DECISION: no automatic renewal, no trial reset, founding first 1,008 paying families and approved retention gates
 * TODO(INTEGRATION/FAILURE): Partial delete; pending provider copy; backup restore
 * Acceptance: Erasure cannot be undone by later restored database. Confirm expiry-to-free six-hour history and reduced GPS; prepaid explicit confirmation; X close does not end trial.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P44Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-44", title = "Account and child deletion", hero = "Withdrawal stops new processing",
        kind = "privacy", milestone = "M6", requirement = "FR-013/027",
        details = listOf("Select child/account", "explain backup delay", "no automatic prepaid renewal", "legacy subscriptions checked separately"),
        action = "Request deletion", modifier = modifier
    )
}
