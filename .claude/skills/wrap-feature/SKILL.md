---
name: wrap-feature
description: Use this when a user signals an implementation is finished and wants it wrapped up, verified, committed, shipped, or handed off. Trigger on phrases like "done with X," "finished the Y feature," "that's the last change," "wrap it up," "wrap up this branch," "close this out," "run your end-of-task checks," "verify everything," "double-check before I push," "we good to ship?," or "ready to commit/hand off" — after any feature, bugfix, or logic change. This runs the final quality pass before work is declared complete: confirms it actually runs, is correct for the real app and every user (not just passing a test), checks impact on callers, cleans the diff, red-teams the change, and commits + opens a PR. Prefer this over a plain commit or generic review whenever real code was just completed. Do not use for starting/writing new code, mid-task debugging, text wrapping/word-wrap, ending a chat session, or trivial typo/comment/one-line edits.
---

# wrap-feature

The whole point of this skill: when you stop working, the work must be **truly done in a real product used by real people** — not "done enough to look done." This is the same mandate that should be on your mind the whole time: you are not building for the developer in the chat, and not to make a snippet or a test pass. You are building for software that ships to many users, including inputs you will never see.

So this is not a mechanical checklist you race through. Each step exists to answer one question: **is this change right for the whole app and for every user, or am I about to ship a mistake?** If you can't answer "yes, and here's the proof," you are not done.

## Stay light — this must be useful, not bureaucratic

A finish that takes longer than the work it's checking is a failed finish. So:

- **Trivial edits don't need this.** A typo, a comment, a one-line config — say so in one line and skip. Running the full finish on a one-character change is the kind of ceremony that makes people stop trusting the tool.
- **Every step can be N/A** when it genuinely doesn't apply — say why in one line and move on. A refactor fully covered by existing tests doesn't need a new test; a pure-docs change has no blast radius. Don't invent work to look thorough.
- **The red-team is idempotent** (see below) precisely so you never re-run an expensive review on something already reviewed.
- **Default to fast checks**, not a full app build/launch, unless the change really demands it.

The goal is the smallest amount of work that gives real confidence — and no less.

## When to run

Run at the end of a real implementation: a new feature or behavior, a logic change, a bugfix, anything over ~50 lines or touching more than a couple of files — before you say "done," before a commit you intend as final, or before a handoff.

Propose it yourself when you're about to claim completion, even if the user didn't ask. If they decline, respect that.

## The finish, step by step

Run these in order. Each one needs **evidence**, not "should work." If a step fails, you are not done — fix it and re-check. Two failed fix attempts on the same problem → revert and re-plan; don't stack patch on patch.

**1. Capture the scope.** Establish exactly what you're finishing: `git diff $(git merge-base HEAD main 2>/dev/null || git merge-base HEAD master)..HEAD` plus the working tree (`git status --porcelain`, `git diff`). Name the files and the behavior this touches. If you can't name the scope, you don't understand the change yet.

**2. Prove it runs.** Run the project's REAL checks for the touched scope and show the actual output. Discover them rather than assuming: a `pre-commit` config, `make` targets, `package.json` scripts (typecheck/lint/test), or the language toolchain. Run the cheap checks first (typecheck, lint), then tests. If the stack has no runnable check, say so explicitly — don't pretend. Default to fast checks; only build/launch the full app when the change can't be trusted without it.

**3. A test for the new behavior.** There should be a test that fails without your change and passes with it. If you didn't add one, justify N/A in one line (pure docs/config, or a refactor already covered by tests you just ran). "Hard to test" is not a justification — it's a smell.

