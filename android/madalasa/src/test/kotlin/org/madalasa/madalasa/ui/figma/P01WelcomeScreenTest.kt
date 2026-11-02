package org.madalasa.madalasa.ui.figma

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.assertEquals
import org.junit.Test

/** P-01's role/flow model is pure; UI clicks must not create child records. */
class P01WelcomeScreenTest {
    @Test fun onlyParentWithAnExplicitNavigationTargetCanContinue() {
        assertTrue(canStartParentSetup(WelcomeRole.PARENT, true))
        assertFalse(canStartParentSetup(WelcomeRole.PARENT, false))
        assertFalse(canStartParentSetup(WelcomeRole.CHILD_COMPANION, true))
        assertFalse(canStartParentSetup(WelcomeRole.CHILD_COMPANION, false))
    }

    @Test fun allInformationalEntriesHaveClearOfflineLocalDescriptions() {
        assertEquals(3, WelcomeInformation.entries.size)
        WelcomeInformation.entries.forEach { info ->
            assertTrue(welcomeInformationHeading(info).isNotBlank())
            assertTrue(welcomeInformationDetail(info).isNotBlank())
        }
        assertTrue(welcomeInformationDetail(WelcomeInformation.PRIVACY)
            .contains("does not collect your location"))
        assertTrue(welcomeInformationDetail(WelcomeInformation.LANGUAGE)
            .contains("English is the only"))
        assertTrue(welcomeInformationDetail(WelcomeInformation.SUPPORT)
            .contains("No help request has been submitted"))
    }
}
