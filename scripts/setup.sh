#!/usr/bin/env bash

function install_packages() {
    # shellcheck source=./install.sh
    source "${BASH_SOURCE%/*}/install.sh"
}

function copy_dot_files() {
    config_root=$1
    copy_destination=$2
    local -n config_selection=$3
    for dir in "${config_selection[@]}"; do
        for entry in "$config_root/$dir"/*; do
            if [[ -f $entry ]]; then
                cp "$entry" "$copy_destination"
            fi
        done
    done
}

function configure_vim() {
    vim -E +PlugInstall +qall
}

##################################################
# shopt reference:
# https://www.gnu.org/software/bash/manual/html_node/The-Shopt-Builtin.html
# Enable globbing for dot files.
##################################################
shopt -s dotglob
default_copy_destination="$HOME/temp"
COPY_DESTINATION=${1:-$default_copy_destination}
CONFIG_ROOT="${BASH_SOURCE%/*}/../src"
# shellcheck disable=SC2034  # Unused variables left for readability
CONFIG_SELECTION=(bash git system vim)

echo "⌛ Installing packages."
install_packages ""
echo "✅ Packages installed."

echo "⌛ Copying configuration files."
copy_dot_files "$CONFIG_ROOT" "$COPY_DESTINATION" CONFIG_SELECTION
echo "✅ Configuration files copied."

echo "⌛ Configuring vim."
configure_vim ""
echo "✅ vim configured."

# Cleanup
shopt -u dotglob
