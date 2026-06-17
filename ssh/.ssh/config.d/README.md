# `~/.ssh/config.d/` — private SSH includes

`~/.ssh/config` pulls everything here into effect via:

```text
Include ~/.ssh/config.d/*.conf
```

Only `*.conf` files are loaded by SSH. This directory is tracked in dotfiles but
its contents are git-ignored (see `.gitignore`) — **except** `README.md` and
`config.example`. So the folder always exists after `stow`, your real `*.conf`
and `*.pub` files stay local, and nothing private is ever accidentally committed.

- `config.example` — sample include; copy to a real `<name>.conf` and edit.
- `README.md` — this guide.

## How multiple GitHub accounts work

Every GitHub account connects to the same host (`github.com`), and any given SSH
key is registered to exactly **one** account. All your keys live in the Bitwarden
desktop agent, so without pinning GitHub just accepts whichever key it is offered
first — the *wrong* account can authenticate silently.

We make it deterministic by **pinning per host**:

- a distinct **Host alias** per account (`github.com` = personal, `github.com-work` = work)
- `IdentitiesOnly yes` — offer **only** the named key, not every key in the agent
- `IdentityFile <pub>` — picks which agent key by its public blob (the private key
  never leaves Bitwarden; only the `.pub` is on disk)

The personal account is the bare `Host github.com` block in `~/.ssh/config`.

## Adding an account (e.g. a second work / org account)

1. Export the account's **public** key from the Bitwarden agent into `~/.ssh/`:

   ```bash
   ssh-add -L | grep '<key label in Bitwarden>' > ~/.ssh/<user>_github.pub
   ```

2. Fact-check the key is actually registered on that GitHub account (the blob must
   appear, or auth fails with `Permission denied (publickey)`):
   `https://github.com/<user>.keys`
3. Copy `config.example` to a real include and add a `Host` block with a unique
   alias suffix after `github.com-`:

   ```text
   Host github.com-<alias>
       HostName github.com
       User git
       IdentitiesOnly yes
       IdentityFile ~/.ssh/<user>_github.pub
   ```

## Cloning — be careful so routing is correct

The Host **alias** is what selects the key, so the clone URL **must** use the
alias, not plain `github.com`. Clone with the wrong host and the repo is pinned to
the wrong identity (e.g. your personal key on a work repo) — which surfaces later
as push failures or commits attributed to the wrong account.

```bash
# personal (default)
git clone git@github.com:<owner>/<repo>.git
# work alias
git clone git@github.com-work:<owner>/<repo>.git
```

Only the **host** changes. The `<owner>/<repo>` path is the real GitHub org/user
and is identical regardless of alias — GitHub still sees a normal `github.com`
connection; the alias exists only in your local SSH config.

Fix an existing clone that used the wrong host (run inside the repo):

```bash
git remote -v                                          # inspect current URL
git remote set-url origin git@github.com-work:<owner>/<repo>.git
```

Verify routing for a repo / account:

```bash
ssh -T git@github.com-<alias>     # -> "Hi <expected-username>!"
git -C <repo> ls-remote           # should succeed for the intended account
```

**Tip:** to auto-attribute commits per account, pair the alias with a git
`includeIf` in `~/.gitconfig` (per-directory `user.email`), so work clones use
your work identity automatically.
