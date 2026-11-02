#!/usr/bin/env python3
"""Checks the physical M1 schema (parsed from backend/persistence/migrations) against the logical ERD through the
reviewed mapping docs/data-model/M1_PHYSICAL_TO_LOGICAL_CATALOG.json, and keeps docs/M1_PHYSICAL_TABLE_CATALOG.md
in sync with that mapping.

Fails when: a physical table is unmapped; a mapped ERD entity is missing or used twice; a rename names a column that
does not exist; the real column differences no longer equal the recorded ones; the ERD entity count changes silently;
the generated document is stale.  `--write` regenerates the document.  SYNTHETIC DATA ONLY (no database needed)."""
import json, pathlib, sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import physical_schema as ps  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
MAPPING = ROOT / "docs" / "data-model" / "M1_PHYSICAL_TO_LOGICAL_CATALOG.json"
REPORT = ROOT / "docs" / "M1_PHYSICAL_TABLE_CATALOG.md"


def check(mapping, erd, physical, logical):
    errors = []
    if erd.get("tableCount") != len(logical):
        errors.append(f"ERD tableCount {erd.get('tableCount')} != entities found {len(logical)}")
    entries = {}
    for t in mapping["tables"]:
        if t["physical"] in entries:
            errors.append(f"{t['physical']}: mapped twice")
        entries[t["physical"]] = t
    without = {x["physical"]: x for x in mapping.get("physical_without_entity", [])}
    for name in sorted(set(physical) - set(entries) - set(without)):
        errors.append(f"physical table {name} is not in the mapping (add it, or list it under physical_without_entity with a reason)")
    for name in sorted((set(entries) | set(without)) - set(physical)):
        errors.append(f"mapping names {name}, which no migration creates")
    for name, w in without.items():
        if name in entries:
            errors.append(f"{name}: both mapped and listed without entity")
        if not w.get("reason", "").strip():
            errors.append(f"{name}: physical_without_entity needs a reason")
    seen = {}
    for name, t in entries.items():
        lg = t["logical"]
        if lg not in logical:
            errors.append(f"{name}: ERD entity {lg} does not exist")
            continue
        if lg in seen:
            errors.append(f"{name}: ERD entity {lg} is already mapped from {seen[lg]}")
        seen[lg] = name
        if name not in physical:
            continue
        if not t.get("note", "").strip():
            errors.append(f"{name}: a note explaining the differences is required")
        ren = t.get("column_renames", {})
        for src, dst in ren.items():
            if src not in physical[name]:
                errors.append(f"{name}: rename source {src} is not a physical column")
            if dst not in logical[lg]:
                errors.append(f"{name}: rename target {dst} is not an ERD column of {lg}")
        pc = {ren.get(c, c) for c in physical[name]}
        got_p, got_l = sorted(pc - logical[lg]), sorted(logical[lg] - pc)
        if got_p != sorted(t.get("physical_only", [])):
            errors.append(f"{name}: physical-only columns changed. recorded={sorted(t.get('physical_only', []))} actual={got_p}")
        if got_l != sorted(t.get("logical_only", [])):
            errors.append(f"{name}: ERD-only columns changed. recorded={sorted(t.get('logical_only', []))} actual={got_l}")
    return errors


def render(mapping, erd, physical, logical):
    mapped = {t["logical"] for t in mapping["tables"]}
    L = []
    a = L.append
    a("# M1 physical table catalog (generated)")
    a("")
    a("Generated from `docs/data-model/M1_PHYSICAL_TO_LOGICAL_CATALOG.json` by `backend/tests/check_physical_catalog.py --write`. "
      "**Do not edit by hand**; edit the JSON and regenerate. CI fails if this file is stale or if the migrations or the ERD drift from the mapping.")
    a("")
    a(f"- Physical tables (schema `{mapping['schema']}`, manifest-selected common + M1 through0006 only): **{len(physical)}**")
    a(f"- Logical ERD entities: **{len(logical)}**; mapped to a physical table: **{len(mapped)}**; not yet physical (M2 and later, design only): **{len(logical) - len(mapped)}**")
    a(f"- Physical tables with no ERD entity: **{len(mapping.get('physical_without_entity', []))}**")
    a("")
    a("The ERD is a conceptual design; the migrations are what actually exists. Every difference below is known and recorded. "
      "The largest one is the tenant model: M1 is family-scoped with forced row-level security, while the owner-approved ERD V2 is child-scoped "
      "(see `ADR_2026_10_28_BLEND_FAMILY_V2`). This report describes the historical M1 baseline through0006, not the converged V2 runtime. "
      "See `data-model/local-postgresql/README.md` for separately scoped V2 execution evidence; "
      "`data-model/historical-m1/PHYSICAL_TABLE_CATALOG.md` is the frozen source-through0004 snapshot, not a second current report.")
    a("")
    a("| Physical table | ERD entity | Renamed columns | Physical only | ERD only |")
    a("|---|---|---|---|---|")
    for t in mapping["tables"]:
        ren = ", ".join(f"`{k}` → `{v}`" for k, v in t["column_renames"].items()) or "-"
        po = ", ".join(f"`{x}`" for x in t["physical_only"]) or "-"
        lo = ", ".join(f"`{x}`" for x in t["logical_only"]) or "-"
        a(f"| `{t['physical']}` | `{t['logical']}` | {ren} | {po} | {lo} |")
    a("")
    a("## Notes per table")
    a("")
    for t in mapping["tables"]:
        a(f"- **`{t['physical']}`**: {t['note']}")
    a("")
    a("## Physical tables without an ERD entity")
    a("")
    for w in mapping.get("physical_without_entity", []):
        a(f"- **`{w['physical']}`**: {w['reason']}")
    a("")
    return "\n".join(L)


def main(argv):
    mapping = json.loads(MAPPING.read_text())
    erd = json.loads((ROOT / mapping["erd"]).read_text())
    physical, logical = ps.physical_tables(), ps.logical_entities(erd)
    errors = check(mapping, erd, physical, logical)
    text = render(mapping, erd, physical, logical)
    if "--write" in argv:
        if errors:
            print("PHYSICAL CATALOG CHECK FAILED; generated report not written:\n- " + "\n- ".join(errors))
            return 1
        REPORT.write_text(text)
    elif not REPORT.exists() or REPORT.read_text() != text:
        errors.append("docs/M1_PHYSICAL_TABLE_CATALOG.md is stale: run backend/tests/check_physical_catalog.py --write")
    if errors:
        print("PHYSICAL CATALOG CHECK FAILED:\n- " + "\n- ".join(errors))
        return 1
    print(f"Physical catalog PASS: {len(physical)} physical tables, {len(mapping['tables'])} mapped to the {len(logical)}-entity ERD, "
          f"{len(mapping.get('physical_without_entity', []))} without an entity")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
