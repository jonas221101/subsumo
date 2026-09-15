#!/usr/bin/env python3
"""Kalibrierungs-Harness fuer den Evaluator (SUB-69/SUB-70).

Misst, wie weit die Bewertung des bestehenden Evaluators (get_evaluator() in
app/services/evaluator.py) von einer durch einen Dozenten vergebenen
Punktzahl abweicht - ausgedrueckt als mittlerer absoluter Fehler (MAE) ueber
eine Menge von Referenzfaellen. Reine Mess-Infrastruktur: aendert weder die
Bewertungslogik noch die Prompts des Evaluators.

Beispiel:
    python scripts/kalibrierung_cli.py run --input tests/fixtures/kalibrierung_beispiel.yaml

Referenzdatei-Format (YAML):
    faelle:
      - slug: "fall-1"                  # optional, nur fuer die Ausgabe
        gutachten: |                    # Volltext des zu bewertenden Gutachtens
          A koennte gegen B einen Anspruch ...
        expectation:                    # gleiches Format wie 'expectation' in
          pruefpunkte:                  # content.py/parse_expectation() - siehe dort
            - id: "p1"
              label: "Anspruchsgrundlage § 433 Abs. 2 BGB"
              weight: 2.0
              required: true
              norms: ["§ 433 Abs. 2 BGB"]
        punkte: 9.5                     # von einem Dozenten vergebene Punktzahl (0-18, JAP-Skala)

Laeuft ohne konfigurierten LLM-Provider (SUBSUMO_LLM_PROVIDER/SUBSUMO_LLM_API_KEY
nicht gesetzt) automatisch gegen den heuristischen Fallback (HeuristicEvaluator,
siehe get_evaluator() in evaluator.py) - ohne externe Abhaengigkeit, damit die
Harness in CI lauffaehig ist. Ein Lauf gegen den echten LLM-Evaluator ist mit
gesetztem Provider moeglich, aber nicht Voraussetzung.
"""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.services.evaluator import Evaluator, get_evaluator  # noqa: E402
from app.services.gutachten import analyze  # noqa: E402

JAP_MIN, JAP_MAX = 0.0, 18.0


@dataclass
class CalibrationCase:
    """Ein auswertbarer Referenzfall: Gutachtentext, Erwartungshorizont und
    die vom Dozenten tatsaechlich vergebene Punktzahl."""

    slug: str
    gutachten: str
    expectation: dict[str, Any]
    punkte: float


@dataclass
class CalibrationResult:
    slug: str
    predicted: float
    actual: float

    @property
    def diff(self) -> float:
        return abs(self.predicted - self.actual)


def load_cases(path: Path) -> tuple[list[CalibrationCase], list[str]]:
    """Liest die Referenzfaelle aus der YAML-Datei unter ``path``.

    Gibt (auswertbare Faelle, Fehlermeldungen) zurueck. Ein einzelner Fall mit
    fehlendem Erwartungshorizont, fehlendem Gutachtentext oder fehlender/
    ungueltiger Punktzahl wird als Fehler gemeldet statt den ganzen Lauf
    abzubrechen - so bleiben die uebrigen Faelle auswertbar.
    """
    if not path.exists():
        return [], [f"Referenzdatei nicht gefunden: {path}"]

    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except yaml.YAMLError as exc:
        return [], [f"{path.name}: YAML nicht lesbar - {exc}"]

    rohfaelle = data.get("faelle") if isinstance(data, dict) else None
    if not rohfaelle:
        return [], [f"{path.name}: kein Fall unter 'faelle' hinterlegt"]

    errors: list[str] = []
    cases: list[CalibrationCase] = []
    for i, roh in enumerate(rohfaelle):
        slug = str((roh or {}).get("slug") or f"fall_{i}")
        where = f"{path.name} faelle[{i}] ('{slug}')"

        gutachten = (roh or {}).get("gutachten")
        if not isinstance(gutachten, str) or not gutachten.strip():
            errors.append(f"{where}: 'gutachten' fehlt oder ist leer")
            continue

        expectation = (roh or {}).get("expectation")
        pruefpunkte = (
            (expectation or {}).get("pruefpunkte") if isinstance(expectation, dict) else None
        )
        if not pruefpunkte:
            errors.append(f"{where}: 'expectation.pruefpunkte' fehlt oder ist leer")
            continue

        punkte = (roh or {}).get("punkte")
        if not isinstance(punkte, int | float) or isinstance(punkte, bool):
            errors.append(f"{where}: 'punkte' fehlt oder ist keine Zahl")
            continue
        if not (JAP_MIN <= float(punkte) <= JAP_MAX):
            errors.append(f"{where}: 'punkte' liegt ausserhalb der JAP-Skala [0, 18]")
            continue

        cases.append(
            CalibrationCase(
                slug=slug, gutachten=gutachten, expectation=expectation, punkte=float(punkte)
            )
        )

    return cases, errors


def run_calibration(
    cases: list[CalibrationCase], evaluator: Evaluator | None = None
) -> tuple[list[CalibrationResult], list[str]]:
    """Ruft den bestehenden Evaluator je Fall auf und vergleicht mit der
    Dozentenpunktzahl. Ein Evaluator-Fehler markiert nur diesen einen Fall als
    nicht auswertbar, statt den ganzen Lauf abzubrechen."""
    evaluator = evaluator or get_evaluator()
    results: list[CalibrationResult] = []
    errors: list[str] = []
    for case in cases:
        try:
            evaluation = evaluator.evaluate(
                text=case.gutachten,
                expectation=case.expectation,
                structure=analyze(case.gutachten),
            )
        except Exception as exc:  # noqa: BLE001 - Fall wird als Fehler gemeldet, nicht der Lauf
            errors.append(f"Fall '{case.slug}': Evaluator-Fehler - {exc}")
            continue
        results.append(
            CalibrationResult(slug=case.slug, predicted=evaluation.points, actual=case.punkte)
        )
    return results, errors


def mae(results: list[CalibrationResult]) -> float:
    """Mittlerer absoluter Fehler ueber alle uebergebenen Ergebnisse."""
    return sum(r.diff for r in results) / len(results)


def cmd_run(args: argparse.Namespace) -> int:
    cases, load_errors = load_cases(args.input)
    evaluator = get_evaluator()
    eval_results, eval_errors = run_calibration(cases, evaluator) if cases else ([], [])
    errors = load_errors + eval_errors

    print(f"Engine: {evaluator.name}")
    for r in eval_results:
        print(
            f"  {r.slug}: vorhergesagt={r.predicted:.1f}  "
            f"dozent={r.actual:.1f}  diff={r.diff:.1f}"
        )
    for e in errors:
        print(f"FEHLER: {e}")

    if not eval_results:
        print("Keine auswertbaren Faelle - MAE nicht berechenbar.")
        return 1

    print(f"\nMAE ueber {len(eval_results)} Fall/Faelle: {mae(eval_results):.3f}")
    return 1 if errors else 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p_run = sub.add_parser("run", help="MAE ueber eine Referenzdatei berechnen")
    p_run.add_argument("--input", type=Path, required=True, help="Pfad zur Referenzdatei (YAML)")
    p_run.set_defaults(func=cmd_run)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
