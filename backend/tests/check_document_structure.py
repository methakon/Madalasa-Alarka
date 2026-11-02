#!/usr/bin/env python3
"""Validate the canonical M0–M9 document filing layout and its compatibility links.

Runs with Python 3 standard library only; no network, no child data, no runtime app.
This verifies structure and new library/index links, NOT legal signoff or code health.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / "docs"
MANIFEST = DOCS / "DOCUMENT_RELOCATION_MANIFEST.json"
EXPECTED_PHASES = ("M0", "M1", "M2", "M3", "M4", "M5", "M6", "M7", "M8", "M9", "P3", "CROSS")
LINK_RE = re.compile(r"\]\(([^\)\n]+)\)")


def check(condition: bool, message: str, failures: list[str]) -> None:
    if not condition:
        failures.append(message)


def check_local_links(path: Path, failures: list[str]) -> None:
    for raw in LINK_RE.findall(path.read_text(encoding="utf-8")):
        target = raw.strip().split(maxsplit=1)[0].strip("<>")
        if not target or target.startswith(("#", "http:", "https:", "mailto:", "tel:", "data:")):
            continue
        target = unquote(target.split("#", 1)[0].split("?", 1)[0])
        if target and not (path.parent / target).exists():
            failures.append(f"Broken controlled navigation link: {path.relative_to(ROOT)} -> {target}")


def main() -> int:
    failures: list[str] = []
    check(MANIFEST.is_file(), "Missing document relocation manifest", failures)
    if failures:
        print("\n".join(failures), file=sys.stderr)
        return 1
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    entries = data["entries"]
    check(data["document_count"] == len(entries) == 72,
          f"Expected 72 canonical documents, found {len(entries)}", failures)
    paths: set[str] = set()
    for entry in entries:
        new = ROOT / entry["canonical_path"]
        old = ROOT / entry.get("compatibility_pointer_path", entry["original_path"])
        check(entry["canonical_path"] not in paths,
              f"Duplicate canonical path {new}", failures)
        paths.add(entry["canonical_path"])
        check(new.is_file() and new.stat().st_size > 200,
              f"Missing or suspiciously short canonical document: {new}", failures)
        check(old.is_file(), f"Missing relocated legacy reference: {old}", failures)
        if old.is_file():
            check(new.name in old.read_text(encoding="utf-8"),
                  f"Forwarding page does not point to correct filename: {old}", failures)
    controls = ["README.md", "MASTER_DOCUMENT_CONTROL_REGISTER.md",
                "DOCUMENT_CONTROL_POLICY.md", "PHASE_DOCUMENTATION_COVERAGE_MATRIX.md"]
    for filename in controls:
        p = DOCS / filename
        check(p.is_file(), f"Missing docs control/index: {p}", failures)
        if p.is_file():
            check_local_links(p, failures)
    phase_dirs = data.get("phase_dirs")
    if not isinstance(phase_dirs, dict):
        failures.append("Missing phase_dirs dictionary in document relocation manifest")
        phase_dirs = {}
    check(set(phase_dirs) == set(EXPECTED_PHASES),
          f"Phase directory map differs from M0–M9 + P3/CROSS: {list(phase_dirs)}", failures)
    for phase, dirname in phase_dirs.items():
        index = DOCS / "phases" / dirname / "README.md"
        check(index.is_file(), f"Phase index missing: {index}", failures)
        if index.is_file():
            check_local_links(index, failures)
    category_readmes = sorted((DOCS / "phases").glob("*/[0-9][0-9]-*/README.md"))
    check(len(category_readmes) == 19,
          f"Expected 19 category index files; found {len(category_readmes)}", failures)
    for p in category_readmes:
        check_local_links(p, failures)
    check((DOCS / "openapi-m1.yaml").is_file(), "M1 OpenAPI path changed", failures)
    check((DOCS / "openapi.yaml").is_file(), "Design OpenAPI path changed", failures)
    check((DOCS / "ui" / "figma-functional-handoff" / "README.md").is_file(),
          "Figma handoff path changed", failures)
    if failures:
        for failure in failures:
            print(f"ERROR: {failure}", file=sys.stderr)
        return 1
    print(f"Documentation structure OK: {len(entries)} canonical docs, "
          f"{len(phase_dirs)} phase indexes, {len(category_readmes)} categories, "
          "compatible old links, unchanged M1/API/UI paths.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
