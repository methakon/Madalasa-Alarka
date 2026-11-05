package org.madalasa.alarka.service

/**
 * A parent issues the one-time code on the *server*, not on the child.
 * The real Drogon API uses ten symbols from an unambiguous uppercase alphabet.
 * Six-digit examples belong ONLY to an isolated, clearly labeled debug preview.
 *
 * Valid syntax never proves parental authority, service admission or consent:
 * the backend must consume the code and accept Android Keystore key possession.
 */
object ChildPairingPolicy {
    private val productionCode = Regex("^[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{10}$")
    private val debugOnlyCode = Regex("^[0-9]{3}-?[0-9]{3}$")

    fun normalizeEnteredCode(entered: String, syntheticPreview: Boolean = false): String? {
        val value = entered.trim().uppercase(java.util.Locale.ROOT)
        if (productionCode.matches(value)) return value
        if (syntheticPreview && debugOnlyCode.matches(value)) {
            val digits = value.replace("-", "")
            return digits.substring(0, 3) + "-" + digits.substring(3, 6)
        }
        return null
    }

    fun validate(
        disclosureAcknowledged: Boolean,
        enteredCode: String,
        syntheticPreview: Boolean = false
    ): Result<String> {
        if (!disclosureAcknowledged) return Result.failure(
            IllegalStateException("Review and acknowledge monitoring disclosure before pairing")
        )
        val code = normalizeEnteredCode(enteredCode, syntheticPreview)
            ?: return Result.failure(IllegalArgumentException(
                "Enter the ten-character pairing code shown in Madalasa"
            ))
        return Result.success(code)
    }
}
