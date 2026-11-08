# dotfiles

Cross-platform dotfiles for macOS and Linux (Ubuntu, including WSL), symlinked into `$HOME` with
[GNU Stow](https://www.gnu.org/software/stow/). Each top-level directory is a Stow package laid out
relative to `$HOME`.

Installing the tools themselves (Homebrew or apt, Stow, oh-my-zsh, runtimes) is handled by
[dev-environment](https://github.com/mtkhawaja/dev-environment). This repo only provides their config.

## Quick start

```bash
git clone --recurse-submodules git@github.com:mtkhawaja/dotfiles.git ~/.dotfiles
~/.dotfiles/setup.sh
```

`setup.sh` is safe to re-run. It:

1. Moves any existing, unmanaged config it would replace to `~/.dotfiles-setup/backup.*` (logs live in
   `~/.dotfiles-setup/` too).
2. Dry-runs Stow and restores the backups if that fails.
3. Creates `.secrets` from `.secrets.example` (mode 0600, git-ignored) if it doesn't exist.
4. Stows the packages, then installs `~/.gnupg/gpg-agent.conf` and `~/.ssh/config` into real directories.

Overrides: `DOTFILES_HOME` (repo location, default `~/.dotfiles`), `STOW_FOLDERS` and
`CONFIG_FILES_TO_REMOVE` (bash arrays).

## Platforms

The same config is stowed on every OS; files branch on the OS at runtime where they must:

- `setup.sh` picks `gnupg-macos` or `gnupg-linux` (they differ only in `pinentry-program`).
- `.zshenv` sets up Homebrew and the Bitwarden desktop SSH agent on macOS only; Linux uses
  apt-installed tools and the machine's own SSH agent.
- `.zshrc` adds the `macos` oh-my-zsh plugin on macOS only.
- `aerospace` is macOS-only; stowing it on Linux is harmless.

Keep new config portable, or guard it with `[[ "$OSTYPE" == darwin* ]]`.

## Packages

| Package        | Installs to                            | What                                                     |
|----------------|----------------------------------------|----------------------------------------------------------|
| `zsh`          | `~/.zshenv`, `~/.zshrc`                | oh-my-zsh shell; [zsh/README.md](zsh/README.md)          |
| `git`          | `~/.gitconfig`, `~/.gitconfig.d/`      | Per-account identities; [README](git/.gitconfig.d/README.md) |
| `ssh`          | `~/.ssh/config`, `~/.ssh/*.pub`        | Public SSH config; [README](ssh/.ssh/config.d/README.md) |
| `bin`          | `~/.local/bin/`                        | Personal scripts; [bin/.local/README.md](bin/.local/README.md) |
| `nvim`         | `~/.config/nvim/`                      | Submodule: [nvim-config](https://github.com/mtkhawaja/nvim-config) |
| `tmux`         | `~/.tmux.conf`                         | Minimal tmux config                                      |
| `aerospace`    | `~/.aerospace.toml`                    | AeroSpace tiling WM (macOS); [aerospace/README.md](aerospace/README.md) |
| `ghostty`      | `~/.config/ghostty/`                   | Ghostty terminal                                         |
| `ccstatusline` | `~/.config/ccstatusline/settings.json` | Claude Code status line                                  |
| `claude`       | `~/.claude/` (selected files)          | Portable Claude Code config (no secrets)                 |
| `gnupg-macos`, `gnupg-linux` | `~/.gnupg/gpg-agent.conf` | GPG agent; picked by OS                                 |

## Secrets

Tokens go in `.secrets` at the repo root, which `~/.zshenv` sources in every shell. It is git-ignored; see
`.secrets.example` for the supported variables. Machine-specific Claude Code settings and credentials
stay in `~/.claude/settings.local.json` and `~/.claude.json`, which are never tracked.

## Checks

```bash
./scripts/check.sh lint    # shellcheck, zsh -n, markdownlint, JSON parse (what CI runs)
./scripts/check.sh static  # syntax and JSON only; no shellcheck or npx
./scripts/check.sh test    # Python unit tests in tests/
```

## Adding a package

Create `<name>/` with files at their paths relative to `$HOME`, add it to `STOW_FOLDERS` in `setup.sh`,
and re-run `setup.sh`. Design notes and gotchas for agents and maintainers are in [AGENTS.md](AGENTS.md).

## License

[MIT](LICENSE.md)
