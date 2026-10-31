# Android screen-design completion and 7-day inactivity policy — execution addendum

**Snapshot:** 2026-11-01. **Scope:** local/synthetic development only. **Status:** source exists; full design/compilation QA and runtime sampling implementation pending. This extends, rather than renumbers, the immutable 262-task base DAG and the separate Figma gap backlog. The canonical task ledger remains unchanged per-task until acceptance evidence is recorded.

## Observed repository checkpoints (not blanket PASS)

| Workstream | Evidence in GitHub | Actual status |
|---|---|---|
| Android Gradle scaffolds | `main:android/settings.gradle.kts`, `android/gradlew`, both app modules and `:ui-common` | SOURCE_PRESENT; independent clean build proof pending |
| Parent screen source | `parent@8353ab68`: 60 P-01..P-60 composables and dispatcher | SOURCE_IMPLEMENTED_INITIAL; screen-specific fidelity, navigation integration and build pending |
| Child screen source | `child@8dfe335c`: 21 C-01..C-21 composables and dispatcher | SOURCE_IMPLEMENTED_INITIAL; fidelity/navigation/build pending |
| Shared design catalog | `parent@9d6aee1` and subsequent parent commits | 81 JSON handoff entries translated to UI-only catalog; no runtime backend claims |
| Backend ParentOIDC bridge | merged PR #16 https://github.com/methakon/Madalasa-Alarka/pull/16 | CODE_MERGED; real provider integration/release tests pending |
| Inactivity-adaptive tracking | M2 2026-11-01 policy and tracking contract cross-reference on main | DESIGN_ONLY; not implemented |

**Important:** Many initial screen layouts are template-derived from each record's `hero`, `ui`, `action`, `rule`, `api`, `error`, and acceptance description. This is not proof of faithful Figma layers, illustrations, strings, state variants or UX. Never report 81/81 pixel-matched screens. Current PRs and external branch commits are not automatically in main.

## Worker execution order — workstream branch rules

Follow `AGENTS.md` and `docs/phases/M1-secure-platform-foundation/02-development-process/BRANCHING_VERSIONING_AND_RELEASE_PROCESS.md`. Workstream branches (`parent`, `child`, `api`, `admin-web`) target `dev`; `dev` is reviewed/integrated into `main`. Canonical `docs/**` edits go on `main` only. Start with clean checkout and `bash docs/tools/sync_work_branch.sh <branch>`; re-inspect current SHAs and overlapping worker files before writes. Avoid mass merges, force pushes, and false CI results.

### UI-01 — Parent compilation & dispatch (parent)
- Confirm all 60 P-screen composables and existing app navigation compile with pinned toolchain; make initial Figma gallery/debug routes **debug-only**, explicitly not production entry points.
- Connect 60 screen destinations into a typed *design-preview* navigation system; no API calls, no synthetic success claims and no permission activation.
- Add JVM tests that all 60 IDs resolve and debug navigation cannot cross from child actor.
- Provide clean Gradle unit-test/build exit codes and redacted logs; obtain PR `parent → dev`.

### UI-02 — Child compilation & dispatch (child)
- Synchronize after shared library is integrated, verify all 21 C-screen composables and child shell compile.
- Add 21 debug-only design routes with visible transparency state, no monitoring activation.
- Test all C-IDs, unsupported IDs, offline/denied/unknown states, accessibility labels; PR `child → dev`.

### UI-03 — True Figma design implementation (parent/child independently)
- For each screen compare actual Figma frame and developer description to Kotlin component tree: artwork only as decoration, typography, 8dp spacing, minimum 48dp targets, safe scroll, 390x844 preview, small screens, text scaling, dark/eco handling.
- Replace template-derived generic rows with screen-specific controls and layouts; never simulate live child location, permissions granted, paid eligibility, emergency acknowledgements or successful remote capture.
- For every screen document intended navigation edge, API/DB contract, OS/legal gate, unknown/loading/denied/error/offline states and TODO(INTEGRATION) where actual runtime code will later connect.
- Capture a screen-level verification matrix of P-01..P-60 / C-01..C-21 with screenshot path, frame ID, reviewer, actual result, defects, commit SHA and next action. Do not mark VISUAL_PASS without screenshots and comparison.
- Theme C 5-page story ST-01..ST-05 are additional requirements outside the numbered 81; document separately and do not falsely count them as completed.
- Obtain security review for design claims and a11y verification; only then promote PR(s) to dev and main.

### LOC-01 — Backend engagement and policy (api)
- Implement authenticated human-foreground family/child-scoped engagement receipt; require V2 trusted parent session, validate membership/grants, dedupe/rate limit, server UTC clock; never accept client claims of paid tier.
- Add versioned FREE_ACTIVE, PAID_ACTIVE, FREE_INACTIVE, PAID_INACTIVE profiles; transition at 168 hours. Resolve cross-family viewer activity without leaking parent IDs; retain conservative UNKNOWN_ENGAGEMENT.
- Use verified billing entitlement and consent; policy device-bound, tamper-evident, expiry-checked, monotonic versioned and auditable; full RLS and revocation negative tests.
- Suggested inactive moving targets: free 20min, paid 5min. Stationary free 60min, paid 20min. Tunable under policy bounds; requested, not guaranteed.

### LOC-02 — Alarka policy reducer (child; depends LOC-01 contract)
- Pure Kotlin policy selector with fake signed payloads and permission, consent, lifecycle, battery, motion and OS eligibility as inputs.
- Do not implement actual background capture until approved gates and test-device eligibility. Revocation must always win over increased frequency or subscription.
- Test 167h59 vs 168h, stale policy, clock skew, offline, duplicate policy, paid expiry, emergency exception, permission denial and OS start rejection.

