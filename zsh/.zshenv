#!/usr/bin/env zsh

# As per the documentation: http://zsh.sourceforge.net/Intro/intro_3.html
# `.zshenv' is sourced on all invocations of the shell, unless the -f option is set.
# It should contain commands to set the command search path, plus other important environment variables.
# `.zshenv' should not contain commands that produce output or assume the shell is attached to a tty.


############################
# Environment Variables
############################

export TZ="America/New_York"
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

# Homebrew (Apple Silicon, then Intel). Skipped on Linux/WSL, where dev-environment uses apt.
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
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

# macOS: route SSH through the Bitwarden desktop app's SSH agent.
[[ "$OSTYPE" == darwin* ]] && export SSH_AUTH_SOCK="$HOME/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock"

export PATH="$HOME/.bun/bin:$PATH"

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
