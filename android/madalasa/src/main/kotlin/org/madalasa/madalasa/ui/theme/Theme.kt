package org.madalasa.madalasa.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable

private val LightColorScheme = lightColorScheme(
    primary = ThemeCTokens.DeepIndigo,
    onPrimary = ThemeCTokens.Parchment,
    primaryContainer = ThemeCTokens.PaleWarmSurface,
    onPrimaryContainer = ThemeCTokens.DeepIndigo,
    secondary = ThemeCTokens.Teal,
    onSecondary = ThemeCTokens.Parchment,
    tertiary = ThemeCTokens.Vermilion,
    onTertiary = ThemeCTokens.Parchment,
    background = ThemeCTokens.Parchment,
    onBackground = ThemeCTokens.Ink,
    surface = ThemeCTokens.PaleWarmSurface,
    onSurface = ThemeCTokens.Ink,
    error = ThemeCTokens.CriticalRed,
    onError = ThemeCTokens.Parchment,
    outline = ThemeCTokens.DividerWarm
)

@Composable
fun MadalasaTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = LightColorScheme,
        content = content
    )
}
