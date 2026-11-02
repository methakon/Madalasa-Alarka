package org.madalasa.madalasa

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import org.madalasa.madalasa.ui.screens.ParentPrivacyPage
import org.madalasa.madalasa.ui.screens.ParentPrivacyScreen
import org.madalasa.madalasa.ui.figma.ParentFigmaScreen
import org.madalasa.madalasa.ui.figma.SupplementalFigmaCatalog
import org.madalasa.madalasa.ui.figma.SupplementalFigmaScreen
import org.madalasa.madalasa.ui.figma.ThemeCSharingCatalog
import org.madalasa.madalasa.ui.figma.ThemeCSharingScreen
import org.madalasa.uicommon.MadalasaTheme
import org.madalasa.uicommon.ScreenId

/**
 * DEBUG BUILD ONLY: standalone navigation into 60 original + 22 capability + 11 media + 8 Theme C family + 4 privacy Figma designs.
 * Does not use the production NavHost, authentication, OS permissions or APIs.
 * TODO(INTEGRATION): connect reviewed final screen routes after visual/UX QA.
 * Launch through Android Studio's Run configuration or adb explicit activity.
 */
class DesignPreviewActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { MadalasaTheme { DesignPreviewGallery() } }
    }
}

@Composable private fun DesignPreviewGallery() {
    var selected by remember { mutableStateOf<String?>(null) }
    BackHandler(enabled = selected != null) { selected = null }
    val supplemental = SupplementalFigmaCatalog.screens
    val themed = ThemeCSharingCatalog.screens
    val active = selected
    if (active != null) {
        Column(Modifier.fillMaxSize()) {
            TextButton(onClick = { selected = null }, modifier = Modifier.padding(8.dp)) {
                Text("All screen designs")
            }
            Box(Modifier.weight(1f)) {
                val spec = when {
                    active.startsWith("CAP-") -> supplemental.firstOrNull { it.id == active.removePrefix("CAP-") && it.kind == "CAPABILITY" }
                    active.startsWith("PA-") -> supplemental.firstOrNull { it.id == active && it.kind == "MEDIA" }
                    else -> null // Original P-01..P-60 must stay on the existing renderer.
                }
                val themeSpec = when {
                    active.startsWith("THEME-") -> themed.firstOrNull { it.id == active.removePrefix("THEME-") }
                    active.startsWith("SH-") -> themed.firstOrNull { it.id == active }
                    else -> null
                }
                val privacyPage = if (active.startsWith("PRIV-UI-")) {
                    val number = active.removePrefix("PRIV-UI-").toIntOrNull()
                    ParentPrivacyPage.entries.getOrNull((number ?: 0) - 1)
                } else null
                if (privacyPage != null) {
                    ParentPrivacyScreen(
                        page = privacyPage,
                        hasSelectedChild = false,
                        onBack = { selected = null },
                        onNavigate = { selected = "PRIV-UI-" + "%02d".format(it.ordinal + 1) }
                    )
                } else if (themeSpec != null) {
                    ThemeCSharingScreen(themeSpec, onNextDesign = {
                        val index = themed.indexOfFirst { it.id == themeSpec.id }
                        val next = themed.getOrNull(index + 1) ?: themed.first()
                        selected = if (next.id.startsWith("P-")) "THEME-" + next.id else next.id
                    })
                } else if (spec != null) {
                    SupplementalFigmaScreen(spec, onNextDesign = {
                        val group = supplemental.filter { it.kind == spec.kind &&
                            (spec.id.startsWith("PA-") == it.id.startsWith("PA-")) }
                        val index = group.indexOfFirst { it.id == spec.id }
                        val next = group.getOrNull(index + 1) ?: group.firstOrNull()
                        selected = if (next == null) null else if (next.id.startsWith("P-"))
                            "CAP-" + next.id else next.id
                    })
                } else {
                    ParentFigmaScreen(ScreenId(active))
                }
            }
        }
    } else {
        val ids = (1..60).map { "P-%02d".format(it) }
        LazyColumn(contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)) {
            item {
                Text("Madalasa design previews", style = MaterialTheme.typography.headlineSmall)
                Text("DEBUG ONLY · Example data; no API, sensor access or OS permission changes")
                Text("Original handoff · 60", style = MaterialTheme.typography.titleMedium)
            }
            items(ids, key = { it }) { id ->
                ElevatedCard(modifier = Modifier.fillMaxWidth().clickable { selected = id }) {
                    Text(id, modifier = Modifier.padding(18.dp))
                }
            }
            item { Text("Capability onboarding · 22",
                style = MaterialTheme.typography.titleMedium) }
            items(supplemental.filter { it.kind == "CAPABILITY" }, key = { "CAP-" + it.id }) { spec ->
                ElevatedCard(modifier = Modifier.fillMaxWidth().clickable {
                    selected = if (spec.id.startsWith("P-")) "CAP-" + spec.id else spec.id
                }) {
                    Text(spec.id + " · " + spec.title, modifier = Modifier.padding(18.dp))
                }
            }
            item { Text("Theme C family sharing · 8", style = MaterialTheme.typography.titleMedium) }
            items(themed, key = { "THEME-" + it.id }) { design ->
                ElevatedCard(modifier = Modifier.fillMaxWidth().clickable {
                    selected = if (design.id.startsWith("P-")) "THEME-" + design.id else design.id
                }) {
                    Text(design.id + " · " + design.title, modifier = Modifier.padding(18.dp))
                }
            }
            item { Text("Privacy controls · 4 new", style = MaterialTheme.typography.titleMedium) }
            items(ParentPrivacyPage.entries.toList(), key = { it.route }) { page ->
                ElevatedCard(modifier = Modifier.fillMaxWidth().clickable {
                    selected = "PRIV-UI-" + "%02d".format(page.ordinal + 1)
                }) {
                    Text("PRIV-UI-" + "%02d".format(page.ordinal + 1) + " · " + page.title,
                        modifier = Modifier.padding(18.dp))
                }
            }
            item { Text("Media activity · 11", style = MaterialTheme.typography.titleMedium) }
            items(supplemental.filter { it.kind == "MEDIA" }, key = { it.id }) { spec ->
                ElevatedCard(modifier = Modifier.fillMaxWidth().clickable { selected = spec.id }) {
                    Text(spec.id + " · " + spec.title, modifier = Modifier.padding(18.dp))
                }
            }
        }
    }
}
