package org.madalasa.alarka.service

/**
 * Evaluates whether a requested capability is supported on a given Android API level
 * and returns an explicit reason when it is not (Phase-05 L05-011). Encodes the
 * ANDROID_COMPATIBILITY_MATRIX "fail closed" contract: unknown/unsupported/stale
 * modes return a reason code, never a silent bypass.
 *
 * Pure and deterministic so the matrix logic is unit-testable off-device; the
 * instrumented androidTest harness exercises the same evaluator against real OS
 * grant state on Android 10..16 / OEM fixtures.
 */

/** Explicit, non-bypassable outcomes. */
enum class CapabilityDecisionReason {
    SUPPORTED,
    UNSUPPORTED_OS,
    PERMISSION_REQUIRED,
    USER_ACTION_REQUIRED,
    OS_REJECTED
}

data class CapabilityDecision(
    val reason: CapabilityDecisionReason,
    val explanation: String
) {
    val isSupported: Boolean get() = reason == CapabilityDecisionReason.SUPPORTED
    /** A decision never implies a bypass: anything other than SUPPORTED blocks the action. */
    val allowsAction: Boolean get() = isSupported
}

/** Capabilities whose OS availability varies across Android 10..16. */
enum class ChildCapability(val minApi: Int) {
    // Background location gating tightened; app baseline is API 29 (Android 10).
    BACKGROUND_LOCATION(29),
    // POST_NOTIFICATIONS runtime grant introduced at API 33 (Android 13).
    POST_NOTIFICATIONS(33),
    // Package suspension (managed) available from API 24; app baseline 29.
    MANAGED_PACKAGE_SUSPEND(24),
    // Usage access always needs an explicit Settings action.
    USAGE_ACCESS(21)
}

object PermissionMatrixEvaluator {

    const val SUPPORTED_MIN_API = 29 // Android 10
    const val SUPPORTED_MAX_API = 36 // Android 16

    /**
     * @param api            device SDK_INT (29..36 in scope)
     * @param capability     requested capability
     * @param permissionGranted whether the required runtime permission is granted
     * @param settingsActionDone whether a required Settings opt-in was completed
     */
    fun evaluate(
        api: Int,
        capability: ChildCapability,
        permissionGranted: Boolean,
        settingsActionDone: Boolean = true
    ): CapabilityDecision {
        if (api < SUPPORTED_MIN_API || api > SUPPORTED_MAX_API) {
            return CapabilityDecision(
                CapabilityDecisionReason.UNSUPPORTED_OS,
                "Android API $api is outside the supported range $SUPPORTED_MIN_API..$SUPPORTED_MAX_API"
            )
        }
        if (api < capability.minApi) {
            return CapabilityDecision(
                CapabilityDecisionReason.UNSUPPORTED_OS,
                "${capability.name} requires API ${capability.minApi}; device is $api"
            )
        }
        if (capability == ChildCapability.USAGE_ACCESS && !settingsActionDone) {
            return CapabilityDecision(
                CapabilityDecisionReason.USER_ACTION_REQUIRED,
                "Usage Access must be granted from Android Settings"
            )
        }
        if (!permissionGranted) {
            return CapabilityDecision(
                CapabilityDecisionReason.PERMISSION_REQUIRED,
                "${capability.name} permission is not granted"
            )
        }
        return CapabilityDecision(CapabilityDecisionReason.SUPPORTED, "${capability.name} available on API $api")
    }
}
