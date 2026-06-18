#!/usr/bin/env bash
#
# check.sh — repository checks, runnable locally and in CI (same entry point).
#
# Usage:
#   check.sh          Run everything (lint)
#   check.sh lint     shellcheck + markdownlint + static (needs shellcheck, npx, jq)
#   check.sh static   bash -n + zsh -n syntax + JSON parse (needs bash, zsh, jq;
#                     the shellcheck/markdownlint steps run in CI as pinned actions)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly SCRIPT_DIR
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly REPO_ROOT

cd "${REPO_ROOT}"

say() {
  echo "==> $*"
}

err() {
  echo "FAIL: $*" >&2
}

#######################################
# Asserts a required tool is installed.
# Arguments:
#   $1: command name
#######################################
require() {
  command -v "$1" >/dev/null 2>&1 || { err "$1 is required"; exit 1; }
}

#######################################
# Lists tracked shell scripts shellcheck can actually parse (bash/sh). zsh files
# (fix-ssh.sh, .zshrc, .zshenv) are excluded — shellcheck rejects them (SC1071).
#######################################
bash_scripts() {
  local f
  while IFS= read -r f; do
    case "$(head -n1 "$f")" in
      *"/bin/bash"* | *"/bin/sh"* | *"env bash"* | *"env sh"*) echo "$f" ;;
    esac
  done < <(git ls-files '*.sh')
}

#######################################
# Lists tracked zsh scripts to syntax-check with `zsh -n` (shellcheck can't parse
# zsh, so this is how zsh files are validated). Matches the zsh dotfiles by name
# (.zshrc has no shebang) plus any file carrying a zsh shebang.
#######################################
zsh_scripts() {
  local f
  while IFS= read -r f; do
    case "${f##*/}" in
      .zshrc | .zshenv | *.zsh)
        echo "$f"
        continue
        ;;
    esac
    case "$(head -n1 "$f" 2>/dev/null)" in
      *"env zsh" | *"/zsh") echo "$f" ;;
    esac
  done < <(git ls-files)
}

# --- checks ---

check_shellcheck() {
  say "shellcheck (bash/sh scripts)"
  local files
  files="$(bash_scripts)"
  if [[ -n "${files}" ]]; then
    echo "${files}" | xargs shellcheck
  fi
}

check_bash_syntax() {
  say "bash -n syntax check"
  local files
  files="$(bash_scripts)"
  if [[ -n "${files}" ]]; then
    echo "${files}" | xargs -n1 bash -n
  fi
}

check_zsh_syntax() {
  say "zsh -n syntax check"
  local files
  files="$(zsh_scripts)"
  if [[ -n "${files}" ]]; then
    echo "${files}" | xargs -n1 zsh -n
  fi
}

check_json() {
  say "tracked JSON parses"
  git ls-files '*.json' | xargs -n1 jq -e . >/dev/null
}

check_markdown() {
  say "markdownlint (config from .markdownlint-cli2.jsonc)"
  npx --yes markdownlint-cli2 "**/*.md"
}

# --- entrypoints ---

run_static() {
  require jq
  require zsh
  check_bash_syntax
  check_zsh_syntax
  check_json
}

run_lint() {
  require shellcheck
  require npx
  check_shellcheck
  check_markdown
  run_static
}

main() {
  case "${1:-lint}" in
    lint) run_lint ;;
    static) run_static ;;
    *)
      err "unknown check group '$1' (expected: lint, static)"
      exit 1
      ;;
  esac
  echo "All checks passed."
}

main "$@"
