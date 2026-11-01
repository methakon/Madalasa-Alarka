package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-06: My children; Figma functional handoff.
 * TODO(INTEGRATION/API): GET /families/{familyId}/children (M1)
 * TODO(INTEGRATION/GATE): RLS plus exact family/child grants; no BOLA
 * TODO(INTEGRATION/FAILURE): Empty state; guardian revoked; wrong family
 * Acceptance: Foreign/ungranted child never appears in list.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P06Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-06", title = "My children", hero = "Authorized children only",
        kind = "list", milestone = "M1", requirement = "FR-022/029",
        details = listOf("Child avatars", "last heartbeat", "battery", "add child"),
        action = "Select or add child", modifier = modifier
    )
}
