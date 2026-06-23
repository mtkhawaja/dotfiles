#!/usr/bin/env python3
#
# aws-creds-to-default.py — set the [default] AWS profile from the clipboard.
#
# Why:
#   The AWS access portal ("Command line or programmatic access") hands you a
#   block you copy to the clipboard:
#
#     [###########_AdminAccess]
#     aws_access_key_id=...
#     aws_secret_access_key=...
#     aws_session_token=...
#
#   Pasting that into ~/.aws/credentials by hand — and renaming the section to
#   [default] every time the short-lived session expires — is tedious and
#   error-prone. This reads the clipboard and writes the credentials straight
#   into the [default] profile.
#
# What:
#   Read the clipboard, drop the leading [profile] header, and write the
#   aws_* keys under [default] in ~/.aws/credentials (created 700/600 if absent).
#   By default other profiles in the file are preserved and only [default] is
#   replaced; --overwrite truncates the file to just [default].
#
# Dependencies: Python 3 standard library only. The clipboard is read by
#   shelling out to the OS clipboard tool (pbpaste / wl-paste / xclip / xsel),
#   so no third-party packages (e.g. pyperclip) are required.
#
# See --help for usage.

import argparse
import configparser
import logging
import os
import platform
import subprocess
import sys
from typing import Final, NoReturn

SCRIPT_NAME = os.path.basename(sys.argv[0])
logger = logging.getLogger(SCRIPT_NAME)

# Keys we extract from the pasted block. Order is preserved on write.
REQUIRED_KEYS = ("aws_access_key_id", "aws_secret_access_key")
OPTIONAL_KEYS = ("aws_session_token",)
KNOWN_KEYS = REQUIRED_KEYS + OPTIONAL_KEYS

# Clipboard readers keyed by platform.system(); for each OS the first tool
# found on PATH wins.
CLIPBOARD_COMMANDS: Final[dict[str, list[list[str]]]] = {
    "Darwin": [["pbpaste"]],
    "Linux": [
        ["wl-paste", "--no-newline"],  # Wayland
        ["xclip", "-selection", "clipboard", "-o"],  # X11
        ["xsel", "-b"],  # X11
    ],
}


def die(message: str) -> NoReturn:
    logger.error("error: %s", message)
    sys.exit(1)


def read_clipboard() -> str:
    """Return clipboard text using the first available OS clipboard tool."""
    system = platform.system()
    commands = CLIPBOARD_COMMANDS.get(system, [])
    if not commands:
        die(f"no clipboard support for this OS ({system})")
    for command in commands:
        try:
            result = subprocess.run(
                command, capture_output=True, text=True, check=True
            )
            return result.stdout
        except FileNotFoundError:
            continue  # tool not installed; try the next one
        except subprocess.CalledProcessError as exc:
            die(f"'{command[0]}' failed: {exc.stderr.strip() or exc}")
    tools = ", ".join(command[0] for command in commands)
    logger.error("error: no clipboard tool found for %s (tried: %s)", system, tools)
    raise SystemExit(1)


def parse_credentials(text: str) -> dict[str, str]:
    """Parse the pasted block into an ordered {key: value} of aws_* creds."""
    creds = {}
    for raw in text.splitlines():
        line = raw.strip()
        # Skip blanks and the [profile] header line.
        if not line or (line.startswith("[") and line.endswith("]")):
            continue
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip().lower()
        value = value.strip()
        if key in KNOWN_KEYS and value:
            creds[key] = value

    missing = [key for key in REQUIRED_KEYS if key not in creds]
    if missing:
        die(
            "clipboard does not look like AWS credentials; missing: "
            + ", ".join(missing)
        )

    # Return in a stable, conventional order.
    return {key: creds[key] for key in KNOWN_KEYS if key in creds}


def _write_secure(config: configparser.ConfigParser, path: str) -> None:
    """Write config to path as 0600, creating ~/.aws (0700) if missing."""
    os.makedirs(os.path.dirname(path), mode=0o700, exist_ok=True)
    # Open 0600 from the start so secrets are never briefly world-readable.
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as handle:
        config.write(handle, space_around_delimiters=False)
    os.chmod(path, 0o600)


def _preserved_note(preserved: list[str]) -> str:
    """One-line note about other profiles left untouched ('' if none)."""
    if not preserved:
        return ""
    return f"  ({len(preserved)} other profile(s) preserved: {', '.join(preserved)})"


def write_credentials(
    creds: dict[str, str], path: str, overwrite: bool, dry_run: bool
) -> None:
    # interpolation=None: credential values are opaque literals; a '%' in a
    # secret/token must not be parsed as configparser interpolation syntax.
    config = configparser.ConfigParser(interpolation=None)
    # Keep existing profiles unless we're overwriting the whole file.
    if not overwrite and os.path.exists(path):
        config.read(path)

    # Replace [default] wholesale so stale keys (e.g. an old session token)
    # from a previous paste don't linger.
    config.remove_section("default")
    config.add_section("default")
    for key, value in creds.items():
        config.set("default", key, value)

    preserved = [section for section in config.sections() if section != "default"]
    note = _preserved_note(preserved)

    if dry_run:
        mode = "overwrite" if overwrite else "replace"
        logger.info("would write [default] to %s (%s mode)", path, mode)
        for key in creds:
            logger.info("  %s=********", key)
        if note:
            logger.info(note)
        return

    _write_secure(config, path)
    logger.info("wrote [default] to %s", path)
    if note:
        logger.info(note)


def main() -> None:
    logging.basicConfig(format="%(name)s: %(message)s", level=logging.INFO)
    parser = argparse.ArgumentParser(
        prog=SCRIPT_NAME,
        description="Set the [default] AWS profile in ~/.aws/credentials from "
                    "credentials copied from the AWS access portal.",
    )
    parser.add_argument(
        "-o", "--overwrite", action="store_true",
        help="truncate ~/.aws/credentials and write only [default] "
             "(default: keep other profiles, replace only [default])",
    )
    parser.add_argument(
        "-n", "--dry-run", action="store_true",
        help="show what would change without writing (secrets masked)",
    )
    parser.add_argument(
        "--path",
        default=os.path.join(os.path.expanduser("~"), ".aws", "credentials"),
        help=argparse.SUPPRESS,  # override target file (mainly for testing)
    )
    args = parser.parse_args()

    creds = parse_credentials(read_clipboard())
    write_credentials(creds, args.path, args.overwrite, args.dry_run)


if __name__ == "__main__":
    main()
