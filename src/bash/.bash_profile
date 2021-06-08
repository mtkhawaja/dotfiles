# include .bashrc if it exists.

if [ -f "$HOME/.bashrc" ]; then
    source "$HOME/.bashrc"
fi

# Java, mvn, etc

export JAVA_HOME="$(dirname $(dirname $(update-alternatives --list javac)))"
export M2_HOME="$HOME/bin/apache-maven-3.8.1/bin"
export MAVEN_HOME="$M2_HOME"

# PATH Config

PATH="$PATH:$HOME/.local/bin"
PATH="$PATH:$HOME/bin/utility-scripts/src/python"
PATH="$PATH:$HOME/bin/utility-scripts/src/bash"
PATH="$PATH:$HOME/.poetry/bin"
PATH="$PATH:$M2_HOME"

# Conditional PATH Additions

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ]; then
    PATH="$PATH:$HOME/bin"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ]; then
    PATH="$HOME/.local/bin:$PATH"
fi
