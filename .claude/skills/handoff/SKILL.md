---
name: handoff
description: Generate or consume a cross-session handoff file so work can resume seamlessly in a new/other session without re-reading the entire transcript. Use when the user requests a handoff, says they're switching sessions, pausing, or continuing elsewhere — or when context is approaching the model's window limit.
---

# Handoff

Hand a session off to another session (same tool, different tool, different machine) without losing continuity. Replaces "I'll just re-read the whole transcript" with a structured, machine-parseable resume document.

**Language.** Write the handoff's human-readable prose AND the copy-paste resume prompt in the **language the user is currently speaking**. Keep the YAML frontmatter keys and machine field values in English; translate only the prose sections and the resume prompt.

## When to load this skill

User-intent triggers (load eagerly):
- `/handoff` (typed verbatim)
- "handoff", "do a handoff", "generate a handoff"
- "I'm switching sessions", "I'll continue in another session", "continue later"
- "save the context", "pause here", "I'm done for now", "wrap up"
- "I'll come back to this tomorrow", "let's resume this later"
- The user starts a new session and there's a recent file under `~/.handoff/` (auto-consume — see Mode B)

System-intent triggers (consider loading):
- Context token count is ≥80% of the model's window (prefer writing a handoff over auto-compaction; auto-compact is lossy, handoff is structured)
- A compaction is recommended at a phase boundary
- User is about to run a long/destructive operation and might want a restore point

## Two modes

### Mode A — WRITE a handoff (leaving the session)

Produce `~/.handoff/<project-slug>-session-<timestamp>-<slug>.md` with complete state.

### Mode B — READ a handoff (entering a session)

Detect an existing handoff, parse it, verify freshness, and resume.

---

## Mode A — Writing a handoff

**Steps, in order. Parallelize the captures where independent.**

1. **Resolve project root.**
   - `git rev-parse --show-toplevel` from cwd. If not a git repo, use cwd.
   - Hold as `$ROOT`.
   - **If the session is GENERAL / meta** (works across the machine, rooted at `~`, not tied to one repo — config, memory, skills, cross-repo ops): set `project: general` and `project_root: ~` in the frontmatter, and use `general` as the filename slug. Do not pin it to whatever repo happened to be touched.

2. **Persist the work so the next session can resume from the branch (auto-commit + push). Do this FIRST, before capturing git state.**
   This is the core promise of a handoff: the next session may open a **fresh worktree from this branch**, so anything not committed AND pushed is **lost** — and an unpushed worktree never auto-cleans, becoming sprawl. Committing + pushing fixes both at once.
   - Resolve the branch: `git -C $ROOT rev-parse --abbrev-ref HEAD`.
   - **Skip entirely** for general/meta sessions or non-git roots (nothing to persist).
   - **If on a protected branch (`main` / `master` / `dev`):** do NOT auto-commit. Surface in Handoff Caveats that uncommitted changes exist on a protected branch and let the user decide.
   - **Otherwise, if dirty** (`git -C $ROOT status --porcelain` non-empty): stage all (`git -C $ROOT add -A`), commit a checkpoint with a message valid for your commit gate (e.g. Conventional Commits: `git -C $ROOT commit -m "chore: handoff checkpoint — <slug>"`), then push (`git -C $ROOT push` — or `git -C $ROOT push -u origin HEAD` if no upstream).
   - **If the commit or push FAILS** (commit gate red, push rejected, etc.): **STOP.** Report the real failure to the user and do NOT write a handoff that claims a clean, resumable state — a handoff over un-persisted work is worse than none. Let the user fix/decide, then retry.
   - **If already clean:** nothing to do; the branch already holds the work.

