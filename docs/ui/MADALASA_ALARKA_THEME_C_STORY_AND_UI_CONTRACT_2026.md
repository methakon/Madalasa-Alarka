# Madalasa–Alarka — Theme C: Illustrated Markandeya Purana | Storybook + Android UI Contract

**Status:** Owner-selected visual direction on 2026-10-28; UI/illustrations are design prototypes, NOT Android implementation or legal/Google Play approval. **Scope:** Madalasa (parent) and Alarka (child), onboarding + parent-core views. Existing 81-screen Figma handoff is retained; new Theme C demonstration screens are progressive visual migration, not evidence that all 81 are redesigned.

## 1. Authentic literary basis and boundaries

Primary narrative: Mārkaṇḍeya Purāṇa, Madālasā/Alarka episodes, especially **Canto XXVI (naming/education of the four sons), Canto XXXVI (ring and parting counsel), and Canto XXXVII (Alarka's difficulties, reading the ring, Dattātreya)** in F. Eden Pargiter's English translation (1904).
- https://www.wisdomlib.org/hinduism/book/the-markandeya-purana/d/doc117059.html
- https://www.wisdomlib.org/hinduism/book/the-markandeya-purana/d/doc117072.html
- https://www.wisdomlib.org/hinduism/book/the-markandeya-purana/d/doc117073.html

**Interpretation, not scripture quotation:** Madalasa is a mother and teacher; Alarka is raised with worldly responsibilities and later recalls her counsel; the ring is a mnemonic token containing written advice about wise association and detachment. Do not claim the Purāṇa depicts GPS tracking, emergency dispatch, a magical protection ring or an omniscient mother. Do not show the ring being handed to a small child: it is given around the transition to kingship. Do not depict Dattātreya as Madalasa. Historical imagery is **interpretive**, not an authentic visual portrait.

**Cultural inclusion:** app is usable without religious affiliation; every decorative element is optional and does not change functionality, terms, consent, pricing or emergency status. English is the only user-facing language at launch; plan future translation support without showing language selection yet.

## 2. Theme identity: selected Theme C — Illustrated Purāṇa

- Storybook direction: pan-Indian classical Puranic manuscript/miniature/mural-inspired **original** hand-painted-style scenes on subtle handmade parchment; floral/lotus/tree ornament, restrained architectural cues; no competitor screenshot tracing, no copied religious artwork.
- Design tokens (provisional, contrast to be device tested): parchment #FFF7E7; ink #292A31; vermilion #B73527; deep indigo #233F69; turmeric gold #E7B44A; teal #28756C; leaf green #5B784B; pale warm surface #F7F1E8; critical red #BA2937.
- Parent work screens: predominantly off-white/parchment neutral and high-contrast data; decorative header/bottom trim only, not on maps or usage charts; avoid low-contrast textured text areas.
- Components: 390×844 dp planning preview; 8dp grid, 16–20dp horizontal padding, 12–20dp card radius, 48dp minimum tap targets, scalable typography, reduced-motion mode, text never baked into artwork.
- Brand motif: one original lotus-and-ring emblem in story and plan status. A ring signifies **remembered guidance**, NOT location capture.
- Type: use a legible Latin UI font and an optional classical display serif; externalize English strings for future translations, never bake text into art. In Figma use editable TextNodes, fonts may be temporary fallbacks until installed/tested.
- App logo/feature iconography original and semantically legible, not replicas of another tracking app.
- Map: functional cartography retains standard legal provider labels; do not repaint tiles into fake art or remove attribution. Do not obscure accuracy, last-seen, revoked permission, SOS, or provider controls.

## 3. Five-page story introduction (ST-01 to ST-05)

User can Skip, move Back/Next, and later find "Our inspiration" under About. **English only for the initial release; no language picker yet.** No collection or child device registration merely from reading. Each passage is **short original paraphrase**, not a direct Purāṇa quotation.

| Page | English heading | On-screen short copy (English) | Original illustrative subject |
|---|---|---|---|
| ST-01 | A Mother's Wisdom | Madalasa raised her sons with thoughtful guidance, encouraging understanding beyond fear and pride. | Mother Madalasa speaking to her children in a tranquil royal courtyard; warm dawn and lotus vines |
| ST-02 | Alarka's Responsibility | For her youngest son Alarka, she also taught the duties of family life and just leadership. | Madalasa instructing young Alarka beside a palm-leaf manuscript and garden |
| ST-03 | The Ring of Counsel | When Alarka became king, Madalasa entrusted him with a ring holding counsel for difficult times. | Adult royal Alarka receiving small gold ring from Madalasa; clear distinction from magical artifact |
| ST-04 | Remembering Her Words | In adversity, Alarka remembered his mother's words and read the message inside the ring. | Adult Alarka quietly reading a small written note during a solemn night; nonviolent illustration |
| ST-05 | The Path to Wisdom | Guided by that counsel, Alarka sought insight from Dattatreya and reconsidered the nature of his difficulties. | Adult Alarka respectfully consulting Dattatreya in a quiet woodland teaching setting |

Controls: progress 1/5…5/5, Skip (do not block enrollment), Back, Next, Finish → parent setup. Optional "Source & interpretation" link opens literary references above, avoiding invented quotations. No coercive push to subscribe.

## 4. Theme C screen mapping and feature contract

| Screen | Old handoff | New Theme C treatment | Mandatory product behavior |
|---|---|---|---|
| Welcome/story | P-01 + new ST-01..05 | Character art, bottom parchment text panels, 5 dots | Skip/replay, readable languages, no consent implied |
| Dashboard & map | P-05, P-07, P-22 | Calm map, avatar marker, ring/lotus crest and compact bottom sheet | Last observed time + uncertainty, current permission status, no fake real-time |
| Daily history | P-15, P-23, P-24 | Warm cards, mode-colored route segments and timeline | Route gaps, observed vs inferred; free history last 6h |
| Places and alert toggles | P-26–P-28, P-50 | Original place symbols and clean rows with native toggles | Per-child, per-place enter/exit alerts, debouncing; unknown/late state |
| Family enrolment | P-06, P-09, P-16, P-39 | Two parent/child entry cards, safe single-use QR flow | Sharing app != invitation != pairing; child grants separate |
| Device usage | P-31, P-32, P-35 | High contrast charts, category labels, clear gated badges | No standard-mode universal app blocking |
| Trial & media | P-18, P-46–P-49, P-57, P-58 | Compact icon and free time balance; no full-screen sales banner | 48h once verified; media OFF until OS/legal/Play tested |
| Billing & account | P-44, P-47–P-49, P-54 | Prepaid plan cards, public/founding price, clear expiration states | No auto-renew, Google Play confirmed purchase; deletion not gated |
| Child Alarka | C-01, C-02, C-12 | Simpler, calming decorative trim only | monitoring transparency and actionable OS permissions |

## 5. Trial badge acceptance

- Active: compact 48–64dp banner or pill **“✦ Super Access · 47h left”**, a clearly labeled X close; no continuous flashing. Do not cover map pins or emergency controls.
- Dismissed: no forced reappearance on screen transitions in current session; status accessible through account or plan; next app launch may show compact notice.
- Source of truth: verified backend server expiry, not client timer; re-registration/reinstall does not reset eligibility when lawfully recognizable.
- Trial quotas per child across 48h: 5min audio/2min video/3 photos/2min screen. Paid Balanced monthly: 60min audio/20min video/30 photos/10min screen (session caps per approved commercial addendum). **All conditional** and unavailable when media flag OFF.
- At trial/prepaid expiry: no auto charge, free live tracking at reduced adaptive GPS target, six hours of visible history (NOT indefinite permission to store prior child location). Paid purchase requires explicit Play confirmation.
- No ads, reward manipulation, hidden purchases, claims of unrestricted mic/camera, flashing or inaccessible ornament.

## 6. Figma build order and QA

1. Preserve archival 81 screens and earlier theme previews.
2. Create **new Theme C stage** of editable phone frames for ST-01…05 and core parent samples; prefer Figma's native frame, auto-layout, text, component and style features. Illustrated art can be raster in **dedicated illustration region only**; whole screen cannot be flattened.
3. New screen frames link back to old IDs (P-05 etc), keep acceptance/security details below or in GitHub structured JSON.
4. Verify Figma element IDs, dimensions, no overlap/overflow, source/failure labels, responsive text/contrast, touch sizes, old screens not deleted.
5. Future work: migrate 81 handoff screens and 21 child screens deliberately in phases; not claim done until verified.
6. The Theme C concept rendering approved by owner is visual inspiration, NOT a pixel-spec, branded map asset, published art or implementation.

**Document control:** English-only initial UI and pan-Indian scripture direction approved by owner; artwork, future professional localization, Android assets, legal/India child-data permission, live media and billing remain review gated.


## Verified Figma Theme C stage — 2026-10-28

**Actual editable Figma file:** [FUNCTIONAL HANDOFF • All Screens](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=6-2). **Readback QA:** original **81** P/C functional handoff tiles remain present; **14 NEW** Theme C phone frames added alongside them (5 story + 9 functional). Each uses Figma frame/auto-layout/text/shape controls; story panels embed **three Figma AI-generated original illustrations as image fills only**, with text/buttons separately editable; assets have dedicated off-screen positions on archival Page 1. The new sample UI is STATIC, navigation/close/toggles are not runnable, and no backend/Android implementation is implied. Screen heights fit 390×844 with no detected vertical content overflow. English screen headers are editable Figma text; Android typography and contrast need device validation. Future localization remains a separate scope.

**Story links:** [ST-01 teaching](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=46-164) · [ST-02 Alarka](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=46-177) · [ST-03 ring](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=46-190) · [ST-04 remembrance](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=46-203) · [ST-05 wisdom](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=46-216).

**Functional links:** [P-05 home/map](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=52-164) · [P-15 timeline](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=52-192) · [P-24 trip](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=52-212) · [P-28 places](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=52-237) · [P-39 family](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=52-263) · [P-48 prepaid](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=52-281) · [P-58 audio gate](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=52-303) · [P-31 usage gate](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=52-317) · [C-02 child disclosure](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=52-337).

[Exact machine-readable 14-screen node IDs and implementation association](figma-functional-handoff/09-theme-c-story-and-screens.json). Original `Po5FqFQQIfttFLrjO5qqvE` trial-design file is an earlier styling exploration, now superseded by this Theme C stage, not deleted. **Still required:** real map provider tiles/attribution, device integration, reusable Compose components, Android feature tests, bilingual QA, true dismissal/countdown behavior, Play prepaid offers, legal/security review, and systematic restyling of remaining 81 handoff screens.



## Authoritative owner correction — 2026-10-28 (overrides any earlier regional/language wording)

**Source & visual identity:** Madalasa and Alarka belong to the **Mārkaṇḍeya Purāṇa** narrative, part of a pan-Indian Sanskrit Puranic tradition. Do **not** describe the narrative or the project's theme as a Bengali regional folk tale, or position regional patachitra as its required style. Chosen Theme C means an **original pan-Indian Puranic illustrated storybook**—classical manuscript/miniature/mural influences without claiming historical authenticity or monopolizing any one regional tradition. Original lotus, ring, tree and court/forest motifs are optional decorative inspiration; all monitoring UI remains modern and clear.

**Launch language is ENGLISH ONLY:** English headings, body copy, app controls, trial/banner, billing, child transparency and story pages. **No Bengali script and no language selector** in current prototype/release screens. Future multilingual enhancement remains planned technically (resource-keyed UI strings, flexible components, Unicode/font fallback, locale-safe dates/numbers, translation QA), but translated screens/content must not be implied ready or implemented.

**Preserve the user-provided screenshots and prior feature discussion:** See [reference workflow register](REFERENCE_SCREENSHOTS_FEATURE_WORKFLOWS_2026.md) (relative link should be resolved from docs/ui when applicable). These supplied third-party screenshots are **functional references only**, capturing map/satellite style selection, collapsible/expanded dashboard, parent/child enrollment, place-specific toggles, timeline, route segments, quota-based sound, usage charts and managed-only restrictions. Copy neither imagery nor exact UI. Do not treat inferred third-party capabilities as certified Madalasa features.


## Superseding design clarification — 2026-10-28

Theme C now means an **original, pan-Indian Markandeya Purana–inspired illustrated storybook**, NOT a Bengali regional folk theme. **English-only screens at launch**: story headings/body, trial notices, map, family, billing, child transparency and controls. No Bengali text or language chooser in current UI; plan future internationalization using external strings, flexible layout, Unicode/font fallback and professionally reviewed translations. Screenshot workflow requirements remain retained in [Reference Screenshot Functional Workflow Register](https://github.com/methakon/Madalasa-Alarka/blob/main/docs/ui/REFERENCE_SCREENSHOTS_FEATURE_WORKFLOWS_2026.md): live map/map style, collapsible quick actions, family enrollment, per-place toggles, route and activity timelines, usage reporting, quota media UI and gated managed controls. The user-supplied screenshots inform behavior, never copied art/icons/layout or promises of restricted capabilities. Existing legal/Android/Play and prepaid gates unchanged.
