package org.madalasa.alarka.di

import org.madalasa.alarka.service.AlarkaEnrollmentService
import org.madalasa.alarka.service.DeviceCapabilityScanner
import org.madalasa.alarka.service.SyntheticAlarkaEnrollmentService
import org.madalasa.alarka.service.SyntheticDeviceCapabilityScanner

interface ChildAppContainer {
    val enrollmentService: AlarkaEnrollmentService
    val capabilityScanner: DeviceCapabilityScanner
}

class DefaultChildAppContainer : ChildAppContainer {
    override val enrollmentService: AlarkaEnrollmentService by lazy {
        SyntheticAlarkaEnrollmentService()
    }
    override val capabilityScanner: DeviceCapabilityScanner by lazy {
        SyntheticDeviceCapabilityScanner()
    }
}
