# Documentation Tools & Validation Scripts

## Branch-policy tests and route validation

Run `python3 -m unittest discover -s docs/tools -p 'test_*.py' -v` for branch manifest/routing negative tests (in addition to documentation tests). The [machine branch policy](../branch-governance.json), [canonical owner process](../phases/M1-secure-platform-foundation/02-development-process/BRANCHING_VERSIONING_AND_RELEASE_PROCESS.md) and [PR route validator](branch_routes.py) are maintained on `main` only; passing static checks alone does not implement GitHub branch protection.

## Current offline documentation checker

Source-preserving CommonMark parser and regression cases imported from
`09689396ac87cc427e9de51b0e6adc1a2dc85e4c`. `check_documentation.py` replaces the
old reorganization-only checker with current human/machine-register and manifest
checks. It scans ALL tracked Markdown, HTML and `LICENSE` files plus nonignored
new inputs, including new documentation controls. Code examples are not navigation.
Local paths/fragments have no error waivers; external URLs are not fetched.

```sh
python3 -m venv .dev-environment/documentation-venv
.dev-environment/documentation-venv/bin/python -m pip install -r docs/tools/requirements.txt
.dev-environment/documentation-venv/bin/python -m unittest discover -s docs/tools -p 'test_*.py' -v
.dev-environment/documentation-venv/bin/python docs/tools/check_documentation.py
python3 backend/tests/check_document_structure.py
python3 -m unittest discover -s backend/tests -p test_pending_identity_documentation.py -v
```

The machine register is deterministically derived with `derive_register(root)` from
the current human register and manifest. Its scope is the 72 relocated documents,
not all later supporting material. No obsolete 72-header, historical API/UI freeze
or old approval state is imposed. Negative controls exercise catalogue corruption,
false approval, broken links and protected substantive-body changes.

Historical proof ledgers, results and old checker source are retained verbatim in
`docs/validation/legacy-reorganization-2026-10-27/`, bound to the source commit above.
The old verification narrative uses `.historical.txt`: its old relative paths are
raw historical evidence, not current navigation. Historical PASS fields are NOT
current results. Never run archival `check_reorganization.py` as a current gate.

Passing these checks is not legal, implementation, device or release acceptance.
See [the current phase gate checklist](../DOCUMENTATION_PHASE_GATE_CHECKLIST.md).


This directory contains automated scripts and validation suites for maintaining documentation structure, link integrity, and reorganization compliance.

## Tools and Validators

- [`backend/tests/check_document_structure.py`](../../backend/tests/check_document_structure.py): Validates canonical document paths, relocation manifest integrity, phase index completeness, and navigation link resolution.
- [`backend/tests/check_erd_references.py`](../../backend/tests/check_erd_references.py): Enforces referential integrity across all entities and foreign key targets in the logical ERD models.
- [`backend/tests/lint_openapi_m1.py`](../../backend/tests/lint_openapi_m1.py): Verifies structural compliance and operation schemas for the M1 OpenAPI specification.
- [`backend/tests/lint_openapi_full.py`](../../backend/tests/lint_openapi_full.py): Cross-verifies the 171-operation whole-project OpenAPI specification against audited Figma screens and database tables.
