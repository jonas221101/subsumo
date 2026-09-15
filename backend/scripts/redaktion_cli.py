#!/usr/bin/env python3
"""CLI fuer die KI-Redaktion. Siehe docs/08-ki-redaktion.md.

Beispiele:
    # Ein einzelnes Thema erzeugen
    python scripts/redaktion_cli.py run --area zivilrecht \\
        --title "Stellvertretung" \\
        --context "BGB AT, §§ 164 ff. BGB, Vollmacht und Vertretungsmacht"

    # Den kuratierten Rueckstand abarbeiten (siehe BACKLOG unten)
    python scripts/redaktion_cli.py backlog --area zivilrecht --limit 3

    # Nur pruefen, welche Inhalte veraltet sind (keine KI noetig)
    python scripts/redaktion_cli.py audit-staleness

    # Lokaler Bruecken-Modus: kein API-Key noetig, der Agent im Gespraech
    # beantwortet Collector- und Reviewer-Prompts selbst ueber Dateien.
    # Siehe docs/08-ki-redaktion.md, Abschnitt "Lokaler Bruecken-Modus".
    python scripts/redaktion_cli.py run --engine bridge --area zivilrecht \\
        --title "Stellvertretung" --bridge-dir /tmp/redaktion-bridge

Mit --engine anthropic (Default) erfordert 'run'/'backlog'
SUBSUMO_LLM_PROVIDER=anthropic und SUBSUMO_LLM_API_KEY - ohne das bricht der
Lauf sofort mit einer klaren Fehlermeldung ab (siehe CollectorError), statt
still leere Inhalte zu erzeugen.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.config import REPO_ROOT, get_settings  # noqa: E402
from app.services.content import STALE_AFTER_MONTHS, load_content  # noqa: E402
from app.services.redaktion.bridge_client import FileBridgeLLMClient  # noqa: E402
from app.services.redaktion.collector import (  # noqa: E402
    CollectorAgent,
    CollectorError,
    TopicRequest,
)
from app.services.redaktion.pipeline import RedaktionPipeline  # noqa: E402
from app.services.redaktion.reviewer import ReviewerAgent, ReviewerError  # noqa: E402

# Kuratierter Rueckstand examensrelevanter Themen, die noch fehlen. Bewusst
# von Hand gepflegt statt vom Modell selbst vorgeschlagen: WAS wichtig ist,
# ist eine redaktionelle/fachliche Entscheidung, nicht die Aufgabe des
# Collectors (der schreibt nur aus, was ihm aufgetragen wird).
BACKLOG: dict[str, list[tuple[str, str]]] = {
    "zivilrecht": [
        ("Stellvertretung", "BGB AT, §§ 164 ff. BGB, Vollmacht, Vertretungsmacht, Missbrauch"),
        ("Leistungsstoerungen: Unmoeglichkeit", "Schuldrecht AT, § 275 BGB, § 283 BGB"),
        ("Deliktsrecht: § 823 Abs. 1 BGB", "Schuldrecht BT, Rechtsgutsverletzung, Kausalitaet"),
        ("Eigentumsherausgabe, § 985 BGB", "Sachenrecht, Vindikationslage, EBV §§ 987 ff. BGB"),
        (
            "Anfechtung von Willenserklaerungen, §§ 119 ff. BGB",
            "BGB AT, Inhalts- und Erklaerungsirrtum, Eigenschaftsirrtum § 119 Abs. 2 BGB, "
            "Anfechtungsfrist § 121 BGB",
        ),
        (
            "AGB-Kontrolle, §§ 305 ff. BGB",
            "Schuldrecht AT, Einbeziehungskontrolle § 305c BGB, Inhaltskontrolle §§ 307 ff. BGB",
        ),
        (
            "Leistungskondiktion, § 812 Abs. 1 S. 1 Alt. 1 BGB",
            "Bereicherungsrecht, Rechtsgrundlosigkeit, Entreicherung § 818 Abs. 3 BGB",
        ),
        (
            "Vertreter ohne Vertretungsmacht, §§ 177 ff. BGB",
            "BGB AT, Genehmigung, Widerrufsrecht des Geschaeftspartners, Haftung § 179 BGB",
        ),
        (
            "Ruecktritt vom gegenseitigen Vertrag, §§ 323, 346 ff. BGB",
            "Schuldrecht AT, Fristsetzung, Ruecktrittsgruende, Rueckgewaehrschuldverhaeltnis",
        ),
        (
            "Culpa in contrahendo, §§ 280 Abs. 1, 311 Abs. 2, 241 Abs. 2 BGB",
            "Schuldrecht AT, vorvertragliches Schuldverhaeltnis, Aufklaerungspflichten",
        ),
    ],
    "strafrecht": [
        ("Diebstahl, § 242 StGB", "Strafrecht BT, Wegnahme, Zueignungsabsicht"),
        (
            "Versuch und Ruecktritt, §§ 22 ff. StGB",
            "Strafrecht AT, Tatentschluss, unmittelbares Ansetzen",
        ),
        (
            "Taeterschaft und Teilnahme, §§ 25 ff. StGB",
            "Strafrecht AT, Abgrenzung Mittaeterschaft/Beihilfe",
        ),
    ],
    "oeffentliches-recht": [
        (
            "Die Anfechtungsklage, § 42 Abs. 1 Var. 1 VwGO",
            "VerwR AT, Zulaessigkeit, Klagebefugnis",
        ),
        ("Art. 12 Abs. 1 GG: Berufsfreiheit", "Grundrechte, Drei-Stufen-Theorie"),
        (
            "Der Verwaltungsakt, § 35 VwVfG",
            "VerwR AT, Begriffsmerkmale, Nichtigkeit, Rechtswidrigkeit",
        ),
        (
            "Die Verpflichtungsklage, § 42 Abs. 1 Var. 2 VwGO",
            "VerwR AT, Versagungsgegenklage, Untaetigkeitsklage § 75 VwGO",
        ),
        (
            "Vorlaeufiger Rechtsschutz, §§ 80, 80a VwGO",
            "VerwR AT, aufschiebende Wirkung, Anordnung/Wiederherstellung",
        ),
        (
            "Art. 3 Abs. 1 GG: Allgemeiner Gleichheitssatz",
            "Grundrechte, neue Formel, Willkuerverbot",
        ),
        (
            "Art. 14 GG: Eigentumsgarantie",
            "Grundrechte, Inhalts- und Schrankenbestimmung, Enteignung",
        ),
        (
            "Ermessen und Beurteilungsspielraum, § 40 VwVfG",
            "VerwR AT, Ermessensfehler, Ermessensreduzierung auf Null",
        ),
    ],
}


def _build_pipeline(args: argparse.Namespace) -> RedaktionPipeline | None:
    """Baut die Pipeline fuer das gewaehlte Engine - oder gibt None zurueck
    und meldet den Grund, wenn die Voraussetzungen fehlen."""
    if args.engine == "bridge":
        if not args.bridge_dir:
            print("--bridge-dir ist im Bruecken-Modus erforderlich.")
            return None
        client = FileBridgeLLMClient(args.bridge_dir)
        print(
            f"Bruecken-Modus aktiv: Anfragen erscheinen in {args.bridge_dir} als "
            "request_NNN.txt. Antworten dort als response_NNN.txt + "
            "response_NNN.ready hinterlegen."
        )
        return RedaktionPipeline(
            content_dir=args.content_dir,
            collector=CollectorAgent(client=client),
            reviewer=ReviewerAgent(client=client),
        )

    settings = get_settings()
    if settings.llm_provider != "anthropic" or not settings.llm_api_key:
        print(
            "SUBSUMO_LLM_PROVIDER=anthropic und SUBSUMO_LLM_API_KEY sind erforderlich "
            "(oder --engine bridge fuer den Offline-Testmodus ohne API-Key)."
        )
        return None
    return RedaktionPipeline(content_dir=args.content_dir)


def cmd_run(args: argparse.Namespace) -> int:
    pipeline = _build_pipeline(args)
    if pipeline is None:
        return 1
    request = TopicRequest(area=args.area, working_title=args.title, context=args.context or "")
    return _run_one(pipeline, request)


def cmd_backlog(args: argparse.Namespace) -> int:
    pipeline = _build_pipeline(args)
    if pipeline is None:
        return 1
    themen = BACKLOG.get(args.area, [])[: args.limit]
    if not themen:
        print(f"Kein Rueckstand fuer '{args.area}' hinterlegt.")
        return 0

    exit_code = 0
    for title, context in themen:
        print(f"\n=== {title} ===")
        request = TopicRequest(area=args.area, working_title=title, context=context)
        exit_code |= _run_one(pipeline, request)
    return exit_code


def _run_one(pipeline: RedaktionPipeline, request: TopicRequest) -> int:
    try:
        result = pipeline.run(request)
    except (CollectorError, ReviewerError) as exc:
        print(f"ABGEBROCHEN: {exc}")
        return 1
    except FileExistsError as exc:
        print(f"UEBERSPRUNGEN: {exc}")
        return 0

    for zeile in result.history:
        print(f"  {zeile}")
    if result.accepted:
        print(f"FREIGEGEBEN nach {result.rounds} Runde(n): {result.path}")
        return 0
    print(f"ABGELEHNT nach {result.rounds} Runde(n) - keine Datei geschrieben.")
    return 1


def cmd_audit_staleness(args: argparse.Namespace) -> int:
    """Rein deterministisch - braucht keinen LLM-Key.

    Meldet Inhalte, die die Alters-Warnschwelle aus content.py ueberschreiten,
    zusammengefasst nach Datei statt als Einzelwarnungen (Challenge 10).
    """
    bundle = load_content(args.content_dir)
    if bundle.errors:
        print(f"{len(bundle.errors)} Formatfehler - erst 'validate_content.py' beheben.")
        return 1
    if not bundle.warnings:
        print(f"Kein Inhalt aelter als {STALE_AFTER_MONTHS} Monate.")
        return 0
    print(f"{len(bundle.warnings)} Inhalt(e) zur redaktionellen Pruefung faellig:")
    for warnung in bundle.warnings:
        print(f"  - {warnung}")
    return 1


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--content-dir", type=Path, default=REPO_ROOT / "content")
    sub = parser.add_subparsers(dest="command", required=True)

    def add_engine_args(p: argparse.ArgumentParser) -> None:
        p.add_argument(
            "--engine",
            choices=["anthropic", "bridge"],
            default="anthropic",
            help="anthropic: echter API-Aufruf (Key erforderlich). "
            "bridge: lokaler Offline-Testmodus, der Agent im Gespraech "
            "antwortet ueber Dateien (siehe docs/08-ki-redaktion.md).",
        )
        p.add_argument(
            "--bridge-dir", type=Path, default=None,
            help="Nur mit --engine bridge: Verzeichnis fuer request_*/response_*-Dateien.",
        )

    p_run = sub.add_parser("run", help="Ein einzelnes Thema erzeugen")
    p_run.add_argument("--area", required=True, choices=sorted(BACKLOG.keys()))
    p_run.add_argument("--title", required=True)
    p_run.add_argument("--context", default="")
    add_engine_args(p_run)
    p_run.set_defaults(func=cmd_run)

    p_backlog = sub.add_parser("backlog", help="Kuratierten Rueckstand abarbeiten")
    p_backlog.add_argument("--area", required=True, choices=sorted(BACKLOG.keys()))
    p_backlog.add_argument("--limit", type=int, default=3)
    add_engine_args(p_backlog)
    p_backlog.set_defaults(func=cmd_backlog)

    p_audit = sub.add_parser("audit-staleness", help="Veraltete Inhalte melden (ohne KI)")
    p_audit.set_defaults(func=cmd_audit_staleness)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
