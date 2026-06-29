#!/bin/bash
# Stop hook: when a session ends with a dirty tree, log it and warn — but do NOT auto-stash.
#
# Auto-stashing from a hook is the wrong default: `git stash push -u` silently sweeps
# untracked files (e.g. brand-new notes) into a stash invisible to `ls`/`git status`, and the
# next session sees a clean tree and assumes nothing was lost — the "where did my file go?"
# failure. Instead we warn loudly and write a manifest the next SessionStart can surface; the
# files stay on disk where the next session will see them and decide.
#
# Skip with SKIP_DIRTY_LOG=1.
set -uo pipefail

[[ "${SKIP_DIRTY_LOG:-0}" == "1" ]] && exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

DIRTY=$(git status --porcelain 2>/dev/null | head -1)
[[ -z "$DIRTY" ]] && exit 0

REPO=$(git rev-parse --show-toplevel)
LOG_DIR="$REPO/.git/claude-tidy"
LOG="$LOG_DIR/last-session-dirty.txt"
mkdir -p "$LOG_DIR"

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "?")
TS=$(date '+%Y-%m-%d %H:%M:%S')
COUNT=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

{
  echo "Session ended dirty at $TS"
  echo "Branch: $BRANCH ($SHA)"
  echo "$COUNT file(s) modified or untracked:"
  echo ""
  git status --porcelain 2>/dev/null
} > "$LOG"

echo "[tidy] tree was dirty at session end ($COUNT files). NOT auto-stashing." >&2
echo "  → manifest at .git/claude-tidy/last-session-dirty.txt" >&2
echo "  → the files are still on disk; the next session will surface them." >&2
echo "  → for a manual stash:  git stash push -u -m 'wip-<desc>'" >&2

exit 0
