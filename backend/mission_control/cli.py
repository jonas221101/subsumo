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

from mission_control.client import (
    PaperclipClient,
    PaperclipConfig,
    PaperclipConflictError,
    PaperclipError,
    PaperclipHTTPError,
    PaperclipNetworkError,
)
from mission_control.messages import KINDS, AgentMessage
from mission_control.outbox import Outbox
from mission_control.verification import VerificationError, check_commit


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


def _default_state_dir() -> Path:
    """Journal location; the env var lets operators keep it outside the checkout.

    Read per invocation rather than at import time, so a caller (or a test) can
    point a single run at its own directory without touching a real journal.
    """
    return Path(os.environ.get("MISSION_CONTROL_STATE_DIR") or ".mission-control")


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
    create.add_argument(
        "--state-dir", type=Path, default=_default_state_dir(),
        help="Verzeichnis fuer den Outbox-Journal (Standard: .mission-control)"
    )
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
    send.add_argument(
        "--state-dir", type=Path, default=_default_state_dir(),
        help="Verzeichnis fuer den Outbox-Journal (Standard: .mission-control)"
    )
    send.add_argument("--force", action="store_true",
                      help="Umgehe Deduplication und sende erneut")
    send.add_argument("--dry-run", action="store_true", help="Nur Vorschau, keine API-Aufrufe")

    handoff = commands.add_parser(
        "request-review", help="Commit und Aufgabe an Reviewer uebergeben",
    )
    handoff.add_argument("task")
    handoff.add_argument("--to", type=_uuid, required=True, dest="recipient")
    handoff.add_argument("--commit", type=_commit, required=True)
    handoff.add_argument("--body-file", type=Path, required=True, help="Pruefnachweise als UTF-8")
    handoff.add_argument(
        "--repo", type=Path, default=Path("."),
        help="Git-Repository (Standard: aktuell)",
    )
    handoff.add_argument("--allow-unpushed", action="store_true",
                         help="Nicht gepushte Commits mit Warnung akzeptieren")
    handoff.add_argument("--no-verify-commit", action="store_true",
                         help="Commit-Pruefung ueberspringen (ausserhalb eines Git-Checkouts)")
    handoff.add_argument(
        "--state-dir", type=Path, default=_default_state_dir(),
        help="Verzeichnis fuer den Outbox-Journal (Standard: .mission-control)"
    )
    handoff.add_argument("--force", action="store_true",
                         help="Umgehe Deduplication und sende erneut")
    handoff.add_argument("--dry-run", action="store_true", help="Nur Vorschau, keine API-Aufrufe")

    reconcile = commands.add_parser(
        "reconcile", help="Unaufgeloeste Outbox-Eintraege gegen Server abgleichen"
    )
    reconcile.add_argument("task", nargs="?", help="Optional: nur diese Aufgabe ueberpruefen")
    reconcile.add_argument(
        "--state-dir", type=Path, default=_default_state_dir(),
        help="Verzeichnis fuer den Outbox-Journal (Standard: .mission-control)"
    )
    reconcile.add_argument("--dry-run", action="store_true",
                           help="Nur Vorschau, keine Schreibzugriffe")
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


def _verify_commit(args: argparse.Namespace) -> None:
    """Refuse a handoff whose commit the reviewer could not actually fetch."""
    if args.command != "request-review":
        return

    if args.no_verify_commit:
        print("Warnung: Commit wurde nicht geprueft", file=sys.stderr)
        return

    check_result = check_commit(args.commit, args.repo)

    if not check_result.exists:
        raise ValueError(f"Commit {args.commit} existiert nicht im Repository")

    if not check_result.pushed:
        if args.allow_unpushed:
            print(
                f"Warnung: Commit {args.commit} wurde noch nicht gepusht; "
                "Reviewer kann diesen moeglicherweise nicht abrufen",
                file=sys.stderr,
            )
        else:
            raise ValueError(
                f"Commit {args.commit} wurde noch nicht gepusht. "
                "Reviewer kann diesen nicht abrufen. "
                "Benutze --allow-unpushed zum Erzwingen."
            )


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


