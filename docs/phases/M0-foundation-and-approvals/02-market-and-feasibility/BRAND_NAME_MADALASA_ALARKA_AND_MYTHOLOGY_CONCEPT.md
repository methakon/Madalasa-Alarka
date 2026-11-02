# Madalasa & Alarka — Application Naming, Mythological Inspiration and Developer Brand Contract

> **Document control:** M0 / 02-market-and-feasibility · Proposed owner: Product + finance (not assigned) · Registry: DOCUMENTED_REVIEW_PENDING; approval not recorded. [Master register](../../../MASTER_DOCUMENT_CONTROL_REGISTER.md).

**Date:** 2026-10-26  
**Decision status:** Product/app display names **APPROVED BY OWNER REQUEST**; Google Play availability, trademark, Android package IDs, icon assets and publisher identity **NOT VERIFIED**.  
**Current GitHub repository name:** **`methakon/Madalasa-Alarka`** — owner-requested rename **COMPLETED AND VERIFIED** on 2026-10-26. The repository ID/history remains associated with the same GitHub repository; its previous name was `Amar-Pola`.

## 1. Product family and app names

| Surface | User-visible name (exact English spelling) | Role and purpose |
|---|---|---|
| **Parent/guardian Android application** | **Madalasa** | Family setup, verified guardians, secure child enrollment, available device observation, alerts, lawful child-purpose privacy controls, billing |
| **Child Android companion application** | **Alarka** | Transparent enrollment, device identity, on-device Android permission instructions, honest permission/health/synchronization states and child-initiated check-ins |
| **Connected service/product concept** | **Madalasa & Alarka** (or **Madalasa–Alarka Family Safety**) | Names of paired applications; neither app requires a religion, spiritual belief or faith assertion to use it |
| **Repository (rename complete)** | **`Madalasa-Alarka`** | **Verified active** at https://github.com/methakon/Madalasa-Alarka. Former name `Amar-Pola` is historical; commit and issue history preserved. |

**App launcher label:** “Madalasa” on guardian phone; “Alarka” on child phone.  
**Paired onboarding labels:** “Install Alarka on your child's Android phone”, “Open Alarka on the child phone”, “Pair Alarka with Madalasa”, “Continue with Google” in Madalasa (Google login remains a technical candidate; identity alone does not prove custody).  
**Internal API/DB/CI paths:** Keep existing stable backend paths and identifiers until a dedicated compatibility migration is approved. Renaming a brand does **not** authorize changing active identity, package IDs, applicationId, Firebase project, OAuth client, Play subscription product IDs, signing keys, token audiences, domain names or published store URL. Those are separate platform decisions.

## 2. English app concept — the story behind the names

### Madalasa and Alarka: Care, Foresight and Guidance Across Distance

In the **Markandeya Purana**, Queen **Madalasa**, wife of King **Ritadhvaja** (also rendered Ritudhvaja or Kuvalayashva), is remembered for educating her sons with wisdom, self-discipline and reflection. Her fourth son, **Alarka**, receives instruction about duty, leadership and the choices that sustain a good life.

As Madalasa and her husband prepare to retire to the forest, she gives Alarka a **ring containing a written message**, instructing him to read it if he later faces severe hardship. When Alarka encounters a grave crisis involving his brother Subahu and the king of Kashi, he remembers the ring, reads his mother's counsel and seeks the wisdom of **Dattatreya**. The story emphasizes the lasting value of a mother's guidance even when she is no longer physically beside her son.

**Our modern interpretation:** **Madalasa**, the guardian app, represents thoughtful parental care and informed responsibility. **Alarka**, the companion app on the child's device, represents a young person's safety, individuality and developing independence. Together, the apps seek to give families **truthful, permission-based information**, a way to stay in touch, and transparent support when they are apart — respecting the child's rights, dignity and privacy.

This is **a cultural and product-design inspiration**, not a claim that the original text describes smartphones, GPS, digital tracking or a technological mechanism for remote observation.

### Source accuracy / the “divine remote viewing” motif

