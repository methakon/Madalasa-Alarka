package org.madalasa.uicommon

/** Stable Figma handoff ID, not a user-controlled destination. */
@JvmInline value class ScreenId(val value: String) {
    init { require(Regex("P-(?:0[1-9]|[1-5][0-9]|60)|C-(?:0[1-9]|1[0-9]|2[01])|ST-0[1-5]").matches(value)) }
}
enum class AppActor { PARENT, CHILD }
/** UI presentation only; no networking or permission side effects. */
sealed interface ScreenState<out T> {
    data object Loading : ScreenState<Nothing>
    data class Content<T>(val value: T) : ScreenState<T>
    data class Empty(val message: String) : ScreenState<Nothing>
    data class Unavailable(val reason: String, val retryAllowed: Boolean = false) : ScreenState<Nothing>
    data class PermissionRequired(val explanation: String) : ScreenState<Nothing>
}
enum class CapabilityPresentation { UNKNOWN, REPORTED, VERIFIED, DENIED, REVOKED, UNSUPPORTED }
/** TODO(INTEGRATION): Connect API, ViewModel and gates in owning screen, never here. */
data class ScreenDescriptor(val id: ScreenId, val actor: AppActor, val title: String,
    val purpose: String, val plannedApi: String? = null, val requiredGate: String? = null) {
    init {
        require((actor == AppActor.PARENT && (id.value.startsWith("P-") || id.value.startsWith("ST-"))) ||
                (actor == AppActor.CHILD && id.value.startsWith("C-")))
    }
}
