#!/usr/bin/env bash
# L01-014 - per-task evidence gate.
# Refuses to call a roadmap task DONE unless its evidence file exists and names
# an executable verification command plus a true result. LOCAL governance only;
# this never grants legal/Play/release approval.
#
# Usage:
#   tools/verify-roadmap-task.sh <TASK-ID>          # check one task's evidence
#   tools/verify-roadmap-task.sh --selftest         # prove a bad evidence file is rejected
#
# Exit 0 = evidence present and well-formed; 1 = missing/insufficient; 2 = usage error.
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

check_one() {
  local task_id="$1" base="$2"
  local ev="$base/evidence/local/tasks/${task_id}.md"
  local problems=0
  if [[ ! -f "$ev" ]]; then
    echo "MISSING: no evidence file $ev" >&2
    return 1
  fi
  # Required markers: a task id, a verification command, an exit code, a PASS/state,
  # and a commit SHA placeholder or value. Refuse "PASS" without an executed command.
  grep -Eq "Task ID:\**[[:space:]]*${task_id}" "$ev" || { echo "evidence missing 'Task ID: ${task_id}'" >&2; problems=1; }
  grep -Eqi "exit code|exit \`?[0-9]" "$ev" || { echo "evidence names no exit code" >&2; problems=1; }
  grep -Eq "python3 |ctest|gradlew|psql|bash |\.sh|\.py" "$ev" || { echo "evidence names no executable command" >&2; problems=1; }
  grep -Eqi "State:\**[[:space:]]*\**(PASS|BLOCKED_ENVIRONMENT|BLOCKED_EXTERNAL|FAILED_TEST)" "$ev" \
    || { echo "evidence has no recognized State" >&2; problems=1; }
  # If it claims PASS, it must also name a command and an exit code (already checked).
  if grep -qi "State:.*PASS" "$ev" && ! grep -Eqi "exit \`?0|exit code.*0" "$ev"; then
    echo "evidence claims PASS but shows no exit 0" >&2; problems=1
  fi
  if [[ "$problems" -eq 0 ]]; then
    echo "OK: ${task_id} evidence well-formed"
    return 0
  fi
  return 1
}

selftest() {
  local tmp; tmp="$(mktemp -d)"
  mkdir -p "$tmp/evidence/local/tasks"
  # Bad: PASS with no command/exit code.
  printf '# Evidence\n- Task ID: L99-999\n- State: PASS\n' > "$tmp/evidence/local/tasks/L99-999.md"
  if check_one "L99-999" "$tmp" 2>/dev/null; then
    echo "selftest FAIL: accepted a bad evidence file"; rm -rf "$tmp"; return 1
  fi
  # Good: PASS with command + exit 0.
  cat > "$tmp/evidence/local/tasks/L99-998.md" <<'EOF'
# Evidence
- Task ID: L99-998
- Verification: `python3 tools/x.py` exit `0`
- State: PASS
EOF
  if ! check_one "L99-998" "$tmp" 2>/dev/null; then
    echo "selftest FAIL: rejected a good evidence file"; rm -rf "$tmp"; return 1
  fi
  rm -rf "$tmp"
  echo "selftest PASS: rejects PASS-without-command, accepts well-formed evidence"
  return 0
}

main() {
  if [[ "${1:-}" == "--selftest" ]]; then selftest; return $?; fi
  if [[ $# -ne 1 ]]; then
    echo "Usage: tools/verify-roadmap-task.sh <TASK-ID> | --selftest" >&2
    return 2
  fi
  check_one "$1" "$repo_root"
}

main "$@"
