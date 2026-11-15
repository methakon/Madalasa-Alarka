package org.madalasa.alarka.service

/**
 * Android 10–16 (SDK 29–36) permission and visible-service *preflight*.
 *
 * No action in this policy grants permission, starts a foreground service,
 * uses GPS, or overrides guardian authority or legal/Play review.
 * All state must be observed on the device again before attempting a start.
 */
enum class LocationSetupAction {
    UNSUPPORTED_ANDROID,
    NOT_PAIRED_OR_ADMITTED,
    AWAITING_SERVER_CONSENT,
    AWAITING_RELEASE_APPROVAL,
    MANIFEST_NOT_READY,
    NO_LOCATION_PROVIDER,
    ENABLE_SYSTEM_LOCATION,
    REQUEST_FOREGROUND_LOCATION,
    REQUEST_BACKGROUND_LOCATION_ANDROID_10,
    OPEN_BACKGROUND_LOCATION_SETTINGS,
    REQUEST_NOTIFICATION_PERMISSION,
    OPEN_NOTIFICATION_SETTINGS,
    OPEN_APP_TO_START_SERVICE,
    FOREGROUND_SERVICE_REJECTED,
    READY_FOR_VISIBLE_LOCATION_SERVICE
}

data class AndroidLocationSetupFacts(
    val api: Int,
    val paired: Boolean = false,
    val admitted: Boolean = false,
    val consentAuthorized: Boolean = false,
    val releaseApproved: Boolean = false,
    val foregroundLocationDeclared: Boolean = false,
    val backgroundLocationDeclared: Boolean = false,
    val notificationPermissionDeclared: Boolean = false,
    val locationServiceDeclared: Boolean = false,
    val locationServicePermissionDeclared: Boolean = false,
    val gpsOrNetworkProvider: Boolean = false,
    val systemLocationEnabled: Boolean = false,
    val coarseGranted: Boolean = false,
    val fineGranted: Boolean = false,
    val backgroundGranted: Boolean = false,
    val notificationGranted: Boolean = false,
    val notificationsEnabled: Boolean = false,
    /** Separate use-case review. A running visible location FGS does not
     * automatically require ACCESS_BACKGROUND_LOCATION. */
    val backgroundLocationRequired: Boolean = false,
    val foregroundAppVisible: Boolean = true,
    val serviceAlreadyRunning: Boolean = false,
    val startExemptionVerified: Boolean = false,
    val osRejectedForegroundService: Boolean = false
)

data class AndroidLocationSetupPlan(
    val action: LocationSetupAction,
    val explanation: String
) {
    val mayAttemptVisibleService: Boolean
        get() = action == LocationSetupAction.READY_FOR_VISIBLE_LOCATION_SERVICE
}

object Android10To16PermissionPlan {
    const val MIN_API = 29
    const val MAX_API = 36

    fun evaluate(f: AndroidLocationSetupFacts): AndroidLocationSetupPlan {
        fun result(action: LocationSetupAction, message: String) =
            AndroidLocationSetupPlan(action, message)

        if (f.api !in MIN_API..MAX_API)
            return result(LocationSetupAction.UNSUPPORTED_ANDROID,
                "This Android version has not passed compatibility testing")
        if (!f.paired || !f.admitted)
            return result(LocationSetupAction.NOT_PAIRED_OR_ADMITTED,
                "Parent pairing and a verified active child service slot are required")
        if (!f.consentAuthorized)
            return result(LocationSetupAction.AWAITING_SERVER_CONSENT,
                "Server-verified guardian consent and device authority are required")
        if (!f.releaseApproved)
            return result(LocationSetupAction.AWAITING_RELEASE_APPROVAL,
                "Location collection is disabled pending Google Play and legal review")
        if (!f.foregroundLocationDeclared || !f.locationServiceDeclared ||
            (f.api >= 34 && !f.locationServicePermissionDeclared))
            return result(LocationSetupAction.MANIFEST_NOT_READY,
                "This build does not declare the approved location and foreground-service capability")
        if (!f.gpsOrNetworkProvider)
            return result(LocationSetupAction.NO_LOCATION_PROVIDER,
                "No suitable device location provider was detected")
        if (!f.systemLocationEnabled)
            return result(LocationSetupAction.ENABLE_SYSTEM_LOCATION,
                "Enable location services in Android settings")
        if (!f.fineGranted && !f.coarseGranted)
            return result(LocationSetupAction.REQUEST_FOREGROUND_LOCATION,
                "Allow location while using Alarka; approximate access is supported")
        if (f.backgroundLocationRequired && !f.backgroundGranted) {
            if (!f.backgroundLocationDeclared)
                return result(LocationSetupAction.MANIFEST_NOT_READY,
                    "Background location was not approved for this build")
            // Android 11+ requires a separate settings visit, not the
            // foreground/both-at-once location dialog.
            return if (f.api == 29)
                result(LocationSetupAction.REQUEST_BACKGROUND_LOCATION_ANDROID_10,
                    "Android 10: request all-the-time location separately after foreground consent")
            else result(LocationSetupAction.OPEN_BACKGROUND_LOCATION_SETTINGS,
                "Android 11–16: explain and open app location settings for all-the-time access")
        }
        if (f.api >= 33) {
            if (!f.notificationPermissionDeclared)
                return result(LocationSetupAction.MANIFEST_NOT_READY,
                    "Monitoring-notification declaration is missing")
            if (!f.notificationGranted)
                return result(LocationSetupAction.REQUEST_NOTIFICATION_PERMISSION,
                    "Ask to display monitoring notifications (not a foreground-service permission)")
        }
        // Before Android 13 the POST_NOTIFICATIONS runtime permission does not exist.
        // A visible monitoring UX still requires enabled notification channels.
        if (!f.notificationsEnabled)
            return result(LocationSetupAction.OPEN_NOTIFICATION_SETTINGS,
                "Enable visible Alarka monitoring notifications in Android settings")
        if (f.osRejectedForegroundService)
            return result(LocationSetupAction.FOREGROUND_SERVICE_REJECTED,
                "Android rejected starting the location foreground service; no hidden retry")
        if (!f.serviceAlreadyRunning && !f.foregroundAppVisible && !f.startExemptionVerified)
            return result(LocationSetupAction.OPEN_APP_TO_START_SERVICE,
                "Open Alarka visibly before starting location monitoring")
        // With API 34+ a background-start exemption by itself is not enough
        // for while-in-use location; require an existing FGS or background grant.
        if (f.api >= 34 && !f.serviceAlreadyRunning && !f.foregroundAppVisible &&
            !f.backgroundGranted)
            return result(LocationSetupAction.OPEN_APP_TO_START_SERVICE,
                "Android 14–16 requires while-in-use location at service creation")
        return result(LocationSetupAction.READY_FOR_VISIBLE_LOCATION_SERVICE,
            "Android preflight passed; recheck all server and device facts before start")
    }
}
