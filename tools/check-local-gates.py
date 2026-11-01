#!/usr/bin/env python3
"""L00-012 local stop/go gate validator.

Fail-closed gate over the feature-gate matrix (config/feature-gates.example.json).
It FAILS (exit 1) if any restricted/sensitive feature is enabled=true without all
of its gates CLEARED, i.e. a restricted flag set true without approved evidence.
LOCAL governance only; never grants release/legal/Play approval.

Usage:
  python3 tools/check-local-gates.py                 # check the committed matrix
  python3 tools/check-local-gates.py --config PATH   # check an alternate matrix
  python3 tools/check-local-gates.py --test          # run built-in pos/neg tests

Exit 0 = safe (no restricted flag enabled without cleared gates); 1 = STOP; 2 = error.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG = ROOT / "config" / "feature-gates.example.json"


def evaluate(cfg: dict) -> list[str]:
    """Return STOP reasons. Empty list == go."""
    stops: list[str] = []
    features = cfg.get("features", {})
    for name, feature in features.items():
        if not feature.get("sensitive", False):
            continue
        if feature.get("enabled") is True:
            gates = feature.get("gates", {})
            if not gates:
                stops.append(f"{name}: restricted feature enabled with NO gate evidence")
                continue
            uncleared = [g for g, s in gates.items() if s != "CLEARED"]
            if uncleared:
                stops.append(f"{name}: restricted feature enabled but gates not CLEARED: {uncleared}")
    return stops


def run_tests() -> int:
    base = {
        "features": {
            "x": {"sensitive": True, "enabled": False,
                  "gates": {"g1": "OPEN"}},
        }
    }
    # Positive (safe): disabled restricted feature -> no stop
    assert evaluate(base) == [], "disabled restricted feature must be safe"
    # Negative: enabled with OPEN gate -> STOP
    neg = json.loads(json.dumps(base))
    neg["features"]["x"]["enabled"] = True
    assert evaluate(neg), "enabled restricted feature with OPEN gate must STOP"
    # Negative: enabled with NO gates -> STOP
    neg2 = {"features": {"y": {"sensitive": True, "enabled": True, "gates": {}}}}
    assert evaluate(neg2), "enabled restricted feature with no gates must STOP"
    # Positive: enabled with all gates CLEARED -> go
    pos = json.loads(json.dumps(base))
    pos["features"]["x"]["enabled"] = True
    pos["features"]["x"]["gates"]["g1"] = "CLEARED"
    assert evaluate(pos) == [], "enabled restricted feature with CLEARED gate is allowed"
    # Positive: non-sensitive enabled -> go
    ns = {"features": {"z": {"sensitive": False, "enabled": True, "gates": {}}}}
    assert evaluate(ns) == [], "non-sensitive enabled feature is allowed"
    print("check-local-gates self-tests: PASS (disabled-safe, open-stop, nogate-stop, cleared-go, nonsensitive-go)")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    ap.add_argument("--test", action="store_true")
    args = ap.parse_args()
    if args.test:
        return run_tests()
    if not args.config.is_file():
        print(f"FAIL: missing config {args.config}", file=sys.stderr)
        return 2
    try:
        cfg = json.loads(args.config.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"FAIL: invalid JSON: {exc}", file=sys.stderr)
        return 2
    stops = evaluate(cfg)
    print(json.dumps({
        "config": str(args.config),
        "decision": "STOP" if stops else "GO",
        "stops": stops,
        "readiness": "Local stop/go gate only; no release/legal/Play approval conferred",
    }, indent=2))
    for s in stops:
        print("STOP: " + s, file=sys.stderr)
    return 1 if stops else 0


if __name__ == "__main__":
    raise SystemExit(main())
