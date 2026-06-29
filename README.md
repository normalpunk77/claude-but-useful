# claude-but-useful

A drop-in set of **Claude Code hooks** + the **`handoff` skill** that make AI-paired coding
safer and less forgetful. Copy the `.claude/` folder into any project and you get guardrails
that fire automatically — block secrets and commits to `main`, keep files small, auto-format
edits, surface a dirty tree, and re-inject engineering discipline every turn.

Everything here is **project-agnostic**. No language lock-in, no proprietary tooling — just
git, bash, and (for two hooks) `jq`.

## What's inside

```
.claude/
├── settings.json          # wires the hooks into Claude Code
├── hooks/
│   ├── README.md          # full table of every hook + env knobs
│   ├── session-start-tidy.sh
│   ├── inject-discipline.sh
│   ├── inject-system-mandate.sh
│   ├── never-commit-to-main.sh
│   ├── never-secrets.sh
│   ├── format-after-edit.sh
│   ├── session-end-tidy.sh
│   ├── git-pre-commit-checks.sh
│   ├── check-file-size.sh
│   └── tidy.sh
└── skills/
    └── handoff/           # cross-session handoff skill (write/read a resume doc)
        ├── SKILL.md
        └── agents/openai.yaml
.pre-commit-config.yaml    # cross-client commit gates (secrets, file-size, conventional commits)
```

## The hooks (at a glance)

- **Every turn** — re-inject a *read-before-write / plan / verify* reminder and a *build for the
  whole product, not to pass one test* mandate, so they don't fade on long conversations.
- **Before any `git commit`/`push`** — block commits to `main`/`master`, block any staged diff
  that contains a secret (Anthropic / OpenAI / AWS / GitHub keys, `api_key=` assignments).
- **After every edit** — auto-format the touched file (swiftformat / prettier / ruff / black /
  gofmt / rustfmt — whichever is installed).
- **At session start/end** — surface a dirty tree so you never layer new edits on unfinished
  work, and never silently auto-stash files away.
- **At commit time (any client)** — a file-size gate (warn over 300 LOC, block over 500) and a
  git-side secret scan, plus Conventional-Commits message enforcement.

See [`.claude/hooks/README.md`](.claude/hooks/README.md) for the full table and every env knob.

## The `handoff` skill

Tool-agnostic session handoff. When you're pausing or switching machines/tools, it commits +
pushes your work, then writes a structured resume document to `~/.handoff/` and hands you a
copy-paste prompt to bootstrap the next session — instead of re-reading the whole transcript.
On the next session it auto-detects and consumes the matching handoff.

## Install

1. **Copy the kit into your project root:**

   ```bash
   cp -R claude-but-useful/.claude your-project/.claude
   cp claude-but-useful/.pre-commit-config.yaml your-project/.pre-commit-config.yaml
   chmod +x your-project/.claude/hooks/*.sh
   ```

   (If you already have a `.claude/settings.json`, merge the `hooks` block instead of overwriting.)

2. **Restart Claude Code** in that project so it picks up the hooks.

3. **(Optional but recommended) wire the cross-client commit gates:**

   ```bash
   pipx install pre-commit          # or: brew install pre-commit
   cd your-project
   pre-commit install --install-hooks --hook-type commit-msg
   ```

4. **Dependencies:** `git` (required), `jq` (for two hooks: `brew install jq`). Formatters are
   optional — each is best-effort and skipped if not installed.

## Customize

- **`inject-discipline.sh` / `inject-system-mandate.sh`** ship as generic templates. Edit the
  reminder text to name your real product, spec/plan paths, and code-intelligence tools.
- **Protected branches** — edit `PROTECTED` in `never-commit-to-main.sh` if you also protect
  `dev`, or your trunk has a different name.
- **Thresholds / behavior** — every knob is an env var (see the hooks README): `BASE_BRANCH`,
  `AUTO_PRUNE_MERGED`, `WARN_THRESHOLD`, `ERROR_THRESHOLD`, `ALLOW_LARGE_FILE`, `SKIP_DIRTY_LOG`.

## License

MIT — see [LICENSE](LICENSE).

---

These hooks started life as the guardrails on a real production app and were generalized here so
anyone can drop them into their own project.
