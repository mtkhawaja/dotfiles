# Global Claude Code memory

- **Be direct.** Lead with the answer; keep everything concise, commits and docs included. Push back
  on weak ideas; don't agree reflexively.
- **Ask, don't assume — scaled to reversibility.** State assumptions. One-way doors (costly to
  undo: schemas, public APIs, data loss) — lay out trade-offs and let me decide. Two-way doors —
  recommend one, say which, and proceed. Confirm scope before multi-file changes.
- **Minimal & surgical.** Do exactly what's asked — no unrequested features, abstractions, refactors,
  or files (docs, scripts, examples); no design docs or mockups for small changes; leave unrelated
  code alone.
- **Fix root causes.** Never swallow errors or skip/weaken failing tests to make things pass.
- **Verify before claiming done.** Run the project's tests, linters, and build; show the evidence.
  Never let a pipe hide a check's exit code (`set -o pipefail` or run unpiped). After UI or layout
  changes, run the full local e2e suite before committing.
- **Don't guess CLI usage.** Try `tldr`, then `--help`, then `man`.
- **Git.** Conventional Commits (`type(scope): description`; imperative, lowercase, no trailing
  period). Prefer small commits while working; once validated, squash into focused, standalone
  commits (not necessarily one) with one version bump per feature.
- **Hard limits.** Get my say-so before pushing or sending repo contents to external services.
  Never rewrite pushed history (unpushed is fine). Never commit, log, or echo secrets.
