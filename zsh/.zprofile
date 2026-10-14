#!/usr/bin/env zsh
# Login shells only. On macOS, /etc/zprofile has just run path_helper, which
# moves /usr/bin and friends ahead of the PATH .zshenv built, so Apple's stubs
# (e.g. /usr/bin/java) would shadow sdkman, nvm, and Homebrew. Restore
# .zshenv's order; path_helper's extra entries stay, after ours (`typeset -U
# path` in .zshenv keeps each directory's first occurrence).
if (( ${+_zshenv_path} )); then
  path=($_zshenv_path $path)
  unset _zshenv_path
fi
