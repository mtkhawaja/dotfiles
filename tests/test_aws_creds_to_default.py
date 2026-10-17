"""Behaviour tests for bin/.local/bin/scripts/utility/aws-creds-to-default.py.

The clipboard is faked with stub pbpaste / wl-paste / xclip / xsel scripts placed
first on PATH, and the hidden --path option points the script at a temporary
credentials file, so the real clipboard and ~/.aws are never touched.

Run: ./scripts/check.sh test   (or: python3 -m unittest discover -s tests -v)
"""

from __future__ import annotations

import configparser
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SCRIPT = REPO / "bin/.local/bin/scripts/utility/aws-creds-to-default.py"
CLIPBOARD_TOOLS = ("pbpaste", "wl-paste", "xclip", "xsel")

PORTAL_BLOCK = """\
[123456789012_AdminAccess]
aws_access_key_id=AKIANEW
aws_secret_access_key=secret/NEW+key
aws_session_token=token%with%percents==
"""


class AwsCredsToDefaultTest(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.clipboard = self.root / "clipboard.txt"
        self.creds = self.root / "aws" / "credentials"
        self.set_clipboard(PORTAL_BLOCK)
        for tool in CLIPBOARD_TOOLS:
            stub = self.bin / tool
            stub.write_text(f'#!/bin/sh\ncat "{self.clipboard}"\n')
            stub.chmod(0o755)

    # --- helpers ---

    def set_clipboard(self, text: str) -> None:
        self.clipboard.write_text(text)

    def run_script(self, *args: str, path: str | None = None) -> subprocess.CompletedProcess[str]:
        env = {**os.environ, "PATH": f"{self.bin}{os.pathsep}{path or os.environ['PATH']}"}
        return subprocess.run(
            [sys.executable, str(SCRIPT), "--path", str(self.creds), *args],
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )

    def ok(self, *args: str) -> str:
        result = self.run_script(*args)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stderr  # the script logs to stderr

    def read_creds(self) -> configparser.ConfigParser:
        config = configparser.ConfigParser(interpolation=None)
        config.read(self.creds)
        return config

    def write_existing(self, text: str) -> None:
        self.creds.parent.mkdir(parents=True, exist_ok=True)
        self.creds.write_text(text)

    # --- tests ---

    def test_writes_default_from_portal_block(self) -> None:
        self.assertIn(f"wrote [default] to {self.creds}", self.ok())
        default = self.read_creds()["default"]
        self.assertEqual(
            dict(default),
            {
                "aws_access_key_id": "AKIANEW",
                "aws_secret_access_key": "secret/NEW+key",
                "aws_session_token": "token%with%percents==",  # no configparser interpolation
            },
        )
        self.assertNotIn("123456789012_AdminAccess", self.creds.read_text())

    def test_creates_private_file_and_directory(self) -> None:
        self.ok()
        self.assertEqual(self.creds.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.creds.parent.stat().st_mode & 0o777, 0o700)

    def test_tolerates_case_whitespace_and_unknown_keys(self) -> None:
        self.set_clipboard(
            "\r\n  [profile]  \r\n"
            "AWS_ACCESS_KEY_ID = AKIA1\r\n"
            "  aws_secret_access_key=S1  \r\n"
            "region=us-east-1\r\n"
            "not a key line\r\n"
        )
        self.ok()
        self.assertEqual(
            dict(self.read_creds()["default"]), {"aws_access_key_id": "AKIA1", "aws_secret_access_key": "S1"}
        )

    def test_keeps_other_profiles_and_replaces_stale_default(self) -> None:
        self.write_existing(
            "[default]\naws_access_key_id=OLD\naws_session_token=STALE\nregion=eu-west-1\n\n"
            "[other]\naws_access_key_id=OTHER\n"
        )
        self.set_clipboard("aws_access_key_id=AKIA2\naws_secret_access_key=S2\n")  # no session token
        out = self.ok()
        config = self.read_creds()
        self.assertEqual(dict(config["default"]), {"aws_access_key_id": "AKIA2", "aws_secret_access_key": "S2"})
        self.assertEqual(config["other"]["aws_access_key_id"], "OTHER")
        self.assertIn("1 other profile(s) preserved: other", out)

    def test_overwrite_drops_other_profiles(self) -> None:
        self.write_existing("[other]\naws_access_key_id=OTHER\n")
        self.ok("--overwrite")
        self.assertEqual(self.read_creds().sections(), ["default"])

    def test_dry_run_writes_nothing_and_masks_secrets(self) -> None:
        self.write_existing("[other]\naws_access_key_id=OTHER\n")
        before = self.creds.read_text()
        out = self.ok("--dry-run")
        self.assertEqual(self.creds.read_text(), before)
        self.assertIn("would write [default]", out)
        self.assertIn("aws_secret_access_key=********", out)
        for secret in ("AKIANEW", "secret/NEW+key", "token%with%percents=="):
            self.assertNotIn(secret, out)

    def test_rejects_non_credentials_and_leaves_file_alone(self) -> None:
        self.write_existing("[default]\naws_access_key_id=KEEP\n")
        self.set_clipboard("aws_access_key_id=AKIA3\n")  # secret missing
        result = self.run_script()
        self.assertEqual(result.returncode, 1)
        self.assertIn("missing: aws_secret_access_key", result.stderr)
        self.assertEqual(self.read_creds()["default"]["aws_access_key_id"], "KEEP")

    def test_preserves_symlinked_credentials_file(self) -> None:
        target = self.root / "real-credentials"
        target.write_text("[other]\naws_access_key_id=OTHER\n")
        self.creds.parent.mkdir()
        self.creds.symlink_to(target)
        self.ok()
        self.assertTrue(self.creds.is_symlink())
        self.assertIn("AKIANEW", target.read_text())
        self.assertIn("OTHER", target.read_text())

    def test_clipboard_tool_failure(self) -> None:
        for tool in CLIPBOARD_TOOLS:
            (self.bin / tool).write_text("#!/bin/sh\necho 'clipboard locked' >&2\nexit 3\n")
        result = self.run_script()
        self.assertEqual(result.returncode, 1)
        self.assertIn("failed: clipboard locked", result.stderr)

    def test_no_clipboard_tool(self) -> None:
        for tool in CLIPBOARD_TOOLS:
            (self.bin / tool).unlink()
        # PATH holds only the (now empty) stub dir, so no real clipboard tool is found.
        result = self.run_script(path=str(self.root / "empty"))
        self.assertEqual(result.returncode, 1)
        self.assertIn("no clipboard tool found", result.stderr)
        self.assertFalse(self.creds.exists())

    def test_keeps_comments_and_formatting_outside_default(self) -> None:
        existing = (
            "# managed by hand; rotate monthly\n"
            "[default]\n"
            "; old default, about to be replaced\n"
            "aws_access_key_id = OLD\n"
            "aws_session_token = STALE\n"
            "\n"
            "# work account\n"
            "[work]\n"
            "aws_access_key_id = WORK   ; inline note\n"
        )
        self.write_existing(existing)
        self.set_clipboard("aws_access_key_id=AKIA4\naws_secret_access_key=S4\n")
        self.ok()
        self.assertEqual(
            self.creds.read_text(),
            "# managed by hand; rotate monthly\n"
            "[default]\n"
            "aws_access_key_id=AKIA4\n"
            "aws_secret_access_key=S4\n"
            "; old default, about to be replaced\n"
            "\n"
            "# work account\n"
            "[work]\n"
            "aws_access_key_id = WORK   ; inline note\n",
        )

    def test_appends_default_after_existing_profiles(self) -> None:
        self.write_existing("# first\n[work]\naws_access_key_id=WORK")  # no trailing newline
        self.set_clipboard("aws_access_key_id=AKIA5\naws_secret_access_key=S5\n")
        self.ok()
        self.assertEqual(
            self.creds.read_text(),
            "# first\n[work]\naws_access_key_id=WORK\n\n[default]\naws_access_key_id=AKIA5\naws_secret_access_key=S5\n",
        )

    def test_replaces_multiline_values_in_default(self) -> None:
        self.write_existing("[default]\naws_session_token = first\n  continued\n[work]\naws_access_key_id=WORK\n")
        self.ok()
        text = self.creds.read_text()
        self.assertNotIn("continued", text)
        self.assertEqual(self.read_creds()["work"]["aws_access_key_id"], "WORK")

    def test_malformed_credentials_file_is_a_clean_error(self) -> None:
        for broken, reason in (
            ("aws_secret_access_key=DO-NOT-ECHO\n", "line 1: no section header"),
            ("[default]\nx=1\n[default]\ny=2\n", "line 3: duplicate section [default]"),
            ("[work]\nx=1\nx=2\n", "line 3: duplicate option 'x' in [work]"),
        ):
            with self.subTest(reason=reason):
                self.write_existing(broken)
                result = self.run_script()
                self.assertEqual(result.returncode, 1)
                self.assertNotIn("Traceback", result.stderr)
                self.assertIn(f"{self.creds} is not a valid credentials file", result.stderr)
                self.assertIn(reason, result.stderr)
                self.assertNotIn("DO-NOT-ECHO", result.stderr)  # file contents may be secrets
                self.assertEqual(self.creds.read_text(), broken)

    def test_overwrite_replaces_malformed_file(self) -> None:
        self.write_existing("garbage before any section\n")
        self.ok("--overwrite")
        self.assertEqual(self.read_creds().sections(), ["default"])


if __name__ == "__main__":
    unittest.main()
