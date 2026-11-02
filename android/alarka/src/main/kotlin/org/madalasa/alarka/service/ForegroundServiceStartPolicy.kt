package org.madalasa.alarka.service

/**
 * Android foreground-service start-restriction policy (Phase-06 L06-004).
 *
 * Encodes the TRACKING_RUNTIME_AND_ALGORITHM_CONTRACT rule that a location FGS start
 * must NOT be inferred from checkSelfPermission alone, that a background start may be
 * rejected by the OS (ForegroundServiceStartNotAllowedException), and that the app
 * must never silently run hidden: on rejection it surfaces an explicit reason and
 * stops/degrades, it does not bypass with accessibility overlays or high-priority push.
 */

/** Explicit outcomes of attempting to (continue to) run the location FGS. */
enum class FgsStartDecision {
    /** A compliant FGS may run (foreground access or a valid running-service continuation). */
    ALLOWED,
    /** The OS rejected a background start; surface reason, do not retry covertly. */
    FGS_START_REJECTED,
    /** The user must take an action (grant/enable) before the service can start. */
    USER_ACTION_REQUIRED
}

/** Inputs mirroring the contract's decision table (no single bit is sufficient). */
data class FgsStartFacts(
    val apiLevel: Int,
    val hasForegroundLocationPermission: Boolean,
    val appInForeground: Boolean,
    /** A compliant location FGS is already running (setup activity may be closed). */
    val serviceAlreadyRunning: Boolean,
    /** The OS threw ForegroundServiceStartNotAllowedException on the last attempt. */
    val osRejectedStart: Boolean,
    /** A qualifying background-start exemption currently applies. */
    val hasStartExemption: Boolean
)

data class FgsStartResult(
    val decision: FgsStartDecision,
    val reason: String
) {
    /** True only when a visible, compliant FGS may run. Never implies covert operation. */
    val mayRun: Boolean get() = decision == FgsStartDecision.ALLOWED
}

object ForegroundServiceStartPolicy {

    fun evaluate(facts: FgsStartFacts): FgsStartResult {
        // Permission is necessary but not sufficient; require it first and truthfully.
        if (!facts.hasForegroundLocationPermission) {
            return FgsStartResult(
                FgsStartDecision.USER_ACTION_REQUIRED,
                "Foreground location permission is required before any tracking service starts"
            )
        }
        // An OS rejection is authoritative: never silently retry or bypass.
        if (facts.osRejectedStart) {
            return FgsStartResult(
                FgsStartDecision.FGS_START_REJECTED,
                "OS rejected the foreground-service start; tracking stays stopped until compliant"
            )
        }
        // A compliant already-running service may continue even if the activity closed.
        if (facts.serviceAlreadyRunning) {
            return FgsStartResult(FgsStartDecision.ALLOWED, "Compliant location service already running")
        }
        // A fresh start is allowed only from the foreground or with a valid exemption.
        if (facts.appInForeground || facts.hasStartExemption) {
            return FgsStartResult(FgsStartDecision.ALLOWED, "Foreground or exempted start permitted")
        }
        // Background start without exemption is not permitted; ask for user action,
        // never start hidden.
        return FgsStartResult(
            FgsStartDecision.USER_ACTION_REQUIRED,
            "Background start not permitted without a qualifying exemption; open the app to start tracking"
        )
    }
}
