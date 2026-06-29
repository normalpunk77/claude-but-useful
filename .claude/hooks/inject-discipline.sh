#!/bin/bash
# UserPromptSubmit hook: re-inject a short engineering-discipline reminder on EVERY turn.
# A single CLAUDE.md note fades over a long conversation; re-injecting it each turn keeps it
# active. Keep it short — this is a nudge, not a manual.
#
# CUSTOMIZE the text below for your project (naming your real spec/plan/contract paths,
# your code-intelligence tools, etc.). The generic version ships with the universals.
cat <<'EOF'
{"additionalContext": "ENGINEERING DISCIPLINE (every turn): (1) READ before WRITE — before editing any function, find its callers/callees with your code-intelligence tools (LSP, grep, references). Editing blind is the #1 cause of 'AI broke working code while making a cosmetic change'. (2) Non-trivial change (≥3 steps, ≥2 files, or any architectural decision)? Briefly plan first: state the approach, the files, and the check that proves it works — then implement. (3) Verify, don't hope: run the build/tests for the touched scope and show real output before claiming done. (4) Patches-on-patches banned — after 2 failed corrections on the same problem, revert and re-plan."}
EOF
