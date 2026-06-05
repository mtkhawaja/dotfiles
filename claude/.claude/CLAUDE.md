# Global Claude Code memory

## Communication

Be direct; lead with the answer. Push back on weak ideas instead of agreeing reflexively. Keep all
output concise — prose, commits, docs; don't add verbose or token-heavy content (e.g. attribution
lines) without asking.

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

## Commits

- Conventional Commits: `type(scope): description`, imperative, lowercase, no trailing period.
- Prefer small focused commits while working; once done and validated, squash into focused commits
  that each stand alone — not necessarily one.
- **Never push without my say-so. Never rewrite pushed history** — squash/amend only unpushed commits.

## Safety

Never commit, log, or echo secrets. Don't send repo contents to external services without asking.
