# zsh

Shell config on [oh-my-zsh](https://ohmyz.sh/) (`robbyrussell` theme).

| File       | Loaded by                                | Put here                                                    |
|------------|------------------------------------------|-------------------------------------------------------------|
| `.zshenv`  | Every zsh: scripts, `zsh -c`, `ssh host 'cmd'` | `PATH`, env vars, toolchain bin dirs, `.secrets`       |
| `.zshrc`   | Interactive shells only                  | oh-my-zsh, plugins, aliases, functions, slow init (nvm, sdkman, completions) |

If something works in your terminal but not in a script or over SSH, it's in `.zshrc` and belongs in
`.zshenv`. Keep `.zshenv` fast and silent: it runs for every shell.

## Third-party plugins

Most plugins in `.zshrc` ship with oh-my-zsh. These two must be cloned into `$ZSH_CUSTOM`:

```bash
git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
git clone https://github.com/zsh-users/zsh-syntax-highlighting "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
```

Don't add the `ssh-agent` plugin: it replaces the Bitwarden agent socket set in `.zshenv` and SSH
auth then fails.

## Handy commands

| Command                       | Does                                                        |
|-------------------------------|-------------------------------------------------------------|
| `dot` / `dfs`                 | `cd ~/.dotfiles` / run `setup.sh`                           |
| `reload`                      | Restart the shell to pick up changes                        |
| `clone <owner/repo> [account]`| Clone into `~/source-code/<account>/` with the right git identity |

## References

- [zsh startup files](https://zsh.sourceforge.io/Intro/intro_3.html)
