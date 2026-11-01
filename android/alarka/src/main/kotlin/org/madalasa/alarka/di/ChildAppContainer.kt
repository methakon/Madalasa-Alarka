package org.madalasa.alarka.di

import android.content.Context
import org.madalasa.alarka.service.ChildPrivacyGateway
import org.madalasa.alarka.service.UnauthenticatedChildPrivacyGateway
import org.madalasa.alarka.service.AndroidDeviceCapabilityScanner
import org.madalasa.alarka.service.AlarkaEnrollmentService
import org.madalasa.alarka.service.DeviceCapabilityScanner
import org.madalasa.alarka.service.SyntheticAlarkaEnrollmentService

interface ChildAppContainer {
    val enrollmentService: AlarkaEnrollmentService
    val capabilityScanner: DeviceCapabilityScanner
    val privacyGateway: ChildPrivacyGateway
}

class DefaultChildAppContainer(context: Context) : ChildAppContainer {
    // Real DeviceBearer is injected after confirmed Keystore enrollment, never invented.
    override val privacyGateway: ChildPrivacyGateway = UnauthenticatedChildPrivacyGateway()
    private val applicationContext = context.applicationContext
    override val enrollmentService: AlarkaEnrollmentService by lazy {
        SyntheticAlarkaEnrollmentService()
    }
    override val capabilityScanner: DeviceCapabilityScanner by lazy {
        AndroidDeviceCapabilityScanner(applicationContext)
    }
}
