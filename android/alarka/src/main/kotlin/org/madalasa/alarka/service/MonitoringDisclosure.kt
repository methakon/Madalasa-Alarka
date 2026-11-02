package org.madalasa.alarka.service

/**
 * Visible-monitoring disclosure contract (Phase-05 L05-009). The child build must
 * never run monitoring without a prominent, persistent (ongoing, non-dismissible)
 * Android notification that names the app and states it is actively monitored.
 *
 * This is the pure, testable policy. The real foreground service binds this content
 * to a NotificationChannel; here we prove the invariant: active monitoring REQUIRES
 * a valid persistent disclosure, so covert operation is impossible by construction.
 */
data class MonitoringNotificationSpec(
    val channelId: String,
    val title: String,
    val body: String,
    /** Ongoing notifications cannot be swiped away by the user. */
    val ongoing: Boolean,
    /** The notification is shown whenever monitoring is operational. */
    val visibleWhileMonitoring: Boolean
) {
    /** A disclosure is valid only if it is ongoing, visible and identifies the app. */
    fun isValidDisclosure(): Boolean =
        ongoing &&
            visibleWhileMonitoring &&
            channelId.isNotBlank() &&
            title.contains("Alarka", ignoreCase = true) &&
            body.isNotBlank()
}

object MonitoringDisclosure {

    /** The single, identifying persistent-notification spec used when monitoring runs. */
    val persistentSpec = MonitoringNotificationSpec(
        channelId = "alarka_monitoring_status",
        title = "Alarka is active",
        body = "This device is being monitored with guardian consent. Tap for details and controls.",
        ongoing = true,
        visibleWhileMonitoring = true
    )

    /**
     * Gate that must be satisfied before monitoring is considered operational.
     * Monitoring may be active ONLY when a valid persistent disclosure is present.
     */
    fun monitoringPermitted(monitoringRequested: Boolean, disclosure: MonitoringNotificationSpec): Boolean =
        monitoringRequested && disclosure.isValidDisclosure()
}
