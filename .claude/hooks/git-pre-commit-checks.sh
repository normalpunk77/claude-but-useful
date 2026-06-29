#!/bin/bash
# pre-commit (git-side) secret gate. The Claude Code hook `never-secrets.sh` reads Claude's
# JSON stdin; this one reads the staged diff directly, so it works for ANY `git commit`
# regardless of client. Keep the two patterns in sync.
#
# Exit non-zero => commit blocked.
set -uo pipefail

DIFF=$(git diff --staged 2>/dev/null)
[[ -z "$DIFF" ]] && exit 0

if echo "$DIFF" | grep -qE '(sk-ant-[a-zA-Z0-9_-]{20,}|sk-proj-[a-zA-Z0-9_-]{20,}|sk-[a-zA-Z0-9]{32,}|AKIA[0-9A-Z]{16}|gh[pousr]_[a-zA-Z0-9]{30,}|"?api[_-]?key"?[[:space:]]*[:=][[:space:]]*"[a-zA-Z0-9_-]{20,}")'; then
  echo "pre-commit BLOCKED: staged diff matches a secret pattern (Anthropic/OpenAI/AWS/GitHub/api_key)." >&2
  echo "Remove the secret from the diff. Keep secrets in env vars or a secret manager, never in git." >&2
  exit 1
fi
exit 0
