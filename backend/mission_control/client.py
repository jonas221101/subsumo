"""Bounded Paperclip API client.

This module deliberately contains no persistence or task-model logic.  Network
failures during mutations are reported as ambiguous; mutations are never
retried automatically.
"""

from __future__ import annotations

import os
import re
from collections.abc import Iterable
from dataclasses import dataclass, field
from ipaddress import ip_address
from typing import Any
from urllib.parse import urlsplit

import httpx


class PaperclipError(RuntimeError):
    """Base class for controlled client failures."""


class PaperclipAuthError(PaperclipError):
    """Missing or rejected credentials."""


class PaperclipHTTPError(PaperclipError):
    """A non-success HTTP response (other than a conflict)."""

    def __init__(self, status_code: int, message: str = "Paperclip request failed") -> None:
        self.status_code = status_code
        super().__init__(f"{message} (HTTP {status_code})")


class PaperclipConflictError(PaperclipHTTPError):
    """Paperclip rejected an atomic operation because state changed."""


class PaperclipNetworkError(PaperclipError):
    """A timeout or transport failure; mutation outcome may be unknown."""


class PaperclipResponseError(PaperclipError):
    """Paperclip returned malformed JSON or an unexpected response shape."""


def _valid_base_url(value: str) -> str:
    if not isinstance(value, str) or any(char.isspace() or ord(char) < 32 for char in value):
        raise ValueError("PAPERCLIP_API_URL is not a valid URL")
    try:
        parsed = urlsplit(value)
        host = parsed.hostname
        _ = parsed.port
    except ValueError as exc:
        raise ValueError("PAPERCLIP_API_URL is not a valid URL") from exc
    loopback = False
    if host:
        try:
            loopback = ip_address(host).is_loopback
        except ValueError:
            loopback = host.lower() == "localhost"
    if (
        parsed.scheme not in {"https", "http"}
        or not host
        or parsed.username is not None
        or parsed.password is not None
        or parsed.query
        or parsed.fragment
        or (parsed.scheme == "http" and not loopback)
    ):
        raise ValueError(
            "PAPERCLIP_API_URL must be HTTPS (or loopback HTTP) without credentials/query"
        )
    return value.rstrip("/")


@dataclass(frozen=True, repr=False)
class PaperclipConfig:
    api_url: str
    api_key: str = field(repr=False)
    company_id: str
    agent_id: str | None = None
    run_id: str | None = None

    def __post_init__(self) -> None:
        object.__setattr__(self, "api_url", _valid_base_url(self.api_url))
        if (
            not isinstance(self.api_key, str)
            or not self.api_key.strip()
            or any(char.isspace() or ord(char) < 32 for char in self.api_key)
        ):
            raise ValueError("PAPERCLIP_API_KEY is required")
        for name in ("company_id", "agent_id", "run_id"):
            value = getattr(self, name)
            if name == "company_id" and (
                not isinstance(value, str)
                or not value.strip()
                or not re.fullmatch(r"[A-Za-z0-9_-]+", value)
            ):
                raise ValueError(f"{name} must be a non-empty safe string")
            if name != "company_id" and value is not None and (
                not isinstance(value, str) or not value.strip()
            ):
                raise ValueError(f"{name} must be a non-empty string")

    @classmethod
    def from_env(cls) -> PaperclipConfig:
        values = {
            key: os.environ.get(key, "")
            for key in ("PAPERCLIP_API_URL", "PAPERCLIP_API_KEY", "PAPERCLIP_COMPANY_ID")
        }
        if not all(values.values()):
            raise ValueError(
                "PAPERCLIP_API_URL, PAPERCLIP_API_KEY, and PAPERCLIP_COMPANY_ID are required"
            )
        return cls(
            values["PAPERCLIP_API_URL"],
            values["PAPERCLIP_API_KEY"],
            values["PAPERCLIP_COMPANY_ID"],
            os.environ.get("PAPERCLIP_AGENT_ID") or None,
            os.environ.get("PAPERCLIP_RUN_ID") or None,
        )

    def __repr__(self) -> str:
        return (
            f"PaperclipConfig(api_url={self.api_url!r}, api_key='<redacted>', "
            f"company_id={self.company_id!r}, agent_id={self.agent_id!r}, run_id={self.run_id!r})"
        )


