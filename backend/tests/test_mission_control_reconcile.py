"""Outbox and reconciliation tests for mutation durability."""

from __future__ import annotations

import json
from uuid import uuid4

import httpx
import pytest

from mission_control.cli import execute, parser
from mission_control.client import PaperclipClient, PaperclipConfig, PaperclipError
from mission_control.outbox import Outbox

COMPANY = str(uuid4())
DEVELOPER = str(uuid4())
REVIEWER = str(uuid4())
RUN = str(uuid4())
TASK = str(uuid4())
TASK_IDENTIFIER = "SUB-101"
COMMENT1 = str(uuid4())
COMMENT2 = str(uuid4())


class PaperclipStub:
    """Mock Paperclip server for reconciliation testing."""

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
                return httpx.Response(
                    200,
                    json={"id": REVIEWER, "companyId": COMPANY, "status": self.recipient_status}
                )
            if path == "/api/issues/SUB-101":
                return httpx.Response(200, json=self.task)
            if path == "/api/issues/SUB-101/comments":
                return httpx.Response(200, json=self.comments)
        if request.method == "POST" and path == "/api/issues/SUB-101/comments":
            payload = json.loads(request.content)
            comment = {"id": COMMENT1, "body": payload["body"], "authorAgentId": DEVELOPER}
            self.comments.append(comment)
            if self.fail_write:
                raise httpx.ReadTimeout("DO NOT LEAK SERVER OR CREDENTIAL TEXT")
            return httpx.Response(201, json=comment)
        if self.fail_write and request.method in {"POST", "PATCH", "PUT", "DELETE"}:
            raise httpx.ReadTimeout("DO NOT LEAK SERVER OR CREDENTIAL TEXT")
        if request.method == "PATCH" and path == "/api/issues/SUB-101":
            payload = json.loads(request.content)
            self.task.update(payload)
            return httpx.Response(200, json=self.task)
        if request.method == "POST" and "/issues" in path:
            payload = json.loads(request.content)
            return httpx.Response(201, json={"id": TASK, **payload})
        raise AssertionError(f"Unexpected request: {request.method} {path}")


@pytest.fixture
def connection(tmp_path):
    server = PaperclipStub()
    config = PaperclipConfig("https://paperclip.example", "secret", COMPANY, DEVELOPER, RUN)
    with PaperclipClient(config, transport=httpx.MockTransport(server)) as client:
        yield client, server, tmp_path


def command(*args):
    return parser().parse_args(list(args))


def body_file(tmp_path, content="Abnahme durch Testbericht nachgewiesen."):
    path = tmp_path / "message.md"
    path.write_text(content, encoding="utf-8")
    return str(path)


def test_send_records_confirmed_on_success(connection):
    """A successful send writes a confirmed record with the server's comment id."""
    client, server, tmp_path = connection
    state_dir = tmp_path / "state"

    result = execute(
        command("send", TASK_IDENTIFIER, "--to", REVIEWER, "--body-file", body_file(tmp_path),
                "--state-dir", str(state_dir)),
        client
    )

    assert result["id"] == COMMENT1
    outbox = Outbox(state_dir / "outbox.jsonl")
    records = outbox.records()
    assert len(records) == 1
    assert records[0].status == "confirmed"
    assert records[0].server_ref == COMMENT1


def test_send_leaves_unknown_on_timeout(connection):
    """A timeout during send leaves an unknown record."""
    client, server, tmp_path = connection
    state_dir = tmp_path / "state"
    server.fail_write = True

    with pytest.raises(PaperclipError, match=".*"):
        execute(
            command("send", TASK_IDENTIFIER, "--to", REVIEWER, "--body-file", body_file(tmp_path),
                    "--state-dir", str(state_dir)),
            client
        )

    outbox = Outbox(state_dir / "outbox.jsonl")
    records = outbox.records()
    assert len(records) == 1
    assert records[0].status == "unknown"


