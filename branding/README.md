# Madalasa–Alarka — Brand Asset Delivery

Status: **Design/export assets, pending final Play Console and Android-device checks.** Created in Figma [edit vector masters and branded graphics](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=68-164). Original concept influenced by **Mārkaṇḍeya Purāṇa**, pan-Indian; not Bengali folk art. English-only for launch, future localization-ready.

## Graphic identity

- **Madalasa parent app:** indigo background (#233F69), gold embracing arch and lotus symbol with calm teal petals, representing wisdom and guidance.
- **Alarka child app:** vermilion background (#A83D31), gold ring, ivory/teal rising flame symbolizing growing wisdom and transparent child-device participation.
- **Family website:** indigo and gold circular lotus-ring sign, supplied as raster logo and web SVGs.
- Original minimal vector symbols; NOT representations of any historical or divine figure, not traced from competitor app screenshots.
- Colors: indigo #233F69, vermilion #A83D31, gold #F4CE89, cream #FFF0CE, teal #80BEAF, parchment #FFF7E7.

## Required Play Console assets (individual app listing)

- `branding/play-store/{madalasa|alarka}/icon-512.png`: 512×512, 32-bit PNG, full-bleed square, ≤1024KB; no manual rounded corners or shadows.
- `branding/play-store/{madalasa|alarka}/feature-graphic-1024x500.jpg`: 1024×500 opaque JPEG, no alpha.
- Do not add price, trial badges, ratings, promises of remote listening, Google Play logo, or misleading certifications to listing artwork.
- Actual Play review and developer/publisher name/trademark clearance remain open.

## Android integration

Each `android/{madalasa|alarka}/src/main/res` includes:
- `mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png` (48/72/96/144/192px legacy);
- `mipmap-anydpi-v26/ic_launcher.xml` and `ic_launcher_round.xml`;
- `drawable/ic_launcher_background.xml`, `ic_launcher_foreground.xml`, `ic_launcher_monochrome.xml`.

Adaptive layers are **108×108dp** and key icon content sits within the **central 66×66dp safe zone**. Foreground and monochrome vector drawables are original and independently editable; background color is separate. The icon resource is **not wired into any AndroidManifest.xml yet**, because this repository currently has no complete Android app manifests/build modules. When modules exist, set `android:icon="@mipmap/ic_launcher"` (and optionally `android:roundIcon="@mipmap/ic_launcher_round"`). Run Android Studio preview across OEM masks, themed icons and DPI; run a real build before claiming integration.

## Website delivery

`public/brand/`: editable-source SVG favicon/wordmarks, PNG favicon-32, PWA icon-192, site-mark-512, Apple touch icon-180, two PNG horizontal wordmarks and 1200×630 JPEG social card. `public/manifest.webmanifest` is **prepared but no website integration/deployment is claimed**. To integrate a site, reference `/brand/favicon.svg`, `/brand/apple-touch-icon-180.png`, and the manifest/OG paths explicitly; verify CSP and asset caching.

## Source and production checklist

Canonical vector masters: `branding/source/`; Figma components [Parent](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=68-164), [Child](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=68-173), [Website](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=68-179). Editing a master requires re-exporting matching PNGs and Android vector XML.
Official references: https://support.google.com/googleplay/android-developer/answer/9866151 ; https://developer.android.com/distribute/google-play/resources/icon-design-specifications ; https://developer.android.com/develop/ui/compose/system/icon_design_adaptive .
Release gates: visual scaling/readability on physical phones, Play Console upload validation, accessibility contrast, ownership/trademark search, website deployment checks, asset license/IP register update. No app or site has been published by this commit.


## 2026-10-28 — New ACTIVE illustrated face icons (supersedes abstract-logo guidance above)

The active Play Store / launcher artwork now contains **original generated face portraits** of Madalasa (adult queen) and Alarka (young boy-prince), with a two-face family mark on the website. **These are NOT verified ancient portraits**; the 1904 Markandeya Purana translation gives narrative context but not authentic character photographs or artwork. Figma portrait components are still at [Madalasa](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=68-164), [Alarka](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=68-173) and [website dual portrait](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=68-179). Full details in [Portrait Logo Revision](CHARACTER_PORTRAIT_LOGOS_2026.md). Previous geometric PNG artwork is archived at `branding/archive/abstract-v1/` and legacy geometric `branding/source/*.svg` are **not** source masters for the new portraits. Android launcher now uses adaptive transparent `@drawable/ic_launcher_face` foreground PNG; themed monochrome icon remains geometric. The website portrait look is currently delivered through PNG wordmarks and favicons; SVG alternatives remain older geometric vector marks. Validate small icon readability, copyright/trademark/AI-art usage, exact Play size and adaptive masks on real devices before publication.
