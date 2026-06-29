#!/bin/bash
# Working-tree status report — one command that tells the truth about the repo across
# branches, worktrees, and stashes. Read-only by default.
#
# Usage:
#   .claude/hooks/tidy.sh            report only
#   .claude/hooks/tidy.sh --prune    also prune empty worktrees + run git gc --auto
#
# Env:
#   BASE_BRANCH=main             base branch for the "merged → safe to delete" check (auto-detected)
#   PRUNE_OLD_STASHES=1          with --prune, also drop stashes older than 90 days (destructive, opt-in)
set -uo pipefail

PRUNE=0
[[ "${1:-}" == "--prune" ]] && PRUNE=1

REPO=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "Not in a git repo." >&2; exit 1; }
cd "$REPO" || exit 1

BASE_BRANCH="${BASE_BRANCH:-}"
if [[ -z "$BASE_BRANCH" ]]; then
  if git show-ref --verify --quiet refs/heads/main; then BASE_BRANCH="main";
  elif git show-ref --verify --quiet refs/heads/master; then BASE_BRANCH="master";
  else BASE_BRANCH="main"; fi
fi

echo ""
echo "=================================================================="
echo "  Tree status — $(date '+%Y-%m-%d %H:%M:%S')"
echo "=================================================================="
echo ""

# 1. Current branch + dirty status
BRANCH=$(git rev-parse --abbrev-ref HEAD)
DIRTY_COUNT=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
LAST_COMMIT_AGE=$(git log -1 --format='%cr' 2>/dev/null || echo "no commits")

echo "▕ CURRENT BRANCH"
echo "   $BRANCH (last commit: $LAST_COMMIT_AGE)"
if [[ $DIRTY_COUNT -gt 0 ]]; then
  echo "   ⚠ $DIRTY_COUNT uncommitted file(s):"
  git status --porcelain | head -10 | sed 's/^/      /'
  [[ $DIRTY_COUNT -gt 10 ]] && echo "      ... and $((DIRTY_COUNT - 10)) more"
else
  echo "   ✓ tree is clean"
fi
echo ""

# 2. Active worktrees
echo "▕ WORKTREES"
WT_COUNT=$(git worktree list | wc -l | tr -d ' ')
git worktree list | sed 's/^/   /'
echo "   ($WT_COUNT total)"
echo ""

# 3. Stashes
echo "▕ STASHES"
STASH_COUNT=$(git stash list | wc -l | tr -d ' ')
if [[ $STASH_COUNT -eq 0 ]]; then
  echo "   ✓ none"
else
  git stash list | head -10 | sed 's/^/   /'
  [[ $STASH_COUNT -gt 10 ]] && echo "   ... and $((STASH_COUNT - 10)) more"
  OLD=$(git stash list --format='%ci %gd %gs' 2>/dev/null | awk -v cutoff="$(date -v-30d +%Y-%m-%d 2>/dev/null || date -d '30 days ago' +%Y-%m-%d)" '$1 < cutoff {print $2}' | wc -l | tr -d ' ')
  [[ $OLD -gt 0 ]] && echo "   ⚠ $OLD stash(es) older than 30 days — consider git stash drop"
fi
echo ""

# 4. Local feature branches and merged status
echo "▕ LOCAL BRANCHES (excluding main/master)"
LOCAL_BRANCHES=$(git for-each-ref --format='%(refname:short)' refs/heads/ | grep -vE '^(main|master)$' | head -20)
if [[ -z "$LOCAL_BRANCHES" ]]; then
  echo "   ✓ no feature branches"
else
  while IFS= read -r br; do
    [[ -z "$br" ]] && continue
    AGE=$(git log -1 --format='%cr' "$br" 2>/dev/null || echo "?")
    MERGED=""
    if git merge-base --is-ancestor "$br" "$BASE_BRANCH" 2>/dev/null; then MERGED=" [merged into $BASE_BRANCH — safe to delete]"; fi
    echo "   $br ($AGE)$MERGED"
  done <<< "$LOCAL_BRANCHES"
fi
echo ""

# 5. Prune if requested
if [[ $PRUNE -eq 1 ]]; then
  echo "▕ PRUNE"
  echo "   running git worktree prune..."
  git worktree prune --verbose 2>&1 | sed 's/^/      /' | head -10
  echo "   running git gc --auto..."
  git gc --auto 2>&1 | head -3 | sed 's/^/      /'
  if [[ "${PRUNE_OLD_STASHES:-0}" == "1" ]]; then
    echo "   pruning stashes older than 90 days..."
    git stash list --format='%ci %gd' 2>/dev/null | awk -v cutoff="$(date -v-90d +%Y-%m-%d 2>/dev/null || date -d '90 days ago' +%Y-%m-%d)" '$1 < cutoff {print $2}' | tac | while read -r ref; do
      [[ -n "$ref" ]] && git stash drop "$ref" 2>&1 | sed 's/^/      /'
    done
  else
    echo "   (skipping stash prune — set PRUNE_OLD_STASHES=1 to enable)"
  fi
  echo ""
fi

echo "=================================================================="
[[ $PRUNE -eq 0 ]] && echo "  Run with --prune to actually clean up." || echo "  Done."
echo "=================================================================="
