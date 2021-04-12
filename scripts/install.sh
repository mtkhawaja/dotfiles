#!/usr/bin/env bash

function install_package() {
    application=$1
    if ! [ -x "$(command -v "$application")" ]; then
        apt install "$application" -y
    fi
}

package_list="${BASH_SOURCE%/*}/data/application_list.txt"
while IFS= read -r line; do
    echo "$line"
    install_package "$line"
done <"$package_list"
