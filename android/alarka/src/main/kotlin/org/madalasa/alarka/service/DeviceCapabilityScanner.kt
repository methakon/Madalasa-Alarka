package org.madalasa.alarka.service

data class DeviceCapabilityReport(
    val osVersion: Int,
    val hasGpsHardware: Boolean,
    val hasBleHardware: Boolean,
    val hasCameraHardware: Boolean,
    val hasMicrophoneHardware: Boolean,
    val permissionsGranted: List<String>,
    /** Declared permissions are fixed at build time; grants are dynamic. */
    val permissionsDeclared: List<String> = emptyList(),
    val hasNetworkLocationHardware: Boolean = false,
    val systemLocationEnabled: Boolean = false,
    val notificationsEnabled: Boolean = false,
    val locationForegroundServiceDeclared: Boolean = false
)

interface DeviceCapabilityScanner {
    fun getCapabilityReport(): DeviceCapabilityReport
}

class SyntheticDeviceCapabilityScanner(
    private val osVersion: Int = 34,
    private val hasGps: Boolean = true,
    private val hasBle: Boolean = true,
    private val hasCamera: Boolean = true,
    private val hasMic: Boolean = true,
    private val grantedPermissions: List<String> = emptyList()
) : DeviceCapabilityScanner {
    override fun getCapabilityReport(): DeviceCapabilityReport {
        return DeviceCapabilityReport(
            osVersion = osVersion,
            hasGpsHardware = hasGps,
            hasBleHardware = hasBle,
            hasCameraHardware = hasCamera,
            hasMicrophoneHardware = hasMic,
            permissionsGranted = grantedPermissions
        )
    }
}
