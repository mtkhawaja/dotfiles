#!/usr/bin/env zsh

# As per the documentation: http://zsh.sourceforge.net/Intro/intro_3.html
# `.zshenv' is sourced on all invocations of the shell, unless the -f option is set.
# It should contain commands to set the command search path, plus other important environment variables.
# `.zshenv' should not contain commands that produce output or assume the shell is attached to a tty.


############################
# Environment Variables
############################

# Used by `less` to display line numbers without having to type `-N` every time.
export LESS="-N"
# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

############################
# PATH Variable Setup
############################

path+=("$HOME/.local/bin/scripts/utility")
path+=("$HOME/.local/bin/tools/bitwarden/bin")
export PATH