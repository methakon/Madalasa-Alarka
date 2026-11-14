package org.madalasa.alarka.service

import android.Manifest
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorManager
import android.location.LocationManager
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager

/**
 * Local, read-only scan of Android 10–16 modules. This is NOT a sensor
 * listener, GNSS satellite callback, camera/microphone capture or telemetry.
 * Hardware, declared permissions, granted permissions and active services
 * are separate facts. No IMEI, serial, ad ID or device fingerprint is read.
 */
class AndroidDeviceCapabilityScanner(private val appContext: Context) : DeviceCapabilityScanner {
    override fun getCapabilityReport(): DeviceCapabilityReport {
        val pm=appContext.packageManager
        @Suppress("DEPRECATION")
        val info=pm.getPackageInfo(
            appContext.packageName,
            PackageManager.GET_PERMISSIONS or PackageManager.GET_SERVICES
        )
        val declared=info.requestedPermissions?.toList().orEmpty()
        val permissions=listOf(
            Manifest.permission.ACCESS_COARSE_LOCATION,
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_BACKGROUND_LOCATION,
            Manifest.permission.POST_NOTIFICATIONS,
            Manifest.permission.CAMERA,
            Manifest.permission.RECORD_AUDIO,
            Manifest.permission.ACTIVITY_RECOGNITION
        )
        val granted=permissions.filter { p ->
            p in declared &&
                (p != Manifest.permission.POST_NOTIFICATIONS || Build.VERSION.SDK_INT >= 33) &&
                appContext.checkSelfPermission(p)==PackageManager.PERMISSION_GRANTED
        }
        val location=appContext.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        val notifications=appContext.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        val sensorManager=appContext.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        val batteryManager=appContext.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
        val powerManager=appContext.getSystemService(Context.POWER_SERVICE) as? PowerManager

        val sensorTypes=mapOf(
            AlarkaSensor.ACCELEROMETER to Sensor.TYPE_ACCELEROMETER,
            AlarkaSensor.GYROSCOPE to Sensor.TYPE_GYROSCOPE,
            AlarkaSensor.PROXIMITY to Sensor.TYPE_PROXIMITY,
            AlarkaSensor.AMBIENT_LIGHT to Sensor.TYPE_LIGHT,
            AlarkaSensor.LINEAR_ACCELERATION to Sensor.TYPE_LINEAR_ACCELERATION,
            AlarkaSensor.GRAVITY to Sensor.TYPE_GRAVITY,
            AlarkaSensor.ROTATION_VECTOR to Sensor.TYPE_ROTATION_VECTOR,
            AlarkaSensor.MAGNETOMETER to Sensor.TYPE_MAGNETIC_FIELD,
            AlarkaSensor.BAROMETER to Sensor.TYPE_PRESSURE,
            AlarkaSensor.STEP_DETECTOR to Sensor.TYPE_STEP_DETECTOR,
            AlarkaSensor.STEP_COUNTER to Sensor.TYPE_STEP_COUNTER,
            AlarkaSensor.SIGNIFICANT_MOTION to Sensor.TYPE_SIGNIFICANT_MOTION
        )
        val present=sensorTypes.mapNotNull { (name,type) ->
            if (runCatching { sensorManager?.getDefaultSensor(type)!=null }.getOrDefault(false))
                name else null
        }.toSet()

        // ACTION_BATTERY_CHANGED is sticky. This query does not register a
        // receiver for later delivery or require dangerous permissions.
        @Suppress("DEPRECATION")
        val battery=runCatching {
            appContext.registerReceiver(null as BroadcastReceiver?,
                IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        }.getOrNull()
        val rawLevel=battery?.getIntExtra(BatteryManager.EXTRA_LEVEL,-1) ?: -1
        val rawScale=battery?.getIntExtra(BatteryManager.EXTRA_SCALE,-1) ?: -1
        val percentage=if(rawLevel>=0 && rawScale>0)
            ((rawLevel.toDouble()*100)/rawScale).toInt().coerceIn(0,100)
            else batteryManager?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                ?.takeIf { it in 0..100 }
        val batteryPresent=battery?.getBooleanExtra(BatteryManager.EXTRA_PRESENT,true)
            ?: if(percentage!=null) true else null
        val status=battery?.getIntExtra(BatteryManager.EXTRA_STATUS,
            BatteryManager.BATTERY_STATUS_UNKNOWN)
        val charging=if(status==null || status==BatteryManager.BATTERY_STATUS_UNKNOWN) null
            else status==BatteryManager.BATTERY_STATUS_CHARGING ||
                status==BatteryManager.BATTERY_STATUS_FULL
        val hasLocationPermission=
            Manifest.permission.ACCESS_COARSE_LOCATION in granted ||
                Manifest.permission.ACCESS_FINE_LOCATION in granted
        val gpsHardware=pm.hasSystemFeature(PackageManager.FEATURE_LOCATION_GPS)
        val networkHardware=pm.hasSystemFeature(PackageManager.FEATURE_LOCATION_NETWORK)
        val hardware=DeviceHardwareInventory(
            sensorsPresent=present,
            batteryPresent=batteryPresent,
            batteryPercentage=percentage,
            batteryCharging=charging,
            batteryLow=battery?.getBooleanExtra(BatteryManager.EXTRA_BATTERY_LOW,false),
            powerSaving=powerManager?.isPowerSaveMode,
            gpsProviderEnabled=runCatching {
                location?.isProviderEnabled(LocationManager.GPS_PROVIDER)
            }.getOrNull(),
            networkProviderEnabled=runCatching {
                location?.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
            }.getOrNull(),
            gnssObservation=when {
                !gpsHardware -> GnssObservation.NOT_SUPPORTED
                !hasLocationPermission -> GnssObservation.LOCATION_PERMISSION_REQUIRED
                else -> GnssObservation.NOT_REQUESTED
            },
            observedConstellations=emptySet() // Cannot claim NavIC support from a feature flag.
        )
        val locationFgs = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            info.services.orEmpty().any {
                (it.foregroundServiceType and ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION) != 0
            }
        } else false
        return DeviceCapabilityReport(
            osVersion=Build.VERSION.SDK_INT,
            hasGpsHardware=gpsHardware,
            hasBleHardware=pm.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE),
            hasCameraHardware=pm.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY),
            hasMicrophoneHardware=pm.hasSystemFeature(PackageManager.FEATURE_MICROPHONE),
            permissionsGranted=granted,
            permissionsDeclared=declared,
            hasNetworkLocationHardware=networkHardware,
            systemLocationEnabled=location?.isLocationEnabled==true,
            notificationsEnabled=notifications?.areNotificationsEnabled()==true,
            locationForegroundServiceDeclared=locationFgs,
            hardware=hardware
        )
    }
}
