#!/usr/bin/env bash
# Owner-approved task-start preflight: update from BOTH remote main and dev.
# Run on the intended branch. This tool makes NO attempt to resolve conflicts.
set -euo pipefail
if [[ "$#" != 1 ]]; then
  echo "Usage: bash docs/tools/sync_work_branch.sh <api|parent|child|admin-web|dev|main|temp/...>" >&2
  exit 2
fi
branch="$1"
case "$branch" in
  api|parent|child|admin-web|dev|main) ;;
  temp/*|feat/local-postgresql-physical-schema)
    echo "Temporary/legacy branch: verify written owner authorization and required review before proceeding." >&2 ;;
  *) echo "Unapproved branch: $branch. Do not start work." >&2; exit 2 ;;
esac
top="$(git rev-parse --show-toplevel)" || exit 2
cd "$top"
current="$(git branch --show-current)"
if [[ "$current" != "$branch" ]]; then
  echo "Wrong checked-out branch: $current (expected $branch). Stop." >&2
  exit 2
fi
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Dirty worktree; preserve existing work and resolve before syncing." >&2
  exit 2
fi
# Fetch both gate branches on EVERY task start, even for main documentation work.
git fetch --prune origin main dev "$branch"
# Do not reset, rebase, or force-push. Refuse non-fast-forward local divergence.
git pull --ff-only origin "$branch"
if [[ "$branch" == "main" ]]; then
  echo "Main-only documentation: fetched dev for inspection; NOT merging dev into main."
  git log --oneline --max-count=10 origin/main..origin/dev || true
elif [[ "$branch" == "dev" ]]; then
  git merge --no-edit origin/main
  git merge-base --is-ancestor origin/main HEAD
else
  # Main first keeps canonical documentation in scope; dev second brings tested
  # cross-workstream integration changes into this isolated working branch.
  git merge --no-edit origin/main
  git merge --no-edit origin/dev
  git merge-base --is-ancestor origin/main HEAD
  git merge-base --is-ancestor origin/dev HEAD
fi
printf 'PREWORK_SYNC_OK branch=%s main=%s dev=%s head=%s utc=%s\n' \
  "$branch" "$(git rev-parse origin/main)" "$(git rev-parse origin/dev)" \
  "$(git rev-parse HEAD)" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Record this output in PR/task evidence and rerun affected tests after merge."
