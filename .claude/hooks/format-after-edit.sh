#!/bin/bash
# PostToolUse(Edit|Write) hook: auto-format the file Claude just touched, so the agent
# never re-reads its own formatting noise on the next turn. Each formatter is best-effort:
# if the tool isn't installed, the file is left as-is (never blocks the edit).
#
# Add or remove formatters to match your stack.
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
[[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]] && exit 0

case "$FILE_PATH" in
  *.swift)
    command -v swiftformat >/dev/null 2>&1 && swiftformat "$FILE_PATH" >/dev/null 2>&1 || true
    ;;
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.json|*.md|*.css|*.scss|*.html|*.yml|*.yaml)
    if command -v prettier >/dev/null 2>&1; then
      prettier --write "$FILE_PATH" >/dev/null 2>&1 || true
    elif command -v bunx >/dev/null 2>&1; then
      bunx --bun prettier --write "$FILE_PATH" >/dev/null 2>&1 || true
    elif command -v npx >/dev/null 2>&1; then
      npx --no-install prettier --write "$FILE_PATH" >/dev/null 2>&1 || true
    fi
    ;;
  *.py)
    if command -v ruff >/dev/null 2>&1; then
      ruff format "$FILE_PATH" >/dev/null 2>&1 || true
    elif command -v black >/dev/null 2>&1; then
      black -q "$FILE_PATH" >/dev/null 2>&1 || true
    fi
    ;;
  *.go)
    command -v gofmt >/dev/null 2>&1 && gofmt -w "$FILE_PATH" >/dev/null 2>&1 || true
    ;;
  *.rs)
    command -v rustfmt >/dev/null 2>&1 && rustfmt "$FILE_PATH" >/dev/null 2>&1 || true
    ;;
esac
exit 0
