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

`setup.sh` defaults to stowing: `zsh`, `bin`, `nvim`, `tmux`, `git`, `gnupg`, `aerospace`, `ccstatusline`, `ghostty`.
Supports overriding via env vars (`DOTFILES_HOME`, `STOW_FOLDERS`, `CONFIG_FILES_TO_REMOVE`).

## Package Layout

| Directory       | Symlink target                         | Notes                                                                              |
|-----------------|----------------------------------------|------------------------------------------------------------------------------------|
| `zsh/`          | `~/.zshenv`, `~/.zshrc`                | oh-my-zsh; env vars in `.zshenv`, aliases/plugins in `.zshrc`                      |
| `git/`          | `~/.gitconfig`, `~/.gitignore_global`  | Supports conditional includes via `includeIf` for per-directory overrides          |
| `aerospace/`    | `~/.aerospace.toml`                    | AeroSpace tiling WM; workspaces named by purpose, app-id rules auto-assign windows |
| `ghostty/`      | `~/.config/ghostty/`                   | XDG path; stowed via standard `setup.sh` like all other packages                   |
| `tmux/`         | `~/.tmux.conf`                         | Minimal config; always launched with `-2` flag for 256-color                       |
| `nvim/`         | `~/.config/nvim/`                      | Git submodule pointing to `https://github.com/mtkhawaja/nvim-config.git`           |
| `gnupg/`        | `~/.gnupg/gpg-agent.conf`              | GPG agent config                                                                   |
| `bin/`          | `~/.local/bin/`                        | Custom shell scripts; `utility/` scripts are on `$PATH` via `.zshenv`              |
| `ccstatusline/` | `~/.config/ccstatusline/settings.json` | Claude Code status line config (ccstatusline)                                      |

## Key Tool Versions / Managers

- **Shell**: zsh + oh-my-zsh (`robbyrussell` theme)
- **Runtime managers**: sdkman (JVM), nvm (Node), pyenv (Python), bun
- **SSH agent**: Bitwarden desktop (`$SSH_AUTH_SOCK` set in both `.zshenv` and `.zshrc`)
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
