#!/usr/bin/env bash

FOLDER_ID="$1"
KEYS_FOLDER="$HOME/.ssh"

if [ -z "$FOLDER_ID" ]; then
  echo "Error: FOLDER_ID ($FOLDER_ID) must not be empty"
  echo "The FOLDER_ID refers to the bitwarden folder 'itemid'"
  exit 1
fi

echo "Attempting to add all keys in $KEYS_FOLDER to ssh-agent"

if ! [ "$(bw login --check)" = "You are logged in." ] && [ -z "$BW_SESSION" ]; then
  echo "Logging into bitwarden"
  BW_SESSION=$(bw login --raw)
  export BW_SESSION
  bw sync
fi

echo ""

bw list items --folderid "$FOLDER_ID" | jq '.[]' | jq -c '{passphrase: .login.password,  fileName: .attachments[].fileName }' | while read -r bw_record; do
  PASSPHRASE=$(echo "$bw_record" | jq -r '.passphrase')
  PRIVATE_KEY=$(echo "$bw_record" | jq -r '.fileName')
  if [[ "$PRIVATE_KEY" = *.* ]]; then
    continue
  fi
  PRIVATE_KEY_PATH="$KEYS_FOLDER/$PRIVATE_KEY"
  if ! [ -f "$PRIVATE_KEY_PATH" ]; then
    continue
  fi
  echo "Adding $PRIVATE_KEY_PATH to ssh-agent"
  expect <<EOF
  spawn ssh-add "$PRIVATE_KEY_PATH"
  expect "Enter passphrase"
  send "$PASSPHRASE\r"
  expect eof
EOF
  echo ""
done

unset BW_SESSION
bw logout
