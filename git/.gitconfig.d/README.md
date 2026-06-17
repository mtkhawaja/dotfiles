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

## Alternative condition: by directory

Prefer to switch identity by where a repo lives rather than by remote? Use a
`gitdir` condition instead (or in addition):

```ini
[includeIf "gitdir:~/work/"]
    path = ~/.gitconfig.d/work.config
```

This loads `work.config` for any repo under `~/work/`. The trailing slash matters
(matches the directory and everything beneath it).
