package org.madalasa.madalasa.ui.figma

import org.junit.Assert.assertEquals
import org.junit.Test

/** No name/email checkbox state can confer guardian authority by itself. */
class P03CreateAccountTest {
    @Test fun emptyOrMalformedDraftNeverBecomesEligible() {
        assertEquals(AccountDraftGate.INCOMPLETE,
            accountDraftGate("", "a@example.com", true, true))
        assertEquals(AccountDraftGate.INCOMPLETE,
            accountDraftGate("Test Adult", "invalid-email", true, true))
        assertEquals(AccountDraftGate.INCOMPLETE,
            accountDraftGate("Test Adult", "a@example.com", false, true))
    }

    @Test fun completedLocalFormCannotBypassVerifiedIdentity() {
        assertEquals(AccountDraftGate.IDENTITY_UNVERIFIED,
            accountDraftGate("Test Adult", "a@example.com", true, false))
        assertEquals(AccountDraftGate.READY_FOR_SERVER_VALIDATION,
            accountDraftGate("Test Adult", "a@example.com", true, true))
    }

    @Test fun verifiedIdentityStillOnlyAllowsServerValidationNotAutomaticAccount() {
        // No result represents account-created or family-created.
        assertEquals(setOf(AccountDraftGate.INCOMPLETE, AccountDraftGate.IDENTITY_UNVERIFIED,
            AccountDraftGate.READY_FOR_SERVER_VALIDATION), AccountDraftGate.entries.toSet())
    }
}