_MISSING = object()


def _segment(value: str, label: str = "id") -> str:
    if not isinstance(value, str) or not re.fullmatch(r"[A-Za-z0-9_-]+", value):
        raise ValueError(f"invalid {label} path segment")
    return value


class PaperclipClient:
    def __init__(
        self,
        config: PaperclipConfig,
        http_client: httpx.Client | None = None,
        *,
        transport: httpx.BaseTransport | None = None,
        timeout: float = 10.0,
    ) -> None:
        self.config = config
        self._owned = http_client is None
        self._http = http_client or httpx.Client(
            base_url=config.api_url,
            transport=transport,
            timeout=timeout,
            follow_redirects=False,
            trust_env=False,
        )

    def __enter__(self) -> PaperclipClient:
        return self

    def __exit__(self, *_: object) -> None:
        self.close()

    def close(self) -> None:
        if self._owned:
            self._http.close()

    def _request(
        self, method: str, path: str, *, params: dict[str, Any] | None = None, json: Any = _MISSING
    ) -> Any:
        headers = {"Authorization": f"Bearer {self.config.api_key}", "Accept": "application/json"}
        if self.config.agent_id:
            if not self.config.run_id:
                raise ValueError(
                    "PAPERCLIP_RUN_ID is required for mutations when PAPERCLIP_AGENT_ID is set"
                )
            headers["X-Paperclip-Run-Id"] = self.config.run_id
        try:
            response = self._http.request(
                method,
                self.config.api_url + path,
                params=params,
                json=None if json is _MISSING else json,
                headers=headers,
                follow_redirects=False,
            )
        except httpx.TimeoutException as exc:
            raise PaperclipNetworkError(
                "Paperclip request timed out; mutation outcome is unknown"
            ) from exc
        except httpx.HTTPError as exc:
            raise PaperclipNetworkError(
                "Paperclip transport failed; mutation outcome is unknown"
            ) from exc
        if response.is_redirect:
            raise PaperclipHTTPError(response.status_code, "Paperclip redirect refused")
        if response.status_code in {401, 403}:
            raise PaperclipAuthError(
                f"Paperclip authentication/authorization failed (HTTP {response.status_code})"
            )
        if response.status_code == 409:
            raise PaperclipConflictError(409, "Paperclip state conflict")
        if not 200 <= response.status_code < 300:
            raise PaperclipHTTPError(response.status_code)
        if response.is_error:
            raise PaperclipHTTPError(response.status_code)
        if not response.content:
            return None
        try:
            return response.json()
        except ValueError as exc:
            raise PaperclipResponseError("Paperclip returned invalid JSON") from exc

    @staticmethod
    def _dict(data: Any) -> dict[str, Any]:
        if not isinstance(data, dict):
            raise PaperclipResponseError("Paperclip returned an unexpected object shape")
        return data

    def list_issues(
        self,
        *,
        project_id: str | None = None,
        status: str | None = None,
        assignee_agent_id: str | None = None,
    ) -> Any:
        params = {"projectId": project_id, "status": status, "assigneeAgentId": assignee_agent_id}
        data = self._request(
            "GET",
            f"/api/companies/{_segment(self.config.company_id, 'company id')}/issues",
            params={k: v for k, v in params.items() if v is not None},
        )
        if not isinstance(data, (list, dict)):
            raise PaperclipResponseError("Paperclip issues response is not an object or list")
        return data

    def create_issue(
        self,
        title: str,
        *,
        description: str | None = None,
        status: str = "backlog",
        priority: str = "medium",
        project_id: str | None = None,
        assignee_agent_id: str | None = None,
        parent_id: str | None = None,
    ) -> dict[str, Any]:
        body: dict[str, Any] = {"title": title, "status": status, "priority": priority}
        for key, value in (
            ("description", description),
            ("projectId", project_id),
            ("assigneeAgentId", assignee_agent_id),
            ("parentId", parent_id),
        ):
            if value is not None:
                body[key] = value
        return self._dict(
            self._request(
                "POST",
                f"/api/companies/{_segment(self.config.company_id, 'company id')}/issues",
                json=body,
            )
        )

    def get_issue(self, issue_id: str) -> dict[str, Any]:
        data = self._dict(self._request("GET", f"/api/issues/{_segment(issue_id, 'issue id')}"))
        company = data.get("companyId", data.get("company_id"))
        if company is None or str(company) != self.config.company_id:
            raise PaperclipResponseError("Paperclip issue belongs to a different company")
        return data

    def get_comment(self, issue_id: str, comment_id: str) -> dict[str, Any]:
        requested_issue = _segment(issue_id, "issue id")
        data = self._dict(
            self._request(
                "GET",
                f"/api/issues/{requested_issue}/comments/"
                f"{_segment(comment_id, 'comment id')}",
            )
        )
        company = data.get("companyId", data.get("company_id"))
        if company is None or str(company) != self.config.company_id:
            raise PaperclipResponseError("Paperclip comment belongs to a different company")
        comment_issue = data.get("issueId", data.get("issue_id"))
        if comment_issue is None:
            raise PaperclipResponseError("Paperclip comment has no issue binding")
        parent = self.get_issue(requested_issue)
        valid_issue_ids = {requested_issue}
        for key in ("id", "identifier"):
            if parent.get(key) is not None:
                valid_issue_ids.add(str(parent[key]))
        if str(comment_issue) not in valid_issue_ids:
            raise PaperclipResponseError("Paperclip comment belongs to a different issue")
        return data

    def list_comments(self, issue_id: str, *, after: str | None = None, limit: int = 100) -> Any:
        if not 1 <= limit <= 500:
            raise ValueError("comment limit must be between 1 and 500")
        params: dict[str, Any] = {"order": "asc", "limit": limit}
        if after is not None:
            params["after"] = after
        data = self._request(
            "GET", f"/api/issues/{_segment(issue_id, 'issue id')}/comments", params=params
        )
        if not isinstance(data, (list, dict)):
            raise PaperclipResponseError("Paperclip comments response is not an object or list")
        return data

    def add_comment(self, issue_id: str, body: str) -> dict[str, Any]:
        return self._dict(
            self._request(
                "POST",
                f"/api/issues/{_segment(issue_id, 'issue id')}/comments",
                json={"body": body},
            )
        )

    def checkout(
        self, issue_id: str, *, expected_statuses: Iterable[str] = ("todo",)
    ) -> dict[str, Any]:
        if not self.config.agent_id:
            raise ValueError("PAPERCLIP_AGENT_ID is required for checkout")
        statuses = list(expected_statuses)
        if not statuses or any(not isinstance(s, str) or not s for s in statuses):
            raise ValueError("expected_statuses must contain non-empty strings")
        body = {"agentId": self.config.agent_id, "expectedStatuses": statuses}
        return self._dict(
            self._request(
                "POST", f"/api/issues/{_segment(issue_id, 'issue id')}/checkout", json=body
            )
        )

    def update_issue(
        self,
        issue_id: str,
        *,
        status: str | None = None,
        assignee_agent_id: str | None | object = _MISSING,
        comment: str | None = None,
    ) -> dict[str, Any]:
        body: dict[str, Any] = {}
        if status is not None:
            body["status"] = status
        if assignee_agent_id is not _MISSING:
            body["assigneeAgentId"] = assignee_agent_id
        if comment is not None:
            body["comment"] = comment
        if not body:
            raise ValueError("update_issue requires status, assignee_agent_id, or comment")
        return self._dict(
            self._request("PATCH", f"/api/issues/{_segment(issue_id, 'issue id')}", json=body)
        )

    def get_me(self) -> dict[str, Any]:
        return self._dict(self._request("GET", "/api/agents/me"))

    def get_agent(self, agent_id: str) -> dict[str, Any]:
        data = self._dict(self._request("GET", f"/api/agents/{_segment(agent_id, 'agent id')}"))
        company = data.get("companyId", data.get("company_id"))
        if company is None or str(company) != self.config.company_id:
            raise PaperclipResponseError("Paperclip agent belongs to a different company")
        return data