3. **Prepare path.**
   - Directory: **`~/.handoff/`** — ALWAYS this absolute path, regardless of project or cwd (create if missing). Centralized so any session, opened anywhere, finds it. Do NOT use a per-project `.handoff/`.
   - Filename: `<project-slug>-session-YYYYMMDD-HHMMSS-<4-random-alphanum>.md` (project slug FIRST so handoffs from different repos don't collide and are identifiable at a glance).
   - Example: `~/.handoff/myapp-session-20260421-234507-a3f9.md`.

4. **Capture state in parallel.**

   | Field | How to capture |
   |---|---|
   | Git branch | `git -C $ROOT rev-parse --abbrev-ref HEAD` |
   | Git HEAD SHA | `git -C $ROOT rev-parse --short HEAD` |
   | Dirty status | `git -C $ROOT status --porcelain` (empty = clean) |
   | Modified files | parse `git status --porcelain` — `M ` and ` M` paths |
   | Staged files | parse `git status --porcelain` — first column A/M/D |
   | Untracked files | parse `git status --porcelain` — `??` paths |
   | Memory context (optional) | if a memory MCP is configured, search it for the task topic and summarize the top results |
   | Loaded skills | list every skill whose `SKILL.md` you read this session |
   | MCPs used | list every MCP server you called, with a one-line purpose each |
   | Active subagents | any in-flight threads — IDs + last reported status |

5. **Assemble the file.** Structure is binding — do not deviate:

   ```markdown
   ---
   schema: handoff/v1
   session_id: <session id or "unknown">
   created_at: <ISO-8601 timestamp>
   created_by: claude-code | codex | other
   model: <model id>
   reasoning: <reasoning effort, if applicable>
   project: <project slug>
   project_root: <absolute path>
   git_branch: <branch>
   git_sha: <short SHA>
   git_dirty: <true | false>
   modified_files: [path1, path2, ...]
   staged_files: [path1, ...]
   untracked_files: [path1, ...]
   loaded_skills: [coding-standards, ...]
   mcps_used: [serena, ...]
   active_subagents: [{name: "code_mapper", status: "completed"}, ...]
   resume_hint: <one-line "do this first" for the next session>
   ---

   ## TL;DR for the next session
   <2-3 sentences. Current objective, immediate next action, any blockers.>

   ## Project Context
   - Name: <project>
   - Path: <absolute path>
   - Stack: <1-2 line summary — frameworks, languages, notable libs>
   - State: <where work stands overall — not this turn, the whole initiative>

   ## Persistent Memory
   <Compact summary of relevant memories if a memory MCP is configured. Otherwise "no memory MCP configured".>

   ## Work Completed This Session
   Grouped by file or module. Each entry: what changed + why (one sentence each).
   - `src/path/to/file.ts` — <change + reason>
   - ...

   ## Git State
   - Branch: <branch>
   - HEAD: <short SHA>
   - Clean: <true | false>
   - Modified (uncommitted): <list or "none">
   - Staged: <list or "none">
   - Untracked: <list or "none">

   ## Current Focus
   <The exact thing in progress. If mid-edit, which file and roughly where. If mid-test-run, what command and what was the last output.>

   ## Open Issues & Risks
   - <Issue or risk, one line each>
   - ...

   ## Next Steps (ordered)
   1. <First concrete action for the new session — command-level specific>
   2. <Second action>
   3. <...>

   ## Key Files
   Files that matter most for continuation. One line per file.
   - `path/to/file.ts` — <why it matters>
   - ...

   ## Handoff Caveats
   - <Anything the next session must NOT do, assumptions current session made that might be wrong, rules that were particularly active>
   ```

6. **Write the file.**

7. **Output the file path + a one-sentence confirmation** to the user. Do not narrate the file contents — they're in the file.

8. **ALSO output a copy-paste-ready resume prompt** to the user in chat, immediately after the confirmation, as a single fenced code block — **no marker lines** (the code block already gives a copy button). It must include:

   - The **ABSOLUTE** handoff path `~/.handoff/<file>.md` — always absolute (the next session may open in a different cwd; relative paths are the #1 resume failure).
   - **Project session:** also `Work in <ABSOLUTE project_root> (branch <branch>).` **General / meta session** (rooted at `~`, not tied to one repo): do NOT pin any project cwd — say it's a general session and point only to the handoff.
   - A 2–3 sentence TL;DR of where work stands (in the user's current language — see the Language rule above).
   - The first concrete next action.
   - Any critical caveats the next session must respect.

   Example:

   ```
   General meta session (root ~, no fixed project). Read the handoff: ~/.handoff/general-session-20260421-234507-a3f9.md. TL;DR: <2-3 sentences>. Start by: <first action, or "nothing in flight">. Caveats: <list>.
   ```

9. **If a memory MCP is configured**, also save a brief memory about the handoff itself: "Session handoff written at <path> on <date>. Next step: <resume_hint>." This step is optional — skip it cleanly if no memory MCP is available.

---

## Mode B — Reading a handoff (new-session bootstrap)

Run this as part of session bootstrap, AFTER repo resolution and BEFORE heavy code-intelligence setup.

**Steps:**

1. **Scan** `~/.handoff/` for `*.md`, sorted by mtime descending. Then FILTER to the current project: match each file's frontmatter `project_root` against `git rev-parse --show-toplevel` (or the `project` slug / filename prefix). Pick the newest file that matches the CURRENT project — never another project's handoff.

2. **Skip** if:
   - No matching files.
   - The newest is older than 24h AND the user hasn't said "resume" / "continue" / etc.
   - The user explicitly said "fresh start" / "ignore handoff" / "start over".

3. **Load** the newest matching file. Parse YAML frontmatter into structured fields.

4. **Verify git freshness:**
   - Current branch vs `git_branch`: if different → warn the user, ask whether to switch or continue on the current branch.
   - Current HEAD vs `git_sha`: if different but same branch → note "branch advanced N commits since handoff" and inspect those commits to understand what changed. If they relate to the handoff's work, incorporate; otherwise note divergence.
   - Different branch entirely → stop and ask the user before consuming.

5. **Reload the same skill set.** For each name in `loaded_skills`, read `~/.claude/skills/<name>/SKILL.md` in full (or your tool's skills directory). This ensures behaviour parity.

6. **Announce continuation** in one sentence to the user:
   > "Resuming from handoff (`<filename>`, <age>). Current focus: <TL;DR>. Starting with: <resume_hint>."

7. **Execute** Next Step #1 from the handoff without further confirmation, unless your project's rules gate the action (e.g. ask before destructive operations).

8. **Archive** the consumed handoff: move it to `~/.handoff/archive/`. Do not delete — keeps a history trail for debugging. Periodically clean archives older than 30 days.

---

## Relationship to other skills

- **Compaction:** when a compaction is recommended at a phase boundary, prefer writing a handoff first — handoff is structured; auto-compact is lossy.
- **Verification:** do NOT skip verification just because a handoff is imminent. If work is in-flight and unverified, say so in "Open Issues".
- The handoff file itself should be clean markdown. One code block per list item max; no prose duplication.

## Edge cases

- **Not a git repo:** skip git fields in frontmatter (or set to `null`), use cwd as `project_root`. Still write the handoff.
- **No memory MCP:** the Persistent Memory section reads "no memory MCP configured" — handoff still written.
- **User running subagents in flight:** list them with last known status; do not block waiting for their completion. The next session can poll.
- **User has uncommitted changes on main/master:** MUST surface this in `Handoff Caveats` — the next session might accidentally commit/push them.
- **Multi-worktree setup:** still resolve `$ROOT` via `git rev-parse --show-toplevel` from the current cwd. But ALL handoffs go to the single central `~/.handoff/` — never per-worktree. The project slug + branch in the file disambiguate.
- **Interrupted mid-edit (unsaved buffer):** not capturable — note "editor buffer may contain unsaved changes" in Handoff Caveats.

## Anti-patterns (NEVER)

- Don't paste large code blocks into the handoff — it's a map, not a mirror.
- Don't duplicate the conversation transcript.
- Don't write before capturing all the state (an incomplete handoff is worse than none).
- Don't assume the next session is the same tool — stay tool-agnostic in the body (frontmatter declares `created_by` for disambiguation).
- Don't "optimize" by skipping frontmatter fields that are `null`/empty — write them as `null`/`[]` so the consumer knows the field was considered.
- Don't delete the handoff file after reading — archive it.

## Quick-reference: trigger-to-mode map

| User intent / system state | Mode |
|---|---|
| User types `/handoff` or mentions handoff keywords | A — write |
| Context ≥80% of window, user hints at break | A — write |
| Compaction recommended at a phase boundary | A — write (preferred over compaction) |
| New session bootstrap, fresh `~/.handoff/*.md` exists, <24h old | B — read |
| User says "resume" / "continue from yesterday" / "pick up where we left off" | B — read |
| User explicitly says "fresh start" / "ignore handoff" | Skip B |
