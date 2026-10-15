"""Welle 11: kurze Ergebnissaetze zaehlen, Stichwortlisten weiterhin nicht."""

from app.services.evaluator import HeuristicEvaluator
from app.services.gutachten import analyze

EXP = {
    "pruefpunkte": [
        {
            "id": "p1",
            "label": "Ergebnis: Vorhaben unzulaessig",
            "keywords": ["Vorhaben ist unzulässig"],
        },
    ]
}


def _eval(text: str):
    return HeuristicEvaluator().evaluate(text=text, expectation=EXP, structure=analyze(text))


def test_kurzer_ergebnissatz_trifft():
    text = (
        "Das Vorhaben könnte nach § 35 BauGB zulässig sein, wenn öffentliche Belange nicht "
        "beeinträchtigt werden. Hier widerspricht es dem Flächennutzungsplan. "
        "Das Vorhaben ist unzulässig."
    )
    assert _eval(text).checkpoints[0].hit


def test_stichwortzeile_ohne_satz_trifft_nicht():
    assert not _eval("Vorhaben ist unzulässig, Außenbereich, § 35 BauGB").checkpoints[0].hit
    assert not _eval("Vorhaben unzulässig").checkpoints[0].hit
