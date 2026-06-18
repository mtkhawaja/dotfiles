#!/usr/bin/env zsh

#
# fix-ssh-permissions.zsh
#
# Normalizes SSH file permissions
#
#

set -o errexit   # die on unhandled errors
set -o pipefail  # catch errors in any part of a pipeline

#######################################
# Configuration
#######################################
SCRIPT_NAME="${0:t}"
DEFAULT_SSH_DIR="${HOME}/.ssh"

# Permission modes
DIR_MODE=700
PUBLIC_KEY_MODE=644
PRIVATE_KEY_MODE=600

# Reserved SSH files get a fixed mode (see reserved_file_mode). Implemented as a
# case rather than an associative array so `zsh -n` can syntax-check this file:
# under -n the `typeset -A` isn't executed, so an [key]=value literal would trip
# "bad subscript for direct array assignment".

#######################################
# Logging helpers (with colors)
#######################################

autoload -Uz colors && colors

function _timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

function log_info() {
  local msg
  msg="$*"
  print -r -- "$(_timestamp) [INFO]  [$SCRIPT_NAME] ${fg[green]}${msg}${reset_color}" >&2
}

function log_warn() {
  local msg
  msg="$*"
  print -r -- "$(_timestamp) [WARN]  [$SCRIPT_NAME] ${fg[yellow]}${msg}${reset_color}" >&2
}

function log_error() {
  local msg
  msg="$*"
  print -r -- "$(_timestamp) [ERROR] [$SCRIPT_NAME] ${fg[red]}${msg}${reset_color}" >&2
}

#######################################
# Counters
#######################################

integer count_pub=0
integer count_private=0
integer count_reserved=0

#######################################
# Functional blocks
#######################################

function ensure_target_dir() {
  local target="$1"
  if [[ -e "$target" && ! -d "$target" ]]; then
    log_error "Path exists but is not a directory: $target"
    return 1
  fi
  if [[ ! -d "$target" ]]; then
    log_warn "Directory does not exist; creating: $target"
    mkdir -p "$target"
  fi
}

function set_directory_permissions() {
  local target="$1"
  log_info "Setting directory permissions '$DIR_MODE' on '$target'"
  chmod "$DIR_MODE" "$target"
}

# Echoes the required mode for a reserved SSH filename; returns non-zero if the
# name is not reserved (so callers fall through to the public/private heuristics).
function reserved_file_mode() {
  case "$1" in
    config | authorized_keys | authorized_keys2) print -r -- 600 ;;
    known_hosts | known_hosts.old) print -r -- 644 ;;
    *) return 1 ;;
  esac
}

function process_reserved_file() {
  local file="$1"
  local mode="$2"
  log_info "[RESERVED_FILE] '$file' -> chmod $mode"
  chmod "$mode" "$file"
}

function process_public_key() {
  local file="$1"
  log_info "[PUBLIC KEY] '$file' -> chmod $PUBLIC_KEY_MODE"
  chmod "$PUBLIC_KEY_MODE" "$file"
}

function process_private_key() {
  local file="$1"
  log_info "[PRIVATE KEY] '$file' -> chmod $PRIVATE_KEY_MODE"
  chmod "$PRIVATE_KEY_MODE" "$file"
}

function scan_and_fix_files() {
  local target="$1"
  local file base mode
  log_info "Normalizing permissions for files in: '$target'"

  for file in "$target"/*; do
    # Skip anything that isn't a real regular file. The -L guard skips symlinks
    # (e.g. a stowed ~/.ssh/config); without it chmod would follow the link and
    # silently re-perm the tracked file in the dotfiles repo.
    [[ -f "$file" && ! -L "$file" ]] || continue
    base="${file:t}"
    if mode="$(reserved_file_mode "$base")"; then
      process_reserved_file "$file" "$mode"
    elif [[ "$base" == *.pub ]]; then
      process_public_key "$file"
    else
      process_private_key "$file"
    fi
  done
}

#######################################
# Main
#######################################

function main() {
  local target_dir
  target_dir="${1:-${DEFAULT_SSH_DIR}}"
  log_info "Starting SSH permission normalization for ssh directory: '$target_dir'"
  ensure_target_dir "$target_dir" || return 1
  set_directory_permissions "$target_dir"
  scan_and_fix_files "$target_dir"
  log_info "SSH permission normalization complete"
}

main "$@"