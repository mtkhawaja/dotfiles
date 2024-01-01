#!/usr/bin/env bash

FOLDER_ID="$1"
DESTINATION_FOLDER="${DESTINATION_FOLDER:-"$HOME/.ssh"}"

if [ -z "$FOLDER_ID" ]; then
  echo "Error: FOLDER_ID ($FOLDER_ID) and DESTINATION_FOLDER ($DESTINATION_FOLDER) must not be empty"
  echo "The FOLDER_ID refers to the bitwarden folder 'itemid'"
  exit 1
fi

echo "Installing SSH keys to $DESTINATION_FOLDER"

mkdir -p "$DESTINATION_FOLDER"
chmod 700 ~/.ssh

bw login --check || bw login
bw sync

pushd "$DESTINATION_FOLDER" >/dev/null || {
  echo "Error: $DESTINATION_FOLDER does not exist"
  exit 1
}

echo ""

bw list items --folderid "$FOLDER_ID" | jq '.[]' | jq -c '{id: .id,  fileName: .attachments[].fileName }' | while read -r attachment; do
  ITEM_ID=$(echo "$attachment" | jq -r '.id')
  ATTACHMENT_NAME=$(echo "$attachment" | jq -r '.fileName')
  echo "Attempting to download attachment: $ATTACHMENT_NAME"
  bw get attachment "$ATTACHMENT_NAME" --itemid "$ITEM_ID" --output "$ATTACHMENT_NAME"
  if [[ "$ATTACHMENT_NAME" == *"pub"* ]]; then
    echo "Setting public key permissions (644) for: $ATTACHMENT_NAME"
    chmod 644 "$ATTACHMENT_NAME"
  else
    echo "Setting private key permissions (600) for: $ATTACHMENT_NAME"
    chmod 600 "$ATTACHMENT_NAME"
  fi
  echo ""
done

popd >/dev/null || {
  echo "Failed to change directory to previous directory"
  exit 1
}
