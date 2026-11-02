package org.madalasa.uicommon

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

/** Theme C design-contract colors; verify accessibility contrast on a device. */
object ThemeCColors {
    val Parchment = Color(0xFFFFF7E7)
    val Ink = Color(0xFF292A31)
    val Vermilion = Color(0xFFB73527)
    val Indigo = Color(0xFF233F69)
    val Gold = Color(0xFFE7B44A)
    val Teal = Color(0xFF28756C)
    val Leaf = Color(0xFF5B784B)
    val Surface = Color(0xFFF7F1E8)
    val Critical = Color(0xFFBA2937)
}
private val LightColors = lightColorScheme(primary = ThemeCColors.Indigo, onPrimary = Color.White,
    secondary = ThemeCColors.Teal, background = ThemeCColors.Parchment,
    onBackground = ThemeCColors.Ink, surface = ThemeCColors.Surface,
    onSurface = ThemeCColors.Ink, error = ThemeCColors.Critical)
private val DarkColors = darkColorScheme(primary = Color(0xFFB7D0F4), secondary = Color(0xFF9FD3CB),
    background = Color(0xFF171C25), surface = Color(0xFF242B35), error = Color(0xFFFFAAB1))

@Composable fun MadalasaTheme(darkTheme: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = if (darkTheme) DarkColors else LightColors, content = content)
}