### LOC-03 — Madalasa foreground event/UI (parent; depends LOC-01 contract)
- Emit event only for visible authenticated resumed Activity; server validates scope and cadence. Opening UI alone must not initiate GPS capture.
- Clearly show stale last-location timestamp, accuracy and reduced update mode. Returning to app restores active policy only after child acknowledgment; no false LIVE state.
- Add synthetic navigation/UI reducer tests.

### LOC-04 — integrated evidence (dev)
- Compile and test both Android apps, API and V2 PostgreSQL integration. Run privacy/security negative tests.
- Compare actual delivered frequencies/battery on lawful adult-owned laboratory devices before assertions about rate or 48-hour queue capacity.
- Reconcile Play/Families/background-location and child monitoring disclosures; no release claims before official review.

## Evidence and task accounting

Use `docs/roadmap/AGENT_EXECUTION_AND_TEST_EVIDENCE.md` for exact task evidence, actual SHAs, executed command/exit status, environment and fixture IDs. Individual `Lxx-xxx` statuses remain NOT_STARTED in `LOCAL_TASK_EXECUTION_STATUS.json` until individually evidenced; the new workstream checkpoints clarify progress without bypassing DAG prerequisites. These addendum IDs are supplementary checkpoints, not a fabricated change from 262 to a new base task count.

**Next worker instruction:** Complete UI-01, UI-02, then UI-03 screen-by-screen. Implement LOC-01/02/03 only after design handoff and respective security/OS/legal gates, independent of screenshot verification where dependencies permit.

## EMAIL-01..06 — New prepaid reminder and support-mail workstream (2026-11-01)

**Design and sender allocation:** [Transactional mail templates](../phases/M7-commercial-integrations/01-commercial-plans-and-costing/EMAIL_LIFECYCLE_AND_SUPPORT_TEMPLATES_2026-11-01.md). MAIL-01 verifies transport/domain/inbound mailbox; MAIL-02 renders 11 template IDs in safe HTML+text; MAIL-03 schedules T−30d, T−7d, T−24h, T−9h, expiry T, T+24h, T+7d with verified entitlements and atomic free fallback; MAIL-04 supports verified two-way threaded tickets; MAIL-05 provides negative and idempotency tests; MAIL-06 covers legal/provider/staffing release gates. **All six are DOCUMENTED_NOT_IMPLEMENTED**; they do not count as PASS in the 262-task base DAG. Backend mail services belong to `api`; admin/support UI integration uses `admin-web`; canonical documentation changes only on `main`. Do not commit `.env` or credentials.

## 2026-11-01 email and artwork checkpoint

Eleven branded HTML and text email template pairs exist at email/templates/ plus a manifest (commit c611dfaf). Outbound email test success is worker-reported; mail schedule, actual rendered template delivery and inbound replies remain unverified. Figma AI produced a candidate original Theme C family-safety illustration at node 144:2 in the existing Figma file: https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=144-2 . Illustration generation does not imply Android asset placement, screen integration or visual PASS. Keep statuses TEMPLATE_SOURCE_PRESENT and ARTWORK_GENERATED_NOT_ANDROID_INTEGRATED.

## ADMIN-STACK-01..06 — Approved frontend stack migration (2026-11-01)

Owner approved **Drogon server-rendered HTML/CSS + HTMX + Alpine.js CSP-compatible distribution**, superseding prior UI technology TBD; React/Vite prototype remains existing source pending validated replacement. Follow [Admin frontend stack ADR](../phases/P3-deferred-research/01-media-and-administrator-research/ADMIN_FRONTEND_STACK_DECISION_2026-11-01.md) for freeze/inventory, secure template/fragment foundation, all Figma BO screens, auth/FAQ/support/billing integration, adversarial tests and reviewed promotion. Status DECISION_APPROVED / IMPLEMENTATION_PENDING; base DAG tasks not falsely passed.

## 2026-11-01 — UI artwork and support screen implementation checkpoint

- Parent: native scalable Theme C vector illustration `ThemeCArtwork.kt` integrated into the reusable hero panels across P-01..P-60 on `parent`, commit `ffa4f23a4d4e350dfb12baa361c90074160d0993`.
- Child: corresponding vector artwork integrated into C-01..C-21 on `child`, commit `c0e2133cdf19ed99c13ac6519821d0f36ef891c6`.
- These are functional native vector motifs; **detailed Figma AI raster artwork has not yet been exported and placed as Android drawable assets**. Exact screenshots/device builds are not verified, so do not mark comprehensive artwork/visual QA PASS.
- Support: AI-generated illustration directly in Figma at node [145:2](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=145-2); three **editable Figma** two-way support designs at page [146:2](https://www.figma.com/design/TKiZXwjkWdkponF1zNsfli?node-id=146-2): SUP-01 inbox, SUP-02 conversation, SUP-03 new request.
- Support HTML/CSS static screen implementation committed on `admin-web` at `admin-web/htmx-migration/support/`, commit `3484cd06aaa1d4601ee44e2af5551315de537b6f`. This is **NOT** authenticated or connected to real tickets, email replies, or HTMX/Drogon handlers. Actions are deliberately disabled and examples synthetic. Next: secure Drogon server templates, HTMX fragments, actual API/inbound threading, redacted E2E tests and Figma screenshot parity.
