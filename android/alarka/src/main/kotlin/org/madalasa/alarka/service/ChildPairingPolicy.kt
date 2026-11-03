package org.madalasa.alarka.service

/**
 * Consent-aware child setup boundary. A sample/suggested code is never an
 * authorization to pair: the user must explicitly enter the six-digit code
 * after reading the disclosure. The backend still validates single-use code,
 * device proof of possession, guardian authority, and expiry.
 */
object ChildPairingPolicy {
    fun normalizeEnteredCode(entered: String): String? {
        val value = entered.trim()
        if (!Regex("^[0-9]{3}-?[0-9]{3}$").matches(value)) return null
        val digits = value.replace("-", "")
        return digits.substring(0, 3) + "-" + digits.substring(3, 6)
    }

    fun validate(disclosureAcknowledged: Boolean, enteredCode: String): Result<String> {
        if (!disclosureAcknowledged) {
            return Result.failure(IllegalStateException(
                "Review and acknowledge monitoring disclosure before pairing"
            ))
        }
        val code = normalizeEnteredCode(enteredCode)
            ?: return Result.failure(IllegalArgumentException(
                "Enter the six-digit pairing code shown on the guardian's device"
            ))
        return Result.success(code)
    }
}