_PAGE_SIZE = 200
_MAX_PAGES = 50


def _comment_page(data: Any) -> list[dict[str, Any]]:
    """Normalise one page of comments, refusing shapes we cannot read.

    An unreadable shape must never look like "no match": that would report a
    delivered message as still missing and invite a duplicate send.
    """
    if isinstance(data, list):
        entries = data
    elif isinstance(data, dict):
        for key in ("comments", "items", "data", "results"):
            if isinstance(data.get(key), list):
                entries = data[key]
                break
        else:
            raise ValueError("Thread-Antwort hat eine unbekannte Form")
    else:
        raise ValueError("Thread-Antwort hat eine unbekannte Form")
    return [entry for entry in entries if isinstance(entry, dict)]


def _find_comment(client: PaperclipClient, task_id: str, needle: str) -> dict[str, Any] | None:
    """Search the whole thread page by page for the correlation id.

    Reads only; a partial read would be worse than no read, so it pages until
    the thread is exhausted instead of judging from the first page alone.
    """
    after: str | None = None
    for _ in range(_MAX_PAGES):
        page = _comment_page(client.list_comments(task_id, after=after, limit=_PAGE_SIZE))
        if not page:
            return None
        for comment in page:
            if needle in str(comment.get("body", "")):
                return comment
        last_id = page[-1].get("id")
        if len(page) < _PAGE_SIZE or not last_id or last_id == after:
            return None
        after = str(last_id)
    raise ValueError("Thread ist laenger als die Abgleichsgrenze; bitte am Board pruefen")


def _reconcile(args: argparse.Namespace, client: PaperclipClient) -> dict[str, Any]:
    """Match unresolved journal records against server state. Read-only."""
    outbox = Outbox(args.state_dir / "outbox.jsonl")
    unresolved = outbox.unresolved()
    if args.task:
        unresolved = [record for record in unresolved if record.task_id == args.task]

    newly_confirmed = 0
    open_records: list[dict[str, Any]] = []

    for record in unresolved:
        reason = "Ohne Korrelations-ID nicht maschinell zuzuordnen; am Board vergleichen"
        if record.correlation_id and record.task_id:
            try:
                comment = _find_comment(client, record.task_id, record.correlation_id)
            except (PaperclipError, ValueError) as exc:
                reason = f"Abgleich nicht moeglich: {exc}"
            else:
                if comment is not None:
                    if not args.dry_run:
                        outbox.mark_confirmed(record.record_id, str(comment.get("id", "")))
                    newly_confirmed += 1
                    continue
                reason = "Im Thread nicht gefunden; vermutlich nie angekommen"
        open_records.append(
            {
                "record_id": record.record_id,
                "kind": record.kind,
                "task_id": record.task_id,
                "detail": record.detail,
                "grund": reason,
            }
        )

    summary: dict[str, Any] = {
        "checked": len(unresolved),
        "newly_confirmed": newly_confirmed,
        "still_unresolved": len(open_records),
        "dry_run": args.dry_run,
    }
    if open_records:
        summary["unresolved_records"] = open_records
    return summary


