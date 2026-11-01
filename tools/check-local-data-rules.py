#!/usr/bin/env python3
"""L00-003 scanner enforcing synthetic-only local data rules.

Fails closed if committed text appears to contain real sensitive data:
Indian PAN, Aadhaar, card numbers, Play purchase tokens, or private keys.
This is a LOCAL governance check, NOT legal/Play approval.

Usage:
  python3 tools/check-local-data-rules.py            # scan tracked text files
  python3 tools/check-local-data-rules.py --selftest # prove detection works

Exit 0 = clean; 1 = suspected real data found; 2 = usage/environment error.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# The documents that legitimately *name* these categories (definitions, not data).
SELF_REFERENTIAL = {
    "docs/roadmap/LOCAL_DATA_RULES.md",
    "tools/check-local-data-rules.py",
}

TEXT_SUFFIXES = {".md", ".json", ".yaml", ".yml", ".py", ".sh", ".kt", ".kts",
                 ".cc", ".h", ".cpp", ".sql", ".txt", ".csv", ".env", ".example"}

PATTERNS = {
    "pan": re.compile(r"\b[A-Z]{5}[0-9]{4}[A-Z]\b"),
    "aadhaar": re.compile(r"\b[0-9]{4}\s[0-9]{4}\s[0-9]{4}\b"),
    "private_key": re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |)PRIVATE KEY-----"),
    "purchase_token": re.compile(r"(?:purchase_?[tT]oken)\"?\s*[:=]\s*\"?[A-Za-z0-9._-]{30,}"),
    # A payment card is 13-16 digits optionally grouped in 4s by single spaces,
    # NOT a UUID. We require pure digit groups and reject anything embedded in a
    # longer hex/UUID token via the UUID guard below.
    "card_number": re.compile(r"(?<![0-9A-Fa-f-])(?:[0-9]{4} ){2,3}[0-9]{1,4}(?![0-9A-Fa-f-])"
                              r"|(?<![0-9A-Fa-f-])[0-9]{13,16}(?![0-9A-Fa-f-])"),
}

# Reject UUID / hex-id shapes that superficially contain digit runs.
UUID_RX = re.compile(r"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}")

# Allow obvious synthetic/doc markers so definitions and fixtures don't false-positive.
ALLOW_MARKERS = ("demo_", "synthetic_", "test_", "fake_", "example", "XXXX",
                 "placeholder", "REDACTED", "<", "{{", "uuid", "UUID")


def tracked_text_files() -> list[Path]:
    names = subprocess.check_output(
        ["git", "ls-files", "-z"], cwd=ROOT
    ).decode().split("\0")
    out = []
    for n in names:
        if not n:
            continue
        p = ROOT / n
        if p.suffix.lower() in TEXT_SUFFIXES and p.is_file():
            out.append(p)
    return out


def scan_text(text: str, rel: str) -> list[str]:
    hits = []
    for name, rx in PATTERNS.items():
        for m in rx.finditer(text):
            frag = m.group(0)
            line_start = text.rfind("\n", 0, m.start()) + 1
            line_end = text.find("\n", m.end())
            line = text[line_start:line_end if line_end != -1 else len(text)]
            if any(mark in line for mark in ALLOW_MARKERS):
                continue
            # URL guard: long digit runs inside a URL are identifiers, not cards.
            if name == "card_number" and ("http://" in line or "https://" in line):
                continue
            # UUID guard: reject digit runs that are part of a UUID/hex id.
            if name == "card_number" and UUID_RX.search(line):
                continue
            # card_number: ignore if it is clearly a long id of non-digits-with-dots (version etc.)
            if name == "card_number" and sum(c.isdigit() for c in frag) < 13:
                continue
            hits.append(f"{rel}: suspected {name}: '{frag[:12]}...'")
    return hits


def selftest() -> int:
    sample = 'pan "ABCDE1234F" purchase_token="aZ09aZ09aZ09aZ09aZ09aZ09aZ09aZ09"'
    hits = scan_text(sample, "<selftest>")
    kinds = {h.split("suspected ")[1].split(":")[0] for h in hits}
    ok = "pan" in kinds and "purchase_token" in kinds
    # Negative control: a synthetic-marked line must NOT trip.
    clean = scan_text('demo_ pan "ABCDE1234F"', "<selftest-clean>")
    ok = ok and not clean
    print(f"selftest detection={'PASS' if ok else 'FAIL'} kinds={sorted(kinds)} "
          f"allowlist_suppressed={len(clean) == 0}")
    return 0 if ok else 1


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()
    if args.selftest:
        return selftest()

    all_hits: list[str] = []
    files = tracked_text_files()
    for p in files:
        rel = str(p.relative_to(ROOT))
        if rel in SELF_REFERENTIAL:
            continue
        try:
            text = p.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        all_hits.extend(scan_text(text, rel))

    print(f"scanned {len(files)} tracked text files; {len(all_hits)} suspected real-data hit(s)")
    for h in all_hits:
        print("  " + h, file=sys.stderr)
    print("readiness: local synthetic-data scan only; no legal/Play approval conferred")
    return 1 if all_hits else 0


if __name__ == "__main__":
    raise SystemExit(main())
