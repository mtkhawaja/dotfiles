#!/usr/bin/env zsh

# As per the documentation: http://zsh.sourceforge.net/Intro/intro_3.html
# `.zshenv' is sourced on all invocations of the shell, unless the -f option is set.
# It should contain commands to set the command search path, plus other important environment variables.
# `.zshenv' should not contain commands that produce output or assume the shell is attached to a tty.


############################
# Environment Variables
############################

# Default timezone only where the system has none configured (e.g. bare
# containers); macOS and Linux hosts with /etc/localtime keep their own.
[[ -z "$TZ" && ! -e /etc/localtime ]] && export TZ="America/New_York"
export LANG="en_US.UTF-8"
# Used by `less` to display line numbers without having to type `-N` every time.
export LESS="-R -N -C -M -I -j 10 -# 4"

# Default editor for every shell — interactive and non-interactive (e.g. git
# launched from a script or `ssh host 'git commit'`), so it belongs here, not .zshrc.
export EDITOR="nvim"

############################
# PATH Variable Setup
############################

path+=("$HOME/.local/bin/scripts/utility")
path+=("$HOME/.local/bin")


# Linux/WSL: dev-environment installs the Bitwarden CLI here (macOS gets `bw` via brew).
[[ -d "$HOME/.local/bin/tools/bitwarden/bin" ]] && path+=("$HOME/.local/bin/tools/bitwarden/bin")

# Homebrew (Apple Silicon only). Skipped on Linux/WSL, where dev-environment uses apt.
#
# The exports below are the output of `brew shellenv zsh`, written out
# instead of eval'd. Running `brew shellenv` costs ~25ms, and .zshenv runs for every zsh,
# including scripts and `ssh host 'cmd'` (static: ~4ms vs ~29ms). If Homebrew ever behaves
# oddly after an upgrade (missing commands, man pages, or completions), compare these lines
# with `brew shellenv zsh`, or switch back to `eval "$(/opt/homebrew/bin/brew shellenv)"`.
if [[ -x /opt/homebrew/bin/brew ]]; then
  export HOMEBREW_PREFIX="/opt/homebrew"
  export HOMEBREW_CELLAR="/opt/homebrew/Cellar"
  export HOMEBREW_REPOSITORY="/opt/homebrew"
  fpath[1,0]="/opt/homebrew/share/zsh/site-functions"
  export FPATH
  export PATH="/opt/homebrew/bin:/opt/homebrew/sbin${PATH+:$PATH}"
  [ -z "${MANPATH-}" ] || { export MANPATH="${MANPATH%"${MANPATH##*[!:]}"}"; export MANPATH=":${MANPATH#"${MANPATH%%[!:]*}"}"; }
  export INFOPATH="/opt/homebrew/share/info:${INFOPATH:-}"
fi

############################
# Version Managers (PATH only)
############################

export SDKMAN_DIR="$HOME/.sdkman"
export NVM_DIR="$HOME/.nvm"

# Put the active toolchains on PATH for every shell — scripts, `zsh -c`,
# `ssh host 'mvn test'`, launchd/cron. The managers' init scripts are slow and
# only add functions/completions, so they stay in .zshrc. Prepended after brew
# so sdkman/nvm win over brew java/node, as in interactive shells. nvm: highest
# installed version (the default alias is not resolved). -U keeps nested shells
# (tmux, subshells) from accumulating duplicate entries.
typeset -U path
path=("$SDKMAN_DIR"/candidates/*/current/bin(N) "$NVM_DIR"/versions/node/*/bin(Nn[-1]) $path)

# macOS with Bitwarden installed: route SSH through its desktop SSH agent (see
# ~/.ssh/config for GUI apps). Otherwise keep the machine's own agent.
_bw="$HOME/Library/Containers/com.bitwarden.desktop"
[[ "$OSTYPE" == darwin* && -d "$_bw" ]] && export SSH_AUTH_SOCK="$_bw/Data/.bitwarden-ssh-agent.sock"
unset _bw

[[ -d "$HOME/.bun/bin" ]] && path=("$HOME/.bun/bin" $path)

# App-installed CLIs (macOS). Previously appended by Docker Desktop and JetBrains
# Toolbox to an untracked ~/.zprofile, which only login shells read.
[[ -d "$HOME/.docker/bin" ]] && path+=("$HOME/.docker/bin")
[[ -d "$HOME/Library/Application Support/JetBrains/Toolbox/scripts" ]] && path+=("$HOME/Library/Application Support/JetBrains/Toolbox/scripts")

# Go: GOPATH + the toolchain. Only add directories that actually exist so PATH
# never carries dead entries (consistent on macOS/brew and Linux/tarball installs).
export GOPATH="$HOME/go"
# $GOPATH/bin is the install target for `go install`; may not exist until the
# first install, so guard it too (new shell picks it up after that).
[[ -d "$GOPATH/bin" ]] && path+=("$GOPATH/bin")
# /usr/local/go/bin only exists where Go was installed from tarball (Linux); on
# macOS `go` comes from brew and is already on PATH, so only add it if it's real.
[[ -d /usr/local/go/bin ]] && path+=("/usr/local/go/bin")

export PATH

# macOS login shells (what Ghostty and Terminal open) run /etc/zprofile next, whose
# path_helper moves system dirs ahead of everything above. Remember the order so
# .zprofile can restore it.
[[ "$OSTYPE" == darwin* && -o login ]] && _zshenv_path=($path)

# Machine-local secrets, created by setup.sh from .secrets.example in the repo
# root. Resolve the root through this file's stow symlink (~/.zshenv ->
# <repo>/zsh/.zshenv) so a DOTFILES_HOME override still finds it.
_dotfiles_root="${${(%):-%x}:A:h:h}"
[[ -r "$_dotfiles_root/.secrets" ]] && source "$_dotfiles_root/.secrets"
unset _dotfiles_root
