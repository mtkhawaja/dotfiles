#!/usr/bin/env bash

BITWARDEN_HOME=${BITWARDEN_HOME:-"/opt/bitwarden/bin"}
rm -rf "$BITWARDEN_HOME"
mkdir -p "$BITWARDEN_HOME"
curl -L "https://vault.bitwarden.com/download/?app=cli&platform=linux" -o bw.zip
unzip bw.zip
rm bw.zip
chmod +x bw
mv bw "$BITWARDEN_HOME"
