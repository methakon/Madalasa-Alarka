package org.madalasa.alarka.service

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.location.LocationManager
import android.os.IBinder
import org.madalasa.alarka.MainActivity

/**
 * Internal Android 10–16 foreground-service lifecycle QA only.
 * Never uses LocationManager.requestLocationUpdates, reads location,
 * uploads personal data, or runs in an Alarka release build.
 * Testers must launch only from a visible Activity after explicit OS grants.
 */
class VisibleLocationTestService : Service() {
    companion object {
        const val CHANNEL = "alarka_visible_monitoring_test"
        const val ACTION_STOP = "org.madalasa.alarka.action.STOP_TEST_FGS"
        private const val NOTIFICATION_ID = 1204
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        val permissionAvailable =
            checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED
        val location = getSystemService(LOCATION_SERVICE) as? LocationManager
        if (!permissionAvailable || location?.isLocationEnabled != true) {
            stopSelf()
            return START_NOT_STICKY
        }
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(NotificationChannel(
            CHANNEL, "Alarka internal permission tests", NotificationManager.IMPORTANCE_LOW
        ))
        val pending = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val notification = Notification.Builder(this, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle("Alarka test foreground service")
            .setContentText("Internal QA only. No location is collected or transmitted.")
            .setContentIntent(pending)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()
        try {
            startForeground(
                NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            )
        } catch (_: SecurityException) {
            stopSelf()
        } catch (_: RuntimeException) {
            // OS start denial is authoritative. No covert restart or fallback.
            stopSelf()
        }
        return START_NOT_STICKY
    }
}
