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
    )
  fi

  if [[ -z ${STOW_FOLDERS+x} ]]; then
    STOW_FOLDERS=(
      "zsh"
      "bin"
      "nvim"
      "tmux"
      "git"
      "gnupg"
      "aerospace"
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

  logSuccess "Dotfiles setup completed successfully!"
  return 0
}

main "$@"