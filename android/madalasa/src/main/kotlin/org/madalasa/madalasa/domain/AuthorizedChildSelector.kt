package org.madalasa.madalasa.domain

import org.madalasa.madalasa.api.ChildSummaryResponse

/**
 * Restricts the parent child selector to only the exact children a guardian is
 * authorized to view (Phase-07 L07-001). Unshared siblings must not appear and must
 * not be inferable — no total count, no gap in IDs, no "N hidden" hint.
 *
 * Pure/deterministic so the exact-child isolation is unit-testable. The server
 * remains the source of truth (RLS); this is the client-side guard that never
 * renders or counts anything the server did not return.
 */
object AuthorizedChildSelector {

    /**
     * Return only the children whose id is in [authorizedChildIds]. Any child the
     * server did not authorize is dropped silently (not shown, not counted).
     */
    fun visibleChildren(
        serverReturned: List<ChildSummaryResponse>,
        authorizedChildIds: Set<String>
    ): List<ChildSummaryResponse> =
        serverReturned.filter { it.id in authorizedChildIds }

    /**
     * A selection is permitted only for an authorized child. Selecting any other id
     * (including a crafted sibling id) is refused.
     */
    fun canSelect(childId: String, authorizedChildIds: Set<String>): Boolean =
        childId in authorizedChildIds

    /**
     * The count shown to the user is exactly the number of authorized children —
     * never the server's raw list size, so unshared siblings cannot be inferred.
     */
    fun displayedCount(
        serverReturned: List<ChildSummaryResponse>,
        authorizedChildIds: Set<String>
    ): Int = visibleChildren(serverReturned, authorizedChildIds).size
}
