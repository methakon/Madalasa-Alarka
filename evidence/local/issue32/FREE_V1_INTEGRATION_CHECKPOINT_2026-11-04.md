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

Parent #30 security review found asynchronous stale selection and implicit first-child pairing defects; corrections are in progress. Child #31 lab collector/encrypted outbox is implemented at `6551bb60ab07a0b93fb9f1f8d1422517b0c66b8d`, independent review pending. Child application artifact hashes were independently read back: default-off `8428380cb2688461b80b4bef8cd7d088b4948a89fd3ecfed1da7e76c645dae1e`, lab-opt-in `2fbd0a2ecf974b01e2d8e3f5a26fdcde13541dc4ed6ee4f7d9b769c8cd5208cb`. Both deliberately have no configured HTTPS origin and cannot collect; source/build is not real-device acceptance.

Real-device matrix, HTTPS parent-to-child end-to-end pairing, physical Keystore execution, notification/permission/battery acceptance: NOT_RUN. No request for physical-device or VPS help yet. Main has documentation only; implementation promotion still requires cumulative dev verification and reviewed dev→main PR. No retention durations activated; SOS/media/payment release gates unchanged; 108-client prior benchmark remains synthetic DB-only evidence.
