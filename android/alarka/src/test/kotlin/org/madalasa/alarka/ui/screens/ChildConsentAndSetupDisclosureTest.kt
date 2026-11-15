package org.madalasa.alarka.ui.screens

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.madalasa.alarka.service.ChildPairingPolicy
import org.madalasa.alarka.service.MonitoringDisclosure
import org.madalasa.alarka.service.MonitoringNotificationSpec
import org.madalasa.alarka.ui.navigation.ChildNavRoute

class ChildConsentAndSetupDisclosureTest {

    @Test
    fun setupInitialDestinationIsDisclosure() {
        assertEquals("disclosure", ChildNavRoute.Disclosure.route)
        assertEquals(ChildNavRoute.Disclosure, ChildNavRoute.fromRoute("disclosure"))
    }

    @Test
    fun pairingCannotProceedWithoutAcknowledgedDisclosure() {
        // Real pairing code
        val unacknowledgedReal = ChildPairingPolicy.validate(
            disclosureAcknowledged = false,
            enteredCode = "23456789AB"
        )
        assertTrue(unacknowledgedReal.isFailure)
        assertTrue(unacknowledgedReal.exceptionOrNull() is IllegalStateException)
        assertEquals(
            "Review and acknowledge monitoring disclosure before pairing",
            unacknowledgedReal.exceptionOrNull()?.message
        )

        // Debug/synthetic pairing code
        val unacknowledgedSynthetic = ChildPairingPolicy.validate(
            disclosureAcknowledged = false,
            enteredCode = "482-901",
            syntheticPreview = true
        )
        assertTrue(unacknowledgedSynthetic.isFailure)
        assertEquals(
            "Review and acknowledge monitoring disclosure before pairing",
            unacknowledgedSynthetic.exceptionOrNull()?.message
        )
    }

    @Test
    fun pairingProceedsWhenDisclosureIsAcknowledgedAndCodeIsValid() {
        val acknowledgedReal = ChildPairingPolicy.validate(
            disclosureAcknowledged = true,
            enteredCode = "23456789AB"
        )
        assertTrue(acknowledgedReal.isSuccess)
        assertEquals("23456789AB", acknowledgedReal.getOrThrow())
    }

    @Test
    fun monitoringDisclosureSpecMustBeChildVisibleOngoingAndIdentifyApp() {
        val spec = MonitoringDisclosure.persistentSpec
        assertTrue("Notification channel must be non-blank", spec.channelId.isNotBlank())
        assertTrue("Notification title must identify Alarka", spec.title.contains("Alarka", ignoreCase = true))
        assertTrue("Notification must be marked ongoing (non-dismissible)", spec.ongoing)
        assertTrue("Notification must be visible while monitoring", spec.visibleWhileMonitoring)
        assertTrue("Notification body must disclose guardian monitoring", spec.body.contains("monitored", ignoreCase = true))
        assertTrue("Must be valid disclosure", spec.isValidDisclosure())
    }

    @Test
    fun covertOrDismissibleMonitoringIsForbidden() {
        // Covert / dismissible / silent notification variants
        val dismissible = MonitoringNotificationSpec(
            channelId = "test",
            title = "Alarka is active",
            body = "Monitoring",
            ongoing = false, // swipable -> illegal for child monitoring tool
            visibleWhileMonitoring = true
        )
        assertFalse(dismissible.isValidDisclosure())
        assertFalse(MonitoringDisclosure.monitoringPermitted(true, dismissible))

        val hidden = MonitoringNotificationSpec(
            channelId = "test",
            title = "Alarka is active",
            body = "Monitoring",
            ongoing = true,
            visibleWhileMonitoring = false // invisible -> illegal
        )
        assertFalse(hidden.isValidDisclosure())
        assertFalse(MonitoringDisclosure.monitoringPermitted(true, hidden))

        val anonymous = MonitoringNotificationSpec(
            channelId = "test",
            title = "System service", // doesn't name Alarka -> stealth/stalkerware forbidden
            body = "Monitoring",
            ongoing = true,
            visibleWhileMonitoring = true
        )
        assertFalse(anonymous.isValidDisclosure())
        assertFalse(MonitoringDisclosure.monitoringPermitted(true, anonymous))
    }
}