**4. Right for the whole app — the heart of the finish.** This is where mistakes hide, so go deep. Confirm each, with evidence, not vibes:
   - **Real intent, not test-targeting.** The change solves the actual need for *every* user. It does not recognize known inputs / fixtures to return the expected answer. Litmus: *would this be correct for an input you have never seen?* If not, you memorized the test instead of solving the problem.
   - **Verified with a fresh input.** Exercise it with at least one input you did NOT use while developing, and show what happened.
   - **Every changed line traces to the request.** No speculative features, no "flexibility" nobody asked for, no error handling for impossible cases. If a line doesn't serve the actual goal, cut it.
   - **Integrated into the whole app.** The change plugs into the real flows it's meant to serve — name them — and you've confirmed those flows still hold. It isn't a correct-looking island that nothing actually calls.
   - **No masking.** No swallowed errors, no type-coercion tricks, no hardcoded outputs, nothing that hides a failure to make the surface look green.
   - **If the request itself is wrong for the app, say so** instead of shipping it. Finishing a bad instruction cleanly is still shipping a mistake.

   If any of these is unmet, or you can only say "should," you are not done.

**5. Blast radius.** For the symbols/functions you changed, re-check their callers and the flows that depend on them — with the tools available (LSP, a code-intelligence/impact graph, or grep). Name what you checked and confirm it still holds. A change that's locally correct but breaks a caller is not done.

**6. Diff hygiene.** Re-read the full diff end to end. Remove debug prints, scratch files, sample/mock data, and any `TEMP(`/`THROWAWAY` markers — or justify each in one line. Nothing built only to verify the work should ship.

**7. Red-team — idempotent (see next section).** Adversarially try to break the change. But skip it if the current state was already reviewed — re-reviewing unchanged work is wasted effort, which is the whole reason the ledger exists.

**8. Honest report.** State what you VERIFIED, with the evidence (commands run, outputs, fresh input used). Anything you did not verify, name it as unverified. No rounding "I ran typecheck" up to "everything works."

**9. Finalize — commit, then open the PR.** Commit with a Conventional-Commit-valid message (the `commit-msg` gate rejects others), push the branch, then **open (or reuse) a PR** for it. The finish ends with a PR, not a dangling pushed branch: the work lands through PR + CI review, never a direct push to the trunk. Follow the project's landing convention if it defines one (target branch, labels such as `auto-merge`). If the stack doesn't use PRs, push and say so explicitly. **Never** commit or push the work directly onto a protected branch (`main`/`master`/`dev`): if you're sitting on one, branch first; if you genuinely can't, surface it and let the user decide. Pushing also lets the worktree go clean so it can be cleaned up later instead of lingering.

## Red-team idempotency (git notes ledger)

Re-running an adversarial review on work that was already reviewed and hasn't changed is pure waste — and waste erodes trust in the finish. So track what's been reviewed in a git notes ledger keyed to the commit, visible across all worktrees because notes live in the shared `.git`.

**Check before reviewing.** If the working tree is clean and the current commit already carries a red-team note, the exact state was already reviewed — skip step 7 and say so:

```bash
git diff --quiet && git diff --cached --quiet \
  && git notes --ref=redteam show HEAD >/dev/null 2>&1 \
  && echo "already red-teamed at $(git rev-parse --short HEAD) — skipping" \
  || echo "needs red-team"
```

If the tree is dirty, or HEAD has no note, the current scope is not fully reviewed → run the red-team on the unreviewed work (the delta since the last reviewed commit, or the whole scope if none).

**Stamp after a pass.** Whenever a red-team passes — here in step 7, OR mid-work following your project's red-team rule — record it on the reviewed commit so the next finish can trust it:

```bash
git notes --ref=redteam add -f -m "redteam pass $(date -u +%Y-%m-%dT%H:%M:%SZ)" HEAD
```

Stamp the commit that actually contains the reviewed code: commit the work first, review it, then stamp `HEAD`. The ledger is only trustworthy if every passing review stamps it — that's the single source of truth, so don't review without stamping.

**How to red-team.** Follow your project's review discipline if it has one (e.g. independent multi-agent reviewers, a second-pass reviewer subagent, or a careful adversarial self-review). Adversarially look for the ways this breaks — wrong for some input, a broken caller, a masked failure, a missed edge. Fix every blocking finding before stamping. An honest pass with zero findings is a pass; don't invent issues to look diligent.

## If you're tempted to cut a corner

The pressure to declare done is real, especially late in a task. But a finish that waves work through is worse than no finish — it launders "should work" into "done." When in doubt, run the check and show the output. Evidence before assertions, always.
