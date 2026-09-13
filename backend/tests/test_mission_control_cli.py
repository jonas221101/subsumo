"""Agent-to-agent wire integration without credentials, workers, or a real server."""

from __future__ import annotations

import json
from uuid import uuid4

import httpx
import pytest

from mission_control.cli import execute, main, parser
from mission_control.client import PaperclipClient, PaperclipConfig, PaperclipError

COMPANY = str(uuid4())
DEVELOPER = str(uuid4())
REVIEWER = str(uuid4())
RUN = str(uuid4())
TASK = str(uuid4())
COMMENT = str(uuid4())


class PaperclipStub:
    """Records expected HTTP contracts; does not simulate any model reasoning."""

    def __init__(self):
        self.requests = []
        self.task = {
            "id": TASK, "companyId": COMPANY, "identifier": "SUB-101",
            "status": "in_progress", "assigneeAgentId": DEVELOPER,
        }
        self.comments = []
        self.recipient_status = "active"
        self.sender = DEVELOPER
        self.fail_write = False

    def __call__(self, request):
        self.requests.append(request)
        path = request.url.path
        if request.method == "GET":
            if path == "/api/agents/me":
                return httpx.Response(200, json={"id": self.sender, "companyId": COMPANY})
            if path == f"/api/agents/{REVIEWER}":
                return httpx.Response(200, json={
                    "id": REVIEWER, "companyId": COMPANY, "status": self.recipient_status,
                })
            if path == "/api/issues/SUB-101":
                return httpx.Response(200, json=self.task)
            if path == f"/api/issues/SUB-101/comments/{COMMENT}":
                return httpx.Response(200, json={
                    "id": COMMENT, "companyId": COMPANY, "issueId": TASK,
                    "authorAgentId": REVIEWER,
                })
            if path == "/api/issues/SUB-101/comments":
                return httpx.Response(200, json=self.comments)
        if self.fail_write:
            raise httpx.ReadTimeout("DO NOT LEAK SERVER OR CREDENTIAL TEXT")
        payload = json.loads(request.content)
        if request.method == "POST" and path == "/api/issues/SUB-101/comments":
            comment = {"id": COMMENT, "body": payload["body"], "authorAgentId": DEVELOPER}
            self.comments.append(comment)
            return httpx.Response(201, json=comment)
        if request.method == "PATCH" and path == "/api/issues/SUB-101":
            self.task.update(payload)
            return httpx.Response(200, json=self.task)
        if request.method == "POST" and path == f"/api/companies/{COMPANY}/issues":
            return httpx.Response(201, json={"id": TASK, **payload})
        if request.method == "POST" and path == "/api/issues/SUB-101/checkout":
            if self.task["status"] not in payload["expectedStatuses"]:
                return httpx.Response(409)
            self.task["status"] = "in_progress"
            return httpx.Response(200, json=self.task)
        raise AssertionError(f"Unexpected request: {request.method} {path}")


@pytest.fixture
def connection():
    server = PaperclipStub()
    config = PaperclipConfig("https://paperclip.example", "secret", COMPANY, DEVELOPER, RUN)
    with PaperclipClient(config, transport=httpx.MockTransport(server)) as client:
        yield client, server


def command(*args):
    return parser().parse_args(list(args))


def body_file(tmp_path, content="Abnahme durch Testbericht nachgewiesen."):
    path = tmp_path / "message.md"
    path.write_text(content, encoding="utf-8")
    return str(path)


def test_create_preview_works_offline_without_credentials(monkeypatch, capsys):
    for key in ("PAPERCLIP_API_URL", "PAPERCLIP_API_KEY", "PAPERCLIP_COMPANY_ID",
                "PAPERCLIP_AGENT_ID", "PAPERCLIP_RUN_ID"):
        monkeypatch.delenv(key, raising=False)
    assert main(["create", "--title", "Delta-Sync", "--criteria", "Offline-Test gruen",
                 "--dry-run"]) == 0
    preview = json.loads(capsys.readouterr().out)
    assert preview["dry_run"] is True
    assert preview["payload"]["status"] == "backlog"


def test_send_persists_directed_message_without_reassigning(connection, tmp_path):
    client, server = connection
    result = execute(command("send", "SUB-101", "--to", REVIEWER,
                             "--body-file", body_file(tmp_path)), client)
    assert result["id"] == COMMENT
    assert server.task["assigneeAgentId"] == DEVELOPER
    assert server.comments[0]["body"].startswith(f"[@Agent](agent://{REVIEWER})")
    writes = [r for r in server.requests if r.method != "GET"]
    assert len(writes) == 1
    assert writes[0].headers["X-Paperclip-Run-Id"] == RUN


def test_reply_references_original_agent_comment(connection, tmp_path):
    client, server = connection
    result = execute(command("send", "SUB-101", "--to", REVIEWER, "--kind", "answer",
                             "--reply-to", COMMENT, "--body-file", body_file(tmp_path)), client)
    assert COMMENT in result["body"]
    assert len(server.comments) == 1


def test_handoff_changes_owner_status_and_evidence_in_one_write(connection, tmp_path):
    client, server = connection
    result = execute(command("request-review", "SUB-101", "--to", REVIEWER,
                             "--commit", "a" * 40, "--body-file", body_file(tmp_path)), client)
    assert result["status"] == "in_review"
    assert result["assigneeAgentId"] == REVIEWER
    assert "a" * 40 in result["comment"]
    assert [r.method for r in server.requests if r.method != "GET"] == ["PATCH"]


@pytest.mark.parametrize("case", ["wrong_identity", "wrong_company", "paused", "closed"])
def test_preflight_rejects_unsafe_send_without_write(connection, tmp_path, case):
    client, server = connection
    if case == "wrong_identity":
        server.sender = REVIEWER
    elif case == "wrong_company":
        server.task["companyId"] = "other-company"
    elif case == "paused":
        server.recipient_status = "paused"
    else:
        server.task["status"] = "done"
    with pytest.raises((ValueError, PaperclipError)):
        execute(command("send", "SUB-101", "--to", REVIEWER,
                        "--body-file", body_file(tmp_path)), client)
    assert all(r.method == "GET" for r in server.requests)


def test_timeout_is_not_retried_and_exposes_correlation_for_reconciliation(connection, tmp_path):
    client, server = connection
    server.fail_write = True
    with pytest.raises(PaperclipError) as error:
        execute(command("send", "SUB-101", "--to", REVIEWER,
                        "--body-file", body_file(tmp_path)), client)
    assert "Nachrichten-ID" in str(error.value)
    assert "DO NOT LEAK" not in str(error.value)
    assert "secret" not in str(error.value)
    assert len([r for r in server.requests if r.method == "POST"]) == 1


def test_claim_requires_assignment_and_handles_conflict(connection):
    client, server = connection
    server.task["assigneeAgentId"] = REVIEWER
    with pytest.raises(ValueError):
        execute(command("claim", "SUB-101"), client)
    server.task["assigneeAgentId"] = DEVELOPER
    with pytest.raises(PaperclipError):
        execute(command("claim", "SUB-101"), client)
    assert execute(command("claim", "SUB-101", "--resume"), client)["status"] == "in_progress"


def test_empty_handoff_evidence_is_rejected(connection, tmp_path):
    client, server = connection
    with pytest.raises(ValueError):
        execute(command("request-review", "SUB-101", "--to", REVIEWER, "--commit", "a" * 40,
                        "--body-file", body_file(tmp_path, " ")), client)
    assert not server.requests
