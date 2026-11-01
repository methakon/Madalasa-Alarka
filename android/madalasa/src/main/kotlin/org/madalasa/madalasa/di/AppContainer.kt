package org.madalasa.madalasa.di

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
    val apiClient: MadalasaApiClient
    val privacyGateway: PrivacyGateway
    val repository: MadalasaRepository
}

class DefaultAppContainer : AppContainer {
    // Google OIDC -> trusted V2 session integration supplies a live HTTPS gateway later.
    // No fake authorization or hardcoded token is used as a fallback.
    override val privacyGateway: PrivacyGateway = UnauthenticatedPrivacyGateway()
    override val apiClient: MadalasaApiClient by lazy {
        SyntheticMadalasaApiClient()
    }

    override val repository: MadalasaRepository by lazy {
        SyntheticMadalasaRepository(apiClient)
    }
}
