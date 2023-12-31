#!/usr/bin/env bash

# See: https://stackoverflow.com/questions/21691202/how-to-create-file-execute-mode-permissions-in-git-on-windows

TARGET_FILE=$1

if ! [ -f "$TARGET_FILE" ]; then
  echo "File does not exist: '$TARGET_FILE'"
  exit 1
fi

echo "Attempting to make '$TARGET_FILE' executable"
git add --chmod=+x -- "$TARGET_FILE"
git commit -m "Updated permissions to make '$TARGET_FILE' executable" -- "$TARGET_FILE"
