package org.madalasa.madalasa

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.lifecycle.viewmodel.compose.viewModel
import org.madalasa.madalasa.di.DefaultAppContainer
import org.madalasa.madalasa.ui.navigation.MadalasaNavHost
import org.madalasa.madalasa.ui.theme.MadalasaTheme
import org.madalasa.madalasa.ui.viewmodel.ParentViewModel

/**
 * Single Activity entry point for Madalasa guardian application.
 * Uses Jetpack Compose single-activity architecture with Navigation.
 * No runtime permissions requested on startup.
 */
class MainActivity : ComponentActivity() {

    private val appContainer by lazy { DefaultAppContainer() }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MadalasaTheme {
                val viewModel: ParentViewModel = viewModel(
                    factory = ParentViewModel.provideFactory(appContainer.repository)
                )
                MadalasaNavHost(viewModel = viewModel, privacyGateway = appContainer.privacyGateway)
            }
        }
    }
}
