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
export LESS="-N -C -M -I -j 10 -# 4"
# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Required for gpg.
# Documentation: http://manpages.ubuntu.com/manpages/precise/en/man1/gpg-agent.1.html
export GPG_TTY=$(tty)

# Java
export JAVA_HOME="$(dirname $(dirname $(readlink -f $(which javac))))"
export M2_HOME="$HOME/.local/bin/tools/apache-maven"

# Other Tools
export BITWARDEN_HOME="$HOME/.local/bin/tools/bitwarden"

############################
# PATH Variable Setup
############################

path+=("$HOME/.local/bin/scripts/utility")
path+=("$HOME/.local/bin/tools/bitwarden/bin")
path+=("$JAVA_HOME")
path+=("$M2_HOME/bin")
export PATH