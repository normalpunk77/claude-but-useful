#!/bin/bash
# Pre-commit hook: warn on source files over WARN_THRESHOLD lines, block on any over
# ERROR_THRESHOLD lines. Large files become drift hotspots — agents (and humans) lose
# track of them. Splitting early keeps every file reviewable in one pass.
#
# Thresholds and the override are env-configurable:
#   WARN_THRESHOLD=300   ERROR_THRESHOLD=500   ALLOW_LARGE_FILE=1 (bypass, explicit only)
set -euo pipefail

if [[ "${ALLOW_LARGE_FILE:-0}" == "1" ]]; then exit 0; fi

WARN_THRESHOLD="${WARN_THRESHOLD:-300}"
ERROR_THRESHOLD="${ERROR_THRESHOLD:-500}"
FAILED=0

while IFS= read -r f; do
  case "$f" in
    *.swift|*.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.py|*.go|*.rs|*.rb|*.java|*.kt|*.kts|*.c|*.cc|*.cpp|*.h|*.hpp|*.cs|*.php|*.scala|*.vue|*.svelte) ;;
    *) continue ;;
  esac
  if [[ ! -f "$f" ]]; then continue; fi

  CURRENT=$(wc -l < "$f" | tr -d ' ')
  if [[ $CURRENT -gt $ERROR_THRESHOLD ]]; then
    echo "pre-commit BLOCKED: '$f' is $CURRENT lines (threshold $ERROR_THRESHOLD)." >&2
    echo "  → Files over $ERROR_THRESHOLD LOC drift; split before committing." >&2
    echo "  → Override (rare, explicit): ALLOW_LARGE_FILE=1 git commit ..." >&2
    FAILED=1
  elif [[ $CURRENT -gt $WARN_THRESHOLD ]]; then
    echo "pre-commit WARN: '$f' is $CURRENT lines (warn $WARN_THRESHOLD). Consider splitting before it crosses $ERROR_THRESHOLD." >&2
  fi
done < <(git diff --staged --name-only --diff-filter=ACM)

exit $FAILED
