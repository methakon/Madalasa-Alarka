package org.madalasa.alarka.ui.figma

import androidx.compose.runtime.Composable
import org.madalasa.uicommon.ScreenId

/** Design-only screen dispatch; TODO(INTEGRATION): connect to app navigation after QA. */
@Composable fun ChildFigmaScreen(id: ScreenId) {
    when (id.value) {
        "C-01" -> C01Screen()
        "C-02" -> C02Screen()
        "C-03" -> C03Screen()
        "C-04" -> C04Screen()
        "C-05" -> C05Screen()
        "C-06" -> C06Screen()
        "C-07" -> C07Screen()
        "C-08" -> C08Screen()
        "C-09" -> C09Screen()
        "C-10" -> C10Screen()
        "C-11" -> C11Screen()
        "C-12" -> C12Screen()
        "C-13" -> C13Screen()
        "C-14" -> C14Screen()
        "C-15" -> C15Screen()
        "C-16" -> C16Screen()
        "C-17" -> C17Screen()
        "C-18" -> C18Screen()
        "C-19" -> C19Screen()
        "C-20" -> C20Screen()
        "C-21" -> C21Screen()
        else -> androidx.compose.material3.Text("Unknown screen")
    }
}
