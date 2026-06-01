#!/usr/bin/env bash

set -e
set -o pipefail

LOG_DIR="${HOME}/.dotfiles-setup"
mkdir -p "$LOG_DIR"
LOGFILE="${LOG_DIR}/$(date +%Y%m%d-%H%M%S).log"

function log() {
  local level=$1
  local message=$2
  echo "[$(date +"%Y-%m-%d %H:%M:%S")] [${level}] $message" | tee -a "$LOGFILE"
}

function logFailureAndExit() {
  log "ERROR" "$1 ❌"
  exit 1
}

function logSuccess() {
  log "SUCCESS" "$1 ✅"
}

function logPending() {
  log "PENDING" "$1 ⌛"
}

function logInfo() {
  log "INFO" "$1"
}

function removeExistingConfigurationFiles() {
  local existing_files_to_remove=("$@")
  for file in "${existing_files_to_remove[@]}"; do
    if [ -f "$file" ]; then
      logPending "Attempting to remove existing configuration file: '${file}'"
      rm "${file}" || logFailureAndExit "Failed to remove existing configuration file: '${file}'"
      logSuccess "Successfully removed existing configuration file: '${file}'"
    else
      logSuccess "'${file}' does not exist. Nothing to remove."
    fi
  done
}

function stowDotfiles() {
  local dotfiles_home="$1"
  local stow_folders=("${@:2}")
  if ! command -v stow &> /dev/null; then
    logFailureAndExit "GNU Stow is not installed. Please install it first."
  fi
  pushd "$dotfiles_home" >/dev/null || logFailureAndExit "Failed to change directory to: '${dotfiles_home}'"
  for folder in "${stow_folders[@]}"; do
    if [ ! -d "$folder" ]; then
      logFailureAndExit "Stow folder does not exist: '${folder}'"
    fi
    logPending "Attempting un-stow: '${folder}'"
    stow -D "${folder}" || logFailureAndExit "Failed to un-stow: '${folder}'"
    logPending "Attempting stow: '${folder}'"
    stow "${folder}" || logFailureAndExit "Failed to stow: '${folder}'"
    logSuccess "Successfully stowed: '${folder}'"
  done
  popd >/dev/null || logFailureAndExit "Failed to change directory to previous directory"
}

# Stow the OS-appropriate gnupg package so ~/.gnupg/gpg-agent.conf is symlinked
# like every other dotfile. The two packages (gnupg-macos, gnupg-linux) share the
# same internal path (.gnupg/gpg-agent.conf); only the pinentry-program differs.
function configureGpgAgent() {
  local dotfiles_home="$1"
  local gnupg_dir="$HOME/.gnupg"
  local pkg
  if [[ "$(uname -s)" == "Darwin" ]]; then
    pkg="gnupg-macos"
  else
    pkg="gnupg-linux"
  fi

  # Ensure ~/.gnupg is a real dir with safe perms BEFORE stowing, so stow links
  # gpg-agent.conf *inside* it instead of folding ~/.gnupg into a repo symlink
  # (which would drag your keyrings under version control / wrong perms).
  mkdir -p "$gnupg_dir"
  chmod 700 "$gnupg_dir"

  stowDotfiles "$dotfiles_home" "$pkg"

  # Warn (don't fail) if the configured pinentry isn't actually installed yet.
  local pinentry
  pinentry="$(awk '/^pinentry-program/ {print $2; exit}' "${dotfiles_home}/${pkg}/.gnupg/gpg-agent.conf")"
  if [[ -n "$pinentry" && ! -x "$pinentry" ]]; then
    logInfo "WARNING: pinentry-program '${pinentry}' is not executable; GPG prompts may fail until it is installed."
  fi

  command -v gpgconf >/dev/null 2>&1 && gpgconf --kill gpg-agent >/dev/null 2>&1 || true
}

function main() {
  DOTFILES_HOME=${DOTFILES_HOME:-"${HOME}/.dotfiles"}

  if [[ ! -d "$DOTFILES_HOME" ]]; then
    logFailureAndExit "Dotfiles directory does not exist: '${DOTFILES_HOME}'"
  fi

  if [[ -z ${CONFIG_FILES_TO_REMOVE+x} ]]; then
    CONFIG_FILES_TO_REMOVE=(
      "$HOME/.zshrc"
      "$HOME/.gnupg/gpg-agent.conf"
      "$HOME/.zshenv"
      "$HOME/.gitconfig"
      "$HOME/.gitignore_global"
      "$HOME/.claude/settings.json"
    )
  fi

  if [[ -z ${STOW_FOLDERS+x} ]]; then
    STOW_FOLDERS=(
      "zsh"
      "bin"
      "nvim"
      "tmux"
      "git"
      "aerospace"
      "ccstatusline"
      "ghostty"
      "claude"
    )
  fi

  logInfo ""
  logInfo "--------------------------------------------------------------------------------"
  logInfo "Starting dotfiles setup..."
  logInfo "Logging to: '${LOGFILE}'"
  logInfo "Dotfiles home: '${DOTFILES_HOME}'"
  logInfo "Configuration files to remove: '${CONFIG_FILES_TO_REMOVE[*]}'"
  logInfo "Stow folders: '${STOW_FOLDERS[*]}'"
  logInfo "--------------------------------------------------------------------------------"
  logInfo ""

  removeExistingConfigurationFiles "${CONFIG_FILES_TO_REMOVE[@]}"
  stowDotfiles "${DOTFILES_HOME}" "${STOW_FOLDERS[@]}"
  configureGpgAgent "${DOTFILES_HOME}"

  logSuccess "Dotfiles setup completed successfully!"
  return 0
}

main "$@"