Some modern retellings creatively evoke **yogic foresight, remote sight or an invisible protective shield** to describe Madalasa's maternal intuition. Those are **interpretive metaphors** for this product concept. In the checked English translation of the **Markandeya Purana, Cantos XXVI–XXVII and XXXVI–XXXVII**, the directly supported narrative describes her teaching Alarka, giving him a ring with written guidance, and his use of that message in distress. These passages **do not substantiate continuous supernatural remote viewing of his daily movements or mind**. Do not advertise a literal scriptural passage or divine power as if it described remote surveillance.

**Primary story references:**
- Markandeya Purana, Canto XXVI — the education and naming of Alarka: https://www.wisdomlib.org/hinduism/book/the-markandeya-purana/d/doc117059.html
- Canto XXVII — Madalasa's instruction to Alarka: https://www.wisdomlib.org/hinduism/book/the-markandeya-purana/d/doc117060.html
- Canto XXXVI — the ring and advice for future hardship: https://www.wisdomlib.org/hinduism/book/the-markandeya-purana/d/doc117072.html
- Canto XXXVII — Alarka in difficulty remembers the ring and seeks guidance: https://www.wisdomlib.org/hinduism/book/the-markandeya-purana/d/doc117073.html
- Translation reference: F. Eden Pargiter, *The Markandeya Purana* (1904). The ancient narrative has variant transliterations and retellings.

## 3. Why these names match functional responsibilities

| Narrative inspiration | Madalasa guardian app | Alarka child app | Important boundary |
|---|---|---|---|
| Madalasa's wisdom and foresight | Quality-aware, **last-observed** family information; explain uncertainty | Report observations only with actual Android and lawful purpose authorization | No magical “always live”/hidden tracking claim |
| Thoughtful preparation for future distress | Parent sees permission/connection reliability and clear check-in acknowledgements | Child can initiate a visible check-in and contact a trusted adult | No guaranteed emergency response until tested independent fallback |
| Ring carrying guidance | Parent gives clear **visible setup steps** and reviewable guardian permissions | Child receives an explicit setup/instruction flow on their own device | A paired code is not legal guardian verification; parent cannot grant OS permissions remotely |
| Alarka's independence | Scoped guardians and temporary grants, audit and deletion | Child transparency center and access information | The child is a person, not an object to be secretly watched |
| Support across distance | Privacy-aware family connection with real status timestamps | OS-governed, verifiable and revocable device participation | History and app-usage behavioural monitoring disabled for Indian minors pending separate legal review |

**Suggested optional marketing tagline (not approved final store copy):** “Thoughtful care. Honest connection.”  
**Alternative concept line:** “Inspired by a mother's lasting guidance; designed for modern family safety with transparency and choice.”  
Avoid “divine remote seeing”, “watch every step in secret”, “unbreakable protection”, “guaranteed rescue”, “track without knowing” and similar unsupported or unsafe claims.

## 4. UI/UX text and release specifications

