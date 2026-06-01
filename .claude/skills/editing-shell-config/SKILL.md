---
name: editing-shell-config
description: Use when adding or changing anything in shell startup files (aliases, PATH, env vars, keybindings, login banners) for zsh or bash in this dotfiles repo, and you must decide which file a behavior belongs in. Especially when the behavior must reach non-interactive shells, scripts, or `ssh host 'command'` sessions — where the wrong file means "works in my terminal but not in scripts/ssh".
---

# editing-shell-config

## Overview

Which startup file a change belongs in is decided by **two independent axes** of the shell that will run the code:

1. **login vs non-login** — login = the first shell after authenticating (TTY login, `ssh host`, `--login`). Non-login =
   any shell started after (terminal tabs, subshells).
2. **interactive vs non-interactive** — interactive = talks to a human (has a prompt/tty). Non-interactive = runs a
   script/command then exits (`bash -c`, `zsh -c`, `ssh host 'command'`).

**Core principle:** put the change in the *earliest-loading file that every target shell reads, and no broader.* Pick by
**reach**, not by habit.

## Repo rules — read FIRST

- `~/.zshenv`, `~/.zshrc`, etc. are **GNU Stow symlinks** into this repo. **Always edit the source in the
  repo's `zsh/` package** (e.g. `zsh/.zshrc`), never the `~/` symlink — so the change is version-controlled
  and survives a re-stow.
- **A new startup file** (e.g. first-time `.zlogin`, or any bash file) must be created **inside the stow package**, then
  stowed (`./setup.sh`). A file dropped directly in `$HOME` is untracked and unmanaged.
- This repo currently ships **zsh only**. Bash files belong in a `bash/` stow package — create it mirroring `zsh/` and
  register it (see `track-tool` / CLAUDE.md "Adding a New Package"). Do not invent ad-hoc paths.
- **Edits must be idempotent** (guard with `[[ -d … ]]`, `command -v`, etc.) and **`.zshenv` must stay tty-free**: no
  output, no prompts, no commands assuming a terminal.

## Decide which file — zsh

| You want the behavior to reach…                                                     | Edit            | Notes                                                                               |
|-------------------------------------------------------------------------------------|-----------------|-------------------------------------------------------------------------------------|
| Interactive shells only — aliases, prompt, keybindings, completion, functions       | `zsh/.zshrc`    | Default for "make my terminal do X"                                                 |
| **Every** invocation incl. scripts, `zsh -c`, **`ssh host 'cmd'`** — PATH, env vars | `zsh/.zshenv`   | Only file read non-interactively. Keep tty-free, no output                          |
| Login sessions only (TTY + ssh), env/setup but not scripts                          | `zsh/.zprofile` | Read once per login, before `.zshrc`                                                |
| Run **once at login**, output OK (banner, fortune)                                  | `zsh/.zlogin`   | Login-only, after `.zshrc`; NOT `.zshrc` (that re-runs in every tmux pane/subshell) |
| On login shell exit                                                                 | `zsh/.zlogout`  |                                                                                     |

## Decide which file — bash

| You want the behavior to reach…                                           | Edit                                                           | Notes                                                                        |
|---------------------------------------------------------------------------|----------------------------------------------------------------|------------------------------------------------------------------------------|
| Interactive shells only — aliases, prompt, keybindings                    | `bash/.bashrc`                                                 | Ensure a login file sources `.bashrc` so interactive login/ssh shells get it |
| All login sessions (TTY + interactive `ssh host`)                         | `bash/.bash_profile` (or `.profile`)                           | Source `.bashrc` from here for interactive bits                              |
| **Non-interactive** shells — scripts, `bash -c`, **`ssh host 'command'`** | file named by **`$BASH_ENV`** (or configure inside the script) | ⚠️ NOT `.bashrc` — see gotcha below                                          |

## The bash non-interactive gotcha (most common error)

For **`ssh host 'command'`** (and any non-interactive bash), bash does **NOT** read `~/.bashrc`. It runs the file named
by `$BASH_ENV` if set; otherwise no user rc at all. Most distro `~/.bashrc` files *also* begin with an interactive guard
like `case $- in *i*) ;; *) return ;; esac`, so even if it were sourced it would bail out immediately.

→ To make a PATH/env change apply to remote commands or scripts, set it in **`$BASH_ENV`'s target** (or the login
profile if the shell is a login shell), **not** `.bashrc`.

(zsh has no such trap — `.zshenv` is read by *all* invocations, which is exactly why PATH/env go there.)

## Common mistakes

| Symptom                                                             | Cause                                 | Fix                                          |
|---------------------------------------------------------------------|---------------------------------------|----------------------------------------------|
| "Works in my terminal, missing in `ssh host 'cmd'` / scripts" (zsh) | Put env/PATH in `.zshrc`              | Move it to `.zshenv`                         |
| Same symptom, bash                                                  | Put env/PATH in `.bashrc`             | Use `$BASH_ENV` target / login profile       |
| Login banner re-prints in every tmux pane                           | Put it in `.zshrc`                    | Use `.zlogin`                                |
| Edited `~/.zshrc` directly                                          | It's a stow symlink                   | Edit `zsh/.zshrc` in the repo                |
| `.zshenv` change broke non-interactive use / scp                    | Output or tty assumption in `.zshenv` | Keep `.zshenv` silent and tty-free           |
| New `.zlogin`/bash file "doesn't load"                              | Created in `$HOME`, not the package   | Create in the stow package, run `./setup.sh` |

## Verify after editing

```bash
zsh -ic 'alias gs'                       # interactive: alias present
zsh -c 'echo $PATH' | tr ':' '\n' | grep foo   # non-interactive: PATH reaches scripts
ls -la ~/.zshrc                          # still a symlink into .dotfiles/zsh/
```