def execute(args: argparse.Namespace, client: PaperclipClient) -> Any:
    """One bounded action. The Paperclip server enforces permissions and run locks."""
    if args.command == "reconcile":
        return _reconcile(args, client)

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
        outbox = Outbox(args.state_dir / "outbox.jsonl")
        record = outbox.record(
            kind="issue", task_id=None, correlation_id=None, detail=args.title
        )
        try:
            result = client.create_issue(**payload)
            outbox.mark_confirmed(record.record_id, result.get("id", ""))
            return result
        except PaperclipNetworkError as exc:
            outbox.mark_unknown(record.record_id, "Netzwerkfehler bei Aufgabenerzeugung")
            raise PaperclipError(
                f"{exc}. Vor erneutem Senden Reconcile ausfuehren."
            ) from exc
        except (PaperclipConflictError, PaperclipHTTPError):
            outbox.mark_failed(record.record_id, "Ablehnung vom Server")
            raise

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

    # Read and validate evidence before consulting Git.  Bad local input should
    # not be obscured by an unrelated repository error (and must never trigger
    # a server request).
    message = _message(args, client.config)
    _verify_commit(args)
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
    outbox = Outbox(args.state_dir / "outbox.jsonl")
    if args.command == "request-review":
        if task.get("assigneeAgentId") != client.config.agent_id:
            raise ValueError("Nur eigene Aufgaben an den Reviewer uebergeben")
        if task.get("status") != "in_progress":
            raise ValueError("Review-Uebergabe braucht eine Aufgabe in Bearbeitung")
        if not args.force:
            unresolved = [
                r for r in outbox.unresolved() if r.task_id == args.task
            ]
            if unresolved:
                record_ids = ", ".join(r.record_id for r in unresolved)
                raise ValueError(
                    f"Unaufgeloeste Outbox-Eintrag(e) fuer diese Aufgabe: {record_ids}. "
                    "Reconcile ausfuehren oder --force zum Erzwingen nutzen."
                )
        interaction = client.create_review_interaction(
            args.task, addressee_agent_id=args.recipient,
            prompt=f"Bitte Review fuer {args.task} (Commit {args.commit}) durchfuehren.",
        )
        record = outbox.record(
            kind="issue_update", task_id=args.task,
            correlation_id=message.message_id, detail=args.commit
        )
        try:
            result = client.update_issue(
                args.task, status="in_review", assignee_agent_id=args.recipient, comment=body,
                review_interaction_id=interaction.get("id", ""),
            )
            outbox.mark_confirmed(record.record_id, result.get("id", ""))
            return result
        except PaperclipNetworkError as exc:
            outbox.mark_unknown(record.record_id, "Netzwerkfehler bei Update")
            raise PaperclipError(
                f"{exc}; Nachrichten-ID {message.message_id}. "
                "Vor erneutem Senden Reconcile ausfuehren."
            ) from exc
        except (PaperclipConflictError, PaperclipHTTPError) as exc:
            outbox.mark_failed(record.record_id, "Ablehnung vom Server")
            raise PaperclipError(
                f"{exc}; Nachrichten-ID {message.message_id}. "
                "Vor erneutem Senden Aufgabenstatus und Thread abgleichen."
            ) from exc
    if not args.force:
        unresolved = [r for r in outbox.unresolved() if r.task_id == args.task]
        if unresolved:
            record_ids = ", ".join(r.record_id for r in unresolved)
            raise ValueError(
                f"Unaufgeloeste Outbox-Eintrag(e) fuer diese Aufgabe: {record_ids}. "
                "Reconcile ausfuehren oder --force zum Erzwingen nutzen."
            )
    record = outbox.record(
        kind="comment", task_id=args.task,
        correlation_id=message.message_id, detail=f"Nachricht an {args.recipient}"
    )
    try:
        result = client.add_comment(args.task, body)
        outbox.mark_confirmed(record.record_id, result.get("id", ""))
        return result
    except PaperclipNetworkError as exc:
        outbox.mark_unknown(record.record_id, "Netzwerkfehler beim Kommentar")
        raise PaperclipError(
            f"{exc}; Nachrichten-ID {message.message_id}. "
            "Vor erneutem Senden Reconcile ausfuehren."
        ) from exc
    except (PaperclipConflictError, PaperclipHTTPError) as exc:
        outbox.mark_failed(record.record_id, "Ablehnung vom Server")
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
    except (PaperclipError, VerificationError, ValueError, OSError) as exc:
        # Network errors are deliberately concise and never include tokens or server bodies.
        print(f"Mission Control: {exc}", file=sys.stderr)
        return 1
