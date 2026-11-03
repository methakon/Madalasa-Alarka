package org.madalasa.alarka.service

/**
 * Read-only physical capability inventory, not permission to use a module.
 * Sensor "available" means Android exposed an appropriate default sensor,
 * NOT that a validated fall/SOS detector exists or runs in the background.
 */
object AlarkaSensor {
    const val ACCELEROMETER = "accelerometer"
    const val GYROSCOPE = "gyroscope"
    const val PROXIMITY = "proximity"
    const val AMBIENT_LIGHT = "ambient_light"
    const val LINEAR_ACCELERATION = "linear_acceleration"
    const val GRAVITY = "gravity"
    const val ROTATION_VECTOR = "rotation_vector"
    const val MAGNETOMETER = "magnetometer"
    const val BAROMETER = "barometer"
    const val STEP_DETECTOR = "step_detector"
    const val STEP_COUNTER = "step_counter"
    const val SIGNIFICANT_MOTION = "significant_motion"
    val ALL = listOf(
        ACCELEROMETER, GYROSCOPE, PROXIMITY, AMBIENT_LIGHT,
        LINEAR_ACCELERATION, GRAVITY, ROTATION_VECTOR, MAGNETOMETER,
        BAROMETER, STEP_DETECTOR, STEP_COUNTER, SIGNIFICANT_MOTION
    )
}

/** NavIC is named IRNSS in Android's GNSS constellation API.
 * No satellite constellation can be inferred from GPS hardware alone.
 */
enum class GnssObservation {
    NOT_REQUESTED,
    LOCATION_PERMISSION_REQUIRED,
    NOT_SUPPORTED,
    WAITING_FOR_SATELLITES,
    OBSERVED
}

data class DeviceHardwareInventory(
    val sensorsPresent: Set<String> = emptySet(),
    val batteryPresent: Boolean? = null,
    val batteryPercentage: Int? = null,
    val batteryCharging: Boolean? = null,
    val batteryLow: Boolean? = null,
    val powerSaving: Boolean? = null,
    val gpsProviderEnabled: Boolean? = null,
    val networkProviderEnabled: Boolean? = null,
    val gnssObservation: GnssObservation = GnssObservation.NOT_REQUESTED,
    val observedConstellations: Set<String> = emptySet()
) {
    fun sensorPresent(name: String): Boolean = name in sensorsPresent
}

enum class OptionalModule {
    LOCATION,
    MOTION_FALL_CANDIDATE,
    PROXIMITY_CONTEXT,
    AMBIENT_LIGHT_CONTEXT,
    BATTERY_STATUS,
    ACTIVITY_STEPS,
    MICROPHONE_SOS,
    CAMERA_SOS,
    MANUAL_SOS
}

enum class ModuleReadiness {
    HARDWARE_MISSING,
    PERMISSION_NOT_DECLARED,
    PERMISSION_REQUIRED,
    AWAITING_PARENT_PAIRING,
    DISABLED_BY_RELEASE_POLICY,
    AVAILABLE_FOR_APPROVED_SETUP,
    HARDWARE_DIAGNOSTIC_ONLY
}

data class OptionalModuleDecision(
    val module: OptionalModule,
    val readiness: ModuleReadiness,
    val explanation: String
)

/**
 * Hardware presence, Android grants and independent feature signoff are three
 * different concepts. No module in this evaluator starts a sensor or uploads.
 */
object OptionalHardwareModulePolicy {
    fun evaluate(
        report: DeviceCapabilityReport,
        paired: Boolean,
        approvedModules: Set<OptionalModule> = emptySet()
    ): List<OptionalModuleDecision> {
        val d = report.permissionsDeclared.toSet()
        val g = report.permissionsGranted.toSet()
        val sensors = report.hardware.sensorsPresent
        val out = mutableListOf<OptionalModuleDecision>()

        fun module(
            name: OptionalModule,
            exists: Boolean,
            permission: String? = null,
            diagnostic: Boolean = false
        ) {
            val state = when {
                !exists -> ModuleReadiness.HARDWARE_MISSING
                diagnostic -> ModuleReadiness.HARDWARE_DIAGNOSTIC_ONLY
                !paired -> ModuleReadiness.AWAITING_PARENT_PAIRING
                name !in approvedModules -> ModuleReadiness.DISABLED_BY_RELEASE_POLICY
                permission != null && permission !in d -> ModuleReadiness.PERMISSION_NOT_DECLARED
                permission != null && permission !in g -> ModuleReadiness.PERMISSION_REQUIRED
                else -> ModuleReadiness.AVAILABLE_FOR_APPROVED_SETUP
            }
            val explanation = when(state) {
                ModuleReadiness.HARDWARE_MISSING -> "Not available on this device; other modules continue"
                ModuleReadiness.HARDWARE_DIAGNOSTIC_ONLY -> "Local status only; no automatic collection or upload"
                ModuleReadiness.AWAITING_PARENT_PAIRING -> "Available but no verified guardian pairing"
                ModuleReadiness.DISABLED_BY_RELEASE_POLICY -> "Detected but this feature is not enabled in the free release"
                ModuleReadiness.PERMISSION_NOT_DECLARED -> "This build does not request this sensitive permission"
                ModuleReadiness.PERMISSION_REQUIRED -> "Requires a separate Android user permission after feature approval"
                ModuleReadiness.AVAILABLE_FOR_APPROVED_SETUP -> "Hardware and basic OS prerequisites met; independent consent still required"
            }
            out += OptionalModuleDecision(name,state,explanation)
        }
        val navAvailable = report.hasGpsHardware || report.hasNetworkLocationHardware
        // Use permission in normal OS modules; coarse is sufficient for a
        // degraded location mode. Actual collection still independently gated.
        module(OptionalModule.LOCATION,navAvailable,
            when {
                "android.permission.ACCESS_COARSE_LOCATION" in g ->
                    "android.permission.ACCESS_COARSE_LOCATION"
                "android.permission.ACCESS_FINE_LOCATION" in g ->
                    "android.permission.ACCESS_FINE_LOCATION"
                else -> "android.permission.ACCESS_COARSE_LOCATION"
            })
        // Accelerometer alone can support a *candidate* motion event,
        // never a clinically reliable fall diagnosis or emergency by itself.
        module(OptionalModule.MOTION_FALL_CANDIDATE,
            sensors(AlarkaSensor.ACCELEROMETER))
        module(OptionalModule.PROXIMITY_CONTEXT,sensors(AlarkaSensor.PROXIMITY))
        module(OptionalModule.AMBIENT_LIGHT_CONTEXT,sensors(AlarkaSensor.AMBIENT_LIGHT))
        module(OptionalModule.BATTERY_STATUS,report.hardware.batteryPresent == true,diagnostic=true)
        module(OptionalModule.ACTIVITY_STEPS,
            sensors(AlarkaSensor.STEP_COUNTER) || sensors(AlarkaSensor.STEP_DETECTOR),
            "android.permission.ACTIVITY_RECOGNITION")
        module(OptionalModule.MICROPHONE_SOS,report.hasMicrophoneHardware,
            "android.permission.RECORD_AUDIO")
        module(OptionalModule.CAMERA_SOS,report.hasCameraHardware,
            "android.permission.CAMERA")
        // The manual SOS UI does not need a motion sensor, camera or mic.
        module(OptionalModule.MANUAL_SOS,true)
        return out
    }
}
