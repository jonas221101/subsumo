"""Internal Paperclip CLI. No routes or credentials enter the learner-facing API."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path
from typing import Any
from uuid import UUID

from mission_control.client import PaperclipClient, PaperclipConfig, PaperclipError
from mission_control.messages import KINDS, AgentMessage


def _text(value: str) -> str:
    if not value.strip():
        raise argparse.ArgumentTypeError("Darf nicht leer sein")
    return value.strip()


def _uuid(value: str) -> str:
    try:
        return str(UUID(value))
    except ValueError as exc:
        raise argparse.ArgumentTypeError("Eine vollstaendige UUID wird benoetigt") from exc


def _commit(value: str) -> str:
    if not re.fullmatch(r"[a-fA-F0-9]{40}", value):
        raise argparse.ArgumentTypeError("Vollstaendiger Git-Commit-SHA (40 Zeichen) fehlt")
    return value.lower()


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(
        prog="python -m mission_control",
        description="Subsumo: Aufgaben und Agentenkommunikation ueber Paperclip",
    )
    commands = result.add_subparsers(dest="command", required=True)
    commands.add_parser("doctor", help="Konfiguration und authentifizierte Identitaet pruefen")
    tasks = commands.add_parser("tasks", help="Aufgaben lesen")
    tasks.add_argument("--project")
    tasks.add_argument("--status")
    tasks.add_argument("--mine", action="store_true")

    create = commands.add_parser("create", help="Aufgabe mit Abnahmekriterium erstellen")
    create.add_argument("--title", required=True, type=_text)
    create.add_argument("--criteria", required=True, type=_text)
    create.add_argument("--project")
    create.add_argument("--assignee", type=_uuid)
    create.add_argument("--parent")
    create.add_argument("--ready", action="store_true", help="Status todo statt backlog")
    create.add_argument("--dry-run", action="store_true", help="Nur Vorschau, keine API-Aufrufe")

    thread = commands.add_parser("thread", help="Gespeicherten Aufgabenthread lesen")
    thread.add_argument("task")
    thread.add_argument("--after", help="Kommentar-ID fuer die naechste Seite")
    thread.add_argument("--limit", type=int, default=100)

    claim = commands.add_parser("claim", help="Aufgabe atomar fuer den aktuellen Agenten annehmen")
    claim.add_argument("task")
    claim.add_argument("--review", action="store_true", help="in_review statt todo annehmen")
    claim.add_argument("--resume", action="store_true", help="Verwaisten eigenen Lauf uebernehmen")

    send = commands.add_parser("send", help="Gezielte Agentennachricht im Aufgabenthread senden")
    send.add_argument("task")
    send.add_argument("--to", type=_uuid, required=True, dest="recipient")
    send.add_argument("--kind", choices=KINDS, default="question")
    send.add_argument("--body-file", type=Path, required=True, help="Nachricht als UTF-8-Datei")
    send.add_argument("--reply-to", type=_uuid, help="ID des beantworteten Paperclip-Kommentars")
    send.add_argument("--dry-run", action="store_true", help="Nur Vorschau, keine API-Aufrufe")

    handoff = commands.add_parser(
        "request-review", help="Commit und Aufgabe an Reviewer uebergeben",
    )
    handoff.add_argument("task")
    handoff.add_argument("--to", type=_uuid, required=True, dest="recipient")
    handoff.add_argument("--commit", type=_commit, required=True)
    handoff.add_argument("--body-file", type=Path, required=True, help="Pruefnachweise als UTF-8")
    handoff.add_argument("--dry-run", action="store_true", help="Nur Vorschau, keine API-Aufrufe")
    return result


def _body(path: Path) -> str:
    if path.stat().st_size > 48_000:
        raise ValueError("Nachrichtendatei ist zu gross")
    value = path.read_text(encoding="utf-8-sig")
    if not value.strip():
        raise ValueError("Nachrichtendatei darf nicht leer sein")
    return value


def _identity(client: PaperclipClient) -> dict[str, Any]:
    config = client.config
    if not config.agent_id or not config.run_id:
        raise ValueError("Agentenaktion braucht PAPERCLIP_AGENT_ID und PAPERCLIP_RUN_ID")
    identity = client.get_me()
    if identity.get("id") != config.agent_id or identity.get("companyId") != config.company_id:
        raise ValueError("Konfigurierte Agentenidentitaet stimmt nicht mit dem API-Token ueberein")
    if identity.get("status") in {"paused", "terminated", "pending_approval"}:
        raise ValueError("Dieser Agent ist nicht fuer einen aktiven Lauf freigegeben")
    return identity


def _recipient(client: PaperclipClient, agent_id: str) -> None:
    agent = client.get_agent(agent_id)
    if agent.get("id") != agent_id or agent.get("companyId") != client.config.company_id:
        raise ValueError("Empfaenger gehoert nicht zur konfigurierten Firma")
    if agent.get("status") in {"paused", "terminated", "pending_approval"}:
        raise ValueError("Empfaenger ist nicht aktivierbar; Nachricht noch nicht gesendet")


def _message(args: argparse.Namespace, config: PaperclipConfig) -> AgentMessage:
    if not config.agent_id or not config.run_id:
        raise ValueError("Agentenaktion braucht PAPERCLIP_AGENT_ID und PAPERCLIP_RUN_ID")
    body = _body(args.body_file)
    if args.command == "request-review":
        body = f"Review des Commits {args.commit}\n\n{body}"
    return AgentMessage(
        task_id=args.task, sender_id=config.agent_id, recipient_id=args.recipient,
        run_id=config.run_id, kind="handoff" if args.command == "request-review" else args.kind,
        content=body, reply_to=getattr(args, "reply_to", None),
    )


def execute(args: argparse.Namespace, client: PaperclipClient) -> Any:
    """One bounded action. The Paperclip server enforces permissions and run locks."""
    if args.command == "doctor":
        if client.config.agent_id:
            identity = _identity(client)
            return {"ok": True, "agent_id": identity["id"], "company_id": identity["companyId"]}
        client.list_issues()
        return {"ok": True, "mode": "operator", "company_id": client.config.company_id}

    if args.command == "tasks":
        if args.mine:
            _identity(client)
        return client.list_issues(
            project_id=args.project, status=args.status,
            assignee_agent_id=client.config.agent_id if args.mine else None,
        )

    if args.command == "create":
        description = f"## Abnahme\n\n{args.criteria}"
        payload = {
            "title": args.title, "description": description,
            "status": "todo" if args.ready else "backlog", "project_id": args.project,
            "assignee_agent_id": args.assignee, "parent_id": args.parent,
        }
        if args.dry_run:
            return {"dry_run": True, "operation": "create_issue", "payload": payload}
        if client.config.agent_id:
            _identity(client)
        if args.parent:
            client.get_issue(args.parent)
        if args.assignee:
            _recipient(client, args.assignee)
        return client.create_issue(**payload)

    if args.command == "thread":
        client.get_issue(args.task)
        return client.list_comments(args.task, after=args.after, limit=args.limit)

    if args.command == "claim":
        _identity(client)
        task = client.get_issue(args.task)
        if task.get("assigneeAgentId") != client.config.agent_id:
            raise ValueError("Nur dem eigenen Agenten zugewiesene Aufgaben annehmen")
        expected = ["in_review" if args.review else "todo"]
        if args.resume:
            expected.append("in_progress")
        return client.checkout(args.task, expected_statuses=expected)

    message = _message(args, client.config)
    if args.dry_run:
        return {"dry_run": True, "task": args.task, "body": message.to_markdown()}
    _identity(client)
    task = client.get_issue(args.task)
    _recipient(client, args.recipient)
    if task.get("status") in {"done", "cancelled"}:
        raise ValueError("Abgeschlossene Aufgabe wird nicht durch Nachrichten reaktiviert")
    if message.reply_to:
        parent = client.get_comment(args.task, message.reply_to)
        if parent.get("authorAgentId") != args.recipient:
            raise ValueError("Antwortempfaenger muss der Autor des referenzierten Kommentars sein")
    body = message.to_markdown()
    if args.command == "request-review":
        if task.get("assigneeAgentId") != client.config.agent_id:
            raise ValueError("Nur eigene Aufgaben an den Reviewer uebergeben")
        if task.get("status") != "in_progress":
            raise ValueError("Review-Uebergabe braucht eine Aufgabe in Bearbeitung")
        # One server transaction, not reassignment followed by a separate comment.
        try:
            return client.update_issue(
                args.task, status="in_review", assignee_agent_id=args.recipient, comment=body,
            )
        except PaperclipError as exc:
            raise PaperclipError(
                f"{exc}; Nachrichten-ID {message.message_id}. "
                "Vor erneutem Senden Aufgabenstatus und Thread abgleichen."
            ) from exc
    try:
        return client.add_comment(args.task, body)
    except PaperclipError as exc:
        raise PaperclipError(
            f"{exc}; Nachrichten-ID {message.message_id}. "
            "Vor erneutem Senden Thread abgleichen."
        ) from exc


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    try:
        if getattr(args, "dry_run", False):
            # Offline previews never load a real token or contact a server.
            config = PaperclipConfig(
                "http://localhost:3100", "preview-only", "preview",
                os.environ.get("PAPERCLIP_AGENT_ID"), os.environ.get("PAPERCLIP_RUN_ID"),
            )
        else:
            config = PaperclipConfig.from_env()
        with PaperclipClient(config) as client:
            result = execute(args, client)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    except (PaperclipError, ValueError, OSError) as exc:
        # Network errors are deliberately concise and never include tokens or server bodies.
        print(f"Mission Control: {exc}", file=sys.stderr)
        return 1
