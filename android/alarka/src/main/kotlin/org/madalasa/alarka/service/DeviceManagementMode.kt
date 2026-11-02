package org.madalasa.alarka.service

/**
 * Distinguishes a normal (user-installed) device from a managed (Device Owner /
 * Profile Owner) deployment, for Phase-05 L05-008: "Normal install never claims
 * Device Owner."
 *
 * The real detector queries DevicePolicyManager; this build keeps the decision in a
 * pure function so it is unit-testable and cannot accidentally over-claim. The child
 * app NEVER sets itself as Device Owner — managed mode is only ever reported when the
 * platform already designates this package as owner/profile-owner.
 */
enum class DeviceManagementMode {
    /** Ordinary consumer install from Play; no device/profile ownership. */
    STANDARD,
    /** Package is the platform-designated Device Owner. */
    MANAGED_DEVICE_OWNER,
    /** Package is a work-profile Profile Owner. */
    MANAGED_PROFILE_OWNER
}

/** Platform facts needed to classify the mode, supplied by an Android adapter. */
data class DevicePolicyFacts(
    val isDeviceOwner: Boolean,
    val isProfileOwner: Boolean
)

object DeviceManagementModeDetector {

    /**
     * Classify the management mode from platform facts. A standard install (neither
     * owner nor profile-owner) is STANDARD and must never be reported as managed.
     */
    fun classify(facts: DevicePolicyFacts): DeviceManagementMode = when {
        facts.isDeviceOwner -> DeviceManagementMode.MANAGED_DEVICE_OWNER
        facts.isProfileOwner -> DeviceManagementMode.MANAGED_PROFILE_OWNER
        else -> DeviceManagementMode.STANDARD
    }

    /** True only when the platform itself designates this package as Device Owner. */
    fun claimsDeviceOwner(facts: DevicePolicyFacts): Boolean =
        classify(facts) == DeviceManagementMode.MANAGED_DEVICE_OWNER
}
