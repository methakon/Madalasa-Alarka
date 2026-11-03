package org.madalasa.alarka.service

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ChildPairingPolicyTest {
    @Test fun requiresDisclosureEvenForSyntheticallySuggestedCode() {
        assertTrue(ChildPairingPolicy.validate(false, "482-901").isFailure)
    }

    @Test fun requiresActualExplicitCode() {
        assertTrue(ChildPairingPolicy.validate(true, "").isFailure)
        assertTrue(ChildPairingPolicy.validate(true, "482-90x").isFailure)
        assertTrue(ChildPairingPolicy.validate(true, "482-901;other").isFailure)
        assertTrue(ChildPairingPolicy.validate(true, "1234567").isFailure)
        assertFalse(ChildPairingPolicy.validate(true, "482-901").isFailure)
    }

    @Test fun normalizesExactlySixAsciiDigits() {
        assertEquals("482-901", ChildPairingPolicy.validate(true, " 482901 ").getOrThrow())
        assertEquals("482-901", ChildPairingPolicy.validate(true, "482-901").getOrThrow())
        assertEquals(null, ChildPairingPolicy.normalizeEnteredCode("４８２９０１"))
    }
}
