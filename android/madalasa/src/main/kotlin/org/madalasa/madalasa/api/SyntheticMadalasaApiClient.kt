package org.madalasa.madalasa.api

import org.madalasa.madalasa.domain.Freshness
import org.madalasa.madalasa.domain.VerifiedLocationState

/**
 * Synthetic mock API client for local UI prototyping and isolated tests.
 * Never connects to production services or transmits live child telemetry.
 */
class SyntheticMadalasaApiClient : MadalasaApiClient {
    override suspend fun getMe(): Result<ParentProfileResponse> {
        return Result.success(
            ParentProfileResponse(
                adultId = "00000000-0000-0000-0000-000000000001",
                familyIds = listOf("00000000-0000-0000-0000-00000000000a")
            )
        )
    }

    override suspend fun getChildren(familyId: String): Result<List<ChildSummaryResponse>> {
        return Result.success(
            listOf(
                ChildSummaryResponse(
                    id = "00000000-0000-0000-0000-0000000000c1",
                    familyId = familyId,
                    alias = "Alarka (Synthetic Child 1)"
                ),
                ChildSummaryResponse(
                    id = "00000000-0000-0000-0000-0000000000c2",
                    familyId = familyId,
                    alias = "Alarka (Synthetic Child 2)"
                )
            )
        )
    }

    override suspend fun getChildLocation(childId: String): Result<VerifiedLocationState> {
        return Result.success(
            VerifiedLocationState(
                childId = childId,
                sourceDeviceId = "dev-synthetic-01",
                observedAtEpochMs = System.currentTimeMillis() - 120_000L,
                ingestedAtEpochMs = System.currentTimeMillis() - 110_000L,
                tripProcessedAtEpochMs = null,
                latitudeE6 = 22_572_646,
                longitudeE6 = 88_363_895,
                accuracyMeters = 15.0f,
                freshness = Freshness.VERIFIED_CURRENT
            )
        )
    }

    override suspend fun createPairingCode(childId: String): Result<PairingCodeResponse> {
        return Result.success(
            PairingCodeResponse(
                pairingCode = "23456789AB",
                expiresAtEpochMs = System.currentTimeMillis() + 900_000L
            )
        )
    }
}
