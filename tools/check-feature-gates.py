#!/usr/bin/env python3
"""L00-002 verifier for config/feature-gates.example.json.

Proves the acceptance criterion: "Every sensitive feature starts disabled and
missing flag denies." This is a LOCAL governance check, NOT a release approval.

Checks:
  1. Config parses as JSON and declares fail-closed resolution rules.
  2. Every sensitive feature has enabled == false (none ships enabled).
  3. Every sensitive feature records at least one gate (no silent clearance).
  4. The fail-closed resolver DENIES:
       - an absent/unknown flag,
       - a sensitive flag that is present but disabled,
       - a sensitive flag enabled but with any non-CLEARED gate.
     and only ALLOWS a sensitive flag when enabled AND all gates CLEARED.

Exit code 0 = all invariants hold; non-zero = violation (fail closed).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "config" / "feature-gates.example.json"


def resolve(cfg: dict, feature_name: str) -> str:
    """Fail-closed access decision for a feature flag. Returns 'ALLOW' or 'DENY'."""
    features = cfg.get("features", {})
    # Invariant: a missing/unknown flag denies.
    if feature_name not in features:
        return "DENY"
    feature = features[feature_name]
    # A present-but-unset sensitive flag denies.
    if feature.get("enabled") is not True:
        return "DENY"
    # Non-sensitive and explicitly enabled: allowed.
    if not feature.get("sensitive", False):
        return "ALLOW"
    # Sensitive + enabled requires ALL gates CLEARED.
    gates = feature.get("gates", {})
    if not gates:
        # Sensitive feature with no gate record cannot be cleared.
        return "DENY"
    if all(state == "CLEARED" for state in gates.values()):
        return "ALLOW"
    return "DENY"


def validate(cfg: dict) -> list[str]:
    errors: list[str] = []
    rules = cfg.get("resolution_rules", {})
    if rules.get("default_when_flag_absent") != "DENY":
        errors.append("resolution_rules.default_when_flag_absent must be DENY (fail closed)")
    if rules.get("default_when_sensitive_flag_present_but_unset") != "DENY":
        errors.append("resolution_rules.default_when_sensitive_flag_present_but_unset must be DENY")

    features = cfg.get("features", {})
    if not features:
        errors.append("No features declared")

    for name, feature in features.items():
        if feature.get("sensitive", False):
            if feature.get("enabled") is not False:
                errors.append(f"Sensitive feature '{name}' must start disabled (enabled=false)")
            if not feature.get("gates"):
                errors.append(f"Sensitive feature '{name}' must record at least one gate")

    # --- Negative resolver proofs ---
    # (a) absent/unknown flag denies
    if resolve(cfg, "__does_not_exist__") != "DENY":
        errors.append("Resolver failed: unknown flag did not DENY")

    # (b) every sensitive feature currently resolves DENY (all start disabled)
    for name, feature in features.items():
        if feature.get("sensitive", False) and resolve(cfg, name) != "DENY":
            errors.append(f"Resolver failed: sensitive feature '{name}' resolved ALLOW while disabled/un-cleared")

    # (c) simulated enable-without-clearance still denies (does not mutate file)
    simulated = json.loads(json.dumps(cfg))
    sample = next((n for n, f in features.items() if f.get("sensitive")), None)
    if sample is not None:
        simulated["features"][sample]["enabled"] = True  # enable but leave gates OPEN
        if resolve(simulated, sample) != "DENY":
            errors.append(f"Resolver failed: '{sample}' enabled with OPEN gates must still DENY")
        # (d) positive control: enable AND clear all gates -> ALLOW
        for g in simulated["features"][sample]["gates"]:
            simulated["features"][sample]["gates"][g] = "CLEARED"
        if resolve(simulated, sample) != "ALLOW":
            errors.append(f"Resolver failed: '{sample}' enabled with all gates CLEARED should ALLOW")

    return errors


def main() -> int:
    if not CONFIG.is_file():
        print(f"FAIL: missing {CONFIG}", file=sys.stderr)
        return 2
    try:
        cfg = json.loads(CONFIG.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"FAIL: invalid JSON: {exc}", file=sys.stderr)
        return 2

    errors = validate(cfg)
    sensitive = [n for n, f in cfg.get("features", {}).items() if f.get("sensitive")]
    print(json.dumps({
        "config": str(CONFIG.relative_to(ROOT)),
        "feature_count": len(cfg.get("features", {})),
        "sensitive_count": len(sensitive),
        "all_sensitive_disabled": all(
            cfg["features"][n].get("enabled") is False for n in sensitive
        ),
        "unknown_flag_resolves": resolve(cfg, "__does_not_exist__"),
        "errors": errors,
        "readiness": "Local gate matrix check only; no release/legal/Play approval conferred",
    }, indent=2))
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
