"""Versioned agent messages carried by Paperclip's persistent issue comments."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from datetime import UTC, datetime
from typing import Literal
from uuid import UUID, uuid4

MessageKind = Literal["question", "answer", "handoff", "finding", "decision", "blocker"]
KINDS = ("question", "answer", "handoff", "finding", "decision", "blocker")


@dataclass(frozen=True)
class AgentMessage:
    """An auditable request, never an authority grant or workflow approval.

    Sender identity must be checked against /agents/me before posting. Paperclip
    supplies the authoritative comment author and run binding on the server.
    """

    task_id: str
    sender_id: str
    recipient_id: str
    run_id: str
    kind: MessageKind
    content: str
    reply_to: str | None = None
    message_id: str = field(default_factory=lambda: str(uuid4()))

    def __post_init__(self) -> None:
        if not isinstance(self.task_id, str) or not re.fullmatch(r"[A-Za-z0-9_-]+", self.task_id):
            raise ValueError("Aufgaben-ID muss ein sicherer, nicht leerer Bezeichner sein")
        if not isinstance(self.content, str) or not self.content.strip():
            raise ValueError("Aufgabe und Nachricht duerfen nicht leer sein")
        if not isinstance(self.kind, str) or self.kind not in KINDS:
            raise ValueError("Unbekannter Nachrichtentyp")
        if len(self.content) > 12_000:
            raise ValueError("Nachricht ist zu lang (maximal 12000 Zeichen)")
        uuids: dict[str, UUID] = {}
        for name in ("sender_id", "recipient_id", "run_id", "message_id"):
            value = getattr(self, name)
            if not isinstance(value, str):
                raise ValueError(f"{name} muss eine UUID sein")
            try:
                uuids[name] = UUID(value)
            except (ValueError, AttributeError, TypeError) as exc:
                raise ValueError(f"{name} muss eine UUID sein") from exc
            object.__setattr__(self, name, str(uuids[name]))
        if self.reply_to is not None:
            if not isinstance(self.reply_to, str) or not self.reply_to.strip():
                raise ValueError("reply_to muss eine UUID sein")
            try:
                reply_uuid = UUID(self.reply_to)
            except (ValueError, AttributeError, TypeError) as exc:
                raise ValueError("reply_to muss eine UUID sein") from exc
            object.__setattr__(self, "reply_to", str(reply_uuid))
        if uuids["sender_id"] == uuids["recipient_id"]:
            raise ValueError("Keine Nachrichten an denselben Agenten senden")
        if self.kind == "answer" and not self.reply_to:
            raise ValueError("Eine Antwort braucht die ID des beantworteten Kommentars")

    def to_markdown(self) -> str:
        """Only the routed recipient is mentioned; payload cannot wake other agents.

        JSON escapes also prevent embedded Markdown fences from ending the payload.
        The comment UUID from Paperclip is used as reply_to on subsequent messages.
        message_id is a correlation marker, NOT a server-side idempotency guarantee.
        """
        payload = {
            "schema": "subsumo.message.v1",
            "message_id": self.message_id,
            "task_id": self.task_id,
            "sender_id": self.sender_id,
            "recipient_id": self.recipient_id,
            "run_id": self.run_id,
            "kind": self.kind,
            "reply_to_comment_id": self.reply_to,
            "created_at": datetime.now(UTC).isoformat(),
            "content": self.content,
        }
        encoded = json.dumps(payload, ensure_ascii=False, indent=2)
        encoded = encoded.replace("@", "\\u0040").replace("`", "\\u0060")
        return f"[@Agent](agent://{self.recipient_id}) · {self.kind}\n\n```json\n{encoded}\n```"
