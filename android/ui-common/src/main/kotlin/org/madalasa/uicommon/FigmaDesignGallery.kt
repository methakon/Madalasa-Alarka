package org.madalasa.uicommon

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/**
 * Development-only visual review gallery. Must not be exposed as a substitute
 * for authenticated app navigation or real service functionality.
 * TODO(INTEGRATION): Remove gallery from release navigation; route finished
 * per-screen composables from owning app after visual and accessibility QA.
 */
@Composable
fun FigmaDesignGallery(actor: AppActor) {
    var selected by remember(actor) { mutableStateOf<FigmaScreenSpec?>(null) }
    val active = selected
    if (active != null) {
        Column {
            TextButton(onClick = { selected = null }, modifier = Modifier.padding(8.dp)) {
                Text("All screens")
            }
            FigmaDesignScreen(active)
        }
    } else {
        LazyColumn(contentPadding = PaddingValues(20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            item {
                Text(if (actor == AppActor.PARENT) "Madalasa screen designs" else "Alarka screen designs",
                    style = MaterialTheme.typography.headlineSmall)
                Text("Design previews only · no live data or device access",
                    style = MaterialTheme.typography.bodySmall)
            }
            items(FigmaScreenCatalog.forActor(actor), key = { it.id.value }) { spec ->
                Card(modifier = Modifier.fillMaxWidth().clickable { selected = spec }) {
                    Column(Modifier.padding(16.dp)) {
                        Text("${spec.id.value} · ${spec.title}",
                            style = MaterialTheme.typography.titleMedium)
                        Text(spec.headline, style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
        }
    }
}
