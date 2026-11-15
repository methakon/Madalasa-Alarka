package org.madalasa.alarka.service

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ChildPairingPolicyTest {
    @Test fun disclosureIsRequiredEvenForWellFormedRealCode() {
        assertTrue(ChildPairingPolicy.validate(false,"23456789AB").isFailure)
    }

    @Test fun realParentCodeIsExactlyTenUnambiguousUppercaseSymbols() {
        assertEquals("23456789AB", ChildPairingPolicy.validate(true," 23456789ab ").getOrThrow())
        for (invalid in listOf("", "123456", "482-901", "ABCDEFGHIO", "O23456789A",
            "1234567890", "23456789AB;", "23456789AB extra", "２３４５６７８９ＡＢ")) {
            assertTrue("Rejected real pairing: $invalid", ChildPairingPolicy.validate(true,invalid).isFailure)
        }
    }

    @Test fun testOnlySixDigitCodeIsNeverAdmittedInRealMode() {
        assertTrue(ChildPairingPolicy.validate(true,"482901").isFailure)
        assertEquals("482-901", ChildPairingPolicy.validate(true,"482901",syntheticPreview=true).getOrThrow())
        assertEquals("482-901", ChildPairingPolicy.validate(true,"482-901",syntheticPreview=true).getOrThrow())
        assertNull(ChildPairingPolicy.normalizeEnteredCode("４８２９０１",syntheticPreview=true))
    }
}
