#!/usr/bin/env bash
set -e

PKG="ghostty"

# Targets
CONFIG_TARGET="$HOME/Library/Application Support/com.mitchellh.ghostty"
THEME_TARGET="$HOME/.config/ghostty"

echo "📦 Stowing Ghostty dotfiles"
echo "🔹 Config target: $CONFIG_TARGET"
echo "🔹 Theme target:  $THEME_TARGET"

# Check stow
if ! command -v stow >/dev/null 2>&1; then
    echo "❌ ERROR: stow is not installed. Run: brew install stow"
    exit 1
fi

# Ensure directories
mkdir -p "$CONFIG_TARGET"
mkdir -p "$THEME_TARGET"

####################################
# Stow config into Application Support
####################################
echo "➡️  Installing config..."
stow --target="$CONFIG_TARGET" --dir=. "$PKG" --ignore=themes

####################################
# Stow themes into ~/.config/ghostty
####################################
echo "➡️  Installing themes..."
stow --target="$THEME_TARGET" --dir=. "$PKG" --ignore=config

echo "✅ Done!"
echo "Config installed to: $CONFIG_TARGET"
echo "Themes installed to: $THEME_TARGET"