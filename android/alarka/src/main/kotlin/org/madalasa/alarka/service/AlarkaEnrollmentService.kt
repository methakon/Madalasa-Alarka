package org.madalasa.alarka.service

data class EnrollmentResult(
    val success: Boolean,
    val devicePseudonym: String?,
    val guardianAlias: String?,
    val errorMessage: String? = null
)

interface AlarkaEnrollmentService {
    suspend fun generatePairingChallenge(): Result<String>
    suspend fun completeEnrollment(pairingCode: String): Result<EnrollmentResult>
    suspend fun unpairDevice(): Result<Boolean>
}

class SyntheticAlarkaEnrollmentService : AlarkaEnrollmentService {
    private var isEnrolled: Boolean = false
    private var currentChallenge: String = "482-901"

    override suspend fun generatePairingChallenge(): Result<String> {
        currentChallenge = "482-901"
        return Result.success(currentChallenge)
    }

    override suspend fun completeEnrollment(pairingCode: String): Result<EnrollmentResult> {
        val sanitized = pairingCode.replace("-", "").trim()
        val expected = currentChallenge.replace("-", "").trim()
        return if (sanitized == expected || sanitized == "123456") {
            isEnrolled = true
            Result.success(
                EnrollmentResult(
                    success = true,
                    devicePseudonym = "Alarka Synthetic Alpha",
                    guardianAlias = "Guardian (Verified Adult)"
                )
            )
        } else {
            Result.failure(IllegalArgumentException("Invalid pairing code. Synthetic challenge expects $currentChallenge or 123456"))
        }
    }

    override suspend fun unpairDevice(): Result<Boolean> {
        isEnrolled = false
        return Result.success(true)
    }
}
