package org.madalasa.alarka.service

import android.Manifest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * L05-007: capability sync on resume and revocation. Proves a permission revoked
 * while offline is detected on the next sync and fails closed (halts uploads).
 */
class CapabilitySyncReconcilerTest {

    private fun report(grants: List<String>) = DeviceCapabilityReport(
        osVersion = 34,
        hasGpsHardware = true,
        hasBleHardware = true,
        hasCameraHardware = true,
        hasMicrophoneHardware = true,
        permissionsGranted = grants
    )

    @Test
    fun revocationWhileOfflineIsDetectedOnNextSync() {
        val lastApplied = report(listOf(Manifest.permission.ACCESS_FINE_LOCATION))
        // Device came back online; the fresh scan shows the grant is gone.
        val current = report(emptyList())
        val r = CapabilitySyncReconciler.reconcile(lastApplied, current)
        assertEquals(listOf(Manifest.permission.ACCESS_FINE_LOCATION), r.revoked)
        assertTrue(r.changed)
        assertTrue("A revoked permission must halt uploads", r.mustHaltUploads)
    }

    @Test
    fun noChangeWhenGrantsAreStable() {
        val grants = listOf(Manifest.permission.ACCESS_COARSE_LOCATION)
        val r = CapabilitySyncReconciler.reconcile(report(grants), report(grants))
        assertFalse(r.changed)
        assertFalse(r.mustHaltUploads)
        assertTrue(r.revoked.isEmpty())
    }

    @Test
    fun newGrantIsReportedButDoesNotHaltUploads() {
        val r = CapabilitySyncReconciler.reconcile(
            report(emptyList()),
            report(listOf(Manifest.permission.ACCESS_COARSE_LOCATION))
        )
        assertEquals(listOf(Manifest.permission.ACCESS_COARSE_LOCATION), r.newlyGranted)
        assertFalse(r.mustHaltUploads)
    }

    @Test
    fun firstSyncWithNoPriorSnapshotHaltsNothing() {
        val r = CapabilitySyncReconciler.reconcile(
            lastApplied = null,
            current = report(listOf(Manifest.permission.ACCESS_FINE_LOCATION))
        )
        assertTrue(r.revoked.isEmpty())
        assertFalse(r.mustHaltUploads)
        assertEquals(listOf(Manifest.permission.ACCESS_FINE_LOCATION), r.newlyGranted)
    }
}
