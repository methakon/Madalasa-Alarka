package org.madalasa.madalasa.ui.figma

import androidx.compose.ui.graphics.Color
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.madalasa.uicommon.ThemeCColors
import org.madalasa.uicommon.ThemeCTypography
import java.io.File

/**
 * L12-001 guard: Theme C design tokens, typography and launcher resources must stay
 * consistent across the parent screens, and the shipped resources must remain
 * English-only until translations are added deliberately.
 *
 * Pure JVM test (no Android runtime). The token assertions read the same
 * `org.madalasa.uicommon.ThemeCColors` object the screens consume, so a palette change
 * cannot silently drift away from the Theme C contract.
 */
class ThemeCTokenAndLocaleTest {

    private fun moduleRoot(): File {
        // Test working directory is the :madalasa module dir under Gradle.
        val candidates = listOf(File("."), File("madalasa"), File("android/madalasa"))
        return candidates.firstOrNull { File(it, "src/main/res").isDirectory }
            ?: error("cannot locate the madalasa res tree from ${File(".").absolutePath}")
    }

    private fun resDirs(): List<String> =
        File(moduleRoot(), "src/main/res").listFiles()?.filter { it.isDirectory }?.map { it.name }?.sorted()
            ?: emptyList()

    @Test
    fun themeCPaletteMatchesTheDesignContract() {
        // Values are the Theme C contract colours; ARGB hex form.
        val parchment = ThemeCColors.Parchment
        val ink = ThemeCColors.Ink
        val vermilion = ThemeCColors.Vermilion
        val indigo = ThemeCColors.Indigo
        val gold = ThemeCColors.Gold
        val teal = ThemeCColors.Teal
        val leaf = ThemeCColors.Leaf
        val surface = ThemeCColors.Surface
        val critical = ThemeCColors.Critical

        assertEquals("Theme C colour Parchment", Color(0xFFFFF7E7), parchment)
        assertEquals("Theme C colour Ink", Color(0xFF292A31), ink)
        assertEquals("Theme C colour Vermilion", Color(0xFFB73527), vermilion)
        assertEquals("Theme C colour Indigo", Color(0xFF233F69), indigo)
        assertEquals("Theme C colour Gold", Color(0xFFE7B44A), gold)
        assertEquals("Theme C colour Teal", Color(0xFF28756C), teal)
        assertEquals("Theme C colour Leaf", Color(0xFF5B784B), leaf)
        assertEquals("Theme C colour Surface", Color(0xFFF7F1E8), surface)
        assertEquals("Theme C colour Critical", Color(0xFFBA2937), critical)

        val palette = listOf(parchment, ink, vermilion, indigo, gold, teal, leaf, surface, critical)
        assertEquals("palette entries must be visually distinguishable", 9, palette.toSet().size)
    }

    @Test
    fun typographyScaleIsOrderedAndReadable() {
        val scale = ThemeCTypography.ascending
        assertEquals("scale must be strictly ascending", scale.sorted(), scale)
        assertEquals("scale must not repeat a size", scale.size, scale.toSet().size)
        assertTrue("no entry below the readable minimum",
            scale.all { it >= ThemeCTypography.MinimumReadableSp })
    }

    @Test
    fun shippedResourcesAreEnglishOnly() {
        // A locale-qualified values dir (values-hi, values-bn-rIN, ...) would silently
        // ship a translation. API (`values-v31`) and UI-mode (`values-night`) qualifiers
        // are not languages and remain allowed.
        val languageQualifier = Regex("^[a-z]{2,3}(-r[A-Z]{2})?$")
        for (dir in resDirs()) {
            if (!dir.startsWith("values-")) continue
            val qualifiers = dir.removePrefix("values-").split('-')
            val languages = qualifiers.filter { it != "night" && !it.matches(Regex("^v\\d+$")) }
            assertTrue("unexpected locale qualifier in resource dir $dir", languages.none { languageQualifier.matches(it) })
        }

        val strings = File(moduleRoot(), "src/main/res/values/strings.xml")
        assertTrue("values/strings.xml must exist", strings.isFile)
        val text = strings.readText()
        val forbidden = text.codePoints().toArray().filter { cp ->
            // Latin + common punctuation only for the initial release.
            cp in 0x0900..0x097F ||  // Devanagari
                cp in 0x0980..0x09FF ||  // Bengali
                cp in 0x0B80..0x0BFF ||  // Tamil
                cp in 0x0C00..0x0C7F ||  // Telugu
                cp in 0x0600..0x06FF ||  // Arabic
                cp in 0x4E00..0x9FFF     // CJK
        }
        assertTrue("strings.xml must not ship non-English scripts yet: $forbidden",
            forbidden.isEmpty())
    }

    @Test
    fun launcherResourcesAreComplete() {
        val root = moduleRoot()
        val adaptive = File(root, "src/main/res/mipmap-anydpi-v26/ic_launcher.xml")
        assertTrue("adaptive icon xml must exist", adaptive.isFile)
        val adaptiveText = adaptive.readText()
        assertTrue("adaptive icon needs a background layer", adaptiveText.contains("<background"))
        assertTrue("adaptive icon needs a foreground layer", adaptiveText.contains("<foreground"))
        assertTrue("adaptive icon needs a monochrome layer for themed icons",
            adaptiveText.contains("<monochrome"))
        assertTrue("round icon variant must exist",
            File(root, "src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml").isFile)
        assertTrue("portrait branding asset must be checked in",
            File(root, "src/main/res/drawable-nodpi/ic_launcher_face.png").isFile)

        // Every drawable the adaptive icon references must actually resolve.
        val refs = Regex("@(?:drawable|mipmap)/([A-Za-z0-9_]+)")
            .findAll(adaptiveText).map { it.groupValues[1] }.distinct().toList()
        assertTrue("adaptive icon must reference layers", refs.size >= 3)
        for (ref in refs) {
            val resolved = listOf("drawable/$ref.xml", "drawable-nodpi/$ref.png").any {
                File(root, "src/main/res/$it").isFile
            }
            assertTrue("adaptive icon references a missing drawable: $ref", resolved)
        }

        for (density in listOf("mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi")) {
            val png = File(root, "src/main/res/mipmap-$density/ic_launcher.png")
            assertTrue("missing launcher png for $density", png.isFile)
            assertTrue("launcher png for $density looks empty", png.length() > 256)
        }

        val manifest = File(root, "src/main/AndroidManifest.xml").readText()
        assertTrue("manifest must reference the adaptive launcher", manifest.contains("@mipmap/ic_launcher"))
        assertFalse("manifest must not reference the synthetic placeholder icon",
            manifest.contains("ic_launcher_synthetic"))
    }
}
