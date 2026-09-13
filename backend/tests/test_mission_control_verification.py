"""Local git verification without network or repository access."""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import pytest

from mission_control.verification import CommitCheck, VerificationError, check_commit


@pytest.mark.skipif(shutil.which("git") is None, reason="git not available")
class TestCommitVerification:
    """Verify commits exist and are pushed using local git."""

    def test_valid_commit_exists(self, tmp_path):
        """A commit that exists reports exists=True."""
        repo = tmp_path / "repo"
        repo.mkdir()
        self._init_repo(repo)
        sha = self._commit_file(repo, "file.txt", "content")

        result = check_commit(sha, repo)
        assert result.exists is True
        assert isinstance(result, CommitCheck)

    def test_absent_sha_is_not_an_error(self, tmp_path):
        """A well-formed but absent SHA reports exists=False without raising."""
        repo = tmp_path / "repo"
        repo.mkdir()
        self._init_repo(repo)

        absent_sha = "a" * 40
        result = check_commit(absent_sha, repo)
        assert result.exists is False
        assert result.pushed is False

    def test_malformed_sha_raises_value_error(self, tmp_path):
        """A SHA with wrong length or non-hex characters raises ValueError."""
        repo = tmp_path / "repo"
        repo.mkdir()
        self._init_repo(repo)

        with pytest.raises(ValueError):
            check_commit("abc123", repo)  # Too short

        with pytest.raises(ValueError):
            check_commit("Z" * 40, repo)  # Non-hex character

        with pytest.raises(ValueError):
            check_commit("a" * 39, repo)  # One char short

        with pytest.raises(ValueError):
            check_commit("A" * 40, repo)  # Uppercase

    def test_not_a_git_repository_raises_verification_error(self, tmp_path):
        """A non-git directory raises VerificationError."""
        non_repo = tmp_path / "not_a_repo"
        non_repo.mkdir()

        with pytest.raises(VerificationError) as exc_info:
            check_commit("a" * 40, non_repo)
        assert "Repository" in str(exc_info.value) or "git" in str(exc_info.value)

    def test_unpushed_commit_is_not_pushed(self, tmp_path):
        """A local-only commit (no remote) reports pushed=False."""
        repo = tmp_path / "repo"
        repo.mkdir()
        self._init_repo(repo)
        sha = self._commit_file(repo, "file.txt", "content")

        result = check_commit(sha, repo)
        assert result.exists is True
        assert result.pushed is False

    def test_pushed_commit_is_pushed(self, tmp_path):
        """A commit reachable from a remote branch reports pushed=True."""
        # Create a bare repository to act as origin
        bare_repo = tmp_path / "origin.git"
        bare_repo.mkdir()
        subprocess.run(
            ["git", "init", "--bare"],
            cwd=bare_repo,
            capture_output=True,
            check=True,
        )

        # Create a working repository
        repo = tmp_path / "repo"
        repo.mkdir()
        self._init_repo(repo)

        # Add bare repo as origin
        subprocess.run(
            ["git", "remote", "add", "origin", str(bare_repo)],
            cwd=repo,
            capture_output=True,
            check=True,
        )

        # Create a commit and push it
        sha = self._commit_file(repo, "file.txt", "content")
        # Get the current branch name (master or main)
        branch_result = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            cwd=repo,
            capture_output=True,
            text=True,
            check=True,
        )
        branch_name = branch_result.stdout.strip()
        subprocess.run(
            ["git", "push", "-u", "origin", branch_name],
            cwd=repo,
            capture_output=True,
            check=True,
        )

        result = check_commit(sha, repo)
        assert result.exists is True
        assert result.pushed is True

    @staticmethod
    def _init_repo(repo: Path) -> None:
        """Initialize a git repository with basic config."""
        subprocess.run(
            ["git", "init"],
            cwd=repo,
            capture_output=True,
            check=True,
        )
        subprocess.run(
            ["git", "config", "user.email", "test@example.com"],
            cwd=repo,
            capture_output=True,
            check=True,
        )
        subprocess.run(
            ["git", "config", "user.name", "Test User"],
            cwd=repo,
            capture_output=True,
            check=True,
        )

    @staticmethod
    def _commit_file(repo: Path, filename: str, content: str) -> str:
        """Create a file, commit it, and return the SHA."""
        file_path = repo / filename
        file_path.write_text(content, encoding="utf-8")
        subprocess.run(
            ["git", "add", filename],
            cwd=repo,
            capture_output=True,
            check=True,
        )
        subprocess.run(
            ["git", "commit", "-m", f"Add {filename}"],
            cwd=repo,
            capture_output=True,
            text=True,
            check=True,
        )
        # Extract SHA from commit output
        sha_result = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=repo,
            capture_output=True,
            text=True,
            check=True,
        )
        return sha_result.stdout.strip()
