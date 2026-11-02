package org.madalasa.alarka.service

/**
 * Reconciles the last-applied capability snapshot against a fresh device scan so
 * that a permission revoked while the device was offline is detected on the next
 * sync (Phase-05 L05-007). Pure/deterministic — no Android runtime — so it can be
 * unit-tested and reused by the ViewModel's on-resume refresh.
 *
 * SOLID: single responsibility is diffing two capability snapshots; it does not
 * scan, persist or upload. Callers own persistence (the last-applied snapshot) and
 * the scanner provides the current snapshot.
 */

/** Outcome of comparing a previously-applied snapshot to a fresh scan. */
data class CapabilityReconciliation(
    /** Permissions that were granted before but are no longer granted now. */
    val revoked: List<String>,
    /** Permissions newly granted since the last applied snapshot. */
    val newlyGranted: List<String>,
    /** True when any permission was revoked and uploads/monitoring must stand down. */
    val mustHaltUploads: Boolean
) {
    val changed: Boolean get() = revoked.isNotEmpty() || newlyGranted.isNotEmpty()
}

object CapabilitySyncReconciler {

    /**
     * Compare the set of permissions applied at last sync with the set observed now.
     * Detection does NOT depend on having been online at revocation time: whatever the
     * current scan shows is authoritative, so an offline revocation surfaces on the
     * next scan.
     */
    fun reconcile(
        lastApplied: DeviceCapabilityReport?,
        current: DeviceCapabilityReport
    ): CapabilityReconciliation {
        val before = lastApplied?.permissionsGranted?.toSet() ?: emptySet()
        val now = current.permissionsGranted.toSet()
        val revoked = (before - now).sorted()
        val newlyGranted = (now - before).sorted()
        return CapabilityReconciliation(
            revoked = revoked,
            newlyGranted = newlyGranted,
            // Any loss of a previously-granted permission fails closed: stop uploading.
            mustHaltUploads = revoked.isNotEmpty()
        )
    }
}
