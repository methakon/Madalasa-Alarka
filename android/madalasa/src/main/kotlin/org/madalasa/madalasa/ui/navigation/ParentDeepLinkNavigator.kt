package org.madalasa.madalasa.ui.navigation

import java.net.URI
import org.madalasa.madalasa.api.ChildSummaryResponse
import org.madalasa.madalasa.api.ParentProfileResponse

/**
 * Outcome of resolving a parent application deep link.
 * Guarantees that unauthenticated callers and unauthorized child access
 * are denied BEFORE any sensitive child state is loaded or navigated to.
 */
sealed interface DeepLinkResolution {
    data class Authorized(
        val childId: String,
        val targetRoute: String,
        val subPage: String? = null
    ) : DeepLinkResolution

    data class DeniedUnauthenticated(
        val rawUri: String,
        val redirectRoute: String = Screen.Authentication.route,
        val reason: String = "Authentication required before accessing child details"
    ) : DeepLinkResolution

    data class DeniedUnauthorizedChild(
        val rawUri: String,
        val requestedChildId: String,
        val redirectRoute: String = Screen.ChildSelection.route,
        val reason: String
    ) : DeepLinkResolution

    data class InvalidUri(
        val rawUri: String,
        val reason: String
    ) : DeepLinkResolution
}

class ParentDeepLinkNavigator {
    companion object {
        private val UUID_REGEX = Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
        const val SCHEME_CUSTOM = "madalasa"
        const val SCHEME_HTTPS = "https"
        const val HOST_CUSTOM = "child"
        const val HOST_WEB = "app.madalasa.org"
    }

    /**
     * Resolves an incoming deep link URI string against the current authentication
     * state and verified child grants.
     *
     * @param uriString The raw deep link URI.
     * @param isAuthenticated True if parent has an active, valid session.
     * @param profile The authenticated parent profile (containing authorized family IDs).
     * @param children The list of summary responses for children available to the parent.
     */
    fun resolve(
        uriString: String?,
        isAuthenticated: Boolean,
        profile: ParentProfileResponse?,
        children: List<ChildSummaryResponse>
    ): DeepLinkResolution {
        if (uriString.isNullOrBlank()) {
            return DeepLinkResolution.InvalidUri(uriString ?: "", "Empty or null URI")
        }

        val uri = try {
            URI.create(uriString.trim())
        } catch (e: Exception) {
            return DeepLinkResolution.InvalidUri(uriString, "Malformed URI: ${e.message}")
        }

        val (childId, subPath) = extractChildRoute(uri)
            ?: return DeepLinkResolution.InvalidUri(uriString, "URI is not a supported child navigation path")

        if (!UUID_REGEX.matches(childId)) {
            return DeepLinkResolution.InvalidUri(uriString, "Invalid child identifier format: must be UUID")
        }

        // Gate 1: Authentication Guard
        if (!isAuthenticated) {
            return DeepLinkResolution.DeniedUnauthenticated(rawUri = uriString)
        }

        // Gate 2: Child Grant and Family Membership Guard
        val child = children.find { it.id.equals(childId, ignoreCase = true) }
        if (child == null) {
            return DeepLinkResolution.DeniedUnauthorizedChild(
                rawUri = uriString,
                requestedChildId = childId,
                reason = "No child found matching requested ID"
            )
        }

        if (child.freeServiceState != "ADMITTED") {
            return DeepLinkResolution.DeniedUnauthorizedChild(
                rawUri = uriString,
                requestedChildId = childId,
                reason = "Child service state is '${child.freeServiceState}', required: 'ADMITTED'"
            )
        }

        val familyIds = profile?.familyIds ?: emptyList()
        if (!familyIds.contains(child.familyId)) {
            return DeepLinkResolution.DeniedUnauthorizedChild(
                rawUri = uriString,
                requestedChildId = childId,
                reason = "Parent does not have active grant for child family '${child.familyId}'"
            )
        }

        // Gate 3: Authorized destination routing
        val (targetRoute, subPage) = when (subPath?.lowercase()) {
            "privacy", "privacy/overview" -> Screen.Shell.route to "privacy"
            "location" -> Screen.Shell.route to "location"
            null, "", "detail" -> Screen.Shell.route to null
            else -> Screen.Shell.route to subPath
        }

        return DeepLinkResolution.Authorized(
            childId = child.id,
            targetRoute = targetRoute,
            subPage = subPage
        )
    }

    private fun extractChildRoute(uri: URI): Pair<String, String?>? {
        val scheme = uri.scheme?.lowercase() ?: return null
        val host = uri.host?.lowercase() ?: return null
        val path = uri.path ?: ""

        if (scheme == SCHEME_CUSTOM && host == HOST_CUSTOM) {
            val parts = path.removePrefix("/").split("/").filter { it.isNotBlank() }
            if (parts.isEmpty()) return null
            val childId = parts[0]
            val subPath = if (parts.size > 1) parts.drop(1).joinToString("/") else null
            return childId to subPath
        }

        if (scheme == SCHEME_HTTPS && host == HOST_WEB) {
            val parts = path.removePrefix("/").split("/").filter { it.isNotBlank() }
            if (parts.size >= 2 && parts[0] == "child") {
                val childId = parts[1]
                val subPath = if (parts.size > 2) parts.drop(2).joinToString("/") else null
                return childId to subPath
            }
        }

        return null
    }
}
