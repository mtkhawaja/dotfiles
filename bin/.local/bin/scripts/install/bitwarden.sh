#!/usr/bin/env bash

BITWARDEN_HOME=${BITWARDEN_HOME:-"$HOME/.local/bin/tools/bitwarden"}
BITWARDEN_HOME_BIN="$BITWARDEN_HOME/bin"
BITWARDEN_PASSWORD_MANAGER_URL=${BITWARDEN_PASSWORD_MANAGER_URL:-"https://vault.bitwarden.com/download/?app=cli&platform=linux"}
BITWARDEN_SECRETS_MANAGER_VERSION=${BITWARDEN_SECRETS_MANAGER_VERSION:-"0.4.0"}
BITWARDEN_SECRETS_MANAGER_URL=${BITWARDEN_SECRETS_MANAGER_URL:-"https://github.com/bitwarden/sdk/releases/download/bws-v${BITWARDEN_SECRETS_MANAGER_VERSION}/bws-x86_64-unknown-linux-gnu-${BITWARDEN_SECRETS_MANAGER_VERSION}.zip"}

function downloadBitwardenCLITool() {
  local url="$1"
  local binary_name="$2"
  local zip_name="${binary_name}.zip"
  local destination="$3"
  curl -L "$url" -o "$zip_name"
  unzip "$zip_name"
  rm "$zip_name"
  chmod +x "${binary_name}"
  mv "${binary_name}" "$destination"
}

rm -rf "$BITWARDEN_HOME"
mkdir -p "$BITWARDEN_HOME_BIN"
downloadBitwardenCLITool "$BITWARDEN_PASSWORD_MANAGER_URL" "bw" "$BITWARDEN_HOME_BIN"
downloadBitwardenCLITool "$BITWARDEN_SECRETS_MANAGER_URL" "bws" "$BITWARDEN_HOME_BIN"
