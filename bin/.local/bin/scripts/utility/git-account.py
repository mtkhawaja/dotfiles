#!/usr/bin/env python3
#
# git-account.py — register a git account: an identity plus the rules that select it.
# Also available as `git account` (alias in ~/.gitconfig).
#
# Why:
#   The tracked ~/.gitconfig defaults to the personal identity. Other accounts
#   (GitHub orgs, Bitbucket, GitLab, self-hosted) each need an identity, an SSH
#   entry pinned to the right key, and includeIf rules — tedious and easy to get
#   subtly wrong by hand, and wrong in the worst way: silently, with the wrong email.
#
# What:
#   Each account <name> ties together:
#     ~/.gitconfig.d/<name>.config    its [user] identity (git-ignored)
#     ~/.gitconfig.d/accounts.config  includeIf rules selecting it (git-ignored,
#                                     included last by ~/.gitconfig so they win)
#     ~/.ssh/config.d/<name>.conf     SSH host entry pinned to an SSH agent key
#     ~/source-code/<name>/           repos here always use the account
#
#   Remotes select the account in one of two ways (--match overrides the default):
#     host   every remote on the provider's host. For a host you have ONE account
#            on. Default for bitbucket.
#     alias  only remotes using the SSH alias <host>-<name>, e.g.
#            git@github.com-acme:org/repo.git. For a host shared by several
#            accounts. Default for github, gitlab, and self-hosted.
#
#   `add` finishes with a self-check: a throwaway repo per rule must resolve to
#   the new identity, and `ssh -G` must resolve to the right host and key.
#   Re-running `add` updates the identity and the account's rules in place;
#   existing SSH config and public keys are kept. Lines in accounts.config
#   outside the managed `# >>> account:` blocks are preserved.
#
# Dependencies: Python 3.9+ standard library, git >= 2.36 (hasconfig), ssh, ssh-add.
#
# See --help for usage.

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import tempfile
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

Match = Literal["host", "alias"]

HOME = Path.home()
GIT_DIR_D = HOME / ".gitconfig.d"
SSH_DIR = HOME / ".ssh"
SSH_DIR_D = SSH_DIR / "config.d"
ACCOUNTS = GIT_DIR_D / "accounts.config"
SOURCE_ROOT = HOME / "source-code"

BEGIN = "# >>> account: "
END = "# <<< account: "
INCLUDE_IF = re.compile(r'^\[includeIf "(.*)"\]$')

NAME_RE = re.compile(r"[A-Za-z0-9_]+")
HOST_RE = re.compile(r"[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+")
EMAIL_RE = re.compile(r"[^@\s]+@[^@\s]+")
# Variables that point git at a specific repo (set in hooks, or by hand). Dropped so
# the self-check's throwaway repos and config lookups never touch a real one.
GIT_REPO_VARS = ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_COMMON_DIR", "GIT_PREFIX")


class AccountError(Exception):
    """A user-facing failure; reported as `git-account: <message>` with exit status 1."""


@dataclass(frozen=True)
class Provider:
    web: str  # host in browser/HTTPS URLs
    ssh_host: str  # where SSH actually connects
    slug: str  # used in the public key file name: <account>_<slug>.pub
    match: Match  # default --match


PROVIDERS = {
    "github": Provider("github.com", "github.com", "github", "alias"),
    "gitlab": Provider("gitlab.com", "gitlab.com", "gitlab", "alias"),
    # Bitbucket Cloud SSH moved to ssh.bitbucket.org (bitbucket.org is HTTPS-only
    # from 2026-11-12): https://community.atlassian.com/forums/discussion/3234032/upcoming-change-to-bitbucket-cloud-ssh-access-move-from-bitbucket-org-to-ssh-bitbucket-org
    "bitbucket": Provider("bitbucket.org", "ssh.bitbucket.org", "bitbucket", "host"),
}


@dataclass(frozen=True)
class Plan:
    hosts: tuple[str, ...]  # SSH Host names in <name>.conf; the first is used for owner/repo clones
    patterns: tuple[str, ...]  # hasconfig:remote.*.url globs
    sample_url: str  # a remote the self-check expects to select the account
    hint: str  # how to clone with the account


# --- helpers ---


def tilde(path: Path) -> str:
    try:
        return f"~/{path.relative_to(HOME)}"
    except ValueError:
        return str(path)


def say(tag: str, message: str) -> None:
    print(f"{tag:<7} {message}")


