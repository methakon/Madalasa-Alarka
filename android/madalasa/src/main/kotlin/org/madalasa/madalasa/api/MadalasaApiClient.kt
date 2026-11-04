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
    suspend fun getPairedChildDevice(childId: String): Result<PairedChildDevice?> =
        Result.failure(IllegalStateException("Paired-device status unavailable"))
    suspend fun createFamily(label: String): Result<String> = Result.failure(IllegalStateException("Family creation unavailable"))
    suspend fun createChild(familyId: String, alias: String): Result<ChildSummaryResponse> = Result.failure(IllegalStateException("Child registration unavailable"))
}

data class ParentProfileResponse(
    val adultId: String,
    val familyIds: List<String>
)

data class ChildSummaryResponse(
    val id: String,
    val familyId: String,
    val alias: String,
    val freeServiceState: String = "UNAVAILABLE",
    val queuePosition: Long? = null,
    val slotLimit: Int = 108
)

data class PairingCodeResponse(
    val pairingCode: String,
    val expiresAtEpochMs: Long
)

/** Server-confirmed metadata only; model/manufacturer never identify the device. */
data class PairedChildDevice(
    val id: String,
    val manufacturer: String,
    val model: String,
    val androidApi: Int?,
    val appVersion: String,
    val pairingMethod: String,
    val pairedAt: String?
)
