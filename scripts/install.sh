#!/usr/bin/env bash

function install_application() {
    application=$1
    if ! [ -x "$(command -v "$application")" ]; then
        apt install "$application" -y
    fi
}

application_list="${BASH_SOURCE%/*}/data/application_list.txt"
while IFS= read -r line; do
    install_application "$line"
done <"$application_list"