def test_reconcile_finds_comment_in_thread(connection):
    """Reconcile finds a comment by correlation_id and marks it confirmed."""
    client, server, tmp_path = connection
    state_dir = tmp_path / "state"
    server.fail_write = True

    with pytest.raises(PaperclipError, match=".*"):
        execute(
            command("send", TASK_IDENTIFIER, "--to", REVIEWER, "--body-file", body_file(tmp_path),
                    "--state-dir", str(state_dir)),
            client
        )

    outbox = Outbox(state_dir / "outbox.jsonl")
    records_before = outbox.records()
    assert len(records_before) == 1
    assert records_before[0].status == "unknown"

    server.fail_write = False
    server.requests = []

    result = execute(
        command("reconcile", "--state-dir", str(state_dir)),
        client
    )

    assert result["checked"] >= 1
    records_after = outbox.records()
    final_record = records_after[0]
    assert final_record.status == "confirmed"


def test_reconcile_uses_only_get_requests(connection):
    """Reconcile never sends POST/PATCH/PUT/DELETE; only GET requests."""
    client, server, tmp_path = connection
    state_dir = tmp_path / "state"

    execute(
        command("send", TASK_IDENTIFIER, "--to", REVIEWER, "--body-file", body_file(tmp_path),
                "--state-dir", str(state_dir)),
        client
    )

    server.requests = []

    execute(
        command("reconcile", "--state-dir", str(state_dir)),
        client
    )

    for request in server.requests:
        assert request.method == "GET", f"Unexpected {request.method} request"


def test_reconcile_dry_run_does_not_write_journal(connection):
    """Reconcile --dry-run reports findings but writes nothing to the journal."""
    client, server, tmp_path = connection
    state_dir = tmp_path / "state"

    execute(
        command("send", TASK_IDENTIFIER, "--to", REVIEWER, "--body-file", body_file(tmp_path),
                "--state-dir", str(state_dir)),
        client
    )

    outbox = Outbox(state_dir / "outbox.jsonl")
    records_before = outbox.records()

    result = execute(
        command("reconcile", "--dry-run", "--state-dir", str(state_dir)),
        client
    )

    assert result["dry_run"] is True
    records_after = outbox.records()
    assert len(records_before) == len(records_after)
    assert records_before[0].status == records_after[0].status


def test_dedup_guard_blocks_second_send_without_force(connection):
    """Dedup guard blocks a second send for a task with unresolved record."""
    client, server, tmp_path = connection
    state_dir = tmp_path / "state"
    server.fail_write = True

    with pytest.raises(PaperclipError, match=".*"):
        execute(
            command("send", TASK_IDENTIFIER, "--to", REVIEWER, "--body-file", body_file(tmp_path),
                    "--state-dir", str(state_dir)),
            client
        )

    server.fail_write = False
    server.requests = []

    with pytest.raises(ValueError) as exc_info:
        execute(
            command("send", TASK_IDENTIFIER, "--to", REVIEWER, "--body-file", body_file(tmp_path),
                    "--state-dir", str(state_dir)),
            client
        )

    assert "Unaufgeloeste Outbox-Eintrag" in str(exc_info.value)
    assert "reconcile" in str(exc_info.value).lower()


def test_force_bypasses_dedup_guard(connection):
    """The --force flag lets a second send through despite unresolved records."""
    client, server, tmp_path = connection
    state_dir = tmp_path / "state"
    server.fail_write = True

    with pytest.raises(PaperclipError, match=".*"):
        execute(
            command("send", TASK_IDENTIFIER, "--to", REVIEWER, "--body-file", body_file(tmp_path),
                    "--state-dir", str(state_dir)),
            client
        )

    server.fail_write = False
    server.requests = []
    server.comments = []

    result = execute(
        command("send", TASK_IDENTIFIER, "--to", REVIEWER, "--body-file", body_file(tmp_path),
                "--state-dir", str(state_dir), "--force"),
        client
    )

    assert result["id"] == COMMENT1
    post_requests = [r for r in server.requests if r.method == "POST"]
    assert len(post_requests) >= 1


