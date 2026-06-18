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
    # -e misses dangling symlinks (it follows the link); -L catches them, so a
    # broken link left by a prior run is removed too instead of colliding with stow.
    if [ -e "$file" ] || [ -L "$file" ]; then
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

  # Reload the agent so it picks up the new config; tolerate failure (it may not
  # be running yet) and a missing gpgconf entirely.
  if command -v gpgconf >/dev/null 2>&1; then
    gpgconf --kill gpg-agent >/dev/null 2>&1 || true
  fi
}

# Stow ~/.ssh/config (+ tracked public keys) while keeping ~/.ssh a real directory.
# Work GitHub accounts and private servers go in ~/.ssh/config.d/*.conf, which the
# tracked config Includes but which is deliberately NOT version-controlled here.
function configureSshConfig() {
  local dotfiles_home="$1"
  local ssh_dir="$HOME/.ssh"

  # Ensure ~/.ssh itself is a real dir with safe perms BEFORE stowing, so stow links
  # files *inside* it (config, *.pub) instead of folding ~/.ssh into a repo symlink
  # (which would drag known_hosts / control sockets under version control).
  # config.d is intentionally NOT pre-created: stow folds ~/.ssh/config.d into a
  # symlink to the repo's tracked-but-git-ignored ssh/.ssh/config.d, so private
  # includes dropped there are guaranteed a home yet never committed.
  mkdir -p "$ssh_dir"
  chmod 700 "$ssh_dir"

  # A real (non-symlink) ~/.ssh/config is pre-existing user content (OpenSSH default
  # or hand-written) and would collide with `stow ssh`. Back it up with a timestamp
  # before getting it out of the way, so the first run can never destroy it. A symlink
  # here is one we created on a prior run, so stow -D handles it — no backup needed.
  local ssh_config="${ssh_dir}/config"
  if [ -f "$ssh_config" ] && [ ! -L "$ssh_config" ]; then
    local backup
    backup="${ssh_config}.bak.$(date +%Y%m%d-%H%M%S)"
    logPending "Existing real '${ssh_config}' found; backing it up to '${backup}'"
    mv "$ssh_config" "$backup" || logFailureAndExit "Failed to back up '${ssh_config}'"
    logSuccess "Backed up existing SSH config to '${backup}'"
  fi

  stowDotfiles "$dotfiles_home" "ssh"
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
  configureSshConfig "${DOTFILES_HOME}"

  logSuccess "Dotfiles setup completed successfully!"
  return 0
}

main "$@"