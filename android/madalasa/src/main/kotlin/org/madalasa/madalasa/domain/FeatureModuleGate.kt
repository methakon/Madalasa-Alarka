package org.madalasa.madalasa.domain

/**
 * Honest feature-flag gating for parent modules (Phase-09 L09-011). A module is
 * shown only when it is actually available for this build/child; an unavailable
 * module is HIDDEN (not rendered as a disabled teaser that implies a working
 * feature). Mirrors the backend capability release gates
 * (ENABLED / RESEARCH_DISABLED / LEGAL_BLOCKED / NOT_IN_BUILD).
 */
enum class ParentModule { LOCATION, TRIPS, PLACES, USAGE, HEALTH, SOS, MEDIA }

enum class ModuleRelease { ENABLED, RESEARCH_DISABLED, LEGAL_BLOCKED, NOT_IN_BUILD }

data class ModuleState(
    val module: ParentModule,
    val release: ModuleRelease,
    /** The child/guardian scope + consent actually permit this module. */
    val authorized: Boolean
) {
    /** A module is visible only when released AND authorized — never faked. */
    val visible: Boolean get() = release == ModuleRelease.ENABLED && authorized
}

object FeatureModuleGate {

    /** Return only the modules that should actually appear in the parent UI. */
    fun visibleModules(states: List<ModuleState>): List<ParentModule> =
        states.filter { it.visible }.map { it.module }

    /**
     * Honesty check: a hidden module must have a truthful reason, never be presented
     * as available. Returns the reason a module is hidden, or null when visible.
     */
    fun hiddenReason(state: ModuleState): String? = when {
        state.visible -> null
        state.release == ModuleRelease.LEGAL_BLOCKED -> "Unavailable pending legal review"
        state.release == ModuleRelease.RESEARCH_DISABLED -> "Not released in this version"
        state.release == ModuleRelease.NOT_IN_BUILD -> "Not available in this build"
        !state.authorized -> "Not authorized for this child"
        else -> "Unavailable"
    }
}
