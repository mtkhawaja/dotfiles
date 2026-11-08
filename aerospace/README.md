# AeroSpace

Config for the [AeroSpace](https://nikitabobko.github.io/AeroSpace/guide) tiling window manager,
stowed to `~/.aerospace.toml`. Reload it with `alt-shift-;` then `esc`.

## Workspaces

| Keys                    | Action                                             |
|-------------------------|----------------------------------------------------|
| `alt-1` … `alt-9`       | Summon a numbered workspace                        |
| `alt-<letter>`          | Summon a named one: `d` Development, `w` Web, `t` Tools, `r` Research, `m` Media, `n` Notes, `c` Communication, `e` Email, `a` Apple, `b` Bitwarden, `p` PyCharm; other letters are spare single-letter workspaces |
| `alt-shift-<key>`       | Move the focused window to that workspace          |

`on-window-detected` rules send apps to their workspace automatically, and `after-startup-command`
moves Research, Media, Notes, Tools and Communication to the secondary monitor when one is attached.

## Service mode (`alt-shift-;`)

| Key                    | Action                                  |
|------------------------|-----------------------------------------|
| `esc`                  | Reload config                           |
| `r`                    | Reset layout (flatten workspace tree)   |
| `b`                    | Balance window sizes                    |
| `f`                    | Toggle floating / tiling                |
| `backspace`            | Close all windows but the focused one   |
| `alt-shift-h/j/k/l`    | Join with the window in that direction  |

## macOS setup

Make Spaces span displays, so a workspace isn't pinned to one monitor:

```bash
defaults write com.apple.spaces spans-displays -bool true && killall SystemUIServer
```

## Adding an app rule

Find the app's bundle ID for an `on-window-detected` rule:

```bash
osascript -e 'id of app "<App-Name>"'
```
