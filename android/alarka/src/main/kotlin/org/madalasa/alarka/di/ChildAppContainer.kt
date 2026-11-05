package org.madalasa.alarka.di

import android.content.Context
import android.content.pm.ApplicationInfo
import org.madalasa.alarka.R
import org.madalasa.alarka.service.AlarkaEnrollmentService
import org.madalasa.alarka.service.AndroidDeviceCapabilityScanner
import org.madalasa.alarka.service.ChildPrivacyGateway
import org.madalasa.alarka.service.DeviceCapabilityScanner
import org.madalasa.alarka.service.HttpsChildPrivacyGateway
import org.madalasa.alarka.service.KeystoreAlarkaEnrollmentService
import org.madalasa.alarka.service.KeystoreDeviceSessionStore
import org.madalasa.alarka.service.SyntheticAlarkaEnrollmentService
import org.madalasa.alarka.service.UnauthenticatedChildPrivacyGateway
import org.madalasa.alarka.service.UnavailableAlarkaEnrollmentService

interface ChildAppContainer {
    val enrollmentService: AlarkaEnrollmentService
    val capabilityScanner: DeviceCapabilityScanner
    val privacyGateway: ChildPrivacyGateway
    /** A local, unexpired server-issued credential is necessary, not sufficient. */
    fun hasVerifiedParentPairing(): Boolean = false
}

class DefaultChildAppContainer(context: Context) : ChildAppContainer {
    private val applicationContext = context.applicationContext
    private val apiOrigin: String by lazy {
        applicationContext.getString(R.string.alarka_api_origin).trim()
    }
    private val sessionStore by lazy { KeystoreDeviceSessionStore(applicationContext) }
    private val isSyntheticPreview: Boolean by lazy {
        applicationContext.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0 &&
            apiOrigin.isBlank()
    }

    override val enrollmentService: AlarkaEnrollmentService by lazy {
        when {
            // Release never falls through to a fabricated child credential.
            apiOrigin.isNotBlank() -> KeystoreAlarkaEnrollmentService(
                applicationContext, apiOrigin, sessionStore
            )
            isSyntheticPreview -> SyntheticAlarkaEnrollmentService()
            else -> UnavailableAlarkaEnrollmentService()
        }
    }

    override val privacyGateway: ChildPrivacyGateway by lazy {
        if (apiOrigin.isBlank()) UnauthenticatedChildPrivacyGateway()
        else HttpsChildPrivacyGateway(
            origin = apiOrigin,
            deviceIdProvider = { sessionStore.currentSession()?.deviceId },
            credentialProvider = { sessionStore.currentSession()?.credential }
        )
    }

    override fun hasVerifiedParentPairing(): Boolean =
        apiOrigin.isNotBlank() && sessionStore.currentSession() != null

    override val capabilityScanner: DeviceCapabilityScanner by lazy {
        AndroidDeviceCapabilityScanner(applicationContext)
    }
}
