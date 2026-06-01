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
# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

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

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Homebrew (Apple Silicon, then Intel). Skipped on Linux/WSL, where dev-environment uses apt.
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

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