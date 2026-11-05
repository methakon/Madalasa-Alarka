# Free V1 integration checkpoint — 2026-11-04 UTC

Status: PARTIAL; no production deployment or public child-data release.

## E-03 integration

- Synchronized head: `1c004147601a04c1ef5b26471e302ef72b8fa367`.
- Sync baseline: main `8cf6953f31f22d8521c8e7e9e4afd8af722c41e2`, dev `3c0359b010a46b648860962f69987334db590a34`.
- Conflicts resolved per identity: E-01/0025 unchanged, E-03/0026+0027 preserved; every existing manifest entry/SQL checksum verified.
- `reset && migrate && test`: exit 0, 337 tests, OK (10 skipped).
- `tools/database/build_backend.py`: exit 0, production synthetic auth OFF, 24/24 CTests.
- `integration_device_ingestion_v2.py .local-db/build/ma_backend --evidence .local-db/e03-current-http.json`: exit 0, 11/11 HTTP checks, fixture cleaned, process stopped.
- CI: https://github.com/methakon/Madalasa-Alarka/actions/runs/41884679811 (API), https://github.com/methakon/Madalasa-Alarka/actions/runs/41884679881 (local checks), https://github.com/methakon/Madalasa-Alarka/actions/runs/41884679830 (route): SUCCESS.
- PR #36 merged to dev: `10c97210d9818de0117eadda070cd358b92d8a52`.
- Cumulative exact dev replay: exit 0, 337 tests, OK (10 skipped).
- E-03 remains PARTIAL: synchronous raw+receipt path does not meet the durable inbox ADR.

## E-04 review corrections (PR #37 merged)

Source review found explicitly held batch/session IDs outside 0028's limited hold subject list. Four behavioral regressions reproduced incorrect erasure/restore certification. A separate additive compatibility migration installs BEFORE DELETE guards on every existing physical erasure inventory relation. Held UUID row IDs/references and global holds fail closed; review dates never release holds. A second review identified stale snapshots: a two-connection REPEATABLE READ regression reproduced the bypass, then passed after a second additive migration rejected unsupported transaction isolation.

- Head: `285cb58be5460d87aef7a09aea79e78f7353a4a2`.
- New identities, in order after 0028: `compat:v2_0028_retention_hold_guard`, `compat:v2_0028_hold_snapshot_guard`.
- Published 0001–0028 and the already-pushed first guard remain byte-immutable.
- `reset && migrate && test`: exit 0, 352 tests, OK (10 skipped).
- Production-build DeviceBearer HTTP rerun: exit 0, 11/11.
- Python compileall / secret scan / diff check: exit 0.
- Exact-head hosted CI: PASS. API run https://github.com/methakon/Madalasa-Alarka/actions/runs/41890254178; local checks https://github.com/methakon/Madalasa-Alarka/actions/runs/41890254172; branch route https://github.com/methakon/Madalasa-Alarka/actions/runs/41890254202.
- PR #37 merged to dev as `3b4d3a658a2f4a7dab5773c97cd1009fde286225`; cumulative exact dev replay exit 0: 352 tests OK, 10 skipped.
- Legal hold protection is deliberately conservative. No category TTL or release authority is invented. External deletion and backup acceptance remain incomplete.

## Guardian integration (PR #38 merged)

- Synchronized head `7d69b51107bd4cde412ee6355f1bea18bb4983b6`: preserved both hold fences, all dev manifest entries, published 0029, and explicitly ordered guards after 0028/before 0029.
- Main baseline `8cf6953f31f22d8521c8e7e9e4afd8af722c41e2`; dev baseline `3b4d3a658a2f4a7dab5773c97cd1009fde286225`.
- Full head PostgreSQL replay exit 0: 367 tests OK (10 skipped); DeviceBearer HTTP 11/11 PASS.
- CI: https://github.com/methakon/Madalasa-Alarka/actions/runs/41892001584 (API); https://github.com/methakon/Madalasa-Alarka/actions/runs/41892001526 (local checks); https://github.com/methakon/Madalasa-Alarka/actions/runs/41892001552 (route): SUCCESS.
- PR #38 merged to dev as `255c5a33d22d85ea08038ff3d22016e799dd8460`; cumulative exact dev replay exit 0: 367 tests OK (10 skipped).
- Guardian powers/TTLs remain undecided. Live predicates remain essential: acquisition-versus-revocation can leave stale lease metadata; this is not demonstrated access authorization. Eager invalidation is not claimed exhaustive.

