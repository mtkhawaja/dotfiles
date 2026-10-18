"""Behaviour tests for bin/.local/bin/scripts/utility/git-account.py.

Each test runs the script against a throwaway HOME holding copies of the repo's
tracked git and SSH config, with a scratch ssh-agent loaded with generated keys.
Nothing outside the temporary directories is read or written.

Run: ./scripts/check.sh test   (or: python3 -m unittest discover -s tests -v)
Needs git >= 2.36, ssh, ssh-agent, ssh-keygen; zsh for the `clone` tests.
"""

from __future__ import annotations

import os
import pty
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SCRIPT = REPO / "bin/.local/bin/scripts/utility/git-account.py"
PERSONAL = "36654508+mtkhawaja@users.noreply.github.com"
KEYS = {"acme": "Acme (me)", "corp": "Corp Bitbucket"}


class GitAccountTest(unittest.TestCase):
    agent_dir: Path
    agent_env: dict[str, str]

    @classmethod
    def setUpClass(cls) -> None:
        # Short path: unix socket paths are limited to ~104 bytes.
        cls.agent_dir = Path(tempfile.mkdtemp(prefix="ga-"))
        sock = cls.agent_dir / "agent.sock"
        subprocess.run(["ssh-agent", "-a", str(sock)], check=True, capture_output=True)
        cls.agent_env = {"SSH_AUTH_SOCK": str(sock)}
        for name, label in KEYS.items():
            key = cls.agent_dir / name
            subprocess.run(["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-C", label, "-f", str(key)], check=True)
            subprocess.run(["ssh-add", "-q", str(key)], env={**os.environ, **cls.agent_env}, check=True)

    @classmethod
    def tearDownClass(cls) -> None:
        subprocess.run(["ssh-agent", "-k"], env={**os.environ, **cls.agent_env}, capture_output=True, check=False)
        shutil.rmtree(cls.agent_dir, ignore_errors=True)

    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        # Resolved: on macOS $TMPDIR is under /var -> /private/var, and git matches gitdir
        # rules against the real path, so an unresolved HOME would break ~/source-code/ rules.
        self.home = Path(tmp.name).resolve()
        # The tracked config, as setup.sh would link it (copied, so tests never write to the repo).
        shutil.copy(REPO / "git/.gitconfig", self.home / ".gitconfig")
        (self.home / ".gitconfig.d").mkdir()
        shutil.copy(REPO / "git/.gitconfig.d/personal.config", self.home / ".gitconfig.d")
        (self.home / ".ssh/config.d").mkdir(parents=True)
        # OpenSSH resolves `~` from the passwd entry, not $HOME (macOS honours $HOME; Linux
        # doesn't), so point the Include at the throwaway home and run ssh with -F.
        config = (REPO / "ssh/.ssh/config").read_text()
        (self.home / ".ssh/config").write_text(config.replace("~/.ssh/config.d/", f"{self.home}/.ssh/config.d/"))
        shim = self.home / "bin/ssh"
        shim.parent.mkdir()
        shim.write_text(f'#!/bin/sh\nexec {shutil.which("ssh")} -F "$HOME/.ssh/config" "$@"\n')
        shim.chmod(0o755)
        self.env = {
            **os.environ,
            **self.agent_env,
            "HOME": str(self.home),
            "PATH": f"{shim.parent}{os.pathsep}{os.environ['PATH']}",
            "GIT_CONFIG_NOSYSTEM": "1",
        }
        for var in ("GIT_DIR", "GIT_WORK_TREE", "GIT_CONFIG_GLOBAL"):
            self.env.pop(var, None)

    # --- helpers ---

    def ga(self, *args: str, cwd: Path | None = None, stdin: str | None = None) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(SCRIPT), *args],
            cwd=cwd or self.home,
            env=self.env,
            input=stdin if stdin is not None else "",
            capture_output=True,
            text=True,
            check=False,
        )

    def ok(self, *args: str) -> str:
        result = self.ga(*args)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result.stdout

    def fails(self, *args: str, message: str) -> None:
        result = self.ga(*args)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn(message, result.stderr + result.stdout)

    def email_for(self, url: str | None = None, path: str = "t/repo") -> str:
        repo = self.home / path
        repo.mkdir(parents=True, exist_ok=True)
        subprocess.run(["git", "init", "-q"], cwd=repo, env=self.env, check=True)
        if url:
            subprocess.run(["git", "remote", "add", "origin", url], cwd=repo, env=self.env, check=True)
        return subprocess.run(
            ["git", "config", "user.email"], cwd=repo, env=self.env, capture_output=True, text=True, check=False
        ).stdout.strip()

    def git_config(self, file: str, key: str) -> str:
        return subprocess.run(
            ["git", "config", "--file", str(self.home / file), key], capture_output=True, text=True, check=False
        ).stdout.strip()

    def accounts(self) -> str:
        return (self.home / ".gitconfig.d/accounts.config").read_text()

    def add_work(self) -> str:
        return self.ok("add", "work", "bitbucket", "me@corp.com", "--key", KEYS["corp"])

    def add_acme(self, email: str = "me@acme.com") -> str:
        return self.ok("add", "acme", "github", email, "--key", KEYS["acme"])

    # --- add: files and self-check ---

    def test_bitbucket_host_mode_self_check(self) -> None:
        out = self.add_work()
        self.assertIn("check   remote git@ssh.bitbucket.org:owner/repo.git -> me@corp.com", out)
        self.assertIn("check   folder ~/source-code/work/ -> me@corp.com", out)
        self.assertIn("check   ssh ssh.bitbucket.org -> ssh.bitbucket.org with ~/.ssh/work_bitbucket.pub", out)
        self.assertIn("check   ssh bitbucket.org -> ssh.bitbucket.org with ~/.ssh/work_bitbucket.pub", out)

    def test_written_files(self) -> None:
        self.add_work()
        conf = self.home / ".ssh/config.d/work.conf"
        self.assertEqual(conf.stat().st_mode & 0o777, 0o600)
        self.assertIn("Host ssh.bitbucket.org bitbucket.org", conf.read_text())
        self.assertEqual(self.git_config(".gitconfig.d/work.config", "user.email"), "me@corp.com")
        self.assertEqual(self.git_config(".gitconfig.d/work.config", "user.name"), "Muneeb Khawaja")
        self.assertTrue((self.home / "source-code/work").is_dir())

    def test_alias_providers(self) -> None:
        self.assertIn("check   ssh github.com-acme -> github.com with ~/.ssh/acme_github.pub", self.add_acme())
        self.ok("add", "oss", "gitlab", "me@oss.dev", "--key", KEYS["acme"])
        self.ok("add", "corp", "git.corp.com", "me@corp.com", "--key", KEYS["acme"], "--url", "https://git.corp.com/**")
        self.assertEqual(self.email_for("git@gitlab.com-oss:me/x.git"), "me@oss.dev")
        self.assertEqual(self.email_for("git@git.corp.com-corp:team/x.git", "t/c1"), "me@corp.com")
        self.assertEqual(self.email_for("https://git.corp.com/team/x.git", "t/c2"), "me@corp.com")

    def test_interactive_key_pick(self) -> None:
        pid, fd = pty.fork()
        if pid == 0:  # child: the script, with a terminal on stdin
            os.chdir(self.home)
            os.execve(sys.executable, [sys.executable, str(SCRIPT), "add", "pick", "github", "p@x.com"], self.env)
        output = b""
        answered = False
        while True:
            try:
                chunk = os.read(fd, 1024)
            except OSError:
                break
            if not chunk:
                break
            output += chunk
            if not answered and b"> " in output:
                os.write(fd, b"1\n")
                answered = True
        _, status = os.waitpid(pid, 0)
        text = output.decode()
        self.assertEqual(os.waitstatus_to_exitcode(status), 0, text)
        self.assertIn("1) Acme (me)", text)
        self.assertIn("wrote   ~/.ssh/pick_github.pub", text)

    # --- identity resolution ---

    def test_identity_resolution(self) -> None:
        self.add_work()
        self.add_acme()
        cases = {
            "git@github.com:mtkhawaja/x.git": PERSONAL,
            "https://github.com/mtkhawaja/x.git": PERSONAL,
            None: PERSONAL,
            "git@ssh.bitbucket.org:corp/x.git": "me@corp.com",
            "git@bitbucket.org:corp/x.git": "me@corp.com",
            "https://me@bitbucket.org/corp/x.git": "me@corp.com",
            "https://bitbucket.org/corp/x.git": "me@corp.com",
            "ssh://git@ssh.bitbucket.org/corp/x.git": "me@corp.com",
            "ssh://git@ssh.bitbucket.org:22/corp/x.git": "me@corp.com",
            "git@github.com-acme:acme/x.git": "me@acme.com",
        }
        for i, (url, expected) in enumerate(cases.items()):
            with self.subTest(url=url):
                self.assertEqual(self.email_for(url, f"t/{i}"), expected)

    def test_folder_selects_account(self) -> None:
        self.add_acme()
        self.assertEqual(self.email_for("https://github.com/acme/x.git", "source-code/acme/a"), "me@acme.com")
        self.assertEqual(self.email_for(None, "source-code/acme/b"), "me@acme.com")

    # --- validation: nothing is written on failure ---

    def test_validation(self) -> None:
        cases = [
            (("add", "x", "github", "a@b.c", "--key", "e"), "matches several keys"),
            (("add", "x", "github", "a@b.c", "--key", "Nope"), "no agent key matches 'Nope'"),
            (("add", "x", "github", "a@b.c"), "--key is required"),
            (("add", "x", "nope", "a@b.c"), "unknown provider 'nope'"),
            (("add", "x", "a b.c", "a@b.c"), "unknown provider 'a b.c'"),
            (("add", "x", "github", "a b@c"), "is not an email address"),
            (("add", "bad-name", "github", "a@b.c"), "account name must be"),
            (("add", "personal", "github", "a@b.c"), "tracked default identity"),
            (("add", "x", "github", "a@b.c", "--key", KEYS["acme"], "--url", 'x" y'), "must not contain"),
            (("add", "x", "github", "a@b.c", "--match", "nope"), "invalid choice: 'nope'"),
        ]
        for args, message in cases:
            with self.subTest(args=args):
                self.fails(*args, message=message)
        self.assertFalse((self.home / ".ssh/config.d/x.conf").exists())
        self.assertFalse((self.home / ".gitconfig.d/x.config").exists())

    def test_exact_key_label_beats_substring(self) -> None:
        self.assertIn("wrote   ~/.ssh/ex_github.pub", self.ok("add", "ex", "github", "a@b.c", "--key", KEYS["acme"]))

    def test_refuses_overlapping_rules(self) -> None:
        self.add_work()
        self.fails(
            "add", "work2", "bitbucket", "w2@corp.com", "--key", "Corp",
            message="'work' already has hasconfig:remote.*.url:git@ssh.bitbucket.org:*/**; use --match alias",
        )  # fmt: skip
        self.assertFalse((self.home / ".ssh/config.d/work2.conf").exists())
        self.ok("add", "corp", "git.corp.com", "c@corp.com", "--key", KEYS["acme"], "--url", "https://git.corp.com/**")
        self.fails(
            "add", "ov", "github", "o@v.com", "--key", KEYS["acme"], "--url", "https://git.corp.com/**",
            message="'corp' already has hasconfig:remote.*.url:https://git.corp.com/**",
        )  # fmt: skip

    # --- accounts.config editing ---

    def test_readd_updates_in_place_and_keeps_manual_lines(self) -> None:
        self.add_work()
        self.add_acme()
        manual = '# manual\n[includeIf "gitdir:~/clients/"]\n    path = ~/.gitconfig.d/work.config\n'
        (self.home / ".gitconfig.d/accounts.config").write_text(self.accounts() + manual)
        order = re.findall(r"# >>> account: (\w+)", self.accounts())

        self.add_acme("new@acme.com")
        self.assertIn(manual, self.accounts())
        self.assertEqual(re.findall(r"# >>> account: (\w+)", self.accounts()), order)
        self.assertEqual(self.email_for("git@github.com-acme:acme/x.git"), "new@acme.com")

    def test_malformed_accounts_config(self) -> None:
        self.add_work()
        path = self.home / ".gitconfig.d/accounts.config"
        good = path.read_text()
        path.write_text(good + "# >>> account: broken\n")
        self.fails("list", message="missing its end marker")
        path.write_text(good + "# >>> account: work\n# <<< account: work\n")
        self.fails("list", message="duplicate block for 'work'")

    # --- existing SSH entries ---

    def test_stale_ssh_entry_is_reported(self) -> None:
        self.add_acme()
        result = self.ga("add", "acme", "gitlab", "me@acme.com")  # acme.conf still says github.com-acme
        self.assertEqual(result.returncode, 1)
        self.assertIn("has no `Host gitlab.com-acme`", result.stdout)
        self.assertIn("FAIL    ssh gitlab.com-acme", result.stdout)

    def test_kept_ssh_entry_key_is_checked(self) -> None:
        self.add_acme()  # creates ~/.ssh/acme_github.pub
        (self.home / ".ssh/config.d/kc.conf").write_text(
            "Host github.com-kc\n    HostName github.com\n    IdentitiesOnly yes\n"
            "    IdentityFile ~/.ssh/acme_github.pub\n"
        )
        out = self.ok("add", "kc", "github", "k@c.com")
        self.assertIn("check   ssh github.com-kc -> github.com with ~/.ssh/acme_github.pub", out)

    # --- self-check catches a broken setup ---

    def test_self_check_fails_without_managed_gitconfig(self) -> None:
        (self.home / ".gitconfig").write_text("[user]\n  email = x@y.z\n")
        result = self.ga("add", "sc", "github", "s@c.com", "--key", KEYS["acme"])
        self.assertEqual(result.returncode, 1)
        self.assertIn("FAIL    remote git@github.com-sc:owner/repo.git -> x@y.z (expected s@c.com)", result.stdout)

    # --- run from inside another account's repo ---

    def test_run_inside_repo_with_git_dir(self) -> None:
        self.add_work()
        subprocess.run(
            ["git", "config", "--file", str(self.home / ".gitconfig.d/work.config"), "user.name", "Work Name"],
            check=True,
        )
        repo = self.home / "source-code/work/inside"
        self.email_for(None, "source-code/work/inside")
        self.env["GIT_DIR"] = str(repo / ".git")
        out = self.ga("add", "fromrepo", "github", "f@r.com", "--key", KEYS["acme"], cwd=repo)
        self.env.pop("GIT_DIR")
        self.assertEqual(out.returncode, 0, out.stdout + out.stderr)
        self.assertEqual(self.git_config(".gitconfig.d/fromrepo.config", "user.name"), "Muneeb Khawaja")
        remotes = subprocess.run(["git", "remote"], cwd=repo, env=self.env, capture_output=True, text=True, check=True)
        self.assertEqual(remotes.stdout, "", "the self-check touched the GIT_DIR repo")

    # --- list / remove ---

    def test_list(self) -> None:
        self.assertIn("no accounts yet", self.ok("list"))
        self.add_work()
        self.add_acme()
        out = self.ok("list")
        self.assertIn("work <me@corp.com>", out)
        self.assertIn("ssh: Host github.com-acme", out)

    def test_remove_and_purge(self) -> None:
        self.ok("add", "oss", "gitlab", "me@oss.dev", "--key", KEYS["acme"])
        other_account_key = self.home / ".ssh/oss_x_github.pub"  # belongs to an account named "oss_x"
        other_account_key.touch()

        self.assertIn("kept    ~/.gitconfig.d/oss.config", self.ok("remove", "oss"))
        self.assertNotIn("# >>> account: oss\n", self.accounts())

        self.ok("add", "oss", "gitlab", "me@oss.dev")
        out = self.ok("remove", "oss", "--purge")
        self.assertIn("deleted ~/.gitconfig.d/oss.config", out)
        self.assertIn("deleted ~/.ssh/oss_gitlab.pub", out)
        self.assertTrue(other_account_key.exists())
        self.assertTrue((self.home / "source-code/oss").is_dir())
        self.fails("remove", "oss", message="no account 'oss'")

    # --- zsh `clone` uses the accounts ---

    @unittest.skipUnless(shutil.which("zsh"), "zsh not installed")
    def test_clone_picks_account(self) -> None:
        self.add_work()
        self.add_acme()
        zshrc = (REPO / "zsh/.zshrc").read_text()
        clone_fn = re.search(r"^clone\(\) \{\n.*?^\}\n", zshrc, re.MULTILINE | re.DOTALL)
        assert clone_fn is not None
        script = clone_fn.group(0) + 'git() { print -r -- "git $*"; mkdir -p "$3/.git"; }\nclone "$@"\n'
        cases = {
            ("mtkhawaja/x",): "git clone git@github.com:mtkhawaja/x.git ~/source-code/personal/x",
            ("corp/x", "work"): "git clone git@ssh.bitbucket.org:corp/x.git ~/source-code/work/x",
            ("git@ssh.bitbucket.org:corp/y.git",): "git clone git@ssh.bitbucket.org:corp/y.git ~/source-code/work/y",
            (
                "https://me@bitbucket.org/corp/z.git",
            ): "git clone https://me@bitbucket.org/corp/z.git ~/source-code/work/z",
            ("git@github.com-acme:acme/w.git",): "git clone git@github.com-acme:acme/w.git ~/source-code/acme/w",
            ("acme/v", "acme"): "git clone git@github.com-acme:acme/v.git ~/source-code/acme/v",
        }
        for args, expected in cases.items():
            with self.subTest(args=args):
                out = subprocess.run(
                    ["zsh", "-fc", script, "clone", *args], env=self.env, capture_output=True, text=True, check=False
                )
                self.assertEqual(out.stdout.splitlines()[0].replace(str(self.home), "~"), expected, out.stderr)
        typo = subprocess.run(
            ["zsh", "-fc", script, "clone", "x/y", "typo"], env=self.env, capture_output=True, text=True, check=False
        )
        self.assertIn("unknown account 'typo'", typo.stderr)


if __name__ == "__main__":
    unittest.main()
