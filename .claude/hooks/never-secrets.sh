#!/bin/bash
# PreToolUse(Bash) hook: block `git commit` when the staged diff contains a secret.
#
# Catches the most common leak patterns:
#   - sk-ant-…          Anthropic API keys
#   - sk-proj-… / sk-…  OpenAI API keys
#   - AKIA[0-9A-Z]{16}  AWS access key IDs
#   - ghp_… / gho_…     GitHub tokens
#   - generic  api_key = "…" / api-key: "…"  assignments
#
# Exit 2 tells Claude Code to BLOCK the tool call and feed stderr back to the model.
# This is advisory-but-enforced inside Claude Code; the matching pre-commit hook is the
# cross-client gate that fires on any `git commit`.
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
if echo "$CMD" | grep -qE '^[[:space:]]*git[[:space:]]+commit'; then
  DIFF=$(git diff --staged 2>/dev/null)
  if echo "$DIFF" | grep -qE '(sk-ant-[a-zA-Z0-9_-]{20,}|sk-proj-[a-zA-Z0-9_-]{20,}|sk-[a-zA-Z0-9]{32,}|AKIA[0-9A-Z]{16}|gh[pousr]_[a-zA-Z0-9]{30,}|"?api[_-]?key"?[[:space:]]*[:=][[:space:]]*"[a-zA-Z0-9_-]{20,}")'; then
    echo "BLOCKED: staged diff matches a secret pattern (Anthropic/OpenAI/AWS/GitHub/api_key)." >&2
    echo "Remove the secret from the diff. Keep secrets in env vars or a secret manager, never in git." >&2
    exit 2
  fi
fi
exit 0
