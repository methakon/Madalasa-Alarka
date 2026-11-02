# Madalasa–Alarka: illustrated face logo revision

Status: owner requested, design/export assets committed, **not Google Play approved or historically authenticated** (2026-10-28).

Source narrative: [1904 Markandeya Purana translation by F. Eden Pargiter](https://books.google.com/books?id=IdxKAQAAMAAJ), a pan-Indian Puranic text. It supplies the story but **no verified original face portraits** for Madalasa or Alarka. New faces are **original AI-generated interpretive artworks**, not copied from modern illustrated editions or claimed historical likenesses.

**Active Figma sources:** [Madalasa adult queen face](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=68-164), [Alarka boy prince face](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=68-173), [combined parent/child website mark](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=68-179). Face art images are generated raster fills; wordmark, framing, background, and graphic layouts are editable Figma layers. Face art source nodes: 75:2 and 76:2. Figma feature graphic frames: 70:200 and 70:213.

**Active delivery assets:** 512x512 32bit full-bleed Play PNG files for both apps and 1024x500 feature JPEGs under `branding/play-store/`; all Android legacy `mipmap-` density PNGs and new transparent portrait foregrounds `android/{madalasa,alarka}/src/main/res/drawable-nodpi/ic_launcher_face.png` (432x432); adaptive XML now uses `@drawable/ic_launcher_face` with existing color backgrounds and geometric monochrome themed symbol. Website dual-face PNG mark, favicons, horizontal wordmark PNGs and 1200x630 social preview are updated under `public/brand/`.

**Legacy artwork retained:** `branding/archive/abstract-v1/` stores previous app/icon/feature assets for rollback. `branding/source/*.svg` and `public/brand/*.svg` are still **legacy geometric vector alternatives**, not portrait masters. To show the new portrait look on the website, use the PNG wordmarks and updated PNG favicons; do not claim matching vector SVG is ready. The small geometric monochrome themed launcher intentionally stays simple.

**Release checks:** Confirm icon 512x512 RGBA <=1MB, feature graphic 1024x500, Android adaptive safe-zone and mask with image at 432px foreground, actual Android manifests/resources/build, Google Play store tests, legal/trademark/AI-art rights and small-size readability. The completed files are artwork candidates, not a deployed application.

English only for initial product UI; future localization remains planned. No camera/mic monitoring claim is conveyed by the portraits.

## 2026-10-28 originality and copyright clearance gate

The original portrait illustrations are AI-generated modern interpretations, **not reproductions of any authenticated ancient character portrait or manually copied modern book image**. That provenance reduces direct-source-copy risk but **does NOT guarantee freedom from copyright, trademark, trade dress or substantial-similarity claims**. Slight color changes or adding ornaments do NOT cure an otherwise infringing image; do not claim "copyright-safe" or "exclusive" without review.

Before publishing: preserve generation prompts/source records and exported file hashes, perform commercial reverse-image/similarity research against prominent child-safety app icons and modern Madalasa/Alarka illustration works, check India's trademark class/name/icon similarity and applicable licensing/AI-service terms, request qualified IP/legal review, and test small-scale icon distinctiveness. If a material resemblance is identified, commission a genuinely different custom face composition/pose and background—not a token alteration—and regenerate/update **all** Play, Android, website assets and Figma. Current artwork remains **launch candidate only**, with existing abstract-logo archive available as fallback. No verified infringement has been identified by the current checks, but no exhaustive clearance was performed.
