"""Tests for the Outbox append-only mutation journal."""

from __future__ import annotations

from pathlib import Path

import pytest

from mission_control.outbox import Outbox


def test_record_creates_file_and_pending_status(tmp_path: Path) -> None:
    """A record() call creates the file and records as pending."""
    outbox_path = tmp_path / "outbox.jsonl"
    outbox = Outbox(outbox_path)
    assert not outbox_path.exists()

    record = outbox.record(kind="comment", task_id="task-1")

    assert outbox_path.exists()
    assert record.status == "pending"
    assert record.kind == "comment"
    assert record.task_id == "task-1"
    assert record.correlation_id is None
    assert record.server_ref is None


def test_mark_confirmed_appends_line(tmp_path: Path) -> None:
    """mark_confirmed appends a new line; records() folds to the latest."""
    outbox_path = tmp_path / "outbox.jsonl"
    outbox = Outbox(outbox_path)

    record1 = outbox.record(kind="comment", task_id="task-1")
    line_count_after_record = len(outbox_path.read_text(encoding="utf-8").splitlines())

    record2 = outbox.mark_confirmed(record1.record_id, "server-id-1")
    line_count_after_confirm = len(outbox_path.read_text(encoding="utf-8").splitlines())

    assert line_count_after_confirm > line_count_after_record
    assert record2.status == "confirmed"
    assert record2.server_ref == "server-id-1"
    assert record2.record_id == record1.record_id

    folded = outbox.records()
    assert len(folded) == 1
    assert folded[0].status == "confirmed"
    assert folded[0].server_ref == "server-id-1"


def test_mark_unknown_appends_line(tmp_path: Path) -> None:
    """mark_unknown appends a new line with the unknown status."""
    outbox_path = tmp_path / "outbox.jsonl"
    outbox = Outbox(outbox_path)

    record1 = outbox.record(kind="issue", task_id="task-2")
    line_count_after_record = len(outbox_path.read_text(encoding="utf-8").splitlines())

    record2 = outbox.mark_unknown(record1.record_id, "Timeout after 10s")
    line_count_after_mark = len(outbox_path.read_text(encoding="utf-8").splitlines())

    assert line_count_after_mark > line_count_after_record
    assert record2.status == "unknown"
    assert record2.detail == "Timeout after 10s"

    folded = outbox.records()
    assert len(folded) == 1
    assert folded[0].status == "unknown"


def test_mark_failed_appends_line(tmp_path: Path) -> None:
    """mark_failed appends a new line with the failed status."""
    outbox_path = tmp_path / "outbox.jsonl"
    outbox = Outbox(outbox_path)

    record1 = outbox.record(kind="issue_update")
    line_count_after_record = len(outbox_path.read_text(encoding="utf-8").splitlines())

    record2 = outbox.mark_failed(record1.record_id, "HTTP 400: Invalid input")
    line_count_after_mark = len(outbox_path.read_text(encoding="utf-8").splitlines())

    assert line_count_after_mark > line_count_after_record
    assert record2.status == "failed"
    assert record2.detail == "HTTP 400: Invalid input"

    folded = outbox.records()
    assert len(folded) == 1
    assert folded[0].status == "failed"


def test_folding_multiple_status_changes(tmp_path: Path) -> None:
    """Multiple status changes fold to one record with the final status."""
    outbox_path = tmp_path / "outbox.jsonl"
    outbox = Outbox(outbox_path)

    r1 = outbox.record(kind="comment", task_id="task-1", correlation_id="corr-1")
    outbox.mark_unknown(r1.record_id, "Network error")
    outbox.mark_confirmed(r1.record_id, "server-ref-1")

    lines = outbox_path.read_text(encoding="utf-8").splitlines()
    assert len(lines) == 3

    folded = outbox.records()
    assert len(folded) == 1
    assert folded[0].status == "confirmed"
    assert folded[0].server_ref == "server-ref-1"
    assert folded[0].record_id == r1.record_id
    assert folded[0].correlation_id == "corr-1"


def test_corrupt_trailing_line_skipped(tmp_path: Path) -> None:
    """A corrupt trailing line is skipped; earlier valid lines are read."""
    outbox_path = tmp_path / "outbox.jsonl"
    outbox = Outbox(outbox_path)

    r1 = outbox.record(kind="comment", task_id="task-1")

    with open(outbox_path, "a", encoding="utf-8") as f:
        f.write("{ corrupted json that will not parse\n")

    folded = outbox.records()
    assert len(folded) == 1
    assert folded[0].record_id == r1.record_id
    assert folded[0].status == "pending"


def test_unresolved_returns_pending_and_unknown(tmp_path: Path) -> None:
    """unresolved() returns only pending and unknown, excludes confirmed/failed."""
    outbox_path = tmp_path / "outbox.jsonl"
    outbox = Outbox(outbox_path)

    r1 = outbox.record(kind="comment", task_id="task-1")
    r2 = outbox.record(kind="comment", task_id="task-2")
    r3 = outbox.record(kind="comment", task_id="task-3")
    r4 = outbox.record(kind="comment", task_id="task-4")

    outbox.mark_confirmed(r2.record_id, "srv-2")
    outbox.mark_failed(r4.record_id, "HTTP 400")
    outbox.mark_unknown(r3.record_id, "Timeout")

    unresolved = outbox.unresolved()
    statuses = {r.status for r in unresolved}
    assert statuses == {"pending", "unknown"}

    assert len(unresolved) == 2
    record_ids = {r.record_id for r in unresolved}
    assert record_ids == {r1.record_id, r3.record_id}


