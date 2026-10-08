# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

macOS dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/). Each top-level directory is a stow package
whose contents get symlinked into `$HOME`.

## Setup

```bash
# Symlink all dotfiles (un-stows then re-stows each package)
./setup.sh
```

`setup.sh` validates all packages, backs up unmanaged configs under `~/.dotfiles-setup/backup.*`
(mode 0700), and dry-runs Stow. A failed preflight restores the configs; successful preflight
retains backups for manual recovery. It then creates a git-ignored `.secrets` (mode 0600) from
`.secrets.example` if absent; `zsh/.zshenv` sources it so exported tokens reach every shell.
It defaults to stowing: `zsh`, `bin`, `nvim`, `tmux`, `git`, `aerospace`, `ccstatusline`, `ghostty`, `claude`, `codex`.
Supports overrides (`DOTFILES_HOME`, `STOW_FOLDERS`, `CONFIG_FILES_TO_REMOVE`); Stow always targets `$HOME`. The
gnupg (`gnupg-macos` / `gnupg-linux`, selected by OS) and `ssh` packages are stowed by dedicated
functions (`configureGpgAgent`, `configureSshConfig`) rather than `STOW_FOLDERS`, so `~/.gnupg` /
`~/.ssh` stay real dirs instead of being folded into symlinks.

## Checks

```bash
./scripts/check.sh lint    # shellcheck (bash) + zsh -n + markdownlint + JSON parse; same as CI
./scripts/check.sh static  # syntax/JSON only; no shellcheck or npx needed
```

shellcheck can't parse zsh, so `.zshenv`, `.zshrc`, and zsh-shebang files are validated with `zsh -n`
only. markdownlint config is `.markdownlint-cli2.jsonc` (line length off; `nvim/` and `docs/superpowers/`
ignored). CI (`.github/workflows/ci.yml`) runs the same script with a pinned shellcheck.

## Package Layout

| Directory       | Symlink target                         | Notes                                                                              |
|-----------------|----------------------------------------|------------------------------------------------------------------------------------|
| `zsh/`          | `~/.zshenv`, `~/.zshrc`                | oh-my-zsh; env vars in `.zshenv`, aliases/plugins in `.zshrc`                      |
| `git/`          | `~/.gitconfig`, `~/.gitignore_global`  | Personal config tracked; work identity via `includeIf` from git-ignored `~/.gitconfig.d/` — see below |
| `aerospace/`    | `~/.aerospace.toml`                    | AeroSpace tiling WM; workspaces named by purpose, app-id rules auto-assign windows |
| `ghostty/`      | `~/.config/ghostty/`                   | XDG path; stowed via standard `setup.sh` like all other packages                   |
| `tmux/`         | `~/.tmux.conf`                         | Minimal config; always launched with `-2` flag for 256-color                       |
| `nvim/`         | `~/.config/nvim/`                      | Git submodule pointing to `https://github.com/mtkhawaja/nvim-config.git`           |
| `gnupg-macos/`, `gnupg-linux/` | `~/.gnupg/gpg-agent.conf`     | GPG agent config; OS-appropriate package picked by `configureGpgAgent` (differ only in `pinentry-program`) |
| `bin/`          | `~/.local/bin/`                        | Custom shell scripts; `utility/` scripts are on `$PATH` via `.zshenv`              |
| `ccstatusline/` | `~/.config/ccstatusline/settings.json` | Claude Code status line config (ccstatusline)                                      |
| `claude/`       | `~/.claude/` (selected files)          | Portable Claude Code config; see below — secrets deliberately excluded             |
| `codex/`        | `~/.codex/dotfiles.config.toml`        | Portable profile and native statusline; select with `codex -p dotfiles`             |
| `ssh/`          | `~/.ssh/config`, `~/.ssh/*.pub`        | Public personal SSH config; private work/server entries excluded — see below       |

### Git package (`git/`)

The tracked `~/.gitconfig` is the **personal** identity. Other identities (work)
are kept out of version control and pulled in via git's `includeIf`, mirroring the
SSH split. The personal `[user]` block is followed by:

```ini
[includeIf "hasconfig:remote.*.url:git@github.com-work:*/**"]
    path = ~/.gitconfig.d/work.config
```

`hasconfig:remote.*.url` applies the work identity to any repo whose remote uses
the `github.com-work` SSH alias (see the `ssh/` package) — so identity follows the
remote, no directory convention needed. (`*/**` matches `owner/repo` and deeper;
git's `**` only spans `/` adjacent to one, so a bare `**` after the colon won't.)

`git/.gitconfig.d/` is a tracked folder holding only a `.gitignore` (`*` +
`!.gitignore` `!README.md` `!work.config.example`) plus a README and template — so
the folder always exists after stow, but real includes like `work.config` are
git-ignored and never committed. Stow folds `~/.gitconfig.d` into a symlink to it
(same pattern as `~/.ssh/config.d`). Requires git ≥ 2.36 for `hasconfig`.

### SSH package (`ssh/`)

