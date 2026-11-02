package org.madalasa.madalasa.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** L09-011: feature flags hide unavailable modules honestly. */
class FeatureModuleGateTest {

    private fun state(m: ParentModule, r: ModuleRelease, auth: Boolean) = ModuleState(m, r, auth)

    @Test
    fun onlyEnabledAndAuthorizedModulesAreVisible() {
        val states = listOf(
            state(ParentModule.LOCATION, ModuleRelease.ENABLED, true),
            state(ParentModule.USAGE, ModuleRelease.ENABLED, false),          // not authorized
            state(ParentModule.MEDIA, ModuleRelease.LEGAL_BLOCKED, true),     // legally blocked
            state(ParentModule.SOS, ModuleRelease.ENABLED, true),
            state(ParentModule.HEALTH, ModuleRelease.NOT_IN_BUILD, true)      // absent
        )
        val visible = FeatureModuleGate.visibleModules(states)
        assertEquals(setOf(ParentModule.LOCATION, ParentModule.SOS), visible.toSet())
        assertFalse(visible.contains(ParentModule.MEDIA))
        assertFalse(visible.contains(ParentModule.USAGE))
        assertFalse(visible.contains(ParentModule.HEALTH))
    }

    @Test
    fun hiddenModulesCarryTruthfulReasonsNotFalseAvailability() {
        assertEquals("Unavailable pending legal review",
            FeatureModuleGate.hiddenReason(state(ParentModule.MEDIA, ModuleRelease.LEGAL_BLOCKED, true)))
        assertEquals("Not released in this version",
            FeatureModuleGate.hiddenReason(state(ParentModule.USAGE, ModuleRelease.RESEARCH_DISABLED, true)))
        assertEquals("Not available in this build",
            FeatureModuleGate.hiddenReason(state(ParentModule.HEALTH, ModuleRelease.NOT_IN_BUILD, true)))
        assertEquals("Not authorized for this child",
            FeatureModuleGate.hiddenReason(state(ParentModule.USAGE, ModuleRelease.ENABLED, false)))
    }

    @Test
    fun visibleModuleHasNoHiddenReason() {
        assertNull(FeatureModuleGate.hiddenReason(state(ParentModule.SOS, ModuleRelease.ENABLED, true)))
    }
}
