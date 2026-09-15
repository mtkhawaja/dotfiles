# `~/.gitconfig.d/` — private git config includes

The tracked `~/.gitconfig` is the **personal** identity. Work (and any other)
identities are kept out of version control here and pulled in via git's
`includeIf`, mirroring the SSH split in `~/.ssh/config.d/`.

This directory is tracked in dotfiles but its contents are git-ignored (see
`.gitignore`) — **except** `README.md` and `work.config.example`. So the folder
always exists after `stow`, your real `*.config` files stay local, and nothing
private is ever accidentally committed.

- `work.config.example` — sample work include; copy to `work.config` and edit.
- `README.md` — this guide.

## How the split works

`~/.gitconfig` ends the `[user]` block with a conditional include:

```ini
[includeIf "hasconfig:remote.*.url:git@github.com-work:*/**"]
    path = ~/.gitconfig.d/work.config
```

`hasconfig:remote.*.url:<pattern>` matches when the repository has a remote whose
URL matches the pattern. `*/**` matches the `owner/repo` path (and any deeper
path). Note git's `**` only spans `/` when adjacent to one (`/**`, `**/`); a bare
`**` after the colon acts like `*` and won't cross the slash — hence `*/**`. Because work repos are cloned through the
`github.com-work` SSH alias (see `~/.ssh/config.d/`), any such repo automatically
loads `work.config`, whose `[user]` block overrides the personal email/name.
Personal repos (plain `github.com`) don't match, so they keep the personal
identity. **No directory convention required** — identity follows the remote.

Includes apply in file order, so the `includeIf` sits *after* the personal
`[user]` block; when it matches, its values win.

## Setup

1. Copy the template:

   ```bash
   cp ~/.gitconfig.d/work.config.example ~/.gitconfig.d/work.config
   ```

2. Set your work email (and optionally name / signing key) in `work.config`.
3. Clone work repos through the work alias so the include triggers:

   ```bash
   git clone git@github.com-work:<org>/<repo>.git
   ```

## Verify

Inside a work repo (remote uses `github.com-work`):

```bash
git config user.email      # -> your work email
```

Inside a personal repo (remote uses `github.com`):

```bash
git config user.email      # -> 36654508+mtkhawaja@users.noreply.github.com
```

To see *which* file supplied the value (useful when a repo picks the identity you
did not expect):

```bash
git config --show-origin --get user.email
```

## Where matching on the remote falls short

`hasconfig:remote.*.url` can only fire once a matching remote exists. Two cases
slip through, and both fail **silently** by falling back to the personal identity:

| Case | Why it misses |
|---|---|
| Work repo cloned over **HTTPS** | The URL is `https://github.com/owner/repo.git`, which never matches the `git@github.com-work:` pattern. `gh repo clone`, IDE clone dialogs and CI checkouts all default to HTTPS. |
| `git init` **before** `git remote add` | There is no remote yet, so the condition cannot match. Commits made in that window carry the personal identity and keep it after the remote is added. |

So `~/.gitconfig` pairs the remote condition with a **location** condition:

```ini
[includeIf "gitdir:~/source-code/work/"]
    path = ~/.gitconfig.d/work.config
```

Anything under `~/source-code/work/` gets the work identity regardless of remote
(or absence of one). The trailing slash matters: it matches the directory and
everything beneath it. The two conditions are complementary, not redundant — the
remote condition covers work repos cloned outside that tree, the directory
condition covers repos whose remote cannot be matched.

To convert an HTTPS remote to its SSH form, `git-remotes-to-ssh.sh` (in
`bin/.local/bin/scripts/utility/`) rewrites it — but it maps the host literally,
so `https://github.com/...` becomes the **personal** `git@github.com:...`. For a
work repo, set the alias by hand:

```bash
git remote set-url origin git@github.com-work:<owner>/<repo>.git
```

## Signing keys are not part of the split

`user.signingkey` lives in the personal `[user]` block and therefore applies in
work repos too. Nothing is signed automatically (`commit.gpgsign` is unset), so
this is latent rather than active — but if a work org ever requires signed
commits, they would be signed with the personal key. `work.config.example` has a
commented `signingkey` line for that reason; uncomment it and set a work key
before enabling signing on work repos.
