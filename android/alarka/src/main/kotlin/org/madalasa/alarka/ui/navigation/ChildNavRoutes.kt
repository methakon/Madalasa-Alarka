package org.madalasa.alarka.ui.navigation

sealed class ChildNavRoute(val route: String, val title: String) {
    data object Disclosure : ChildNavRoute("disclosure", "Transparency")
    data object Pairing : ChildNavRoute("pairing", "Pair Device")
    data object Permissions : ChildNavRoute("permissions", "Permissions")
    data object CapabilityGuide : ChildNavRoute("capability_guide", "Compatibility Guide")
    data object Connectivity : ChildNavRoute("connectivity", "Connectivity")
    data object AccountInfo : ChildNavRoute("account_info", "Account Info")

    companion object {
        val all: List<ChildNavRoute> = listOf(
            Disclosure,
            Pairing,
            Permissions,
            Connectivity,
            AccountInfo
        )

        fun fromRoute(route: String?): ChildNavRoute {
            return all.find { it.route == route } ?: Disclosure
        }
    }
}
