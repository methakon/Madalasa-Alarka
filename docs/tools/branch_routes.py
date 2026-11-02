#!/usr/bin/env python3
"""Fail-closed PR source/target and documentation-route check; no GitHub API privileges."""
import argparse
import json
import sys
from pathlib import Path

CONFIG = Path(__file__).resolve().parents[1] / "branch-governance.json"


def config():
    return json.loads(CONFIG.read_text(encoding="utf-8"))


def is_documentation(path, rule):
    # Slash-normalized git paths only. Never trust absolute/traversal paths.
    if not path or path.startswith("/") or "\\\\" in path or any(p in ("", ".", "..") for p in path.split("/")):
        return True
    return any(path == prefix if not prefix.endswith("/") else path.startswith(prefix)
               for prefix in rule["documentation_paths"])


def validate(base, head, changed, owner_approved_temporary=False, rule=None):
    """Return human-readable errors. A label NEVER substitutes for documented owner approval."""
    rule = config() if rule is None else rule
    errors = []
    changed = list(changed)
    if not changed:
        errors.append("Empty changed-file list; cannot verify PR routing")
    allowed = rule["allowed_code_pr_routes"]
    if head in allowed:
        if base != allowed[head]:
            errors.append(f"{head} must target {allowed[head]}, not {base}")
    elif head.startswith(rule["temporary_branch_prefix"]) or head == rule["legacy_exception_branch"]:
        if base != "dev":
            errors.append(f"{head} must target dev before main")
        if not owner_approved_temporary:
            errors.append(f"{head} requires recorded owner instruction and owner-approved-temporary label")
    else:
        errors.append(f"Unrecognized code PR source branch {head}; ask owner, do not create ad-hoc branches")
    if base not in ("dev", "main"):
        errors.append(f"Code PR target {base} is forbidden")
    docs = [p for p in changed if is_documentation(p, rule)]
    if docs:
        errors.append("Docs/planning/governance must change directly on main, not via code PR: "
                      + ", ".join(docs[:8]))
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", required=True)
    parser.add_argument("--head", required=True)
    parser.add_argument("--temp-owner-approved", default="false")
    args = parser.parse_args()
    approved = args.temp_owner_approved.lower() == "true"
    errors = validate(args.base, args.head, sys.stdin.read().splitlines(), approved)
    if errors:
        for issue in errors:
            print("BRANCH ROUTE FAILURE: " + issue, file=sys.stderr)
        return 1
    print(f"PR route and doc isolation OK: {args.head} -> {args.base} (not final merge acceptance)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
