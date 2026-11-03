package org.madalasa.alarka.service

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.location.LocationManager
import android.os.Build

/**
 * Read-only Android 10–16 scan. Declaring a permission is NOT a grant.
 *
 * No request dialog, monitoring, sensor access, upload, identifier read or
 * foreground-service start occurs here. Re-scan on resume and before action.
 */
class AndroidDeviceCapabilityScanner(private val appContext: Context) : DeviceCapabilityScanner {
    override fun getCapabilityReport(): DeviceCapabilityReport {
        val pm = appContext.packageManager
        @Suppress("DEPRECATION")
        val packageInfo = pm.getPackageInfo(
            appContext.packageName,
            PackageManager.GET_PERMISSIONS or PackageManager.GET_SERVICES
        )
        val declared = packageInfo.requestedPermissions?.toList().orEmpty()
        val permissions = listOf(
            Manifest.permission.ACCESS_COARSE_LOCATION,
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_BACKGROUND_LOCATION,
            Manifest.permission.POST_NOTIFICATIONS,
            Manifest.permission.CAMERA,
            Manifest.permission.RECORD_AUDIO,
            Manifest.permission.ACTIVITY_RECOGNITION
        )
        val granted = permissions.filter { permission ->
            permission in declared &&
                (permission != Manifest.permission.POST_NOTIFICATIONS || Build.VERSION.SDK_INT >= 33) &&
                appContext.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
        }
        val location = appContext.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        val notifications =
            appContext.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        val locationFgsDeclared = packageInfo.services.orEmpty().any { service ->
            Build.VERSION.SDK_INT >= 29 &&
                (service.foregroundServiceType and ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION) != 0
        }
        return DeviceCapabilityReport(
            osVersion = Build.VERSION.SDK_INT,
            hasGpsHardware = pm.hasSystemFeature(PackageManager.FEATURE_LOCATION_GPS),
            hasBleHardware = pm.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE),
            hasCameraHardware = pm.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY),
            hasMicrophoneHardware = pm.hasSystemFeature(PackageManager.FEATURE_MICROPHONE),
            permissionsGranted = granted,
            permissionsDeclared = declared,
            hasNetworkLocationHardware =
                pm.hasSystemFeature(PackageManager.FEATURE_LOCATION_NETWORK),
            systemLocationEnabled = location?.isLocationEnabled == true,
            notificationsEnabled = notifications?.areNotificationsEnabled() == true,
            locationForegroundServiceDeclared = locationFgsDeclared
        )
    }
}
