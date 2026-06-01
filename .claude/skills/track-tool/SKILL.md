---
name: track-tool
description: Use when the user wants to version-control a CLI tool's config file in this dotfiles repo and symlink it back to where the tool reads it from.
---

# track-tool

## Overview

Add a tool's config to the dotfiles repo and replace the original with a GNU Stow symlink. Keeps config
version-controlled and portable across machines.

## Steps

### 1. Find the config file path

If the user doesn't provide the path, check the tool's docs or locate it:

```bash
# Common locations to check
ls ~/.config/<tool>/
ls ~/Library/Application\ Support/<tool>/
ls ~/.<tool>rc  ~/.<tool>.conf  ~/.<tool>.toml
```

### 2. Determine stow target

| Config lives under                      | Stow target       | Notes                                                  |
|-----------------------------------------|-------------------|--------------------------------------------------------|
| `$HOME` (e.g. `~/.tmux.conf`)           | `$HOME` (default) | Standard stow — use `setup.sh`                         |
| `~/.config/…`                           | `$HOME` (default) | Standard stow — use `setup.sh`                         |
| `~/Library/…` or other non-`$HOME` path | custom `--target` | Write a dedicated install script (see Ghostty pattern) |

### 3. Create stow package

Mirror the path structure relative to `$HOME`:

```bash
# Example: config is at ~/.config/<tool>/settings.json
mkdir -p .dotfiles/<tool>/.config/<tool>/
cp ~/.config/<tool>/settings.json .dotfiles/<tool>/.config/<tool>/settings.json
```

### 4. Replace original with symlink

```bash
rm ~/.config/<tool>/settings.json          # remove original
cd ~/.dotfiles && stow <tool>              # create symlink
ls -la ~/.config/<tool>/settings.json     # verify symlink
```

### 5. Register in setup.sh

Add the package name to `STOW_FOLDERS` in `setup.sh`:

```bash
STOW_FOLDERS=(
  ...
  "<tool>"
)
```

If the target is not `$HOME`, write a dedicated install script (follow the `install_ghostty_config.sh` pattern) and **do
not** add it to `STOW_FOLDERS`.

### 6. Update CLAUDE.md

Add a row to the Package Layout table:

```markdown
| `<tool>/` | `~/.config/<tool>/settings.json` | One-line description |
```

Also update the `setup.sh` defaults line if you added it to `STOW_FOLDERS`.

## Non-$HOME target pattern (Ghostty example)

When the tool reads from a path outside `$HOME` (e.g. `~/Library/Application Support/`):

```bash
#!/usr/bin/env bash
set -e
stow --target="$HOME/Library/Application Support/<tool>" --dir=. <tool>
```

Save as `install_<tool>.sh`, make it executable, and document it in the Setup section of CLAUDE.md.

## Quick verification

```bash
ls -la <target-path>   # must show -> .../.dotfiles/<tool>/...
git status             # new file in dotfiles repo
```