Tracks the **public, personal** parts of `~/.ssh/`: `config` and public keys (`*.pub`). Keys
themselves live in the **Bitwarden desktop SSH agent** (`$SSH_AUTH_SOCK` set per-OS in
`zsh/.zshenv`); no private key touches disk. The tracked `config` wires SSH to that agent on macOS
(`Match exec "uname -s | grep -iq darwin"` → `IdentityAgent`) and pins the personal GitHub account
(`Host github.com`) to its key via `IdentitiesOnly` + `IdentityFile *.pub`.

**Multiple GitHub accounts:** both hit `github.com`, so they're disambiguated by host aliases
(`github.com` personal, `github.com-work` work). Use the alias in remotes, e.g.
`git clone git@github.com-work:org/repo.git`.

**Refreshing/fact-checking a pinned key:** GitHub publishes an account's registered public keys at
`https://github.com/<user>.keys` (e.g. `mtkhawaja.keys` personal, `muneekha.keys` work). The pinned
`*.pub` blob must appear there; if it doesn't, auth fails with `Permission denied (publickey)`. Handy
when rotating a key or debugging which identity a key belongs to.

**Private entries are kept out of version control** (work GitHub, servers): the tracked `config`
starts with `Include ~/.ssh/config.d/*.conf`. The `config.d/` folder *is* part of the package, but
holds only a `.gitignore` (`*` + `!.gitignore`) — so the folder is guaranteed to exist after stow,
yet every include dropped in it (e.g. `work.conf`, work `*.pub`) is ignored and can never be
accidentally committed. Stow folds `~/.ssh/config.d` into a symlink to this tracked folder, so files
placed there live in the repo working tree but stay git-ignored.

Stowing is done by `configureSshConfig` in `setup.sh` (not `STOW_FOLDERS`), which ensures `~/.ssh`
itself stays a real 700 dir so stow links `config`/`*.pub` *inside* it rather than folding all of
`~/.ssh` into a repo symlink (same anti-fold reasoning as `configureGpgAgent`); only `config.d` is
deliberately allowed to fold.

### Claude Code package (`claude/`)

Tracks only the **portable** parts of `~/.claude/`: `settings.json` (model, hooks, statusLine,
`enabledPlugins`, `extraKnownMarketplaces`, theme), a global `CLAUDE.md`, and `commands/`,
`agents/`, `skills/`. Stow uses `--no-folding` to keep runtime directories outside the repo;
rerun setup after adding files to these packages. Tracking
`settings.json` is what makes enabled plugins carry to a fresh install — Claude Code re-clones
them from `enabledPlugins`/`extraKnownMarketplaces` on next launch.

**Secrets are deliberately excluded** (never placed in the package, so no `.gitignore` needed):
`settings.local.json` (machine perms + secret `env`), `~/.claude.json` (MCP servers / OAuth /
bearer tokens), `.credentials.json` / Keychain, the regenerable `plugins/` cache, and runtime
state (`history.jsonl`, `projects/`, `sessions/`, `security/`, `telemetry/`, …). Rule of thumb:
**secret `env` → `settings.local.json` (untracked); portable config → `settings.json` (tracked)** —
Claude Code merges the two.

### Codex package (`codex/`)

Tracks a config profile selected with `codex -p dotfiles` (Codex CLI 0.154.0).
It layers model preferences and the native statusline over the untracked `~/.codex/config.toml`,
preserving local integrations. Stow uses `--no-folding` so `~/.codex` stays a real directory;
credentials, sessions, plugins, and other runtime state stay outside the repo.

The footer approximates ccstatusline with Git branch, directory, model/reasoning, context usage,
five-hour/weekly limits, estimated cost, and input/output tokens. It does not reproduce Claude's
three-row styling, skills count, cache tokens, or timers. Narrow terminals may omit trailing fields.

## Key Tool Versions / Managers

- **Shell**: zsh + oh-my-zsh (`robbyrussell` theme)
- **Runtime managers**: sdkman (JVM), nvm (Node), uv (Python), bun, Go (`GOPATH`). Their bin dirs go
  on PATH in `.zshenv` so scripts and `ssh host 'cmd'` see them; the slow init (the `sdk` function,
  nvm via the oh-my-zsh `nvm` plugin, completions) loads only in `.zshrc`.
- **SSH agent**: Bitwarden desktop (`$SSH_AUTH_SOCK` set in `.zshenv`; never add the `ssh-agent` plugin)
- **Homebrew**: initialized in `.zshenv` via `/opt/homebrew/bin/brew shellenv`

## Adding a New Package

1. Create a directory at the repo root with the files in their relative-to-`$HOME` paths.
2. Add it to `STOW_FOLDERS` in `setup.sh` (or stow it manually: `stow <package>`).
3. If the target directory is not `$HOME`, write a dedicated install script.

## AeroSpace Notes

Both numbered workspaces (`alt-1`…`alt-9`) and descriptively named ones coexist (`Development`, `Web`, `Tools`,
`Research`, `Media`, `Notes`, `Communication`, `Apple`, `Bitwarden`, `Email`, plus single-letter workspaces).
`alt-<key>` summons a workspace; `alt-shift-<key>` moves the focused window there. Service mode (`alt-shift-;`)
provides layout reset, balance, and float-toggle shortcuts.

To find an app's bundle ID for `on-window-detected` rules:

```bash
cd /Applications/Utilities
osascript -e 'id of app "<App-Name>"'
```
