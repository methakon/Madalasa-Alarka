package org.madalasa.uicommon

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/**
 * Visual-only scaffold. TODO(INTEGRATION): add reviewed navigation, API and permission
 * wiring in the owning parent/child module. This preview never starts monitoring.
 */
@Composable fun APPlaceholderScreen(screen: ScreenDescriptor, onBack: (() -> Unit)? = null) {
    Scaffold { inner ->
        Column(modifier = Modifier.fillMaxSize().padding(inner).padding(horizontal = 20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)) {
            APTopBar(screen.title, screen.id.value)
            Text(screen.purpose)
            APStatusPanel("Design preview — not connected",
                screen.requiredGate?.let { "Requires review: $it" }
                    ?: "Backend and device actions are not yet connected.",
                if (onBack != null) "Back" else null, onBack)
            // TODO(API): screen.plannedApi identifies a future endpoint, not an active call.
        }
    }
}
