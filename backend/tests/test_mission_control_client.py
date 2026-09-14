"""Wire-level contract tests for the bounded Paperclip client."""

from __future__ import annotations

import json

import httpx
import pytest

from mission_control import (
    PaperclipClient,
    PaperclipConfig,
    PaperclipConflictError,
    PaperclipHTTPError,
    PaperclipNetworkError,
    PaperclipResponseError,
)


def cfg(**kwargs):
    values = {"api_url": "https://paperclip.example", "api_key": "secret", "company_id": "co_1"}
    values.update(kwargs)
    return PaperclipConfig(**values)


def test_auth_run_header_and_structured_body():
    seen = []

    def handler(request):
        seen.append(request)
        return httpx.Response(200, json={"id": "i1", "nested": {"ok": True}})

    with PaperclipClient(
        cfg(agent_id="a1", run_id="r1"), transport=httpx.MockTransport(handler)
    ) as client:
        assert client.update_issue("i1", status="done") == {"id": "i1", "nested": {"ok": True}}
    assert seen[0].headers["Authorization"] == "Bearer secret"
    assert seen[0].headers["X-Paperclip-Run-Id"] == "r1"
    assert seen[0].read() == b'{"status":"done"}'


def test_update_issue_encodes_review_request_and_interaction_id():
    seen = []

    def handler(request):
        seen.append(request)
        return httpx.Response(200, json={"id": "i1"})

    with PaperclipClient(
        cfg(agent_id="a1", run_id="r1"), transport=httpx.MockTransport(handler)
    ) as client:
        client.update_issue(
            "i1",
            status="in_review",
            review_request_instructions="Bitte pruefen.",
            review_interaction_id="int-1",
        )
    body = json.loads(seen[0].read())
    assert body["reviewRequest"] == {"instructions": "Bitte pruefen."}
    assert body["reviewInteractionId"] == "int-1"


def test_create_review_interaction_posts_request_confirmation():
    seen = []

    def handler(request):
        seen.append(request)
        return httpx.Response(201, json={"id": "int-1", "status": "pending"})

    with PaperclipClient(
        cfg(agent_id="a1", run_id="r1"), transport=httpx.MockTransport(handler)
    ) as client:
        result = client.create_review_interaction(
            "i1", addressee_agent_id="reviewer-1", prompt="Bitte Review durchfuehren."
        )
    assert result == {"id": "int-1", "status": "pending"}
    assert seen[0].url.path == "/api/issues/i1/interactions"
    body = json.loads(seen[0].read())
    assert body["kind"] == "request_confirmation"
    assert body["addresseeAgentId"] == "reviewer-1"
    assert body["payload"] == {"version": 1, "prompt": "Bitte Review durchfuehren."}


def test_missing_token_and_hostile_values():
    with pytest.raises(ValueError):
        PaperclipConfig("https://x.example", "", "c")
    with pytest.raises(ValueError):
        PaperclipConfig("http://evil.example", "x", "c")
    with pytest.raises(ValueError):
        PaperclipConfig("https://user:pass@x.example/path?token=bad", "x", "c")
    with pytest.raises(ValueError):
        PaperclipConfig("https://x.example", "secret\nforged", "c")
    with pytest.raises(ValueError):
        PaperclipConfig("https://x.example", "x", None)
    with PaperclipClient(
        cfg(), transport=httpx.MockTransport(lambda r: httpx.Response(200, json=[]))
    ) as client:
        with pytest.raises(ValueError):
            client.get_issue("x/y")


def test_redirect_timeout_conflict_and_comments():
    with PaperclipClient(
        cfg(),
        transport=httpx.MockTransport(
            lambda r: httpx.Response(307, headers={"location": "https://other"})
        ),
    ) as client:
        with pytest.raises(PaperclipHTTPError):
            client.get_me()

    def timeout(request):
        raise httpx.ReadTimeout("late")

    with PaperclipClient(cfg(), transport=httpx.MockTransport(timeout)) as client:
        with pytest.raises(PaperclipNetworkError):
            client.add_comment("i1", "once")
    with PaperclipClient(
        cfg(agent_id="a1", run_id="r1"),
        transport=httpx.MockTransport(lambda r: httpx.Response(409)),
    ) as client:
        with pytest.raises(PaperclipConflictError):
            client.checkout("i1")
    requests = []
    with PaperclipClient(
        cfg(),
        transport=httpx.MockTransport(
            lambda r: (requests.append(r), httpx.Response(200, json=[]))[1]
        ),
    ) as client:
        client.list_comments("i1", after="cursor", limit=500)
    assert dict(requests[0].url.params) == {"order": "asc", "limit": "500", "after": "cursor"}


def test_non_2xx_without_location_is_rejected():
    with PaperclipClient(
        cfg(), transport=httpx.MockTransport(lambda r: httpx.Response(304))
    ) as client:
        with pytest.raises(PaperclipHTTPError):
            client.get_me()


def test_get_comment_requires_company_and_matches_parent_issue():
    responses = [
        httpx.Response(
            200,
            json={"id": "comment-1", "issueId": "canonical-1", "companyId": "co_1"},
        ),
        httpx.Response(
            200,
            json={"id": "canonical-1", "identifier": "SUB-101", "companyId": "co_1"},
        ),
    ]

    with PaperclipClient(
        cfg(), transport=httpx.MockTransport(lambda r: responses.pop(0))
    ) as client:
        comment = client.get_comment("SUB-101", "comment-1")
    assert comment["id"] == "comment-1"

    with PaperclipClient(
        cfg(), transport=httpx.MockTransport(
            lambda r: httpx.Response(200, json={"id": "comment-1", "issueId": "SUB-101"})
        )
    ) as client:
        with pytest.raises(PaperclipResponseError):
            client.get_comment("SUB-101", "comment-1")


def test_get_agent_requires_company_binding():
    with PaperclipClient(
        cfg(), transport=httpx.MockTransport(lambda r: httpx.Response(200, json={"id": "a1"}))
    ) as client:
        with pytest.raises(PaperclipResponseError):
            client.get_agent("a1")
