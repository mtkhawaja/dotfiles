---
name: scr
description: Use when the user invokes /scr or /squash-commit-review, or asks to squash, tidy, or clean up unpushed commits before review (e.g. "clean up my commits then review", "squash wip commits and code-review"). Rewrites only local unpublished history, then runs code-review on the whole range. Not for pushing, PRs, or reviewing already-published work.
---

# Squash commits, then review

Tidy unpushed history when it helps, then run the bundled `code-review` on the
whole range. Ten good commits are fine; commit count is not a target. Invocation
authorizes safe local history cleanup. **Never push. Never rewrite published commits.**

## 1. Inspect

```bash
git status --porcelain=v1 -b
git fetch --all --prune          # refresh every remote, not just upstream
git log --oneline --decorate -n 30
git for-each-ref --contains HEAD refs/remotes refs/tags   # what already contains HEAD
```

- Read repo guidance (CLAUDE.md) for commit conventions and checks.
- Find the contiguous unpublished suffix ending at HEAD. A commit reachable from
  any remote ref (`git branch -r --contains <sha>`) or any tag is a fixed boundary.
  Upstream comparison alone is insufficient; if publication status is uncertain,
  skip rewriting.
- Record the review base now, before any rewrite: the feature's known base, or the
  parent of the oldest unpublished commit when working directly on a shared branch
  (e.g. `main` ahead of `origin/main`). Ask only if the scope cannot be established;
  a PR is not required.
- Dirty tree/index, a rebase/merge/cherry-pick in progress, or merge commits in
  the suffix: leave history alone, don't stash/commit/discard, and review the
  committed range.

## 2. Consolidate only when worthwhile

- Fold WIP, fixups, test repairs, and reversals into the change they belong to.
  Keep independent changes separate; each result must stand alone.
- Take cheap, adjacent folds; leave entangled ones rather than forcing a reorder.
- Skip for 0–1 unpushed commits, already-clean history, or when the benefit is
  below the risk.
- State the grouping or skip reason in a line or two, then proceed — no approval round.
- Messages: Conventional Commits (`type(scope): description`, imperative,
  lowercase, no period) or the repo's own convention.

## 3. Rewrite safely

1. Record `ORIG=$(git rev-parse HEAD)` and `TREE=$(git rev-parse HEAD^{tree})`;
   back up: `git update-ref refs/scr-backup/$(date +%Y%m%d-%H%M%S) $ORIG`.
2. Smallest rewrite that yields the groups. Interactive rebase is unavailable, so:
   - whole suffix → one commit: `git reset --soft <base> && git commit`
   - partial folds: `GIT_SEQUENCE_EDITOR` with a scripted todo
     (`git rebase -i <base>`), or `git reset --soft` + recommit per group
     when groups are contiguous.
   Preserve final content; never edit code to ease the rewrite.
3. On conflict, resolve it: the correct content is whatever yields `$TREE`, so
   inspect both sides and keep the final intended state. If it can't be resolved
   cleanly, or the tree check in step 4 fails, abort (`git rebase --abort`),
   retry with a simpler grouping, and only then restore `$ORIG` and skip.
4. Verify: `git rev-parse HEAD^{tree}` equals `$TREE`; the published boundary is
   unchanged; `git log --oneline <base>..HEAD` matches the intended groups.
   On mismatch, `git reset --hard $ORIG` before continuing.
5. Run the project's checks (e.g. `./scripts/check.sh lint` here); report failures
   verbatim, don't hide them.

## 4. Review

After cleanup **or a deliberate skip**, invoke `code-review` via the Skill tool with
target `<base-sha>...HEAD`. Don't merely recommend it. The range must cover the
intended work even with zero unpushed commits; an empty working-tree diff is not
"nothing to review".

Local and read-only: no `--fix`, `--comment`, or `ultra`; don't use PR-posting
plugins, create a PR, or push. Wait for completion and report the findings. If it
is unavailable or fails, say review did not complete and why; never imply it passed.

## 5. Report

Concisely: commits before → after (or why unchanged), checks run and results,
review findings, and the backup ref if history was rewritten (restore with
`git reset --hard <ref>`).
