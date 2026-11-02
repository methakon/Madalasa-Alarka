package org.madalasa.alarka.service

/**
 * Power-aware requested tracking cadence (Phase-06 L06-002), encoding the
 * TRACKING_RUNTIME_AND_ALGORITHM_CONTRACT sampling profiles. These are REQUESTED
 * intervals only — the OS may throttle, defer or deny updates; a requested interval
 * is never a guarantee of a delivered fix.
 *
 * Free tier uses a lower cadence than paid; battery-constrained steps down further.
 * The 168h parent-inactivity overlay relaxes routine rates (free 20min moving /
 * 60min stationary; paid 5min moving / 20min stationary).
 */
enum class Tier { FREE, PAID }

enum class MotionState { MOVING, STATIONARY }

enum class PowerState { NORMAL, BATTERY_SAVER }

data class CadenceRequest(
    /** Requested update interval in milliseconds (a request, not a guarantee). */
    val requestedIntervalMillis: Long,
    /** Minimum movement before a new fix is requested. */
    val minDistanceMeters: Int,
    /** Human/UX note that this is a request with no delivery guarantee. */
    val guaranteed: Boolean = false
)

object TrackingCadencePolicy {

    // Base moving profiles (contract §3): paid denser than free.
    private const val FREE_MOVING_MS = 60_000L        // 60s
    private const val PAID_MOVING_MS = 30_000L        // 30s
    private const val FREE_STATIONARY_MS = 300_000L   // 5min
    private const val PAID_STATIONARY_MS = 120_000L   // 2min

    // 168h parent-inactivity overlay targets.
    private const val INACTIVE_FREE_MOVING_MS = 1_200_000L   // 20min
    private const val INACTIVE_PAID_MOVING_MS = 300_000L     // 5min
    private const val INACTIVE_FREE_STATIONARY_MS = 3_600_000L // 60min
    private const val INACTIVE_PAID_STATIONARY_MS = 1_200_000L // 20min

    const val GUARDIAN_INACTIVITY_THRESHOLD_HOURS = 168L

    /**
     * Compute the requested cadence. Lower cadence (larger interval) for FREE,
     * battery saver and guardian inactivity; stronger safety/OS rules still win
     * upstream. Returns a request with [guaranteed]=false always.
     */
    fun requestFor(
        tier: Tier,
        motion: MotionState,
        power: PowerState,
        guardianInactiveHours: Long = 0
    ): CadenceRequest {
        val inactive = guardianInactiveHours >= GUARDIAN_INACTIVITY_THRESHOLD_HOURS
        var interval = when {
            inactive && motion == MotionState.MOVING ->
                if (tier == Tier.PAID) INACTIVE_PAID_MOVING_MS else INACTIVE_FREE_MOVING_MS
            inactive && motion == MotionState.STATIONARY ->
                if (tier == Tier.PAID) INACTIVE_PAID_STATIONARY_MS else INACTIVE_FREE_STATIONARY_MS
            motion == MotionState.MOVING ->
                if (tier == Tier.PAID) PAID_MOVING_MS else FREE_MOVING_MS
            else ->
                if (tier == Tier.PAID) PAID_STATIONARY_MS else FREE_STATIONARY_MS
        }
        // Battery saver steps the interval down (doubles it) — never denser.
        if (power == PowerState.BATTERY_SAVER) interval *= 2

        val distance = if (motion == MotionState.MOVING) 25 else 100
        return CadenceRequest(
            requestedIntervalMillis = interval,
            minDistanceMeters = distance,
            guaranteed = false
        )
    }
}
