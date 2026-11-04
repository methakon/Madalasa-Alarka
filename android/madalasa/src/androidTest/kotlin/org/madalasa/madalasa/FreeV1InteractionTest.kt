package org.madalasa.madalasa

import androidx.compose.runtime.*
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.madalasa.madalasa.api.ChildSummaryResponse
import org.madalasa.madalasa.ui.figma.PremiumPlanPreviewScreen
import org.madalasa.madalasa.ui.screens.ChildSelectionScreen
import org.madalasa.madalasa.ui.viewmodel.ParentUiState

@RunWith(AndroidJUnit4::class)
class FreeV1InteractionTest {
    @get:Rule val compose = createComposeRule()

    @Test fun yearlyDetailsPayAndDismissRemainFree() {
        compose.setContent { PremiumPlanPreviewScreen() }
        compose.onNodeWithText("Premium · yearly").performClick()
        compose.onNodeWithText("• One prepaid year at the yearly list price").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("Pay now").performScrollTo().performClick()
        compose.onNodeWithText("Coming Soon").assertIsDisplayed()
        compose.onNodeWithText("Got it — continue free").performClick()
        compose.onNodeWithText("Coming Soon").assertDoesNotExist()
        compose.onNodeWithText("Pay now").performScrollTo().performClick()
        compose.onNodeWithText("Close").performClick()
        compose.onNodeWithText("Coming Soon").assertDoesNotExist()
    }

    @Test fun pairingRequiresExplicitChildAndLabelsExactSelection() {
        var paired = 0
        compose.setContent {
            var selected by remember { mutableStateOf<String?>(null) }
            ChildSelectionScreen(
                uiState = ParentUiState(children = listOf(
                    ChildSummaryResponse("a", "family", "Adult fixture A", "ADMITTED"),
                    ChildSummaryResponse("b", "family", "Adult fixture B", "ADMITTED")
                ), selectedChildId = selected),
                onChildSelected = { selected = it },
                onPairNewChild = { _, _ -> paired++ }
            )
        }
        compose.onNodeWithText("Select a child before pairing").assertIsNotEnabled()
        compose.onNodeWithText("Adult fixture B").performClick()
        compose.onNodeWithText("Pair device for Adult fixture B").performScrollTo().performClick()
        compose.runOnIdle { assertEquals(1, paired) }
    }
}
