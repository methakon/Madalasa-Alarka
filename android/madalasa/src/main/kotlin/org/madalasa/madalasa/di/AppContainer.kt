package org.madalasa.madalasa.di

import android.content.Context
import org.madalasa.madalasa.R
import org.madalasa.madalasa.api.GoogleParentConfiguration
import org.madalasa.madalasa.api.HttpsPrivacyGateway
import org.madalasa.madalasa.api.ParentSessionMemory

import org.madalasa.madalasa.api.MadalasaApiClient
import org.madalasa.madalasa.api.SyntheticMadalasaApiClient
import org.madalasa.madalasa.api.PrivacyGateway
import org.madalasa.madalasa.api.UnauthenticatedPrivacyGateway
import org.madalasa.madalasa.repository.MadalasaRepository
import org.madalasa.madalasa.repository.SyntheticMadalasaRepository

/**
 * Lightweight manual Dependency Injection container.
 */
interface AppContainer {
    val googleParentConfiguration: GoogleParentConfiguration
    val parentSessionMemory: ParentSessionMemory
    val apiClient: MadalasaApiClient
    val privacyGateway: PrivacyGateway
    val repository: MadalasaRepository
}

class DefaultAppContainer(context: Context) : AppContainer {
    private val appContext = context.applicationContext

    // Public configuration identifiers only: no embedded client secrets.
    override val googleParentConfiguration: GoogleParentConfiguration = GoogleParentConfiguration(
        webClientId = appContext.getString(R.string.parent_google_web_client_id),
        apiOrigin = appContext.getString(R.string.parent_api_origin)
    )
    // Short-lived parent session stays in process memory. Never store an ID
    // token or privileged bearer in SharedPreferences, logs or source files.
    override val parentSessionMemory: ParentSessionMemory = ParentSessionMemory()

    override val privacyGateway: PrivacyGateway by lazy {
        googleParentConfiguration.normalizedOrigin()?.let { origin ->
            HttpsPrivacyGateway(origin) { parentSessionMemory.currentToken() }
        } ?: UnauthenticatedPrivacyGateway()
    }
    override val apiClient: MadalasaApiClient by lazy {
        SyntheticMadalasaApiClient()
    }

    override val repository: MadalasaRepository by lazy {
        SyntheticMadalasaRepository(apiClient)
    }
}
