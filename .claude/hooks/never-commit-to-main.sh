#!/bin/bash
# PreToolUse(Bash) hook: block `git commit` / `git push` when the current branch is
# a protected branch (main / master). Forces feature-branch workflow.
#
# Customize PROTECTED below if your trunk has a different name or you also protect `dev`.
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

PROTECTED="main master"

if echo "$CMD" | grep -qE '^[[:space:]]*git[[:space:]]+(commit|push)([[:space:]]|$)'; then
  # symbolic-ref resolves both normal and unborn branches (so the very first commit on main is
  # caught too); fall back to rev-parse for a detached HEAD (which yields "HEAD", not a branch).
  BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null)
  for p in $PROTECTED; do
    if [[ "$BRANCH" == "$p" ]]; then
      echo "BLOCKED: refusing a commit/push on protected branch '$BRANCH'." >&2
      echo "Use a feature branch instead:  git checkout -b feat/<short-desc>" >&2
      exit 2
    fi
  done
fi
exit 0
