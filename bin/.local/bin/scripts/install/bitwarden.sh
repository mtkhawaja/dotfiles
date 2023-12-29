#!/usr/bin/env bash

BITWARDEN_HOME=${BITWARDEN_HOME:-"$HOME/.dotfiles/bin/.local/bin/tools/bitwarden"}
BITWARDEN_HOME_BIN="$BITWARDEN_HOME/bin"
rm -rf "$BITWARDEN_HOME"
mkdir -p "$BITWARDEN_HOME_BIN"
curl -L "https://vault.bitwarden.com/download/?app=cli&platform=linux" -o bw.zip
unzip bw.zip
rm bw.zip
chmod +x bw
mv bw "$BITWARDEN_HOME_BIN"
