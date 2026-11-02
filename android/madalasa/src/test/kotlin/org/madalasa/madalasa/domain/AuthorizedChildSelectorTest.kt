package org.madalasa.madalasa.domain

import org.madalasa.madalasa.api.ChildSummaryResponse
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** L07-001: only authorized children appear; unshared siblings not shown or counted. */
class AuthorizedChildSelectorTest {

    private fun child(id: String) = ChildSummaryResponse(id = id, familyId = "fam", alias = "Synthetic $id")

    private val serverReturned = listOf(child("c1"), child("c2"), child("c3-sibling"))
    private val authorized = setOf("c1", "c2")

    @Test
    fun unsharedSiblingDoesNotAppear() {
        val visible = AuthorizedChildSelector.visibleChildren(serverReturned, authorized)
        assertEquals(listOf("c1", "c2"), visible.map { it.id })
        assertFalse(visible.any { it.id == "c3-sibling" })
    }

    @Test
    fun displayedCountDoesNotRevealHiddenSiblings() {
        // Count reflects only authorized children, so "N hidden" cannot be inferred.
        assertEquals(2, AuthorizedChildSelector.displayedCount(serverReturned, authorized))
    }

    @Test
    fun craftedSiblingIdCannotBeSelected() {
        assertFalse(AuthorizedChildSelector.canSelect("c3-sibling", authorized))
        assertFalse(AuthorizedChildSelector.canSelect("00000000-crafted", authorized))
        assertTrue(AuthorizedChildSelector.canSelect("c1", authorized))
    }

    @Test
    fun emptyAuthorizationShowsNothing() {
        assertTrue(AuthorizedChildSelector.visibleChildren(serverReturned, emptySet()).isEmpty())
        assertEquals(0, AuthorizedChildSelector.displayedCount(serverReturned, emptySet()))
    }
}
