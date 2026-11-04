package org.madalasa.alarka.service

import android.Manifest
import android.app.*
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.*
import kotlinx.coroutines.*
import org.json.JSONObject
import org.madalasa.alarka.LabLocationActivity
import org.madalasa.alarka.R
import java.time.Instant
import java.util.UUID

/** Explicit adult-owner debug lab only. No boot/push/sticky start or media capture. */
class LabLocationService : Service(), LocationListener {
    companion object {
        const val STOP = "org.madalasa.alarka.LAB_STOP"
        const val OPT_IN = "adult_lab_opt_in"
        const val CHANNEL = "alarka_adult_location_lab"
        private const val NOTIFICATION = 1210
    }
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private lateinit var locations: LocationManager
    private lateinit var sessions: KeystoreDeviceSessionStore
    private var queue: DurableLabQueue? = null
    private var device: String? = null
    private var consent: ServerConsentStatus? = null
    private var consentCheckedAt = 0L
    private var optedIn = false
    private var started = false
    private var stopped = false
    private val permissionListener = AppOpsManager.OnOpChangedListener { _, changedPackage ->
        if (changedPackage == packageName) Handler(Looper.getMainLooper()).post {
            if (osStop() == LabStop.REVOKE) finishLab(revoke = true)
        }
    }
    private val handler = Handler(Looper.getMainLooper())
    private val permissionWatch = object : Runnable {
        override fun run() {
            if (started && !stopped) when (osStop()) {
                LabStop.REVOKE -> finishLab(true)
                // Provider switched off pauses; the durable queue and local session stay.
                LabStop.PAUSE -> finishLab(false)
                LabStop.CONTINUE -> Unit
            }
            if (!stopped) handler.postDelayed(this, 1000)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null
    override fun onCreate() {
        super.onCreate()
        locations = getSystemService(LocationManager::class.java)
        sessions = KeystoreDeviceSessionStore(this)
        getSystemService(AppOpsManager::class.java).apply {
            startWatchingMode(AppOpsManager.OPSTR_COARSE_LOCATION, packageName, permissionListener)
            startWatchingMode(AppOpsManager.OPSTR_FINE_LOCATION, packageName, permissionListener)
        }
        handler.post(permissionWatch)
    }
    private fun locationGranted() = checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) ==
        PackageManager.PERMISSION_GRANTED || checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
        PackageManager.PERMISSION_GRANTED
    private fun notificationReady(): Boolean {
        val nm = getSystemService(NotificationManager::class.java)
        return nm.areNotificationsEnabled() &&
            (Build.VERSION.SDK_INT < 33 || checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED) &&
            (nm.getNotificationChannel(CHANNEL)?.importance ?: NotificationManager.IMPORTANCE_LOW) !=
                NotificationManager.IMPORTANCE_NONE
    }
    private fun osReady() = locationGranted() && notificationReady() && locations.isLocationEnabled
    /** Authority loss revokes; an unavailable provider only pauses. */
    private fun osStop() = LabStopPolicy.forOsState(
        locationGranted(), notificationReady(), sessions.currentSession()?.deviceId == device && device != null,
        locations.isLocationEnabled)
    private fun eligible(status: ServerConsentStatus?) = LabCollectionPolicy.allowed(
        applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0,
        resources.getBoolean(R.bool.alarka_location_lab_enabled), optedIn,
        sessions.currentSession()?.deviceId == device && device != null,
        locationGranted(), notificationReady(), status)

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == STOP) { finishLab(false); return START_NOT_STICKY }
        if (started || stopped) return START_NOT_STICKY
        optedIn = intent?.getBooleanExtra(OPT_IN, false) == true
        if (!optedIn || !resources.getBoolean(R.bool.alarka_location_lab_enabled) || !osReady()) {
            finishLab(false); return START_NOT_STICKY
        }
        device = sessions.currentSession()?.deviceId
        if (device == null) { finishLab(false); return START_NOT_STICKY }
        started = true
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel(CHANNEL, "Adult location lab", NotificationManager.IMPORTANCE_LOW))
        val open = PendingIntent.getActivity(this, 0, Intent(this, LabLocationActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val stop = PendingIntent.getService(this, 1, Intent(this, LabLocationService::class.java).setAction(STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val notification = Notification.Builder(this, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle("Alarka adult location lab")
            .setContentText("Location collection is visible. Tap Stop to end this session.")
            .setContentIntent(open).setOngoing(true).setCategory(Notification.CATEGORY_SERVICE)
            .addAction(Notification.Action.Builder(null, "Stop", stop).build()).build()
        try { startForeground(NOTIFICATION, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION) }
        catch (_: RuntimeException) { finishLab(false); return START_NOT_STICKY }
        scope.launch {
            try {
                queue = withContext(Dispatchers.IO) { AndroidLabQueue.open(this@LabLocationService, device!!) }
                val origin = getString(R.string.alarka_api_origin).trim()
                val transport = LabLocationTransport(origin)
                val privacy = HttpsChildPrivacyGateway(origin, { sessions.currentSession()?.deviceId },
                    { sessions.currentSession()?.credential })
                // No fix subscription until fresh server authorization was obtained.
                while (isActive && !stopped) {
                    if (osStop() != LabStop.CONTINUE) {
                        finishLab(osStop() == LabStop.REVOKE); break
                    }
                    val result = privacy.readConsentStatus()
                    if (result.isFailure) {
                        // Only a definitive denial revokes; offline/5xx/malformed pauses.
                        val stop = LabStopPolicy.forConsentFailure(result.exceptionOrNull())
                        finishLab(stop == LabStop.REVOKE); break
                    }
                    consent = result.getOrThrow()
                    consentCheckedAt = SystemClock.elapsedRealtime()
                    // Not admitted (for example waitlisted) stops collection but keeps the
                    // enrollment; only withdrawn consent or deletion is destructive.
                    val verdict = LabStopPolicy.forConsentSnapshot(consent)
                    if (verdict != LabStop.CONTINUE) { finishLab(verdict == LabStop.REVOKE); break }
                    if (!subscribed) subscribe()
                    val battery = getSystemService(BatteryManager::class.java)
                    val level = battery.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                        .takeIf { it in 0..100 }
                    val healthSession = sessions.currentSession() ?: break
                    withContext(Dispatchers.IO) { transport.health(healthSession, level, battery.isCharging) }
                    // Retry the identical encrypted record only after current authorization.
                    for (record in queue!!.lease().take(10)) {
                        if (stopped || !osReady() || sessions.currentSession()?.deviceId != device) break
                        val current = sessions.currentSession() ?: break
                        val accepted = withContext(Dispatchers.IO) { transport.upload(current, record) }
                        if (stopped || !osReady()) break
                        if (accepted) queue!!.acknowledge(record) else break
                    }
                    delay(10_000) // lab polling candidate, not a tracking SLA or retention TTL
                }
            } catch (_: LabAuthorizationDenied) { finishLab(true) }
            catch (error: CancellationException) { throw error }
            catch (_: Exception) { finishLab(false) } // no raw errors, payloads or tokens in logs
        }
        return START_NOT_STICKY
    }
    private var subscribed = false
    private fun subscribe() {
        check(osReady())
        val provider = if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED && locations.isProviderEnabled(LocationManager.GPS_PROVIDER))
            LocationManager.GPS_PROVIDER else LocationManager.NETWORK_PROVIDER
        check(locations.isProviderEnabled(provider))
        // Visible FGS starts from resumed Activity; no background location grant needed.
        locations.requestLocationUpdates(provider, 15_000L, 0f, this, Looper.getMainLooper())
        subscribed = true
    }
    override fun onLocationChanged(location: Location) {
        if (stopped) return
        if (osStop() != LabStop.CONTINUE) { finishLab(osStop() == LabStop.REVOKE); return }
        // Stale consent is a refresh gap: pause and keep the queue, never destroy the enrollment.
        val stop = LabStopPolicy.forFixArrival(
            eligible(consent), SystemClock.elapsedRealtime() - consentCheckedAt <= 15_000)
        if (stop != LabStop.CONTINUE) { finishLab(stop == LabStop.REVOKE); return }
        if (!location.hasAccuracy() || !location.accuracy.isFinite() || location.accuracy !in 0f..100_000f ||
            !location.latitude.isFinite() || location.latitude !in -90.0..90.0 ||
            !location.longitude.isFinite() || location.longitude !in -180.0..180.0 ||
            location.time <= 0 || location.time > System.currentTimeMillis()) return
        try {
            // Commit monotonic sequence BEFORE enqueue; gaps on crash are safe, reuse is not.
            val prefs = getSharedPreferences("alarka_lab_sequence", MODE_PRIVATE)
            val sequence = Math.addExact(prefs.getLong(device, 0), 1L)
            check(prefs.edit().putLong(device, sequence).commit())
            val id = UUID.randomUUID().toString()
            val event = JSONObject().put("event_id", id).put("sequence", sequence)
                .put("observed_at", Instant.ofEpochMilli(location.time).toString())
                .put("latitude", location.latitude).put("longitude", location.longitude)
                .put("accuracy_m", location.accuracy.toDouble()).put("source_device_id", device)
                .put("provider", location.provider ?: "UNKNOWN")
            if (location.hasSpeed() && location.speed.isFinite() && location.speed in 0f..1000f)
                event.put("speed_mps", location.speed.toDouble())
            queue!!.enqueue(id, event.toString())
        } catch (_: Exception) { finishLab(false) }
    }
    // GPS switched off is availability, not authority: pause without unpairing.
    override fun onProviderDisabled(provider: String) { finishLab(false) }
    override fun onProviderEnabled(provider: String) = Unit
    @Deprecated("Platform callback")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit

    private fun finishLab(revoke: Boolean) {
        if (stopped) return
        stopped = true
        runCatching { locations.removeUpdates(this) }
        if (revoke) runCatching { queue?.halt() }
        // Even if disk is full and a tombstone cannot be committed, this bearer
        // must not later replay old records under the same local enrollment.
        if (revoke) runCatching { sessions.clearLocalSession() }
        scope.cancel()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }
    override fun onDestroy() {
        runCatching { locations.removeUpdates(this) }
        getSystemService(AppOpsManager::class.java).stopWatchingMode(permissionListener)
        handler.removeCallbacks(permissionWatch)
        scope.cancel()
        super.onDestroy()
    }
}
