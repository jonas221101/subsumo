"""Tests der Kalibrierungs-Harness fuer den Evaluator (SUB-69/SUB-70).

tests/fixtures/kalibrierung_beispiel.yaml enthaelt vier synthetische Faelle
mit den Gutachtentexten aus test_evaluator.py (dort deterministisch gegen die
Heuristik verifiziert: vollstaendig -> 11.0, teilweise -> 10.5,
ohne_kernpunkt -> 3.5, nichts -> 0.0 Punkte) und frei erfundenen
Dozentenpunktzahlen. Der erwartete MAE ist von Hand nachgerechnet:

    |11.0 - 12.0| = 1.0
    |10.5 -  9.5| = 1.0
    | 3.5 -  4.0| = 0.5
    | 0.0 -  1.0| = 1.0
    MAE = (1.0 + 1.0 + 0.5 + 1.0) / 4 = 0.875

Kein LLM-Provider ist konfiguriert (Standardeinstellung, siehe
app/config.py Settings.llm_provider = "none") - get_evaluator() liefert
also HeuristicEvaluator, genau wie in CI.
"""

from __future__ import annotations

from pathlib import Path

from scripts.kalibrierung_cli import load_cases, mae, run_calibration

FIXTURES = Path(__file__).parent / "fixtures"


def test_mae_ueber_synthetisches_fixture_set_stimmt_mit_handrechnung_ueberein():
    cases, load_errors = load_cases(FIXTURES / "kalibrierung_beispiel.yaml")
    assert load_errors == []
    assert len(cases) == 4

    results, eval_errors = run_calibration(cases)
    assert eval_errors == []
    assert len(results) == 4

    by_slug = {r.slug: r for r in results}
    assert by_slug["vollstaendig"].predicted == 11.0
    assert by_slug["teilweise"].predicted == 10.5
    assert by_slug["ohne_kernpunkt"].predicted == 3.5
    assert by_slug["nichts"].predicted == 0.0

    assert mae(results) == 0.875


def test_leere_referenzmenge_liefert_fehler():
    cases, errors = load_cases(FIXTURES / "kalibrierung_leer.yaml")
    assert cases == []
    assert errors != []


def test_fehlende_referenzdatei_liefert_fehler():
    cases, errors = load_cases(FIXTURES / "gibt_es_nicht.yaml")
    assert cases == []
    assert "nicht gefunden" in errors[0]


def test_fall_ohne_erwartungshorizont_ist_nicht_auswertbar():
    cases, errors = load_cases(FIXTURES / "kalibrierung_fehlerhaft.yaml")
    # Der eine gueltige Fall bleibt auswertbar, die drei defekten werden als
    # Fehler gemeldet statt den ganzen Lauf abzubrechen.
    assert len(cases) == 1
    assert cases[0].slug == "gueltig"
    assert len(errors) == 3
    assert any("expectation.pruefpunkte" in e for e in errors)
    assert any("gutachten" in e for e in errors)
    assert any("punkte" in e for e in errors)


def test_run_calibration_ist_deterministisch():
    cases, _ = load_cases(FIXTURES / "kalibrierung_beispiel.yaml")
    a, errors_a = run_calibration(cases)
    b, errors_b = run_calibration(cases)
    assert errors_a == errors_b == []
    assert [(r.slug, r.predicted, r.actual) for r in a] == [
        (r.slug, r.predicted, r.actual) for r in b
    ]