def test_send_dry_run_writes_no_journal(connection):
    """Dry-run on send does not write any journal file."""
    client, server, tmp_path = connection
    state_dir = tmp_path / "state"

    result = execute(
        command("send", TASK_IDENTIFIER, "--to", REVIEWER, "--body-file", body_file(tmp_path),
                "--state-dir", str(state_dir), "--dry-run"),
        client
    )

    assert result["dry_run"] is True
    journal_file = state_dir / "outbox.jsonl"
    assert not journal_file.exists()


def test_create_records_confirmed_on_success(connection):
    """A successful create writes a confirmed record with the task id."""
    client, server, tmp_path = connection
    state_dir = tmp_path / "state"

    server.requests = []

    result = execute(
        command(
            "create", "--title", "Test Task", "--criteria", "Must work",
            "--state-dir", str(state_dir)
        ),
        client
    )

    assert "id" in result
    outbox = Outbox(state_dir / "outbox.jsonl")
    records = outbox.records()
    assert len(records) == 1
    assert records[0].status == "confirmed"
    assert records[0].kind == "issue"


def test_reconcile_with_specific_task_filters(connection):
    """Reconcile with a task argument filters to only that task."""
    client, server, tmp_path = connection
    state_dir = tmp_path / "state"

    execute(
        command("send", TASK_IDENTIFIER, "--to", REVIEWER, "--body-file", body_file(tmp_path),
                "--state-dir", str(state_dir)),
        client
    )

    other_task = "SUB-999"

    server.requests = []

    result = execute(
        command("reconcile", other_task, "--state-dir", str(state_dir)),
        client
    )

    assert result["checked"] == 0


def _reconcile_client(handler):
    """A client whose transport is fully controlled by the given handler."""
    config = PaperclipConfig("https://paperclip.example", "secret", COMPANY, DEVELOPER, RUN)
    return PaperclipClient(config, transport=httpx.MockTransport(handler))


def test_reconcile_pages_through_a_long_thread(tmp_path):
    """A message beyond the first page must still be found, not reported missing."""
    state_dir = tmp_path / "state"
    outbox = Outbox(state_dir / "outbox.jsonl")
    correlation = str(uuid4())
    record = outbox.record(kind="comment", task_id=TASK_IDENTIFIER, correlation_id=correlation)
    outbox.mark_unknown(record.record_id, "Zeitueberschreitung")

    first_page = [{"id": f"c{index}", "body": "unbeteiligt"} for index in range(200)]
    second_page = [{"id": COMMENT2, "body": f'{{"message_id": "{correlation}"}}'}]

    def handler(request):
        assert request.method == "GET", "reconcile darf niemals schreiben"
        after = request.url.params.get("after")
        return httpx.Response(200, json=second_page if after == "c199" else first_page)

    with _reconcile_client(handler) as client:
        summary = execute(command("reconcile", "--state-dir", str(state_dir)), client)

    assert summary["newly_confirmed"] == 1
    assert summary["still_unresolved"] == 0
    confirmed = Outbox(state_dir / "outbox.jsonl").records()[0]
    assert confirmed.status == "confirmed"
    assert confirmed.server_ref == COMMENT2


def test_reconcile_refuses_to_guess_on_an_unreadable_thread(tmp_path):
    """An unparsable response must not masquerade as 'not delivered'."""
    state_dir = tmp_path / "state"
    outbox = Outbox(state_dir / "outbox.jsonl")
    record = outbox.record(
        kind="comment", task_id=TASK_IDENTIFIER, correlation_id=str(uuid4())
    )
    outbox.mark_unknown(record.record_id, "Zeitueberschreitung")

    def handler(request):
        return httpx.Response(200, json={"unerwartet": "form"})

    with _reconcile_client(handler) as client:
        summary = execute(command("reconcile", "--state-dir", str(state_dir)), client)

    assert summary["newly_confirmed"] == 0
    assert summary["still_unresolved"] == 1
    assert "Abgleich nicht moeglich" in summary["unresolved_records"][0]["grund"]
    assert Outbox(state_dir / "outbox.jsonl").records()[0].status == "unknown"
