"""Append-only, crash-safe journal of mutations to Paperclip.

This module provides durable local recording of intended mutations before
sending them to the server, enabling post-hoc reconciliation of ambiguous
transport failures.
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Literal
from uuid import uuid4

OutboxStatus = Literal["pending", "confirmed", "unknown", "failed"]
STATUSES = ("pending", "confirmed", "unknown", "failed")
UNRESOLVED_STATUSES = ("pending", "unknown")


@dataclass(frozen=True)
class OutboxRecord:
    """A durable record of an intended mutation.

    server_ref carries the authoritative server id once confirmed; until then
    only correlation_id ties the record to what may already exist server-side.
    """

    record_id: str
    created_at: str
    updated_at: str
    kind: str
    task_id: str | None
    correlation_id: str | None
    status: OutboxStatus
    server_ref: str | None
    detail: str | None = None


class Outbox:
    """Append-only JSONL journal of intended mutations."""

    def __init__(self, path: Path) -> None:
        self.path = Path(path)

    def record(
        self,
        *,
        kind: str,
        task_id: str | None = None,
        correlation_id: str | None = None,
        detail: str | None = None,
    ) -> OutboxRecord:
        """Create a new pending record and append it to the journal."""
        now = datetime.now(UTC).isoformat()
        record = OutboxRecord(
            record_id=str(uuid4()),
            created_at=now,
            updated_at=now,
            kind=kind,
            task_id=task_id,
            correlation_id=correlation_id,
            status="pending",
            server_ref=None,
            detail=detail,
        )
        self._append_record(record)
        return record

    def mark_confirmed(self, record_id: str, server_ref: str) -> OutboxRecord:
        """Mark a record as confirmed and store the server reference."""
        existing = self._find_latest(record_id)
        if existing is None:
            raise KeyError(f"Unknown record_id: {record_id}")
        now = datetime.now(UTC).isoformat()
        updated = OutboxRecord(
            record_id=existing.record_id,
            created_at=existing.created_at,
            updated_at=now,
            kind=existing.kind,
            task_id=existing.task_id,
            correlation_id=existing.correlation_id,
            status="confirmed",
            server_ref=server_ref,
            detail=None,
        )
        self._append_record(updated)
        return updated

    def mark_unknown(self, record_id: str, detail: str) -> OutboxRecord:
        """Mark a record as unknown (transport failure; may have landed)."""
        existing = self._find_latest(record_id)
        if existing is None:
            raise KeyError(f"Unknown record_id: {record_id}")
        now = datetime.now(UTC).isoformat()
        updated = OutboxRecord(
            record_id=existing.record_id,
            created_at=existing.created_at,
            updated_at=now,
            kind=existing.kind,
            task_id=existing.task_id,
            correlation_id=existing.correlation_id,
            status="unknown",
            server_ref=None,
            detail=detail,
        )
        self._append_record(updated)
        return updated

    def mark_failed(self, record_id: str, detail: str) -> OutboxRecord:
        """Mark a record as failed (definitive rejection from server)."""
        existing = self._find_latest(record_id)
        if existing is None:
            raise KeyError(f"Unknown record_id: {record_id}")
        now = datetime.now(UTC).isoformat()
        updated = OutboxRecord(
            record_id=existing.record_id,
            created_at=existing.created_at,
            updated_at=now,
            kind=existing.kind,
            task_id=existing.task_id,
            correlation_id=existing.correlation_id,
            status="failed",
            server_ref=None,
            detail=detail,
        )
        self._append_record(updated)
        return updated

    def records(self) -> list[OutboxRecord]:
        """Return the folded state: one entry per record_id, in order."""
        all_lines = self._read_all_lines()
        folded: dict[str, OutboxRecord] = {}
        creation_order: list[str] = []

        for line_record in all_lines:
            record_id = line_record.record_id
            if record_id not in folded:
                creation_order.append(record_id)
            folded[record_id] = line_record

        return [folded[rid] for rid in creation_order]

    def unresolved(self) -> list[OutboxRecord]:
        """Return pending and unknown records, in order."""
        return [record for record in self.records() if record.status in UNRESOLVED_STATUSES]

    def find_by_correlation(self, correlation_id: str) -> OutboxRecord | None:
        """Return the folded record with the given correlation_id, or None."""
        for record in self.records():
            if record.correlation_id == correlation_id:
                return record
        return None

    def _append_record(self, record: OutboxRecord) -> None:
        """Append a record to the JSONL file, creating parent dirs if needed."""
        self.path.parent.mkdir(parents=True, exist_ok=True)
        line_dict = {
            "record_id": record.record_id,
            "created_at": record.created_at,
            "updated_at": record.updated_at,
            "kind": record.kind,
            "task_id": record.task_id,
            "correlation_id": record.correlation_id,
            "status": record.status,
            "server_ref": record.server_ref,
            "detail": record.detail,
        }
        json_line = json.dumps(line_dict, ensure_ascii=False)
        with open(self.path, "a", encoding="utf-8") as f:
            f.write(json_line + "\n")
            f.flush()
            os.fsync(f.fileno())

    def _read_all_lines(self) -> list[OutboxRecord]:
        """Read all valid lines from the JSONL file, skipping corrupt ones."""
        if not self.path.exists():
            return []

        records = []
        with open(self.path, encoding="utf-8") as f:
            for line in f:
                line = line.rstrip("\n")
                if not line:
                    continue
                try:
                    data = json.loads(line)
                    if not isinstance(data, dict) or "record_id" not in data:
                        continue
                    record = OutboxRecord(
                        record_id=data["record_id"],
                        created_at=data["created_at"],
                        updated_at=data["updated_at"],
                        kind=data["kind"],
                        task_id=data.get("task_id"),
                        correlation_id=data.get("correlation_id"),
                        status=data["status"],
                        server_ref=data.get("server_ref"),
                        detail=data.get("detail"),
                    )
                    records.append(record)
                except (json.JSONDecodeError, KeyError, TypeError):
                    continue

        return records

    def _find_latest(self, record_id: str) -> OutboxRecord | None:
        """Find the latest line for a given record_id."""
        all_lines = self._read_all_lines()
        for line_record in reversed(all_lines):
            if line_record.record_id == record_id:
                return line_record
        return None
