"""Local, read-only git inspection. No network."""

from __future__ import annotations

import os
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path


class VerificationError(RuntimeError):
    """Raised when git itself cannot be consulted (binary missing, not a repo, timeout)."""


@dataclass(frozen=True)
class CommitCheck:
    """Result of a commit existence and push status check."""

    sha: str
    exists: bool
    pushed: bool
    detail: str | None = None


def check_commit(sha: str, repo_dir: Path, *, timeout: float = 10.0) -> CommitCheck:
    """Report whether a commit exists locally and is reachable from a remote branch.

    The SHA is validated before git is invoked, so it can never reach a command
    line unchecked. A missing commit is a normal result (``exists=False``), not
    an exception; ``VerificationError`` means git itself could not be consulted.
    """
    if not isinstance(sha, str) or not re.fullmatch(r"[0-9a-f]{40}", sha):
        raise ValueError("Commit-SHA muss aus genau 40 hexadezimalen Kleinbuchstaben bestehen")

    # Prepare environment with GIT_TERMINAL_PROMPT disabled
    env = os.environ.copy()
    env["GIT_TERMINAL_PROMPT"] = "0"

    try:
        # First, check if directory is a git repository: git rev-parse --git-dir
        repo_check = subprocess.run(
            ["git", "rev-parse", "--git-dir"],
            cwd=repo_dir,
            capture_output=True,
            text=True,
            timeout=timeout,
            env=env,
            shell=False,
        )
        if repo_check.returncode != 0:
            raise VerificationError("Verzeichnis ist kein Git-Repository")

        # Check if commit exists: git cat-file -e <sha>^{commit}
        result = subprocess.run(
            ["git", "cat-file", "-e", f"{sha}^{{commit}}"],
            cwd=repo_dir,
            capture_output=True,
            text=True,
            timeout=timeout,
            env=env,
            shell=False,
        )
        exists = result.returncode == 0

        if not exists:
            return CommitCheck(sha=sha, exists=False, pushed=False)

        # Check if commit is pushed: git branch -r --contains <sha>
        result = subprocess.run(
            ["git", "branch", "-r", "--contains", sha],
            cwd=repo_dir,
            capture_output=True,
            text=True,
            timeout=timeout,
            env=env,
            shell=False,
        )

        if result.returncode != 0:
            # git command failed
            first_line = result.stderr.split("\n")[0] if result.stderr else ""
            raise VerificationError(f"Git-Befehl fehlgeschlagen: {first_line}")

        # pushed = True if at least one remote branch is listed
        pushed = bool(result.stdout.strip())

        return CommitCheck(sha=sha, exists=True, pushed=pushed)

    except FileNotFoundError as exc:
        raise VerificationError("git-Befehl nicht gefunden") from exc
    except subprocess.TimeoutExpired as exc:
        raise VerificationError(
            f"git-Befehl hat das Zeitlimit ueberschritten ({timeout}s)"
        ) from exc
