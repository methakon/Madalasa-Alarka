package org.madalasa.alarka.service

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OptionalHardwareModulePolicyTest {
    private fun report(
        api: Int = 34,
        sensors: Set<String> = emptySet(),
        declared: List<String> = emptyList(),
        granted: List<String> = emptyList(),
        gps: Boolean = false,
        network: Boolean = false,
        camera: Boolean = false,
        microphone: Boolean = false,
        battery: Boolean = true
    ) = DeviceCapabilityReport(
        osVersion=api,hasGpsHardware=gps,hasBleHardware=false,
        hasCameraHardware=camera,hasMicrophoneHardware=microphone,
        permissionsGranted=granted,permissionsDeclared=declared,
        hasNetworkLocationHardware=network,
        hardware=DeviceHardwareInventory(
            sensorsPresent=sensors,batteryPresent=battery,batteryPercentage=73,
            batteryCharging=false,gnssObservation=GnssObservation.NOT_REQUESTED
        )
    )

    private fun decision(
        report: DeviceCapabilityReport,
        module: OptionalModule,
        paired: Boolean=true,
        approved: Set<OptionalModule> = emptySet()
    ): ModuleReadiness = OptionalHardwareModulePolicy.evaluate(report,paired,approved)
        .first { it.module==module }.readiness

    @Test fun everyAndroid10To16DeviceWorksWithNoMotionSensor() {
        for(api in 29..36) {
            val r=report(api=api,network=true)
            assertEquals(ModuleReadiness.HARDWARE_MISSING,
                decision(r,OptionalModule.MOTION_FALL_CANDIDATE))
            assertEquals(ModuleReadiness.HARDWARE_MISSING,
                decision(r,OptionalModule.PROXIMITY_CONTEXT))
            assertEquals(ModuleReadiness.HARDWARE_MISSING,
                decision(r,OptionalModule.AMBIENT_LIGHT_CONTEXT))
            assertEquals(ModuleReadiness.HARDWARE_DIAGNOSTIC_ONLY,
                decision(r,OptionalModule.BATTERY_STATUS))
            assertEquals(ModuleReadiness.DISABLED_BY_RELEASE_POLICY,
                decision(r,OptionalModule.LOCATION))
        }
    }

    @Test fun accelerometerWithoutGyroscopeIsOnlyAUnverifiedFallCandidate() {
        val r=report(sensors=setOf(AlarkaSensor.ACCELEROMETER))
        assertEquals(ModuleReadiness.DISABLED_BY_RELEASE_POLICY,
            decision(r,OptionalModule.MOTION_FALL_CANDIDATE))
        assertEquals(ModuleReadiness.AWAITING_PARENT_PAIRING,
            decision(r,OptionalModule.MOTION_FALL_CANDIDATE,paired=false))
        assertEquals(ModuleReadiness.AVAILABLE_FOR_APPROVED_SETUP,
            decision(r,OptionalModule.MOTION_FALL_CANDIDATE,
                approved=setOf(OptionalModule.MOTION_FALL_CANDIDATE)))
        assertFalse(AlarkaSensor.GYROSCOPE in r.hardware.sensorsPresent)
    }

    @Test fun manualSosDoesNotDependOnCameraMicOrAccelerometer() {
        val r=report(battery=false)
        assertEquals(ModuleReadiness.DISABLED_BY_RELEASE_POLICY,
            decision(r,OptionalModule.MANUAL_SOS))
        assertEquals(ModuleReadiness.AVAILABLE_FOR_APPROVED_SETUP,
            decision(r,OptionalModule.MANUAL_SOS,approved=setOf(OptionalModule.MANUAL_SOS)))
        assertEquals(ModuleReadiness.HARDWARE_MISSING,
            decision(r,OptionalModule.MICROPHONE_SOS))
        assertEquals(ModuleReadiness.HARDWARE_MISSING,
            decision(r,OptionalModule.CAMERA_SOS))
    }

    @Test fun microphoneAndCameraRequireSeparateFeatureReviewAndAndroidGrants() {
        val r=report(camera=true,microphone=true)
        for(m in listOf(OptionalModule.MICROPHONE_SOS,OptionalModule.CAMERA_SOS)) {
            assertEquals(ModuleReadiness.DISABLED_BY_RELEASE_POLICY,decision(r,m))
            assertEquals(ModuleReadiness.PERMISSION_NOT_DECLARED,decision(r,m,approved=setOf(m)))
        }
        val withManifest=r.copy(
            permissionsDeclared=listOf("android.permission.CAMERA","android.permission.RECORD_AUDIO")
        )
        assertEquals(ModuleReadiness.PERMISSION_REQUIRED,
            decision(withManifest,OptionalModule.CAMERA_SOS,approved=setOf(OptionalModule.CAMERA_SOS)))
        assertEquals(ModuleReadiness.PERMISSION_REQUIRED,
            decision(withManifest,OptionalModule.MICROPHONE_SOS,approved=setOf(OptionalModule.MICROPHONE_SOS)))
        assertEquals(ModuleReadiness.AVAILABLE_FOR_APPROVED_SETUP,
            decision(withManifest.copy(permissionsGranted=listOf("android.permission.CAMERA")),
                OptionalModule.CAMERA_SOS,approved=setOf(OptionalModule.CAMERA_SOS)))
    }

    @Test fun coarseLocationCanProvideDegradedModeWithoutGpsOrNavic() {
        val coarse="android.permission.ACCESS_COARSE_LOCATION"
        val r=report(network=true,declared=listOf(coarse),granted=listOf(coarse))
        assertEquals(ModuleReadiness.AVAILABLE_FOR_APPROVED_SETUP,
            decision(r,OptionalModule.LOCATION,approved=setOf(OptionalModule.LOCATION)))
        assertEquals(GnssObservation.NOT_REQUESTED,r.hardware.gnssObservation)
        assertTrue(r.hardware.observedConstellations.isEmpty())
        assertEquals(ModuleReadiness.HARDWARE_MISSING,
            decision(report(),OptionalModule.LOCATION,approved=setOf(OptionalModule.LOCATION)))
    }

    @Test fun stepDetectorNeedsActivityRecognitionIfSeparatelyApproved() {
        val r=report(sensors=setOf(AlarkaSensor.STEP_DETECTOR))
        assertEquals(ModuleReadiness.PERMISSION_NOT_DECLARED,
            decision(r,OptionalModule.ACTIVITY_STEPS,approved=setOf(OptionalModule.ACTIVITY_STEPS)))
        val r2=r.copy(permissionsDeclared=listOf("android.permission.ACTIVITY_RECOGNITION"))
        assertEquals(ModuleReadiness.PERMISSION_REQUIRED,
            decision(r2,OptionalModule.ACTIVITY_STEPS,approved=setOf(OptionalModule.ACTIVITY_STEPS)))
    }
}
