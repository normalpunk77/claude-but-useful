# Hooks

Each hook is a standalone bash script. Claude Code runs them via `.claude/settings.json`; the
commit-time ones also run via `.pre-commit-config.yaml` so they fire for **any** client, not just
Claude Code.

| Hook | Fires on | What it does |
|---|---|---|
| `session-start-tidy.sh` | SessionStart | Reports working-tree state (dirty files, worktrees, stashes) into the agent's context so it never layers edits on a dirty tree. Optional opt-in auto-prune of merged branches (`AUTO_PRUNE_MERGED=1`). |
| `inject-discipline.sh` | UserPromptSubmit | Re-injects a short read-before-write / plan / verify reminder every turn so it doesn't fade on long conversations. **Customize the text per project.** |
| `inject-system-mandate.sh` | UserPromptSubmit | Re-injects a "build for the whole product and its real users, not to pass one test" mandate every turn. **Customize the product name.** |
| `never-commit-to-main.sh` | PreToolUse(Bash) | Blocks `git commit` / `git push` on a protected branch (main/master). Forces feature branches. |
| `never-secrets.sh` | PreToolUse(Bash) | Blocks `git commit` when the staged diff matches a secret pattern (Anthropic / OpenAI / AWS / GitHub / `api_key=`). |
| `format-after-edit.sh` | PostToolUse(Edit\|Write) | Auto-formats the file Claude just touched (swiftformat / prettier / ruff / black / gofmt / rustfmt — whichever is installed). Best-effort; never blocks. |
| `session-end-tidy.sh` | Stop | If the tree is dirty at session end, writes a manifest and warns — but never auto-stashes (auto-stash silently hides untracked files). |
| `git-pre-commit-checks.sh` | pre-commit | Git-side secret scan over the staged diff (the cross-client twin of `never-secrets.sh`, which reads Claude's JSON stdin). |
| `check-file-size.sh` | pre-commit | Warns over `WARN_THRESHOLD` (300) lines, blocks over `ERROR_THRESHOLD` (500). Bypass: `ALLOW_LARGE_FILE=1`. |
| `tidy.sh` | manual | `./tidy.sh` prints a full tree report; `./tidy.sh --prune` cleans empty worktrees + runs `git gc`. |

## Environment knobs

| Var | Default | Effect |
|---|---|---|
| `BASE_BRANCH` | auto (main → master) | Base branch for "merged → safe to delete" checks. |
| `AUTO_PRUNE_MERGED` | `0` (off) | `1` lets SessionStart delete local branches already merged into the base branch. Off by default — deleting branches silently is surprising on a shared repo. |
| `WARN_THRESHOLD` / `ERROR_THRESHOLD` | `300` / `500` | File-size gate thresholds. |
| `ALLOW_LARGE_FILE` | `0` | `1` bypasses the file-size gate for one commit. |
| `SKIP_DIRTY_LOG` | `0` | `1` disables the session-end dirty manifest. |
| `PRUNE_OLD_STASHES` | `0` | With `tidy.sh --prune`, `1` also drops stashes older than 90 days. |

All scripts require `git`; the JSON-emitting hooks (`session-start-tidy.sh`,
`inject-system-mandate.sh`) require `jq`. Install jq with `brew install jq` (macOS) or your
package manager.
