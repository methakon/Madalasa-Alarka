#!/usr/bin/env python3
"""Phase-00 governance-document acceptance checks.

Static, fail-closed checks that each roadmap governance document satisfies the
acceptance invariant recorded for its task. LOCAL governance only; not release
approval. Exit 0 = all present checks pass; non-zero = violation.

Checks (only for files that exist):
  OWNER_APPROVALS.md   - no DECIDED row without an owner + date; no non-DECIDED
                         row carrying a populated decision (unresolved stays BLOCKED).
  LEGAL_PENDING.md     - asserts no real-data pilot before verifiable approval.
  RETENTION_PENDING.md - distinguishes six-hour visibility from storage lifetime.
  COMMERCE_INVARIANTS.md - base-plan lapse suspends (not erases) the 100-day add-on.
  PLAY_ACCOUNT_NONSECRET.md - contains no account id/token/key/secret patterns.
  RESPONSIBILITIES.md  - states no self-approval of owner/legal/platform decisions.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RM = ROOT / "docs" / "roadmap"


def _read(name: str) -> str | None:
    p = RM / name
    return p.read_text(encoding="utf-8") if p.is_file() else None


def check_owner_approvals(errors: list[str]) -> None:
    text = _read("OWNER_APPROVALS.md")
    if text is None:
        return
    # Parse the decision table rows: | id | question | state | decision | by | date | blocks |
    for line in text.splitlines():
        if not line.startswith("| ") or "decision_id" in line or "---" in line:
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 6:
            continue
        _id, _q, state, decision, by, date = cells[0], cells[1], cells[2], cells[3], cells[4], cells[5]
        if state not in {"OPEN", "BLOCKED", "DECIDED", "DEFERRED", "EXTERNAL_PENDING"}:
            continue  # header/legend rows
        if state == "DECIDED":
            if not by or not date:
                errors.append(f"OWNER_APPROVALS: DECIDED row '{_id}' missing owner/date (guessed approval)")
        elif state in {"OPEN", "BLOCKED"}:
            # Truly unresolved states must NOT carry a populated real decision or sign-off.
            if decision and not decision.upper().startswith("NONE"):
                errors.append(f"OWNER_APPROVALS: {state} row '{_id}' carries a decision; must be NONE")
            if by or date:
                errors.append(f"OWNER_APPROVALS: {state} row '{_id}' has owner/date without a DECIDED state")
        else:
            # DEFERRED / EXTERNAL_PENDING are recorded owner acknowledgements: they
            # may carry an owner/date, but must not assert a resolved substantive decision.
            if decision and not decision.upper().startswith("NONE"):
                errors.append(f"OWNER_APPROVALS: {state} row '{_id}' must record NONE for the substantive decision")


def check_contains(name: str, needles: list[str], errors: list[str]) -> None:
    text = _read(name)
    if text is None:
        return
    low = text.lower()
    for n in needles:
        if n.lower() not in low:
            errors.append(f"{name}: missing required assertion containing '{n}'")


def check_no_family_link_adr(errors: list[str]) -> None:
    """L00-007: the ADR must record that no consumer Google parent-role/Family
    Link API dependency remains, while keeping legal authority/consent separate."""
    p = (ROOT / "docs/phases/M1-secure-platform-foundation/03-security-and-permissions/"
         "ADR_2026_10_28_BLEND_FAMILY_V2_AND_NO_FAMILY_LINK_DEPENDENCY.md")
    if not p.is_file():
        errors.append("L00-007 ADR missing")
        return
    low = p.read_text(encoding="utf-8").lower()
    if "no google family link verification task or product gate remains" not in low:
        errors.append("ADR: must state no Family Link verification task/gate remains")
    if "not" not in low or "parent-child relationship" not in low:
        errors.append("ADR: must clarify Google login does not assert a parent-child relationship")
    if "section 9" not in low and "s.9" not in low and "dpdp" not in low:
        errors.append("ADR: must keep statutory consent/authority as a separate review")


def check_play_account_nonsecret(errors: list[str]) -> None:
    text = _read("PLAY_ACCOUNT_NONSECRET.md")
    if text is None:
        return
    # No secrets/ids: developer account numeric id, API keys, private keys, tokens.
    secret_patterns = {
        "private_key": re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |)PRIVATE KEY-----"),
        "developer_account_id": re.compile(r"\bdeveloper account id\s*[:=]\s*\d{6,}", re.I),
        "api_key": re.compile(r"AIza[0-9A-Za-z_\-]{20,}"),
        "bearer_token": re.compile(r"\bey[JI][A-Za-z0-9_\-]{20,}\."),
    }
    for kind, rx in secret_patterns.items():
        if rx.search(text):
            errors.append(f"PLAY_ACCOUNT_NONSECRET: contains a {kind}; must record NO secret/account id")


def main() -> int:
    errors: list[str] = []
    checked: list[str] = []

    for name, checker in (("OWNER_APPROVALS.md", check_owner_approvals),
                          ("PLAY_ACCOUNT_NONSECRET.md", check_play_account_nonsecret)):
        if (RM / name).is_file():
            checked.append(name)
            checker(errors)

    # L00-007: the Family Link ADR lives under docs/phases, not docs/roadmap.
    adr = (ROOT / "docs/phases/M1-secure-platform-foundation/03-security-and-permissions/"
           "ADR_2026_10_28_BLEND_FAMILY_V2_AND_NO_FAMILY_LINK_DEPENDENCY.md")
    if adr.is_file():
        checked.append("ADR_NO_FAMILY_LINK")
        check_no_family_link_adr(errors)

    text_checks = {
        "LEGAL_PENDING.md": ["no real", "approval"],
        "RETENTION_PENDING.md": ["six", "visibility"],
        "COMMERCE_INVARIANTS.md": ["100", "suspend"],
        "RESPONSIBILITIES.md": ["no", "self-approv"],
    }
    for name, needles in text_checks.items():
        if (RM / name).is_file():
            checked.append(name)
            check_contains(name, needles, errors)

    print(f"governance docs checked: {sorted(checked)}; {len(errors)} violation(s)")
    for e in errors:
        print("  " + e, file=sys.stderr)
    print("readiness: local governance acceptance check only; no legal/Play approval conferred")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
