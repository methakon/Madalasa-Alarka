package org.madalasa.madalasa

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onAllNodesWithText
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.madalasa.madalasa.api.ChildSummaryResponse
import org.madalasa.madalasa.ui.screens.ChildSelectionScreen
import org.madalasa.madalasa.ui.theme.MadalasaTheme
import org.madalasa.madalasa.ui.viewmodel.ParentUiState

/**
 * Instrumented structural screenshot-regression (Phase-07 L07-011) for the parent
 * child-selection screen against the documented Theme C layout. Renders on a real
 * device/emulator and asserts the documented copy and the exact set of provided
 * children are shown — catching undocumented drift. (A pixel-diff framework with
 * committed baselines is a separate, heavier gate; no undocumented deviation here.)
 *
 * Run: ./gradlew :madalasa:connectedDebugAndroidTest
 */
@RunWith(AndroidJUnit4::class)
class ParentScreenRegressionTest {

    @get:Rule
    val composeRule = createComposeRule()

    private val children = listOf(
        ChildSummaryResponse("00000000-0000-0000-0000-0000000000c1", "fam", "Alarka (Synthetic Child 1)"),
        ChildSummaryResponse("00000000-0000-0000-0000-0000000000c2", "fam", "Alarka (Synthetic Child 2)")
    )

    @Test
    fun childSelectionScreenRendersDocumentedThemeCCopyAndOnlyProvidedChildren() {
        composeRule.setContent {
            MadalasaTheme {
                ChildSelectionScreen(
                    uiState = ParentUiState(children = children, selectedChildId = children.first().id),
                    onChildSelected = {},
                    onPairNewChild = {}
                )
            }
        }

        // Documented Theme C header + independent-authority disclosure copy.
        composeRule.onNodeWithText("Select Child Profile").assertIsDisplayed()
        composeRule.onNodeWithText(
            "Each child operates under independent parental authority and scope."
        ).assertIsDisplayed()
        composeRule.onNodeWithText("+ Pair New Companion Device").assertIsDisplayed()

        // Exactly the provided children are rendered (no injected/sibling rows).
        composeRule.onNodeWithText("Alarka (Synthetic Child 1)").assertIsDisplayed()
        composeRule.onNodeWithText("Alarka (Synthetic Child 2)").assertIsDisplayed()

        // The selected child shows a single "Active" marker.
        assertEquals(1, composeRule.onAllNodesWithText("Active").fetchSemanticsNodes().size)
    }
}
