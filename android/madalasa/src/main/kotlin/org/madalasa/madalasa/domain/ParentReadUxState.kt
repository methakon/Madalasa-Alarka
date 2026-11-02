package org.madalasa.madalasa.domain

/**
 * Network/offline/auth-failure/permission UX for the parent read experience
 * (Phase-07 L07-010). On auth revocation any cached child data must be cleared so a
 * revoked guardian never sees stale location from memory; stale state is shown
 * truthfully, never as live.
 */
enum class ReadCondition {
    OK,
    OFFLINE,
    AUTH_REVOKED,
    PERMISSION_DENIED
}

data class ParentReadUx(
    val condition: ReadCondition,
    val message: String,
    /** Whether any previously-loaded location may still be displayed. */
    val retainCachedLocation: Boolean,
    /** Whether the shown state must be labelled stale (not live). */
    val showStaleBadge: Boolean
)

object ParentReadUxState {

    fun resolve(condition: ReadCondition): ParentReadUx = when (condition) {
        ReadCondition.OK ->
            ParentReadUx(condition, "Connected", retainCachedLocation = true, showStaleBadge = false)
        ReadCondition.OFFLINE ->
            // Offline: last-known may stay on screen but is clearly stale.
            ParentReadUx(condition, "Offline — showing last known, not live",
                retainCachedLocation = true, showStaleBadge = true)
        ReadCondition.AUTH_REVOKED ->
            // Revocation: purge cached child data; nothing may remain visible.
            ParentReadUx(condition, "Access ended — sign in again",
                retainCachedLocation = false, showStaleBadge = false)
        ReadCondition.PERMISSION_DENIED ->
            ParentReadUx(condition, "You no longer have access to this child",
                retainCachedLocation = false, showStaleBadge = false)
    }

    /** The cached location that may be retained for display under [condition]. */
    fun projectCache(
        condition: ReadCondition,
        cached: VerifiedLocationState?
    ): VerifiedLocationState? =
        if (resolve(condition).retainCachedLocation) cached else null
}