def test_find_by_correlation_finds_folded_record(tmp_path: Path) -> None:
    """find_by_correlation returns the folded record matching correlation_id."""
    outbox_path = tmp_path / "outbox.jsonl"
    outbox = Outbox(outbox_path)

    r1 = outbox.record(kind="comment", correlation_id="corr-abc")
    outbox.mark_confirmed(r1.record_id, "srv-1")

    found = outbox.find_by_correlation("corr-abc")
    assert found is not None
    assert found.record_id == r1.record_id
    assert found.status == "confirmed"


def test_find_by_correlation_returns_none_for_unknown(tmp_path: Path) -> None:
    """find_by_correlation returns None for an unknown correlation_id."""
    outbox_path = tmp_path / "outbox.jsonl"
    outbox = Outbox(outbox_path)

    outbox.record(kind="comment", correlation_id="corr-abc")

    found = outbox.find_by_correlation("corr-unknown")
    assert found is None


def test_mark_confirmed_raises_key_error_for_unknown(tmp_path: Path) -> None:
    """mark_confirmed raises KeyError for an unknown record_id."""
    outbox_path = tmp_path / "outbox.jsonl"
    outbox = Outbox(outbox_path)

    with pytest.raises(KeyError):
        outbox.mark_confirmed("unknown-id", "srv-1")


def test_mark_unknown_raises_key_error_for_unknown(tmp_path: Path) -> None:
    """mark_unknown raises KeyError for an unknown record_id."""
    outbox_path = tmp_path / "outbox.jsonl"
    outbox = Outbox(outbox_path)

    with pytest.raises(KeyError):
        outbox.mark_unknown("unknown-id", "detail")


def test_mark_failed_raises_key_error_for_unknown(tmp_path: Path) -> None:
    """mark_failed raises KeyError for an unknown record_id."""
    outbox_path = tmp_path / "outbox.jsonl"
    outbox = Outbox(outbox_path)

    with pytest.raises(KeyError):
        outbox.mark_failed("unknown-id", "detail")


def test_durability_across_instances(tmp_path: Path) -> None:
    """A fresh Outbox instance sees records written by an earlier instance."""
    outbox_path = tmp_path / "outbox.jsonl"

    outbox1 = Outbox(outbox_path)
    r1 = outbox1.record(kind="comment", task_id="task-1", correlation_id="corr-1")
    outbox1.mark_confirmed(r1.record_id, "srv-1")

    outbox2 = Outbox(outbox_path)
    records = outbox2.records()

    assert len(records) == 1
    assert records[0].record_id == r1.record_id
    assert records[0].status == "confirmed"
    assert records[0].server_ref == "srv-1"
    assert records[0].correlation_id == "corr-1"


def test_empty_file_returns_empty_records(tmp_path: Path) -> None:
    """An empty (or nonexistent) outbox returns empty records."""
    outbox_path = tmp_path / "outbox.jsonl"
    outbox = Outbox(outbox_path)

    records = outbox.records()
    assert records == []

    unresolved = outbox.unresolved()
    assert unresolved == []


def test_multiple_records_ordered_by_creation(tmp_path: Path) -> None:
    """records() returns multiple records in creation order."""
    outbox_path = tmp_path / "outbox.jsonl"
    outbox = Outbox(outbox_path)

    r1 = outbox.record(kind="comment", task_id="task-1")
    r2 = outbox.record(kind="issue", task_id="task-2")
    r3 = outbox.record(kind="issue_update", task_id="task-3")

    records = outbox.records()
    assert len(records) == 3
    assert records[0].record_id == r1.record_id
    assert records[1].record_id == r2.record_id
    assert records[2].record_id == r3.record_id


def test_malformed_json_line_skipped(tmp_path: Path) -> None:
    """A line that is not valid JSON is skipped."""
    outbox_path = tmp_path / "outbox.jsonl"
    outbox = Outbox(outbox_path)

    r1 = outbox.record(kind="comment", task_id="task-1")

    with open(outbox_path, "a", encoding="utf-8") as f:
        f.write("not valid json at all\n")

    with open(outbox_path, "a", encoding="utf-8") as f:
        f.write('{"some": "object"}\n')

    records = outbox.records()
    assert len(records) == 1
    assert records[0].record_id == r1.record_id


def test_missing_record_id_field_skipped(tmp_path: Path) -> None:
    """A JSON object missing record_id is skipped."""
    outbox_path = tmp_path / "outbox.jsonl"
    outbox = Outbox(outbox_path)

    r1 = outbox.record(kind="comment", task_id="task-1")

    with open(outbox_path, "a", encoding="utf-8") as f:
        f.write('{"created_at": "2024-01-01T00:00:00Z"}\n')

    records = outbox.records()
    assert len(records) == 1
    assert records[0].record_id == r1.record_id


def test_create_parent_dirs_on_first_write(tmp_path: Path) -> None:
    """record() creates parent directories if they don't exist."""
    outbox_path = tmp_path / "subdir" / "another" / "outbox.jsonl"
    assert not outbox_path.parent.exists()

    outbox = Outbox(outbox_path)
    record = outbox.record(kind="comment")

    assert outbox_path.exists()
    assert record.status == "pending"
