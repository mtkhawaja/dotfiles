# AGENTS.md

This file provides guidance to coding agents (e.g. Claude Code) when working with code in this repository.

## Overview

Cross-platform (macOS and Ubuntu/WSL) dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/). Each top-level directory is a stow package
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
It defaults to stowing: `zsh`, `bin`, `nvim`, `tmux`, `git`, `aerospace`, `ccstatusline`, `ghostty`, `claude`.
Supports overrides (`DOTFILES_HOME`, `STOW_FOLDERS`, `CONFIG_FILES_TO_REMOVE`); Stow always targets `$HOME`. The
gnupg (`gnupg-macos` / `gnupg-linux`, selected by OS) and `ssh` packages are installed by dedicated
functions (`configureGpgAgent`, `configureSshConfig`) rather than `STOW_FOLDERS`, so `~/.gnupg` /
`~/.ssh` stay real dirs instead of being folded into symlinks.

## Checks

```bash
./scripts/check.sh lint    # shellcheck (bash) + zsh -n + markdownlint + JSON parse; same as CI
./scripts/check.sh static  # syntax/JSON only; no shellcheck or npx needed
./scripts/check.sh test    # unit tests in tests/ (stdlib unittest); needs git, ssh-agent, ssh-keygen
```

`tests/` covers the Python utilities black-box, never touching real config:
`test_git_account.py` uses a throwaway `HOME` (copies of the tracked git/SSH config) and a scratch
`ssh-agent`; `test_aws_creds_to_default.py` fakes the clipboard with stub tools on `PATH`.

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
| `ssh/`          | `~/.ssh/config`, `~/.ssh/*.pub`        | Public personal SSH config; private work/server entries excluded — see below       |

### Git package (`git/`)

`~/.gitconfig` defaults to the tracked personal identity (`.gitconfig.d/personal.config`) and
includes, last so they win: an optional git-ignored `local.config` (machine overrides; `setup.sh`
moves a pre-existing `~/.gitconfig` there), `personal.config` again for `github.com` remotes, and
git-ignored `accounts.config`. Other accounts are added with `git account add <name>
<github|gitlab|bitbucket|host> <email>` (`git-account.py` in `bin/` utility), which writes the
identity, an SSH entry and `includeIf` rules (folder `~/source-code/<name>/` plus remote), then
self-checks them. Details: `git/.gitconfig.d/README.md`.

Gotchas: `hasconfig:remote.*.url` needs git ≥ 2.36, and globs need `*/**` after the host (git's
`**` only spans `/` adjacent to one). Stow folds `~/.gitconfig.d` into a symlink to the repo folder,
whose `.gitignore` ignores everything but the README, `personal.config` and `accounts.config.example`.

### SSH package (`ssh/`)

Tracks the **public, personal** parts of `~/.ssh/`: `config` and `*.pub`. Private keys live in
the SSH agent: the **Bitwarden desktop agent** on Macs that have Bitwarden (`zsh/.zshenv` sets
`$SSH_AUTH_SOCK`; `config` sets `IdentityAgent` so GUI apps use it too), otherwise the machine's own
agent. The tracked `config` pins `Host github.com` (personal) to its key with
`IdentitiesOnly` + `IdentityFile *.pub`. Check a pinned key against `https://github.com/<user>.keys`.

`config` starts with `Include ~/.ssh/config.d/*.conf`: private entries (account aliases like
`github.com-<name>`, servers) go there, git-ignored. Details: `ssh/.ssh/config.d/README.md`.

`configureSshConfig` in `setup.sh` (not Stow) keeps `~/.ssh` a real 700 dir and symlinks each
top-level entry (`config`, `*.pub`, `config.d`) inside it, never overwriting an existing file.

### Claude Code package (`claude/`)

Tracks only the **portable** parts of `~/.claude/`: `settings.json` (model, hooks, statusLine,
`enabledPlugins`, `extraKnownMarketplaces`, theme), a global `CLAUDE.md`, and `commands/`,
`agents/`, `skills/`, `hooks/`. Hook scripts include the opt-in `ui-check` Stop hook, which wraps
`bin/.local/bin/scripts/utility/ui-check` (see its header).

Stow runs with `--no-folding` so Claude Code's runtime directories stay outside the repo; rerun
setup after adding files. `claude/.stow-local-ignore` excludes `skills/synced/`, Claude Code's own
skill-sync output (stowing it caused preflight conflicts). Tracking `settings.json` carries enabled
plugins to a fresh install: Claude Code re-clones them from `enabledPlugins` /
`extraKnownMarketplaces` on next launch.

**Secrets are deliberately excluded** (never placed in the package, so no `.gitignore` needed):
`settings.local.json` (machine perms + secret `env`), `~/.claude.json` (MCP servers / OAuth /
bearer tokens), `.credentials.json` / Keychain, the regenerable `plugins/` cache, and runtime
state (`history.jsonl`, `projects/`, `sessions/`, `security/`, `telemetry/`, …). Rule of thumb:
**secret `env` → `settings.local.json` (untracked); portable config → `settings.json` (tracked)** —
Claude Code merges the two.

## Key Tool Versions / Managers

- **Shell**: zsh + oh-my-zsh (`robbyrussell` theme)
- **Runtime managers**: sdkman (JVM), nvm (Node), uv (Python), bun, Go (`GOPATH`). Their bin dirs go
  on PATH in `.zshenv` so scripts and `ssh host 'cmd'` see them; the slow init (the `sdk` function,
  nvm via the oh-my-zsh `nvm` plugin, completions) loads only in `.zshrc`.
- **SSH agent**: Bitwarden desktop where installed, else the machine's own (`.zshenv`, `~/.ssh/config`;
  never add the `ssh-agent` plugin)
- **Platforms**: one config for macOS and Linux; OS-specific bits are guarded with
  `[[ "$OSTYPE" == darwin* ]]` (zsh) or `uname -s` (`setup.sh`). Keep new config portable.
- **Homebrew**: macOS on Apple Silicon only (`/opt/homebrew`; Linux uses apt); `.zshenv` sets the `brew shellenv` exports
  statically (faster for every shell — see the comment there)

## Adding a New Package

1. Create a directory at the repo root with the files in their relative-to-`$HOME` paths.
2. Add it to `STOW_FOLDERS` in `setup.sh` (or stow it manually: `stow <package>`).
3. If the target directory is not `$HOME`, write a dedicated install script.

## AeroSpace Notes

Keybindings, workspaces and the bundle-ID lookup for `on-window-detected` rules are in
`aerospace/README.md`.
