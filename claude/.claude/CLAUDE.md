# Global Claude Code memory

## Communication

Be direct; lead with the answer. Push back on weak ideas instead of agreeing reflexively. Keep all
output concise — prose, commits, docs.

## CLI tools

Unfamiliar tool or unsure of flags? Try `tldr <tool>`, then `<tool> --help`, then `man <tool>`.

## Working style

- **Ask, don't assume.** State assumptions; surface alternatives instead of silently picking one.
  Confirm scope before multi-file changes.
- **Minimal & surgical.** Do exactly what's asked — no unrequested features, abstractions, refactors,
  or design docs/mockups for small changes. Match existing style; don't touch unrelated code. Don't
  create files (docs, scripts, examples) unless asked.
- **Fix root causes.** Never swallow errors or skip/weaken failing tests to make things pass.
- **Verify before claiming done.** Run the project's tests, linters, and build, and show evidence —
  never assert success you haven't observed.
  - Never pipe checks (tests, linters, markdownlint) in a way that hides a non-zero exit; use
    `set -o pipefail` or run them unpiped.
  - After UI or layout changes, run the full local e2e suite before committing or pushing. Don't
    rely on CI to catch regressions.

## Commits

- Conventional Commits: `type(scope): description`, imperative, lowercase, no trailing period.
- Prefer small focused commits while working; once done and validated, squash into focused commits
  that each stand alone — not necessarily one — with a single version bump per feature.
- **Never push without my say-so. Never rewrite pushed history.** Rewriting unpushed history (amend,
  squash, date resets) is fine.

## Safety

Never commit, log, or echo secrets. Don't send repo contents to external services without asking.
