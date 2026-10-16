"""Welle 6: deutsche Zahlen im Bewertungstext, Regalschaden-Keywords."""

from pathlib import Path

import yaml

from app.services.evaluator import HeuristicEvaluator, _de_zahl
from app.services.gutachten import analyze
from tests.test_evaluator_robustheit import STRAF, _bewerte, _variante

INHALT = Path(__file__).parent.parent.parent / "content" / "zivilrecht"


def test_de_zahl():
    assert _de_zahl(3.5) == "3,5"
    assert _de_zahl(5.5) == "5,5"
    assert _de_zahl(6.0) == "6"
    assert _de_zahl(11) == "11"


def test_summary_ohne_punkt_dezimalzahlen():
    summary = _bewerte(STRAF, _variante(STRAF, "1 eigene Worte")).summary
    assert "begrenzt" in summary
    import re

    assert not re.search(r"\d\.\d", summary), summary


def test_regalschaden_loesung_in_eigenen_worten_wird_nicht_gedeckelt():
    daten = yaml.safe_load((INHALT / "zr-arbeitsrecht-grundzuege.yaml").read_text())
    fall = next(f for f in daten["faelle"] if f["slug"] == "zr-fall-arb-gabelstapler")
    text = (
        "G könnte gegen A einen Anspruch auf Schadensersatz haben. Als Anspruchsgrundlage "
        "kommt § 280 Abs. 1 BGB in Betracht, weil A als Arbeitnehmer seine Pflichten verletzt "
        "haben könnte. Allerdings war die Tätigkeit betrieblich veranlasst, sodass die "
        "Grundsätze des innerbetrieblichen Schadensausgleichs gelten. A handelte allenfalls "
        "mit leichtester Fahrlässigkeit. Daher haftet A nicht, G hat keinen Anspruch."
    )
    r = HeuristicEvaluator().evaluate(
        text=text, expectation=fall["expectation"], structure=analyze(text)
    )
    assert not r.missed_required
    assert r.points > 6
