package org.madalasa.madalasa.api

import org.madalasa.madalasa.domain.VerifiedLocationState

/**
 * Modular API client interface conforming to docs/openapi-m1.yaml.
 * Implementation operates on synthetic fixtures without real network credentials.
 */
interface MadalasaApiClient {
    suspend fun getMe(): Result<ParentProfileResponse>
    suspend fun getChildren(familyId: String): Result<List<ChildSummaryResponse>>
    suspend fun getChildLocation(childId: String): Result<VerifiedLocationState>
    suspend fun createPairingCode(childId: String): Result<PairingCodeResponse>
}

data class ParentProfileResponse(
    val adultId: String,
    val familyIds: List<String>
)

data class ChildSummaryResponse(
    val id: String,
    val familyId: String,
    val alias: String
)

data class PairingCodeResponse(
    val pairingCode: String,
    val expiresAtEpochMs: Long
)
