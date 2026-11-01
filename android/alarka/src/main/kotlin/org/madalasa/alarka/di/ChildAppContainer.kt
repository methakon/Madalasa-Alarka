package org.madalasa.alarka.di

import android.content.Context
import org.madalasa.alarka.service.AndroidDeviceCapabilityScanner
import org.madalasa.alarka.service.AlarkaEnrollmentService
import org.madalasa.alarka.service.DeviceCapabilityScanner
import org.madalasa.alarka.service.SyntheticAlarkaEnrollmentService

interface ChildAppContainer {
    val enrollmentService: AlarkaEnrollmentService
    val capabilityScanner: DeviceCapabilityScanner
}

class DefaultChildAppContainer(context: Context) : ChildAppContainer {
    private val applicationContext = context.applicationContext
    override val enrollmentService: AlarkaEnrollmentService by lazy {
        SyntheticAlarkaEnrollmentService()
    }
    override val capabilityScanner: DeviceCapabilityScanner by lazy {
        AndroidDeviceCapabilityScanner(applicationContext)
    }
}
