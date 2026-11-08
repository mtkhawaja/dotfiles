# ~/.local/bin

Personal scripts, stowed to `~/.local/bin/` (the
[XDG/systemd location](https://www.freedesktop.org/software/systemd/man/latest/file-hierarchy.html#~/.local/bin/)
for user executables). `scripts/utility/` is on `PATH` via `~/.zshenv`.

```text
bin/
└── scripts/
    ├── utility/    on PATH
    └── ui-check/   Bun project behind the ui-check wrapper
```

| Script                    | Does                                                                  |
|---------------------------|-----------------------------------------------------------------------|
| `git-account.py`          | Add/list/remove git accounts (identity + SSH alias + `includeIf`); also `git account`. See `~/.gitconfig.d/README.md` |
| `git-remotes-to-ssh.sh`   | Rewrite a repo's HTTPS remotes to SSH                                 |
| `fix-ssh.sh`              | Normalize `~/.ssh` file permissions                                   |
| `aws-creds-to-default.py` | Set the `[default]` AWS profile from credentials on the clipboard     |
| `commit_as_executable.sh` | Set a file executable in git (works where chmod is ignored) and commit it |
| `ui-check`                | Render a page at several widths and run layout checks (Playwright)    |

See each script's header for usage.
