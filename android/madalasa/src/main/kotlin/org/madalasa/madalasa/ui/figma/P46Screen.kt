package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-46: Capability before purchase; Figma functional handoff.
 * TODO(INTEGRATION/API): Backend device capability and legal-purpose entitlement gating
 * TODO(INTEGRATION/GATE): Do not sell unavailable media, usage or managed controls; OWNER DECISION: no automatic renewal, no trial reset, founding first 1,008 paying families and approved retention gates
 * TODO(INTEGRATION/FAILURE): Feature UNKNOWN; permission denied; old API
 * Acceptance: Unsupported clearly labeled before Play checkout. Confirm expiry-to-free six-hour history and reduced GPS; prepaid explicit confirmation; X close does not end trial.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P46Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-46", title = "Capability before purchase", hero = "Know exactly what your phone supports",
        kind = "billing", milestone = "M7", requirement = "FR-039",
        details = listOf("STANDARD vs MANAGED", "OS restrictions", "legal feature flags", "2026-10-27: compact dismissible Super Access trial status"),
        action = "View plan only if suitable", modifier = modifier
    )
}
