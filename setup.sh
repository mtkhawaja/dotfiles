#!/usr/bin/env bash

function log() {
  tee -a "$LOG_FILE" <<<"$1"
}

function logFailureAndExit() {
  log "$1 ❌"
  exit 1
}

function logSuccess() {
  log "$1 ✅"
}

function logPending() {
  log "$1 ⌛"
}

function removeExistingConfigurationFiles() {
  local existing_files_to_remove="$1"
  for file in "${existing_files_to_remove[@]}"; do
    if [ -f "$file" ]; then
      logPending "Attempting remove existing configuration file: '${file}'"
      rm "${file}" || logFailureAndExit "Failed to remove existing configuration file: '${file}'"
      logSuccess "Successfully removed existing configuration file: '${file}'"
    else
      logSuccess "'${file}' does not exist. Nothing to remove."
    fi
  done
  log ""
}

function stowDotfiles() {
  local dotfiles_home="$1"
  local stow_folders=("${@:2}")
  pushd "$dotfiles_home" >/dev/null || logFailureAndExit "Failed to change directory to: '${dotfiles_home}'"
  for folder in "${stow_folders[@]}"; do
    logPending "Attempting un-stow: '${folder}'"
    stow -D "${folder}" || logFailureAndExit "Failed to un-stow: '${folder}'"
    logPending "Attempting stow: '${folder}'"
    stow "${folder}" || logFailureAndExit "Failed to stow: '${folder}'"
    logSuccess "Successfully stowed: '${folder}'"
    log ""
  done
  popd >/dev/null || logFailureAndExit "Failed to change directory to previous directory"
}

# Main

LOG_FILE=${LOG_FILE:-"${HOME}/$(date +%Y-%m-%d-%H%M%S)-dotfiles-setup.log"}
DOTFILES_HOME=${DOTFILES_HOME:-"${HOME}/.dotfiles"}

if [[ -z $CONFIG_FILES_TO_REMOVE ]]; then
  CONFIG_FILES_TO_REMOVE=(
    # .oh-my-zsh automatically creates a .zshrc file
    "$HOME/.zshrc"
  )
fi

if [[ -z $STOW_FOLDERS ]]; then
  STOW_FOLDERS=(
    "zsh"
    "bin"
    "nvim"
    "tmux"
    "git"
  )
fi
log ""
log "--------------------------------------------------------------------------------"
log "Starting dotfiles setup..."
log "Logging to: '${LOG_FILE}'"
log "Dotfiles home: '${DOTFILES_HOME}'"
log "Configuration files to remove: '${CONFIG_FILES_TO_REMOVE[*]}'"
log "Stow folders: '${STOW_FOLDERS[*]}'"
log "--------------------------------------------------------------------------------"
log ""
removeExistingConfigurationFiles "${CONFIG_FILES_TO_REMOVE[@]}"
stowDotfiles "${DOTFILES_HOME}" "${STOW_FOLDERS[@]}"
exit 0
