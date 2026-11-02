package org.madalasa.alarka.service

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build

/**
 * Read-only, device-local Android capability and app-grant snapshot.
 *
 * This scanner never opens a sensor, requests any permission, starts a background
 * service, uploads identifiers, or claims that a permission implies monitoring is
 * legally or technically enabled. The current synthetic app manifest declares no
 * camera/microphone/location permission; those grants therefore remain unavailable.
 */
class AndroidDeviceCapabilityScanner(private val appContext: Context) : DeviceCapabilityScanner {
    override fun getCapabilityReport(): DeviceCapabilityReport {
        val pm = appContext.packageManager
        val granted = listOf(
            Manifest.permission.ACCESS_COARSE_LOCATION,
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_BACKGROUND_LOCATION,
            Manifest.permission.CAMERA,
            Manifest.permission.RECORD_AUDIO
        ).filter { permission ->
            appContext.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
        }
        return DeviceCapabilityReport(
            osVersion = Build.VERSION.SDK_INT,
            hasGpsHardware = pm.hasSystemFeature(PackageManager.FEATURE_LOCATION_GPS),
            hasBleHardware = pm.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE),
            hasCameraHardware = pm.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY),
            hasMicrophoneHardware = pm.hasSystemFeature(PackageManager.FEATURE_MICROPHONE),
            permissionsGranted = granted
        )
    }
}
