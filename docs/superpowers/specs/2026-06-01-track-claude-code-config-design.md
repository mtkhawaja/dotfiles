# Track Claude Code config in dotfiles — Design

**Date:** 2026-06-01
**Status:** Approved

## Goal

Version-control the portable parts of the global `~/.claude/` configuration in this dotfiles
repo so a fresh machine install gets the same Claude Code setup — **primarily so enabled
plugins are available on a new terminal/install** — without leaking sensitive or
machine-specific data.

## Where Claude Code stores things (verified 2026-06-01)

| Data                                                                                                 | Location                                                                                                              | Track?  |
|------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------|---------|
| Portable config: `model`, `hooks`, `statusLine`, `enabledPlugins`, `extraKnownMarketplaces`, `theme` | `~/.claude/settings.json`                                                                                             | **Yes** |
| Claude OAuth login token                                                                             | `~/.claude/.credentials.json` (absent locally → stored in macOS Keychain)                                             | Never   |
| MCP server configs + OAuth/bearer tokens                                                             | `~/.claude.json` (`mcpServers`), project `.mcp.json`                                                                  | Never   |
| Machine-specific permissions / secret env                                                            | `~/.claude/settings.local.json`                                                                                       | Never   |
| Regenerable plugin cache (absolute paths, timestamps, git SHAs)                                      | `~/.claude/plugins/` (`cache/`, `marketplaces/`, `installed_plugins.json`, `known_marketplaces.json`)                 | Never   |
| Runtime/transient state                                                                              | `history.jsonl`, `projects/`, `sessions/`, `security/`, `daemon/`, `telemetry/`, `usage-data/`, `shell-snapshots/`, … | Never   |

**Key fact:** MCP OAuth/bearer tokens never live in `settings.json` — they live in
`~/.claude.json` / `.mcp.json` / the credentials store. The only way `settings.json` can hold
a secret is via an `"env"` block; the rule is therefore **secret env → `settings.local.json`
(untracked); portable config → `settings.json` (tracked).** Claude Code merges
`settings.json` + `settings.local.json`, so this split is lossless.

## Architecture

A new GNU Stow package `claude/` mirroring `~/.claude/`, following the existing
`track-tool` / Stow pattern. Because `~/.claude/` is a real, busy runtime directory, Stow
creates **file-level symlinks** for individual tracked files and **directory-level symlinks**
for dirs that do not yet exist on the machine.

```
claude/
└── .claude/
    ├── settings.json      # copied from current machine; portable config only
    ├── CLAUDE.md          # scaffolded global user memory (new)
    ├── commands/          # future slash-commands (.gitkeep)
    ├── agents/            # future subagents (.gitkeep)
    └── skills/            # future user-level skills (.gitkeep)
```

`commands/`, `agents/`, and `skills/` are symlinked as whole directories, so files added
later are auto-tracked with no further setup.

## Excluded data

Everything in the table above marked "Never" is simply **never placed in the package**.
Runtime files live in the real `~/.claude/` directory, outside the repo, so **no `.gitignore`
is required** and there is no leak surface.

## setup.sh integration

- Add `"claude"` to `STOW_FOLDERS`.
- Add `"$HOME/.claude/settings.json"` to `CONFIG_FILES_TO_REMOVE` — it always exists after
  first launch, so Stow would otherwise report a conflict (same handling as `.zshrc`,
  `.gitconfig`, etc.). `CLAUDE.md` / `commands/` / `agents/` / `skills/` do not exist on a
  fresh machine, so they produce no conflict.
- Migration is non-destructive: the repo copy *is* the current content (copied in first),
  then the original is removed and replaced by the symlink.

## Plugin portability (primary goal)

On a fresh machine, `setup.sh` symlinks the tracked `settings.json`. On next launch Claude
Code reads `enabledPlugins` + `extraKnownMarketplaces` and re-clones/installs the plugins
automatically. The heavy `plugins/` cache is regenerated and is never tracked.

## Docs

- Add a `claude/` row to the CLAUDE.md Package Layout table.
- Update the `setup.sh` defaults line in CLAUDE.md.
- One-line note documenting the secrets split (portable vs `settings.local.json`).

## Verification

Per the "verify in Docker, not host" rule, the Stow / `setup.sh` behavior is verified in a
throwaway container with a fake `$HOME` containing a dummy `~/.claude/settings.json` **before**
running against the real Mac. Verify:

1. `settings.json` becomes a symlink into the repo (file-level fold).
2. `commands/` / `agents/` / `skills/` become directory symlinks when absent.
3. No sensitive/runtime path is captured by the package.

Then apply on host and confirm `ls -la ~/.claude/settings.json` shows the symlink.

## Out of scope (YAGNI)

- Pre-commit guard warning on an `env` block in tracked `settings.json` — easy to add later.
- Tracking the `plugins/` cache or pinning plugin git SHAs.
- Cross-OS branching: `settings.json` is platform-agnostic (hooks use `bunx ccstatusline`).