- **Parent splash:** “Madalasa” and an optional small description, “Family Safety”. Primary: “I'm a parent or guardian” and “Set up Alarka on a child's device”.
- **Parent sign-in:** “Sign in to Madalasa”; “Continue with Google”; “Verify your authority to manage this child's device” separately when legally required.
- **Parent setup journey:** “Step 1 — Install Alarka”; “Step 2 — Pair Alarka securely”; “Step 3 — Review child-data purposes”; “Step 4 — Follow permissions on the Alarka phone”; “Step 5 — Check Alarka device status”.
- **Child splash:** “Alarka”; “Companion app for visible, authorized family safety setup”; “Who can access my information?”.
- **Child permissions:** “On this phone, open Android Settings”; report GRANTED/DENIED/UNSUPPORTED/OS_REJECTED based on actual OS state; do not claim that Madalasa changed these permissions remotely.
- **Parent dashboard:** “Children” labels are ordinary generic concepts; “Alarka” is the **app**, not the child's name, account display alias, or a claim every enrolled child is Alarka.
- **App switch / pairing:** “Alarka device” is the child-device endpoint; authenticated paired Madalasa guardian accounts can read only approved child scopes.
- **Store descriptions and Data Safety:** use app names with separate app roles and accurate declared data flows; do not claim guaranteed background tracking, emergency dispatch or remote camera/mic bypass.
- **English is canonical spelling for developer strings:** Madalasa / Alarka. Sanskritized forms Madālasā / Alarka and Bengali/other script localization can be added via Android \`strings.xml\` translations without changing English brand IDs.
- **App icon and imagery:** cultural motif may reference a ring or guiding light **abstractly**, but avoid inventing a religious endorsement, depicting a specific deity as a tracker, or demanding religious affiliation of users. Logos, trademarks and publication assets require independent validation.

## 5. Developer migration checklist and unresolved public-release matters

**Brand naming and repository rename outcome:** The requested user-facing names and new GitHub repository name are **in effect**. Android package IDs, app binaries, signing keys and Play product IDs have not been created/renamed as part of this documentation change. Plan an independently reviewed Android implementation migration:
1. Separate Gradle app modules \`parent-android\` and \`child-android\` (or chosen names); launcher strings use **Madalasa** and **Alarka**.
2. Choose **two unique immutable application IDs** **before first Play upload**. Example placeholders may be \`<approved.domain>.madalasa\` and \`<approved.domain>.alarka\` only after publisher domain approval; **do not use a guessed owner domain**.
3. Establish parent OIDC OAuth app identity, Alarka Android Keystore enrollment identity, matching package signature pinning and Google Play Console app declarations. Never assume changing display label changes authorization/crypto.
4. Android parent-to-child walkthrough and any FCM/SMS notifications use actual brand strings; capability and OS notification disclosure identify **Alarka** explicitly on the child's device.
5. Update parent/child Figma screen titles and linked Eraser/tldraw visuals during next connected visual-design sync. **Existing saved visual canvases still contain legacy “Amar-Pola” text**, since documentation changes do not automatically update Figma/Eraser/tldraw. Their current links remain valid.
6. Google Play listings and legal notices must name the correct publisher and app separately, and cover India DPDP child-age, purpose, storage/processor, deletion and grievance rules.
7. Check name availability/trademark/IP and pronunciation; approved publishing name and support URL still open (B-01/B-02).
8. **Repository rename is complete and new URL verified**: `https://github.com/methakon/Madalasa-Alarka`. For local clones update remote via `git remote set-url origin https://github.com/methakon/Madalasa-Alarka.git`. Check CI badges, webhooks and connected app references; keep M1 API, crypto and package identifiers stable.

## 6. Documentation precedence and scope

This naming and narrative policy **supersedes older use of “Amar-Pola” as a consumer application title** in the README, SRS, technical specs, architecture diagrams, onboarding and Play/privacy drafts. **The GitHub repository was renamed `Madalasa-Alarka` on 2026-10-26** and is active at the verified new URL. Filenames, package IDs, database and OpenAPI identifiers remain stable unless explicitly migrated. When an old file says “Amar-Pola Parent App”, read **Madalasa**. When it says “Amar-Pola Child App”, read **Alarka**.

**The design remains a transparent, legally constrained family-safety product. Naming inspired by mythology does not change the Android security model, children's consent and privacy duties, or the product's approved feature set.**


## 2026-10-28 visual narrative decision: Theme C — পুরাণের চিত্রকথা

Owner selected an original pan-Indian classical Markandeya Purana–inspired illustration style for story introduction and Madalasa parent screens. The five-page source-aware narrative follows Madalasa's teaching, Alarka's responsibilities, adult Alarka receiving the ring on becoming king, his later distress and message, and guidance from Dattatreya. See [canonical story/UI design contract](../../../ui/MADALASA_ALARKA_THEME_C_STORY_AND_UI_CONTRACT_2026.md) for wording, literary chapter references and Figma mapping. Ring is remembrance and wisdom, **not a supernatural tracking or surveillance metaphor**. Culture/religion participation cannot be required for app use, permissions or pricing. Art is interpretive, not a literal historical portrait; preserve child rights and platform safety constraints.



