package org.madalasa.madalasa.ui.figma

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** P-03: Create account; Figma functional handoff.
 * TODO(INTEGRATION/API): OIDC onboarding; principal+family binding after verification
 * TODO(INTEGRATION/GATE): Do not attach existing child with client-supplied family ID
 * TODO(INTEGRATION/FAILURE): Duplicate principal; incomplete fields; auth error
 * Acceptance: Family created only once after verified principal.
 * UI-only; exact per-node screenshot QA remains necessary.
 */
@Composable fun P03Screen(modifier: Modifier = Modifier) {
    HandoffDesign(
        id = "P-03", title = "Create account", hero = "Create your parent account",
        kind = "form", milestone = "M1", requirement = "FR-001",
        details = listOf("Name", "email", "password or Google", "terms"),
        action = "Create account", modifier = modifier
    )
}
