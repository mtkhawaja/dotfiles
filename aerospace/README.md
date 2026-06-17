# AeroSpace

Make Spaces span displays (so a workspace isn't pinned to one monitor):

```bash
defaults write com.apple.spaces spans-displays -bool true && killall SystemUIServer
```

Find an app's bundle ID for `on-window-detected` rules:

```bash
cd /Applications/Utilities
osascript -e 'id of app "<App-Name>"'
```
