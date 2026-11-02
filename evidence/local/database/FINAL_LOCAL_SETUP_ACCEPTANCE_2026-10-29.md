# Final synthetic local database setup acceptance

Decision: **LOCAL_READY for the database foundation and synthetic admin API development.** Product/admin UI/provider/real-child/production release remains **NOT_READY**. This is not a declaration that the roadmap or all application features are complete.

Verified implementation revision: `698bbccd304b84d15e886a23b8f9ed4573764d15`, following lineage/restore commits `4b4c4e85cebd3c35877d49e25fc2d7c11dc5f1a1` and `50333c6dee6dfb45d6f56fd70501b8a4cb7a810f`.

## Final execution

- `./tools/database/db test`: exit 0, **176 tests in 54.455s**, unfiltered discovery including all seven new metadata tests, six real C++/Drogon HTTP tests and both existing actual backup/restore tests. Raw ignored log: `.local-db/final-complete-suite.log`.
- `.local-db/venv/bin/python tools/database/export_schema.py`: exit 0; seven artifacts regenerated from the actual test catalog.
- `.local-db/venv/bin/python tools/database/export_schema.py --check`: exit 0 after final suite/restore and regeneration.
- `python3 -m unittest discover -s backend/tests/database -p test_schema_export_metadata.py -v`: exit 0, seven tests repeated against the final exported catalog. Missing-owner, dropped-owner, cycles, unknowns, partition, enum and raw-constraint controls pass.
- Full OpenAPI/screen contract lint: exit 0, 171 draft operations, 155 paths, 187 screens and 120 canonical logical concepts. M1 structural lint remains 11 operations/16 schemas; design lint does not certify handlers.
- Documentation structure check: exit 0, existing 72 canonical documents/12 phase indexes/19 categories preserved.
- Native build/CTest and actual historical fresh/populated-upgrade/restore/convergence replay: exit 0, recorded in [lineage convergence evidence](LINEAGE_CONVERGENCE_2026-10-29.md). Historical catalog negative controls: 17 tests passed.
- Persistent development: checksum-bound private backup, additive 0015→0018 upgrade and verification all exit 0. Additional live `verify_lineage_security('dev')` passes. No development reset, deployment or production connection.

Both named databases report PostgreSQL 16.9/PostGIS 3.5.2, 139 application tables, two recovery tables, two migration ledgers, seven views, 292 indexes and 82 policies. Every application/recovery base table has ENABLE/FORCE RLS. The two migration ledgers are bookkeeping, not falsely described as RLS-protected application tables. Runtime logins remain non-superuser/non-bypass. RAM-backed test acceptance does not establish reboot/power-loss durability; persistent development did complete its bounded backup/migration/readback.

## Metadata acceptance

[Retention/ownership manifest](../../../docs/data-model/local-postgresql/retention-ownership-manifest.json) covers **143 base tables**, including migration bookkeeping: 82 have a direct/catalog-FK child path, while 61 are explicitly unknown and require manual privacy classification. Unknown does not mean nonpersonal or exempt. Every base table has explicit declaring-source ownership; missing ownership fails export.

[Typed constraint registry](../../../docs/data-model/local-postgresql/typed-constraint-registry.json) records actual column types/defaults/nullability, raw CHECK SQL and validation state, FK paths, captured enum labels and partition facts. Inventory configuration is the only allowlisted noncatalog row source; no child/application records or credentials are exported.

All candidate retention periods remain null, policy approval is NONE/OWNER_COUNSEL_PENDING, legal-hold rules remain pending and real-child release is OFF. Six-hour visible history is not represented as a physical retention TTL. These unresolved policy decisions block real-data release, not synthetic implementation.

The source migration export has **22 unique namespaced identities**, retaining both published chains and the compatibility bridge; it explicitly describes source lineages, not 22 installed migrations on clean V2. Clean V2 has 18 installed entries; historical convergence retains its additional original history. All original published SQL bytes remain unchanged.

Raw CHECK deparsing can change redundant AND parentheses after an actual PostgreSQL dump/restore without changing the predicate. Final snapshots were therefore regenerated after the final restore and then byte-checked. No CHECK normalization, constraint weakening or approval fabrication was used to make the export pass.

## Admin API development decision

**Yes: proceed locally with synthetic, metadata-only admin API implementation.** The migration-number collision, logical-model baseline drift, schema-export gap and unfiltered-regression gate are now closed for this database foundation. The owner [six-gate handoff](../../../docs/roadmap/SIX_GATE_OWNER_DECISIONS_AND_AGENT_HANDOFF_2026-10-29.md) explicitly separates synthetic coding from hosting, Play and real-child legal release.

The contract has 48 draft `/admin/` operations and **zero implemented admin adapters**. Only four existing parent/child read adapters are implemented and HTTP-tested; do not equate the schema or 171 draft operations with a completed backend.

Recommended first slice: the existing `GET /admin/access/me` contract (`AdminApplicantBearer`), server-verified identity and account-approval/RBAC denial tests. Bind owner authority to verified Google OIDC `sub`, not email or caller-selected headers. Use clearly labelled synthetic issuer fixtures until the real OIDC verifier is implemented and exercised. Unapproved/revoked users must fail closed; application owner authority must not bypass exact-child restrictions or expose raw location/media. Follow with narrow metadata-only owner-approval/support slices under existing contracts.

Remaining product/release work includes real OIDC/provider verification, actual admin HTTP handlers/UI/build and security acceptance, visual Figma validation, approved category-specific retention/authority policy, Play sandbox verification and separately authorized deployment. None is represented as already implemented by this setup acceptance.
