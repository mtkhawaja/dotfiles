---
name: ship
description: Use when the user invokes /ship or asks to get unpushed work ready to ship — review the unpushed changes for bugs, run every gate (lint, unit, e2e), and squash into clean commits with one version bump. Does not push.
---

# Ship

Get unpushed work ready to push. Stop at the first problem you can't fix.
**Never push.**

1. **Review.** `git log --oneline @{u}..HEAD` and `git diff @{u}...HEAD` (no upstream:
   ask for the base). Read the diff for bugs; fix any before continuing.
2. **Gate.** Run lint, unit tests, and the full e2e suite, using the project's own
   commands (CLAUDE.md, package scripts, Makefile). Run them unpiped or under
   `set -o pipefail` so no failure is hidden. On a failure, fix the root cause and
   rerun every gate.
3. **Squash.** Fold into clean logical commits that each stand alone, with exactly
   ONE version bump across the set (skip if the project has no version). Rewrite only
   unpublished commits, following the `scr` skill's inspect and rewrite-safely steps.

Report each gate's command and result, and the final `git log --oneline @{u}..HEAD`.
