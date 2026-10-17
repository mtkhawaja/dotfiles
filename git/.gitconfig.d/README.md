# `~/.gitconfig.d/` — git identities

The tracked `~/.gitconfig` defaults to the **personal** identity. Other accounts
(GitHub orgs, Bitbucket, GitLab, self-hosted) take over per repo, selected by
folder or remote. Everything here except `personal.config`, the sample and this README
is git-ignored.

| File | Purpose |
|---|---|
| `personal.config` | Personal identity (tracked): the default, and forced for `github.com` remotes |
| `local.config` | Optional machine overrides, e.g. a different default identity |
| `<name>.config` | One account's `[user]` identity |
| `accounts.config` | The `includeIf` rules that select each account; managed by `git account` (sample: `accounts.config.example`) |

`~/.gitconfig` includes them in that order, and later ones win.

## Accounts

```bash
git account add work bitbucket me@corp.com      # every Bitbucket remote is work
git account add acme github me@acme.com         # GitHub org account; prompts for the SSH key
git account add corp git.corp.com me@corp.com   # self-hosted
git account list
git account remove acme [--purge]               # --purge also deletes its files
```

`git account --help` lists every option. An account is selected by:

- **Folder**: anything under `~/source-code/<name>/`, with or without a remote.
  The most reliable rule: immune to HTTPS clones, `git init` before
  `git remote add`, and host renames.
- **Remote** (`--match` overrides the default):
  - `host` (Bitbucket's default): every remote on that host, SSH or HTTPS. For a
    host you have one account on. Covers both `ssh.bitbucket.org` and legacy
    `git@bitbucket.org` ([host change](https://community.atlassian.com/forums/discussion/3234032/upcoming-change-to-bitbucket-cloud-ssh-access-move-from-bitbucket-org-to-ssh-bitbucket-org)).
  - `alias` (default otherwise): only remotes using the SSH alias
    `<host>-<name>`. For hosts shared by several accounts, like GitHub.

`add` writes the identity, the SSH entry (`~/.ssh/config.d/<name>.conf`) and the
rules, then self-checks that git and ssh resolve to the new account, exiting
non-zero if not. It refuses a remote rule another account already has, since git
and ssh would then disagree. Re-running it updates the account in place; lines you
add to `accounts.config` outside the `# >>> account:` blocks are kept.

`clone <owner/repo|url> [account]` (in `.zshrc`) infers the account from the URL
and clones into `~/source-code/<account>/`.

## Verify

```bash
git config --show-origin --get user.email   # which file supplied the identity
```

## Signing keys

Accounts inherit `user.signingkey` from `personal.config` unless their
`<name>.config` sets one. Nothing is signed automatically (`commit.gpgsign` is
unset); set an account's own key before enabling signing for it.
