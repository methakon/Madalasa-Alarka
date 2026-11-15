package org.madalasa.alarka.manifest

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * L13-001 guard: the Alarka child launcher must present Theme C portrait branding
 * (adaptive icon with a real portrait layer, themed-icon monochrome layer, all density
 * buckets) and must keep its shipped resources English-only initially.
 *
 * Pure JVM test (no Android runtime or device required).
 */
class AlarkaLauncherBrandingTest {

    private fun moduleRoot(): File {
        val candidates = listOf(File("."), File("alarka"), File("android/alarka"))
        return candidates.firstOrNull { File(it, "src/main/res").isDirectory }
            ?: error("cannot locate the alarka res tree from ${File(".").absolutePath}")
    }

    private fun adaptiveIcon(): String =
        File(moduleRoot(), "src/main/res/mipmap-anydpi-v26/ic_launcher.xml").readText()

    private fun drawableRefs(xml: String): List<String> =
        Regex("@drawable/([A-Za-z0-9_]+)").findAll(xml).map { it.groupValues[1] }.distinct().toList()

    private fun drawableExists(name: String): Boolean {
        val root = moduleRoot()
        return File(root, "src/main/res/drawable/$name.xml").isFile ||
            File(root, "src/main/res/drawable-nodpi/$name.png").isFile
    }

    @Test
    fun adaptiveIconDeclaresEveryLayer() {
        val xml = adaptiveIcon()
        assertTrue("adaptive icon needs a background layer", xml.contains("<background"))
        assertTrue("adaptive icon needs a foreground layer", xml.contains("<foreground"))
        assertTrue("child launcher must support themed icons", xml.contains("<monochrome"))
    }

    @Test
    fun everyReferencedDrawableIsCheckedIn() {
        val refs = drawableRefs(adaptiveIcon())
        assertTrue("adaptive icon must reference at least three drawables", refs.size >= 3)
        for (ref in refs) {
            assertTrue("adaptive icon references a missing drawable: $ref", drawableExists(ref))
        }
    }

    @Test
    fun portraitBrandingIsRealArtworkNotAPlaceholder() {
        val root = moduleRoot()
        val portrait = File(root, "src/main/res/drawable-nodpi/ic_launcher_face.png")
        assertTrue("portrait branding asset must be checked in at drawable-nodpi/ic_launcher_face.png",
            portrait.isFile)
        assertTrue("portrait asset looks empty", portrait.length() > 1024)
        // A PNG signature check proves it is real raster artwork, not a renamed text stub.
        val header = portrait.inputStream().use { it.readNBytes(8) }
        val pngMagic = byteArrayOf(0x89.toByte(), 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)
        assertTrue("portrait asset is not a valid PNG", header.contentEquals(pngMagic))
    }

    @Test
    fun allDensityBucketsArePresent() {
        val root = moduleRoot()
        for (density in listOf("mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi")) {
            val png = File(root, "src/main/res/mipmap-$density/ic_launcher.png")
            assertTrue("missing launcher png for $density", png.isFile)
            assertTrue("launcher png for $density looks empty", png.length() > 256)
        }
        assertTrue("round icon variant must exist",
            File(root, "src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml").isFile)
    }

    @Test
    fun manifestUsesTheProductionLauncherAndLabel() {
        val manifest = File(moduleRoot(), "src/main/AndroidManifest.xml").readText()
        assertTrue("manifest must use the adaptive launcher", manifest.contains("@mipmap/ic_launcher"))
        assertTrue("manifest must use the round launcher", manifest.contains("@mipmap/ic_launcher_round"))
        assertTrue("manifest must label from resources", manifest.contains("@string/app_name"))
        assertFalse("manifest must not reference a synthetic placeholder launcher",
            manifest.contains("ic_launcher_synthetic"))
    }

    @Test
    fun childStringsAreHonestAndEnglishOnly() {
        val strings = File(moduleRoot(), "src/main/res/values/strings.xml")
        assertTrue("values/strings.xml must exist", strings.isFile)
        val text = strings.readText()
        assertTrue("child app must name itself from resources", text.contains("name=\"app_name\""))
        assertTrue("child app must state that monitoring is not active",
            text.contains("no monitoring enabled") && text.contains("Synthetic data only"))
        assertFalse("child strings must not promise detection or guaranteed response",
            text.contains("guaranteed") || text.contains("emergency response"))

        val forbidden = text.codePoints().toArray().filter { cp ->
            cp in 0x0900..0x097F || cp in 0x0980..0x09FF || cp in 0x0B80..0x0BFF ||
                cp in 0x0C00..0x0C7F || cp in 0x0600..0x06FF || cp in 0x4E00..0x9FFF
        }
        assertTrue("child strings must not ship non-English scripts yet: $forbidden", forbidden.isEmpty())

        // No locale-qualified values directory may ship silently.
        val languageQualifier = Regex("^[a-z]{2,3}(-r[A-Z]{2})?$")
        val dirs = File(moduleRoot(), "src/main/res").listFiles()?.filter { it.isDirectory }?.map { it.name } ?: emptyList()
        for (dir in dirs) {
            if (!dir.startsWith("values-")) continue
            val languages = dir.removePrefix("values-").split('-')
                .filter { it != "night" && !it.matches(Regex("^v\\d+$")) }
            assertEquals("unexpected locale qualifier in resource dir $dir", emptyList<String>(), languages)
        }
    }
}
