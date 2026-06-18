#!/usr/bin/env bash
#
# git-remotes-to-ssh.sh — rewrite a repo's HTTPS Git remotes to their SSH form.
#
# Why:
#   SSH client config (~/.ssh/config: host aliases, IdentitiesOnly, agent keys)
#   only governs ssh:// and git@host: remotes. A remote cloned over HTTPS
#   (https://github.com/owner/repo.git) bypasses all of that and falls back to
#   HTTPS credential prompts (a Personal Access Token these days). Converting the
#   remote to its SSH form routes pushes/fetches through your SSH identity.
#
# What:
#   For each selected remote whose URL is HTTPS, rewrite it in place:
#     https://HOST/OWNER/REPO(.git)  ->  git@HOST:OWNER/REPO(.git)
#   The transform is host-agnostic (github.com, gitlab.com, ...). Remotes that
#   are already SSH (or git://, etc.) are left untouched.
#
# See --help for usage. Caveat on personal/work identity is documented there.

set -euo pipefail

readonly SCRIPT_NAME="${0##*/}"

usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [-n|--dry-run] [REMOTE ...]

Rewrite a repository's HTTPS Git remotes to their SSH equivalent, so pushes and
fetches use your SSH identity (~/.ssh/config) instead of HTTPS credentials:

  https://HOST/OWNER/REPO.git  ->  git@HOST:OWNER/REPO.git

Arguments:
  REMOTE ...      Only convert the named remote(s). Default: every remote.

Options:
  -n, --dry-run   Show what would change without modifying anything.
  -h, --help      Show this help and exit.

Note: the host is mapped literally, so https://github.com/... always becomes
git@github.com:... (your personal identity). For a work alias, fix it by hand:

  git remote set-url origin git@github.com-work:OWNER/REPO.git
EOF
}

die() {
  echo "${SCRIPT_NAME}: error: $*" >&2
  exit 1
}

#######################################
# Converts a single URL to its SSH form. HTTPS URLs are rewritten; anything else
# (already SSH, git://, ...) is echoed unchanged so callers can detect "no diff".
# Arguments:
#   $1: the remote URL
# Outputs:
#   The (possibly rewritten) URL on stdout.
#######################################
to_ssh_url() {
  local url="$1"
  case "${url}" in
    https://*)
      # Drop the scheme, split host from path at the first '/', rejoin as SSH.
      local rest="${url#https://}"
      local host="${rest%%/*}"
      local path="${rest#*/}"
      printf 'git@%s:%s\n' "${host}" "${path}"
      ;;
    *)
      printf '%s\n' "${url}"
      ;;
  esac
}

main() {
  local dry_run=0
  local -a remotes=()

  # Parse options; remaining operands are remote names. '--' ends option parsing.
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n | --dry-run) dry_run=1 ;;
      -h | --help)
        usage
        exit 0
        ;;
      --)
        shift
        remotes+=("$@")
        break
        ;;
      -*) die "unknown option '$1' (try --help)" ;;
      *) remotes+=("$1") ;;
    esac
    shift
  done

  git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || die "not inside a git repository"

  # No remotes named -> operate on all configured remotes.
  if [[ ${#remotes[@]} -eq 0 ]]; then
    local r
    while IFS= read -r r; do
      remotes+=("${r}")
    done < <(git remote)
  fi

  [[ ${#remotes[@]} -gt 0 ]] || die "this repository has no remotes"

  local changed=0 remote url new
  for remote in "${remotes[@]}"; do
    url="$(git remote get-url "${remote}" 2>/dev/null)" \
      || die "no such remote: '${remote}'"
    new="$(to_ssh_url "${url}")"

    if [[ "${new}" == "${url}" ]]; then
      echo "  ${remote}: ${url} (unchanged)"
      continue
    fi

    if ((dry_run)); then
      echo "  ${remote}: ${url} -> ${new} (dry-run)"
    else
      git remote set-url "${remote}" "${new}"
      echo "  ${remote}: ${url} -> ${new}"
    fi
    changed=$((changed + 1))
  done

  if ((dry_run)); then
    echo "${SCRIPT_NAME}: ${changed} remote(s) would change."
  else
    echo "${SCRIPT_NAME}: ${changed} remote(s) updated."
  fi
}

main "$@"
