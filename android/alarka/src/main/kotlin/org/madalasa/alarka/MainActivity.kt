package org.madalasa.alarka

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import org.madalasa.alarka.di.DefaultChildAppContainer
import org.madalasa.alarka.ui.navigation.ChildNavHost
import org.madalasa.alarka.ui.viewmodel.ChildViewModel
import org.madalasa.uicommon.MadalasaTheme

class MainActivity : ComponentActivity() {

    private val appContainer by lazy { DefaultChildAppContainer(applicationContext) }
    private val childViewModel by lazy { ChildViewModel(appContainer) }

    override fun onResume() {
        super.onResume()
        // Android Settings may have changed app grants while this Activity was paused.
        // Refresh on device only; do not infer or upload a server-confirmed state.
        childViewModel.refreshCapabilities()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MadalasaTheme {
                ChildNavHost(viewModel = childViewModel)
            }
        }
    }
}
