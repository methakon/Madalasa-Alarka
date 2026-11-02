package org.madalasa.uicommon

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/** UI controls have no backend side effects; owning screen supplies callbacks. */
@Composable fun APButton(label: String, enabled: Boolean = true, onClick: () -> Unit) {
    Button(onClick = onClick, enabled = enabled, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) {
        Text(label)
    }
}
@Composable fun APTopBar(title: String, subtitle: String? = null) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp),
        modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp)) {
        Text(title, style = MaterialTheme.typography.headlineSmall)
        if (subtitle != null) Text(subtitle, style = MaterialTheme.typography.bodyMedium)
    }
}
/** Never fabricate live, connected or permission-granted data. */
@Composable fun APStatusPanel(title: String, detail: String, actionLabel: String? = null,
    onAction: (() -> Unit)? = null) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            Text(detail, style = MaterialTheme.typography.bodyMedium)
            if (actionLabel != null && onAction != null)
                OutlinedButton(onClick = onAction, modifier = Modifier.heightIn(min = 48.dp),
                    contentPadding = PaddingValues(horizontal = 16.dp)) { Text(actionLabel) }
        }
    }
}
@Composable fun <T> APScreenBody(state: ScreenState<T>, content: @Composable (T) -> Unit) {
    when (state) {
        ScreenState.Loading -> CircularProgressIndicator()
        is ScreenState.Content -> content(state.value)
        is ScreenState.Empty -> APStatusPanel("Nothing to show", state.message)
        is ScreenState.Unavailable -> APStatusPanel("Unavailable", state.reason)
        is ScreenState.PermissionRequired -> APStatusPanel("Permission required", state.explanation)
    }
}
