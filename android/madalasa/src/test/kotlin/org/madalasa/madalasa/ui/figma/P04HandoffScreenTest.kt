package org.madalasa.madalasa.ui.figma

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.madalasa.madalasa.api.GoogleParentConfiguration

class P04HandoffScreenTest {
    private val config = GoogleParentConfiguration(
        webClientId = "1234567890-synthetic.apps.googleusercontent.com",
        apiOrigin = "https://parent.example.invalid"
    )

    @Test fun chooserIsUnavailableWithoutAllThreePrerequisites() {
        assertFalse(canLaunchGoogleAccountChooser(null, true, true, false))
        assertFalse(canLaunchGoogleAccountChooser(config, false, true, false))
        assertFalse(canLaunchGoogleAccountChooser(config, true, false, false))
        assertFalse(canLaunchGoogleAccountChooser(config, true, true, true))
        assertTrue(canLaunchGoogleAccountChooser(config, true, true, false))
    }

    @Test fun disabledConfigurationNeverStartsChooser() {
        val invalid = GoogleParentConfiguration(
            webClientId = "",
            apiOrigin = "https://parent.example.invalid"
        )
        assertFalse(canLaunchGoogleAccountChooser(invalid, true, true, false))
    }
}