def condition(rule: str) -> str | None:
    """The condition of an `[includeIf "<condition>"]` line, else None."""
    m = INCLUDE_IF.match(rule)
    return m.group(1) if m else None


def run(*args: str, cwd: Path | None = None, check: bool = False) -> subprocess.CompletedProcess[str]:
    """Runs a command with output captured; with check, a non-zero exit raises AccountError."""
    env = {k: v for k, v in os.environ.items() if k not in GIT_REPO_VARS}
    result = subprocess.run(args, cwd=cwd, env=env, capture_output=True, text=True, check=False)
    if check and result.returncode != 0:
        raise AccountError(f"`{' '.join(args)}` failed: {result.stderr.strip()}")
    return result


def write_file(path: Path, text: str, mode: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    path.chmod(mode)


def resolve_provider(name: str) -> Provider:
    if name in PROVIDERS:
        return PROVIDERS[name]
    if HOST_RE.fullmatch(name):  # self-hosted SSH host, e.g. git.corp.com
        return Provider(name, name, name.split(".")[0], "alias")
    raise AccountError(f"unknown provider '{name}' (github, gitlab, bitbucket, or a host name)")


def make_plan(name: str, provider: Provider, match: Match) -> Plan:
    if match == "host":
        hosts = [provider.ssh_host]
        if provider.web != provider.ssh_host:
            hosts.append(provider.web)  # e.g. legacy git@bitbucket.org remotes
        patterns = [p for h in hosts for p in (f"git@{h}:*/**", f"ssh://git@{h}/**", f"ssh://git@{h}:*/**")]
        patterns += [f"https://{provider.web}/**", f"https://*@{provider.web}/**"]
        return Plan(
            tuple(hosts),
            tuple(patterns),
            sample_url=f"git@{provider.ssh_host}:owner/repo.git",
            hint=f"any {provider.web} URL also works",
        )
    alias = f"{provider.web}-{name}"
    return Plan(
        (alias,),
        (f"git@{alias}:*/**", f"ssh://git@{alias}/**"),
        sample_url=f"git@{alias}:owner/repo.git",
        hint=f"or git@{alias}:<owner>/<repo>.git",
    )


# --- accounts.config: managed blocks inside a file that may hold other lines ---


def read_lines() -> list[str]:
    return ACCOUNTS.read_text().splitlines() if ACCOUNTS.exists() else []


def parse_blocks(lines: Sequence[str]) -> dict[str, tuple[int, int]]:
    """Returns {account: (begin index, end index)}; raises on a malformed file."""
    spans: dict[str, tuple[int, int]] = {}
    current: str | None = None
    start = 0
    for i, line in enumerate(lines):
        where = f"{tilde(ACCOUNTS)}:{i + 1}"
        if line.startswith(BEGIN):
            if current is not None:
                raise AccountError(f"{where}: block '{current}' is missing its end marker")
            current, start = line.removeprefix(BEGIN), i
            if current in spans:
                raise AccountError(f"{where}: duplicate block for '{current}'")
        elif line.startswith(END):
            if current is None or line.removeprefix(END) != current:
                raise AccountError(f"{where}: unexpected end marker")
            spans[current] = (start, i)
            current = None
    if current is not None:
        raise AccountError(f"{tilde(ACCOUNTS)}: block '{current}' is missing its end marker")
    return spans


def blocks() -> dict[str, list[str]]:
    lines = read_lines()
    return {name: lines[begin + 1 : end] for name, (begin, end) in parse_blocks(lines).items()}


def set_block(name: str, rules: Sequence[str] | None) -> None:
    """Replaces account name's block in place (appends if new; removes if rules is None)."""
    lines = read_lines()
    span = parse_blocks(lines).get(name)
    block = [] if rules is None else [BEGIN + name, *rules, END + name]
    if span:
        begin, end = span
        lines[begin : end + 1] = block
    else:
        lines += block
    tmp = ACCOUNTS.with_suffix(".tmp")
    write_file(tmp, "\n".join(lines) + "\n" if lines else "", 0o600)
    tmp.replace(ACCOUNTS)


# --- SSH ---


def agent_keys() -> list[str]:
    """Public keys in the SSH agent; empty when there is no agent or no ssh-add."""
    try:
        result = run("ssh-add", "-L")
    except OSError:
        return []
    if result.returncode != 0:
        return []
    return [key for key in result.stdout.splitlines() if key.strip()]


def key_label(key: str) -> str:
    kind, _, rest = key.partition(" ")
    blob, _, comment = rest.partition(" ")
    return comment or f"{kind} …{blob[-12:]}"


def key_blob(key: str) -> str:
    parts = key.split()
    return parts[1] if len(parts) > 1 else ""


def pick_key(key_hint: str | None, *, allow_none: bool) -> str | None:
    """Returns the agent key whose label is key_hint (exact, else unique substring),
    or prompts for one. None only when allow_none and the user picks "none"."""
    keys = agent_keys()
    if not keys:
        raise AccountError("no keys in the SSH agent (is it running and unlocked?)")
    available = ", ".join(key_label(k) for k in keys)
    if key_hint:
        exact = [k for k in keys if key_label(k) == key_hint]
        found = exact or [k for k in keys if key_hint in key_label(k)]
        if not found:
            raise AccountError(f"no agent key matches '{key_hint}'; available: {available}")
        if len(found) > 1:
            raise AccountError(f"'{key_hint}' matches several keys: {', '.join(key_label(k) for k in found)}")
        return found[0]
    if not sys.stdin.isatty():
        raise AccountError(f"--key is required (available: {available})")

    print("Pick the SSH key for this account:", file=sys.stderr)
    for i, key in enumerate(keys, 1):
        print(f"  {i}) {key_label(key)}", file=sys.stderr)
    if allow_none:
        print("  0) none (use any agent key)", file=sys.stderr)
    try:
        choice = input("> ").strip()
    except EOFError:
        raise AccountError("cancelled") from None
    if allow_none and choice == "0":
        return None
    if not choice.isdigit() or not 1 <= int(choice) <= len(keys):
        raise AccountError(f"invalid choice '{choice}'")
    return keys[int(choice) - 1]


def conf_values(conf: Path, keyword: str) -> list[str]:
    """Values of every `<keyword> ...` line in an ssh config file (case-insensitive)."""
    values = []
    for line in conf.read_text().splitlines():
        parts = line.split()
        if len(parts) > 1 and parts[0].lower() == keyword.lower():
            values += parts[1:]
    return values


def write_ssh_conf(
    name: str, provider: Provider, hosts: Sequence[str], key_hint: str | None, match: Match
) -> str | None:
    """Ensures ~/.ssh/config.d/<name>.conf exists, creating it pinned to an agent key.

    An existing conf is kept as is. Returns its pinned IdentityFile as written
    (e.g. `~/.ssh/acme_github.pub`), or None if it doesn't pin one.
    """
    conf = SSH_DIR_D / f"{name}.conf"
    if conf.exists():
        say("kept", f"{tilde(conf)} (already exists)")
        missing = [h for h in hosts if h not in conf_values(conf, "Host")]
        if missing:
            say("warn", f"it has no `Host {' '.join(missing)}`; edit it, or delete it and re-run")
        identities = conf_values(conf, "IdentityFile")
        return identities[0] if identities else None

    pub = SSH_DIR / f"{name}_{provider.slug}.pub"
    identity: str | None = f"~/.ssh/{pub.name}"
    if pub.exists() and pub.stat().st_size:
        say("kept", f"{tilde(pub)} (already exists)")
        loaded = {key_blob(k) for k in agent_keys()}
        if loaded and key_blob(pub.read_text()) not in loaded:
            say("warn", f"{tilde(pub)} is not in the SSH agent; auth will fail until it is")
    elif key := pick_key(key_hint, allow_none=match == "host"):
        write_file(pub, key + "\n", 0o644)
        say("wrote", tilde(pub))
    else:
        identity = None  # the user chose "none": any agent key may be offered

    lines = [
        f"# Private — git-ignored. Generated by git-account.py for the '{name}' account.",
        f"Host {' '.join(hosts)}",
        f"    HostName {provider.ssh_host}",
        "    User git",
    ]
    if identity:
        lines += ["    IdentitiesOnly yes", f"    IdentityFile {identity}"]
    write_file(conf, "\n".join(lines) + "\n", 0o600)  # ssh rejects group/world-writable configs
    say("wrote", tilde(conf))
    return identity


# --- git ---


def default_user_name() -> str:
    """The machine's default user.name (personal.config, or local.config's override).

    --includes because ~/.gitconfig gets the name from an include; run outside any
    repo so the current repo's includeIf rules (e.g. a work identity) don't apply.
    """
    with tempfile.TemporaryDirectory() as outside:
        return run("git", "config", "--global", "--includes", "user.name", cwd=Path(outside)).stdout.strip()


def resolved_email(repo_dir: Path, url: str) -> str:
    """The user.email git resolves for a fresh repo in repo_dir with remote url."""
    run("git", "init", "-q", cwd=repo_dir, check=True)
    run("git", "remote", "add", "origin", url, cwd=repo_dir, check=True)
    return run("git", "config", "user.email", cwd=repo_dir).stdout.strip()


# --- self-check ---


def check_git(name: str, email: str, sample_url: str) -> bool:
    """Fresh repos selected by remote and by folder must resolve to the new email."""
    ok = True
    folder = SOURCE_ROOT / name
    with tempfile.TemporaryDirectory() as by_remote, tempfile.TemporaryDirectory(dir=folder) as by_folder:
        cases = (
            (f"remote {sample_url}", Path(by_remote), sample_url),
            (f"folder {tilde(folder)}/", Path(by_folder), "https://example.invalid/x/y.git"),
        )
        for what, repo, url in cases:
            got = resolved_email(repo, url)
            if got == email:
                say("check", f"{what} -> {email}")
            else:
                ok = False
                say("FAIL", f"{what} -> {got or 'no email'} (expected {email})")
    if not ok:
        version = run("git", "version").stdout.split()[-1]
        say("hint", f"needs git >= 2.36 (have {version}) and ~/.gitconfig including ~/.gitconfig.d/accounts.config")
    return ok


def check_ssh(hosts: Sequence[str], provider: Provider, identity: str | None) -> bool:
    """`ssh -G` must resolve every host to the provider, with the pinned key first."""
    ok = True
    for host in hosts:
        try:
            output = run("ssh", "-G", host, check=True).stdout
        except OSError:
            say("skip", "ssh not found; SSH entry not checked")
            return True
        resolved: dict[str, str] = {}
        for line in output.splitlines():
            key, _, value = line.partition(" ")
            resolved.setdefault(key, value)  # ssh uses the first value, e.g. of identityfile
        hostname, first_identity = resolved.get("hostname"), resolved.get("identityfile", "")
        if hostname == provider.ssh_host and identity in (None, first_identity):
            say("check", f"ssh {host} -> {hostname}" + (f" with {identity}" if identity else ""))
        else:
            ok = False
            say("FAIL", f"ssh {host} -> {hostname} with {first_identity or 'any key'}")
    if not ok:
        say("hint", "is ~/.ssh/config including ~/.ssh/config.d/*.conf, with no earlier entry for this host?")
    return ok


# --- commands ---


def add(
    name: str,
    provider_name: str,
    email: str,
    *,
    key_hint: str | None,
    match: Match | None,
    user_name: str | None,
    urls: Sequence[str],
) -> bool:
    """Adds or updates an account; returns whether the self-check passed."""
    if not NAME_RE.fullmatch(name):
        raise AccountError(f"account name must be letters, digits or _ (got '{name}')")
    if name == "personal":
        raise AccountError("'personal' is the tracked default identity; edit personal.config instead")
    if not EMAIL_RE.fullmatch(email):
        raise AccountError(f"'{email}' is not an email address")
    bad_urls = [url for url in urls if re.search(r'[\s"\\]', url)]
    if bad_urls:
        raise AccountError(f"--url pattern must not contain spaces, quotes or backslashes: {bad_urls[0]}")
    provider = resolve_provider(provider_name)
    match = match or provider.match
    plan = make_plan(name, provider, match)

    include = f"    path = ~/.gitconfig.d/{name}.config"
    rules = [f'[includeIf "gitdir:~/source-code/{name}/"]', include]
    for pattern in (*plan.patterns, *urls):
        rules += [f'[includeIf "hasconfig:remote.*.url:{pattern}"]', include]

    # Two accounts matching the same remote would mean git and ssh disagree on which
    # one applies (later git rule wins, first ssh entry wins): refuse.
    for other, other_rules in blocks().items():
        shared = [cond for rule in rules if rule in other_rules and (cond := condition(rule))]
        if other != name and shared:
            hint = "; use --match alias for a second account there" if match == "host" else ""
            raise AccountError(f"'{other}' already has {shared[0]}{hint}")
    if match == "host" and provider.web == "github.com":
        say("note", f"every github.com remote, including personal ones, will use '{name}'")

    # SSH first: it is the step that can fail (no matching agent key) or prompt.
    identity = write_ssh_conf(name, provider, plan.hosts, key_hint, match)

    config = GIT_DIR_D / f"{name}.config"
    if not config.exists():
        write_file(config, f"# Private — git-ignored. Identity for the {name} account.\n", 0o600)
    run("git", "config", "--file", str(config), "user.email", email, check=True)
    user_name = user_name or default_user_name()
    if user_name:
        run("git", "config", "--file", str(config), "user.name", user_name, check=True)
    say("wrote", tilde(config))

    set_block(name, rules)
    say("wrote", f"{tilde(ACCOUNTS)} (rules for '{name}')")
    (SOURCE_ROOT / name).mkdir(parents=True, exist_ok=True)

    git_ok = check_git(name, email, plan.sample_url)
    ssh_ok = check_ssh(plan.hosts, provider, identity)
    print(f"\nClone with: clone <owner>/<repo> {name}   ({plan.hint})")
    return git_ok and ssh_ok


def remove(name: str, *, purge: bool) -> None:
    if name not in blocks():
        raise AccountError(f"no account '{name}'")
    set_block(name, None)
    say("removed", f"rules for '{name}' from {tilde(ACCOUNTS)}")

    # Only key files this script generates (<name>_<slug>.pub; slugs have no `_`, so
    # account `work` never claims `work_x_github.pub`). Never the repos folder.
    own_key = re.compile(rf"{re.escape(name)}_[A-Za-z0-9-]+\.pub")
    keys = [p for p in SSH_DIR.glob(f"{name}_*.pub") if own_key.fullmatch(p.name)]
    files = [p for p in (GIT_DIR_D / f"{name}.config", SSH_DIR_D / f"{name}.conf", *keys) if p.exists()]
    for path in files:
        if purge:
            path.unlink()
            say("deleted", tilde(path))
        else:
            say("kept", tilde(path))
    if files and not purge:
        print("(re-run with --purge to delete them)")


def list_accounts() -> None:
    found = blocks()
    if not found:
        print("no accounts yet (see: git account --help)")
        return
    for name, rules in found.items():
        config, conf = GIT_DIR_D / f"{name}.config", SSH_DIR_D / f"{name}.conf"
        email = run("git", "config", "--file", str(config), "user.email").stdout.strip() or "no email"
        print(f"{name} <{email}>")
        for rule in rules:
            if cond := condition(rule):
                print(f"    {cond}")
        ssh = f"Host {' '.join(conf_values(conf, 'Host'))}" if conf.exists() else "no SSH entry"
        print(f"    ssh: {ssh}")


def parse_args(argv: Sequence[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="git account",
        description="Manage git identities for extra accounts (GitHub orgs, Bitbucket, GitLab, self-hosted).",
        epilog="examples:\n"
        "  git account add work bitbucket me@corp.com\n"
        "  git account add acme github me@acme.com --key 'Acme (me)'\n"
        "  git account add oss gitlab me@example.com\n"
        "  git account add corp git.corp.com me@corp.com\n"
        "  git account remove acme --purge",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    commands = parser.add_subparsers(dest="command", required=True)

    add_cmd = commands.add_parser("add", help="add or update an account")
    add_cmd.add_argument("name", help="letters, digits or _; also the ~/source-code/<name>/ folder")
    add_cmd.add_argument("provider", help="github | gitlab | bitbucket | <self-hosted SSH host>")
    add_cmd.add_argument("email")
    add_cmd.add_argument("--key", help="SSH agent key (its `ssh-add -L` comment); prompted if omitted")
    add_cmd.add_argument("--match", choices=("host", "alias"), help="select by whole host or by SSH alias")
    add_cmd.add_argument("--user-name", help="full name (default: the personal one)")
    add_cmd.add_argument(
        "--url", action="append", default=[], help="extra `hasconfig:remote.*.url` glob, e.g. 'https://git.corp.com/**'"
    )

    commands.add_parser("list", help="show accounts, their rules and SSH entries")

    remove_cmd = commands.add_parser("remove", help="remove an account's rules")
    remove_cmd.add_argument("name")
    remove_cmd.add_argument("--purge", action="store_true", help="also delete its identity, SSH entry and key file")

    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        if args.command == "add":
            ok = add(
                args.name,
                args.provider,
                args.email,
                key_hint=args.key,
                match=args.match,
                user_name=args.user_name,
                urls=args.url,
            )
            return 0 if ok else 1
        if args.command == "remove":
            remove(args.name, purge=args.purge)
        else:
            list_accounts()
    except (AccountError, OSError) as e:
        print(f"git-account: {e}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print(file=sys.stderr)
        return 130
    return 0


if __name__ == "__main__":
    sys.exit(main())