## Authoritative owner correction — 2026-10-28 (overrides any earlier regional/language wording)

**Source & visual identity:** Madalasa and Alarka belong to the **Mārkaṇḍeya Purāṇa** narrative, part of a pan-Indian Sanskrit Puranic tradition. Do **not** describe the narrative or the project's theme as a Bengali regional folk tale, or position regional patachitra as its required style. Chosen Theme C means an **original pan-Indian Puranic illustrated storybook**—classical manuscript/miniature/mural influences without claiming historical authenticity or monopolizing any one regional tradition. Original lotus, ring, tree and court/forest motifs are optional decorative inspiration; all monitoring UI remains modern and clear.

**Launch language is ENGLISH ONLY:** English headings, body copy, app controls, trial/banner, billing, child transparency and story pages. **No Bengali script and no language selector** in current prototype/release screens. Future multilingual enhancement remains planned technically (resource-keyed UI strings, flexible components, Unicode/font fallback, locale-safe dates/numbers, translation QA), but translated screens/content must not be implied ready or implemented.

**Preserve the user-provided screenshots and prior feature discussion:** See [reference workflow register](../../../ui/REFERENCE_SCREENSHOTS_FEATURE_WORKFLOWS_2026.md) (relative link should be resolved from docs/ui when applicable). These supplied third-party screenshots are **functional references only**, capturing map/satellite style selection, collapsible/expanded dashboard, parent/child enrollment, place-specific toggles, timeline, route segments, quota-based sound, usage charts and managed-only restrictions. Copy neither imagery nor exact UI. Do not treat inferred third-party capabilities as certified Madalasa features.


## Launch-language and source clarification — 2026-10-28

**Madalasa–Alarka is based on the Markandeya Purana's pan-Indian narrative, not on a regional Bengali folk tale.** UI, story onboarding and screenshots are **English only in this launch stage**. No Bengali text or language switcher appears in current released designs. Future multilingual support remains an architectural extension: translation keys in Android resources, layout growth and Unicode/fonts, locale-aware dates/amounts, reviewed translations and optional user language settings when implemented. Theme C art remains original pan-Indian Puranic illustration; it never changes child-monitoring permissions, Android/Play feasibility, or the underlying commercial terms. Feature behavior inspiration from the user-supplied screenshots is captured at [Screenshot functional workflow register](../../../ui/REFERENCE_SCREENSHOTS_FEATURE_WORKFLOWS_2026.md), without copying competitor designs.


## 2026-10-28 — New approved-for-review icon and logo assets (not Play approved)

**Figma editable vector components:** [Madalasa parent icon](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=68-164), [Alarka child icon](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=68-173), [family/website icon](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=68-179). [Editable website wordmark](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=70-164), [Madalasa Play feature graphic](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=70-200) and [Alarka Play feature graphic](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=70-213). All branding is original geometric illustration inspired by the pan-Indian Markandeya Purana narrative, **not Bengali folk art**, and English-only. No claim of supernatural monitoring, Google approval or operational app release.

**GitHub deliverables:** [master brand source and instructions](https://github.com/methakon/Madalasa-Alarka/tree/main/branding), [individual Play-ready candidate icons and graphics](https://github.com/methakon/Madalasa-Alarka/tree/main/branding/play-store), [Madalasa Android resources](https://github.com/methakon/Madalasa-Alarka/tree/main/android/madalasa/src/main/res), [Alarka Android resources](https://github.com/methakon/Madalasa-Alarka/tree/main/android/alarka/src/main/res), [website wordmarks and favicon assets](https://github.com/methakon/Madalasa-Alarka/tree/main/public/brand). Two 512×512 PNG candidates, two 1024×500 opaque JPEG Play graphics, adaptive 108dp vector layers + monochrome icons, five density variants per app, website 32/180/192/512 PNGs, SVGs, social preview and manifest were committed. [Detailed dimensions, placement and manual release gates](https://github.com/methakon/Madalasa-Alarka/blob/main/branding/README.md). Google Play and Android/OEM validation, publisher/trademark checks and actual AndroidManifest integration remain required.
