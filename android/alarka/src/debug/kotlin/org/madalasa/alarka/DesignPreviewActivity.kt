package org.madalasa.alarka

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
import org.madalasa.alarka.ui.screens.ChildPrivacyPage
import org.madalasa.alarka.ui.screens.ChildPrivacyScreen
import org.madalasa.alarka.ui.figma.ChildFigmaScreen
import org.madalasa.alarka.ui.figma.SupplementalFigmaCatalog
import org.madalasa.alarka.ui.figma.SupplementalFigmaScreen
import org.madalasa.uicommon.MadalasaTheme
import org.madalasa.uicommon.ScreenId

/**
 * DEBUG BUILD ONLY: standalone navigation into 21 original + 24 capability + 2 privacy Figma screens.
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
    val active = selected
    if (active != null) {
        Column(Modifier.fillMaxSize()) {
            TextButton(onClick = { selected = null }, modifier = Modifier.padding(8.dp)) {
                Text("All screen designs")
            }
            Box(Modifier.weight(1f)) {
                val lookup = if (active.startsWith("CAP-")) active.removePrefix("CAP-") else active
                val spec = supplemental.firstOrNull { it.id == lookup }
                val privacyPage = if (active == "PRIV-UI-05")
                    ChildPrivacyPage.TRANSPARENCY
                else if (active == "PRIV-UI-06")
                    ChildPrivacyPage.LOCATION_UNAVAILABLE
                else null
                if (privacyPage != null) {
                    ChildPrivacyScreen(
                        page = privacyPage,
                        report = null,
                        onBack = { selected = null },
                        onShowLocationUnavailable = { selected = "PRIV-UI-06" },
                        onOpenAndroidSettings = {},
                        openSettingsEnabled = false
                    )
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
                    ChildFigmaScreen(ScreenId(active))
                }
            }
        }
    } else {
        val ids = (1..21).map { "C-%02d".format(it) }
        LazyColumn(contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)) {
            item {
                Text("Alarka design previews", style = MaterialTheme.typography.headlineSmall)
                Text("DEBUG ONLY · Example data; no API, sensor access or OS permission changes")
                Text("Original handoff · 21", style = MaterialTheme.typography.titleMedium)
            }
            items(ids, key = { it }) { id ->
                ElevatedCard(modifier = Modifier.fillMaxWidth().clickable { selected = id }) {
                    Text(id, modifier = Modifier.padding(18.dp))
                }
            }
            item { Text("Privacy controls · 2 new", style = MaterialTheme.typography.titleMedium) }
            items(ChildPrivacyPage.entries.toList(), key = { it.route }) { page ->
                ElevatedCard(modifier = Modifier.fillMaxWidth().clickable {
                    selected = if (page == ChildPrivacyPage.TRANSPARENCY) "PRIV-UI-05" else "PRIV-UI-06"
                }) {
                    Text((if (page == ChildPrivacyPage.TRANSPARENCY) "PRIV-UI-05 · Monitoring information"
                        else "PRIV-UI-06 · Location unavailable"), modifier = Modifier.padding(18.dp))
                }
            }
            item { Text("Capability onboarding · 24",
                style = MaterialTheme.typography.titleMedium) }
            items(supplemental.filter { it.kind == "CAPABILITY" }, key = { "CAP-" + it.id }) { spec ->
                ElevatedCard(modifier = Modifier.fillMaxWidth().clickable {
                    selected = if (spec.id.startsWith("P-")) "CAP-" + spec.id else spec.id
                }) {
                    Text(spec.id + " · " + spec.title, modifier = Modifier.padding(18.dp))
                }
            }
        }
    }
}