## Known skipped tests (all 10, not passes)

`test_m1_current_convergence.DatabaseContract`: isolated-DB authorization plus explicit DSNs required; no connections opened by these five tests:

- test_family_actual_issuer_session_and_cap
- test_held_and_unheld_artifacts_pending_dependent_and_audit
- test_issuer_renewal_real_interfaces_and_invalid_binding
- test_purge_invalid_intervals_and_pairing_hold
- test_runtime_cannot_assert_identity_or_write_holds

`test_reconciliation_credentials_media.FragmentSource`: reviewed scratch fragment absent from tracked tree; published 0019/0020 plus manifest checksum gate carry its guarantees:

- test_every_clock_function_is_replaced_additively
- test_media_exact_child_constraints_are_composite_and_non_cascading
- test_published_migrations_are_not_edited
- test_transaction_frozen_clock_is_gone
- test_types_signatures_owner_and_acl_are_untouched

## Remaining gates

### 2026-11-05 — parent PR #30 merged to `dev`; child fix pushed

- **PR #30 merged** (`parent` → `dev`) at head `80369579cf0be5afa5e85bd14ecb80610fa8a4dd`, merge commit `e761977eb22d4eed806ed042ab1e492f3f95305a`. Its earlier defects (late location responses restoring a revoked or superseded child, navigation silently defaulting to the first admitted child, premium detail benefits not rendered) are fixed and were cleared by an independent source review: generation plus actor/authority/child rechecks, explicit-child-only pairing and device actions, real `/location/history` six-hour contract with `has_more` treated as a limit rather than proof of more rows.
- **Cumulative `dev` replay after #30** — `reset && init && migrate && test` on `e761977`: **367 tests OK, 10 skipped**. The probe HTTP suite needs a built probe binary (`MA_PROBE_BINARY`); a rebuild inside that worktree was not possible because its vendored SDK prefix lacks SQLite3/c-ares, so the already-built probe from the sibling checkout was used and the gap is recorded here rather than papered over.
- **Child PR #31 fixes pushed** at `78e7d9211a0f5cb619e4c20883463b8677103a92` (first correction `fd672b6`, `11db7ff`): definitive consent denial (401/403/404/410) is a typed error that durably halts the queue and clears the credential, while 429/5xx/malformed/transport failures and an unavailable GPS provider pause and keep the encrypted queue. A second independent review then blocked `fd672b6` because `onLocationChanged` still revoked on a stale 15-second consent snapshot, which a stalled health call could turn into an unpair plus deletion of pending records; stale consent and waitlisted or unknown admission now pause, and only withdrawn consent, deletion or an explicit non-collection verdict revoke. `:alarka:testDebugUnitTest` **128 tests, 0 failures**; `:alarka:testReleaseUnitTest` **109 tests, 0 failures**; lab-debug **128**. APKs rebuilt — default-off `b0d46bea…`, lab opt-in `1d74bf0f…` (quiesced clean rebuilds; an earlier lab hash was discarded as unattributed after a concurrent worker was found building in the same checkout), androidTest `23c7a26c…` / `026323f4…`. Instrumented tests compiled only; **NOT_RUN** on any device; both application APKs still have no configured HTTPS origin.

Parent and child implementation still sits on `dev`/workstream branches only. Reviewer clearance is source-level: no HTTPS authorization end-to-end, no device matrix, no Android 10–16 runtime acceptance and no physical Keystore enrollment executed.

