# `~/.ssh/config.d/` — private SSH includes

`~/.ssh/config` loads every `*.conf` here (`Include ~/.ssh/config.d/*.conf`), ahead
of its own entries, so these win. Everything except this README is git-ignored:
put account aliases and private servers here, never in the tracked config.

## Accounts

Don't write account entries by hand; `git account add` (see `~/.gitconfig.d/README.md`)
creates `<name>.conf` and the git identity together, and checks both:

```bash
git account add acme github me@acme.com    # Host github.com-acme, pinned to a key you pick
```

Why the alias: every GitHub account connects to `github.com`, and each key belongs
to exactly one account. Offered every key in the SSH agent, GitHub accepts
the first one it knows, so the *wrong* account can authenticate silently. Each entry
pins one key with `IdentitiesOnly yes` + `IdentityFile <name>_<provider>.pub` (only
the public half is on disk). The personal account is `Host github.com` in `~/.ssh/config`.

## Cloning

The host in the URL picks the key, so clone through the alias (or use `clone <repo> <account>`):

```bash
git clone git@github.com-acme:<owner>/<repo>.git           # owner/repo are unchanged
git remote set-url origin git@github.com-acme:<owner>/<repo>.git   # fix an existing clone
```

## Verify

```bash
ssh -T git@github.com-acme     # -> "Hi <expected-username>!"
```

`Permission denied (publickey)` usually means the pinned key isn't registered on
that account: its blob must appear at `https://github.com/<user>.keys`.
