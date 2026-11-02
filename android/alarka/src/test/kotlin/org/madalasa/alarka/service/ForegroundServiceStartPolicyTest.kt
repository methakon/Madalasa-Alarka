package org.madalasa.alarka.service

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** L06-004: FGS denial handled with an explicit reason; never silently run hidden. */
class ForegroundServiceStartPolicyTest {

    private fun facts(
        api: Int = 34,
        perm: Boolean = true,
        fg: Boolean = false,
        running: Boolean = false,
        rejected: Boolean = false,
        exempt: Boolean = false
    ) = FgsStartFacts(api, perm, fg, running, rejected, exempt)

    @Test
    fun osRejectionIsSurfacedAndNeverRunsHidden() {
        val r = ForegroundServiceStartPolicy.evaluate(facts(rejected = true))
        assertEquals(FgsStartDecision.FGS_START_REJECTED, r.decision)
        assertFalse(r.mayRun)
    }

    @Test
    fun missingPermissionRequiresUserActionNotSilentStart() {
        val r = ForegroundServiceStartPolicy.evaluate(facts(perm = false, fg = true))
        assertEquals(FgsStartDecision.USER_ACTION_REQUIRED, r.decision)
        assertFalse(r.mayRun)
    }

    @Test
    fun backgroundStartWithoutExemptionIsNotPermitted() {
        val r = ForegroundServiceStartPolicy.evaluate(facts(fg = false, exempt = false))
        assertEquals(FgsStartDecision.USER_ACTION_REQUIRED, r.decision)
        assertFalse(r.mayRun)
    }

    @Test
    fun alreadyRunningCompliantServiceMayContinue() {
        val r = ForegroundServiceStartPolicy.evaluate(facts(fg = false, running = true))
        assertEquals(FgsStartDecision.ALLOWED, r.decision)
        assertTrue(r.mayRun)
    }

    @Test
    fun foregroundOrExemptStartIsAllowed() {
        assertTrue(ForegroundServiceStartPolicy.evaluate(facts(fg = true)).mayRun)
        assertTrue(ForegroundServiceStartPolicy.evaluate(facts(fg = false, exempt = true)).mayRun)
    }
}
