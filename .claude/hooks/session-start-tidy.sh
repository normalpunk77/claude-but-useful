#!/bin/bash
# SessionStart hook: surface working-tree state to the agent so it never layers new edits
# on top of a dirty tree left by a prior session, and (optionally) auto-prune local
# branches that are already merged into the base branch.
#
# Outputs `additionalContext` JSON (built with jq so any content is safely escaped).
#
# Env:
#   BASE_BRANCH=main        base branch used for the merged-branch check (auto-detected if unset)
#   AUTO_PRUNE_MERGED=1     delete local branches already merged into BASE_BRANCH (default: OFF,
#                           report only — deleting branches silently is surprising on a shared repo)
set -uo pipefail

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo '{}'; exit 0; }
command -v jq >/dev/null 2>&1 || { echo '{}'; exit 0; }

# Resolve base branch: explicit env > origin/main > origin/master > current.
BASE_BRANCH="${BASE_BRANCH:-}"
if [[ -z "$BASE_BRANCH" ]]; then
  if git show-ref --verify --quiet refs/remotes/origin/main; then BASE_BRANCH="origin/main";
  elif git show-ref --verify --quiet refs/remotes/origin/master; then BASE_BRANCH="origin/master";
  elif git show-ref --verify --quiet refs/heads/main; then BASE_BRANCH="main";
  else BASE_BRANCH="master"; fi
fi

CUR=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

# --- Optional auto-prune of merged branches (opt-in, never touches live work) ---
if [[ "${AUTO_PRUNE_MERGED:-0}" == "1" ]]; then
  git worktree prune 2>/dev/null || true
  CHECKED_OUT=$(git worktree list --porcelain 2>/dev/null | awk '/^branch /{sub("refs/heads/","",$2); print $2}')
  git branch --merged "$BASE_BRANCH" --format='%(refname:short)' 2>/dev/null | while IFS= read -r b; do
    [[ -z "$b" || "$b" == "main" || "$b" == "master" || "$b" == "dev" || "$b" == "$CUR" ]] && continue
    grep -qx "$b" <<<"$CHECKED_OUT" && continue
    git branch -d "$b" >/dev/null 2>&1 || true
  done
fi

# --- Surface state ---
DIRTY_FILES=$(git status --porcelain 2>/dev/null)
DIRTY=$(printf '%s' "$DIRTY_FILES" | grep -c . || true)
WORKTREES=$(git worktree list 2>/dev/null | wc -l | tr -d ' ')
STASHES=$(git stash list 2>/dev/null | wc -l | tr -d ' ')

if [[ "$DIRTY" -gt 0 ]]; then
  MSG="TREE STATE — DIRTY: $DIRTY uncommitted file(s) from a prior session on '$CUR':
$(printf '%s' "$DIRTY_FILES" | head -10)

Before NEW work, decide: commit / stash / revert. Do NOT layer new edits on unfinished work. ($WORKTREES worktree(s), $STASHES stash(es).)"
else
  MSG="TREE STATE: clean on '$CUR'. $WORKTREES worktree(s), $STASHES stash(es). Proceed."
fi

jq -n --arg ctx "$MSG" '{additionalContext: $ctx}'