**PR #31 merged** (`child` → `dev`) at head `ca8b9c8e9837be3553383073e0095c2cd434ce5f`, merge commit `9d24f723ed9241791378a6064dde76a9ef4adf03`, after a targeted review cleared both blockers and a follow-up removed the last latent destructive shape: `forFixArrival` now derives its verdict from the consent snapshot (unknown pauses, a recorded denial revokes, staleness alone only pauses, a waitlisted child never collects). Cumulative `dev` replay after #31: **367 tests OK, 10 skipped**.

### Pairing proof blocker corrected; PR #40 review checkpoint — 2026-11-05

A disposable-DB production-build harness (`MA_SYNTHETIC_AUTH=OFF`, separate runtime/issuer logins) exercises the real parent→child pairing path. The initial ten-check failure below is superseded by **21/21 passing HTTP checks** after the corrections:

- **Fixed in `api` `ea88712` (`v2:0030`):** `POST /v1/children/{id}/pairing-codes` inserted into `pairing_codes` directly, but the V2 policy intentionally leaves the runtime role SELECT-only, so every genuine issue attempt returned `403` / SQLSTATE `42501`. Identification now goes through an executor-owned definer that revalidates trusted parent session, exact `PAIR_DEVICE` scope and free admission *after* the child lock, keeping the runtime table grant read-only. Enrollment moved to the separate issuer login with narrow expiry/profile grants.
- **Corrected in `api` `e824b0a`:** `POST /v1/enrollment/{id}/proof` previously rejected a correct P-256 signature with `401 nonce does not match challenge`. Drogon returns raw bytea, but a text-hex decoder corrupted stored nonce hashes and SPKI bytes. Enrollment and renewal now read binary fields directly. The next valid read exposed a separate LIMIT int4/bigint parameter mismatch (`08P01`), corrected with an explicit integer cast.

Current harness: **21/21 PASS**, including code issuance/redemption, genuine P-256 enrollment proof, bearer-bound committed ingest, guardian latest-location read-back and revocation, plus wrong-child, waitlisted, expired/replayed code, replayed proof and missing/wrong/revoked bearer negatives. `f474960` adds actual readiness tests: absent issuer → 503, distinct valid restricted runtime/issuer → 200; readiness checks required function privileges through both pools. CTest **25/25 PASS**; clean ordered database replay **367 tests OK / 10 existing skips**. Synthetic loopback evidence does not prove TLS, hardware Keystore, production Google identity or real-device acceptance.

[Draft PR #40](https://github.com/methakon/Madalasa-Alarka/pull/40) explicitly includes pairing/read fixes, synthetic load tools and x402 packaging, not E-01 alone. Its first exact-head CI (`32d0447`, run `41964135037`) passed the then-current 19-check harness. Review held merging for an unsafe privileged fixture generator and incomplete issuer readiness. Fixture guards now require explicit disposable authorization, private input, exact loopback/test-role/container identity and prior synthetic opt-in; the generator no longer enables authority. **17/17 load/fixture tests PASS** at `31378de`; updated-head CI and independent correction review remain pending. No deployment occurred.

**Open inherited engineering gap:** V2 credential renewal still uses the runtime pool and directly reads restricted challenge expiry. The binary correction alone does not repair that route. Separate issuer routing, a narrow expiry interface and real renewal/old-bearer rejection/new-bearer ingest acceptance remain required; runtime permissions must not be widened.

## Remaining gates

Historical parent/child review blockers and APK hashes are superseded by the #30/#31 integration entries above. Both workstreams are merged into `dev`; their lab artifacts still have no configured HTTPS origin. Source/build is not real-device acceptance.

Real-device matrix, HTTPS parent-to-child end-to-end pairing, physical Keystore execution, notification/permission/battery acceptance: NOT_RUN. No request for physical-device or VPS help yet. Main has documentation only; implementation promotion still requires cumulative dev verification and reviewed dev→main PR. No retention durations activated; SOS/media/payment release gates unchanged; 108-client prior benchmark remains synthetic DB-only evidence.
