# claude-but-useful

**A drop-in pack of Claude Code hooks + two skills (`handoff` and `wrap-feature`) that make
working with AI on your code safer and less forgetful.** Drop it into any project and it quietly stops the dumb stuff —
committing secrets, committing to `main`, files ballooning out of control — auto-formats your
edits, surfaces a messy working tree, and nudges the AI to read before it writes.

> **You could open the files and hooks and analyze them, or just be a normal person and ask
> Claude to analyze the repo for you. It'll know where to put everything if you find it useful.**

It's all plain **git + bash** (plus `jq` for two hooks). No language lock-in, no proprietary
tooling, nothing to learn.

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
    ├── handoff/           # cross-session handoff skill (write/read a resume doc)
    │   ├── SKILL.md
    │   └── agents/openai.yaml
    └── wrap-feature/      # end-of-task finish: verify, red-team, commit, open a PR
        └── SKILL.md
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

## The `wrap-feature` skill

The end-of-task finish. When you say "done", "wrap this up", or "ready to ship", instead of a
careless commit it runs a real quality pass and **lands the work as a Pull Request**:

1. Captures the exact scope (the diff vs. the trunk + working tree).
2. Proves it runs — discovers and runs your real checks (typecheck / lint / tests / `pre-commit`)
   and shows the output, not "should work".
3. Checks the change is right for **every** user, not just the test fixtures — verified with a
   fresh input.
4. Re-checks the blast radius (callers / flows that depend on what changed).
5. Cleans the diff (no debug prints, scratch files, TEMP markers).
6. Red-teams the change — and **won't re-review** work it already reviewed (an idempotent ledger
   stored in `git notes`, so it's not wasted effort across sessions/worktrees).
7. Commits with a Conventional-Commit message, pushes the branch, and **opens (or reuses) a PR**.

### This is a PR-based workflow — set git up for it

`wrap-feature` assumes a sane, branch-and-PR git setup. It will **never** push work straight onto
your trunk. For it to behave, your repo should be wired like this:

- **A protected trunk** (`main`, or `main` + a `dev` integration branch). Protect it on the host
  (GitHub branch protection) so nothing lands without a PR + green CI. The `never-commit-to-main`
  hook in this kit enforces the same rule locally.
- **Feature branches, always.** Each piece of work lives on its own `feat/…` / `fix/…` branch;
  `wrap-feature` opens a PR from it into the trunk. If you're sitting on the trunk, it branches
  first rather than committing there.
- **PRs + CI as the gate.** Work lands by merging the PR once checks pass — not by direct push.
  If your project uses an auto-merge label or a fixed target branch, tell Claude and it follows
  that convention.
- **Worktrees for isolation (recommended).** One branch per
  [git worktree](https://git-scm.com/docs/git-worktree) means parallel tasks never clobber each
  other's working tree. The `git notes` red-team ledger is shared across all worktrees (notes
  live in the common `.git`), so a review done in one worktree is trusted in another. The
  `session-start-tidy` / `session-end-tidy` hooks keep those worktrees and branches honest.

If your project doesn't use PRs at all, `wrap-feature` still does the full verification pass — it
just pushes the branch and tells you so explicitly instead of opening a PR.

## Use it (the lazy way) ✅

1. Clone or download this repo somewhere on your machine.
2. Open **your** project in Claude Code.
3. Tell Claude something like:

   > *"Look at the `claude-but-useful` repo at `<path-or-URL>` and set it up in this project."*

That's it. Claude reads the structure, copies the right files into the right places, makes the
hooks executable, and (if you want) wires up pre-commit. Not sure what a guard does? Ask it to
explain that first — then decide what to keep.

## Install it yourself (manual)

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
