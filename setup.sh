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

function backupExistingConfigurationFiles() {
  local dotfiles_home="$1"
  shift
  local file folder managed backup
  for file in "$@"; do
    if [ -e "$file" ] || [ -L "$file" ]; then
      # Leave managed files to Stow, including files inside a folded directory.
      # Moving those would remove the source file from the repository itself.
      managed=0
      for folder in "${STOW_PACKAGES[@]}"; do
        if [[ "$file" -ef "$dotfiles_home/$folder/${file#"$HOME"/}" ]]; then
          managed=1
          break
        fi
      done
      [[ "$managed" == 1 ]] && continue
      if [[ -d "$file" && ! -L "$file" ]]; then
        logFailureAndExit "Expected a configuration file, found directory: '${file}'"
      fi
      if [[ -z "$BACKUP_DIR" ]]; then
        BACKUP_DIR="$(mktemp -d "${LOG_DIR}/backup.XXXXXXXX")"
        logInfo "Saving existing configurations to: '${BACKUP_DIR}'"
      fi
      backup="${BACKUP_DIR}/${#BACKUP_ORIGINALS[@]}-${file##*/}"
      mv -- "$file" "$backup" || logFailureAndExit "Failed to back up '${file}'"
      BACKUP_ORIGINALS+=("$file")
      BACKUP_PATHS+=("$backup")
      logSuccess "Backed up '${file}' to '${backup}'"
    fi
  done
}

function restoreConfigurationBackups() {
  local i
  for ((i=${#BACKUP_ORIGINALS[@]}-1; i>=0; i--)); do
    mv -- "${BACKUP_PATHS[i]}" "${BACKUP_ORIGINALS[i]}" ||
      log "ERROR" "Could not restore '${BACKUP_ORIGINALS[i]}'; backup remains at '${BACKUP_PATHS[i]}'"
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
    logPending "Attempting restow: '${folder}'"
    local stow_options=()
    # Keep application runtime state outside the repo on a fresh install.
    if [[ "$folder" == "codex" || "$folder" == "claude" ]]; then
      stow_options+=(--no-folding)
    fi
    stow --target="$HOME" --restow "${stow_options[@]}" "${folder}" || logFailureAndExit "Failed to stow: '${folder}'"
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

  # Pre-existing SSH config is backed up with the other configs before preflight.
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
      "codex"
    )
  fi

  logInfo ""
  logInfo "--------------------------------------------------------------------------------"
  logInfo "Starting dotfiles setup..."
  logInfo "Logging to: '${LOGFILE}'"
  logInfo "Dotfiles home: '${DOTFILES_HOME}'"
  logInfo "Configuration files to back up: '${CONFIG_FILES_TO_REMOVE[*]}'"
  logInfo "Stow folders: '${STOW_FOLDERS[*]}'"
  logInfo "--------------------------------------------------------------------------------"
  logInfo ""

  # Validate every package before moving any existing configuration.
  command -v stow >/dev/null 2>&1 || logFailureAndExit "GNU Stow is not installed. Please install it first."
  local gnupg_package="gnupg-linux" folder
  [[ "$(uname -s)" == "Darwin" ]] && gnupg_package="gnupg-macos"
  STOW_PACKAGES=("${STOW_FOLDERS[@]}" "$gnupg_package" ssh)
  for folder in "${STOW_PACKAGES[@]}"; do
    [[ -d "$DOTFILES_HOME/$folder" ]] || logFailureAndExit "Stow folder does not exist: '${folder}'"
  done

  BACKUP_DIR=""
  BACKUP_ORIGINALS=()
  BACKUP_PATHS=()
  # Temporarily move conflicts aside for Stow's dry run. If it fails, restore
  # the originals; after preflight, retain the backups for manual recovery.
  trap restoreConfigurationBackups EXIT
  backupExistingConfigurationFiles "$DOTFILES_HOME" "${CONFIG_FILES_TO_REMOVE[@]}" "$HOME/.ssh/config"
  stow --dir="$DOTFILES_HOME" --target="$HOME" --simulate --restow --no-folding "${STOW_PACKAGES[@]}" ||
    logFailureAndExit "Stow preflight failed; restoring existing configurations"
  trap - EXIT

  # Bootstrap local secrets once; preserve existing files and symlinks.
  if [[ ! -f "$DOTFILES_HOME/.secrets.example" ]]; then
    logInfo "No .secrets.example in '${DOTFILES_HOME}'; skipping secrets bootstrap"
  elif [[ ! -e "$DOTFILES_HOME/.secrets" && ! -L "$DOTFILES_HOME/.secrets" ]]; then
    (umask 077; set -o noclobber; cat "$DOTFILES_HOME/.secrets.example" > "$DOTFILES_HOME/.secrets") ||
      logFailureAndExit "Failed to create local secrets file"
  fi

  stowDotfiles "${DOTFILES_HOME}" "${STOW_FOLDERS[@]}"
  configureGpgAgent "${DOTFILES_HOME}"
  configureSshConfig "${DOTFILES_HOME}"

  logSuccess "Dotfiles setup completed successfully!"
  return 0
}

main "$@"
