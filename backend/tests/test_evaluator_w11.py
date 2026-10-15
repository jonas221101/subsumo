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


def test_konditionaler_obersatz_wird_erkannt():
    from app.services.gutachten import Step, classify_sentence

    assert classify_sentence("Die Klage hat Erfolg, wenn sie zulässig und begründet ist.") is (
        Step.OBERSATZ
    )
    assert (
        classify_sentence(
            "Das Vorhaben ist bauplanungsrechtlich zulässig, wenn § 35 BauGB erfüllt ist."
        )
        is Step.OBERSATZ
    )
    # Definitionen bleiben Definitionen.
    assert (
        classify_sentence(
            "Eine Sache ist fremd, wenn sie nicht im Alleineigentum des Täters steht."
        )
        is Step.DEFINITION
    )


def test_kurzer_schlusssatz_ist_ergebnis():
    from app.services.gutachten import Step, classify_sentence

    assert classify_sentence("A haftet nicht.") is Step.ERGEBNIS
    assert classify_sentence("G hat keinen Anspruch gegen A.") is Step.ERGEBNIS
    # Ein Rechtssatz ueber "den Arbeitnehmer" bleibt kein Ergebnis.
    assert (
        classify_sentence(
            "Nach den Grundsätzen des Schadensausgleichs haftet der Arbeitnehmer nicht."
        )
        is not Step.ERGEBNIS
    )


def test_beispiele_nennen_die_parteien_des_falls():
    from app.services.gutachten import _BEISPIELE, _mit_parteien

    bsp = _mit_parteien(_BEISPIELE["zivilrecht"], "G könnte gegen A einen Anspruch haben.")
    assert bsp["ergebnis"].startswith("Mithin hat G gegen A")
    assert _mit_parteien(_BEISPIELE["zivilrecht"], "Ohne Kürzel.") == _BEISPIELE["zivilrecht"]


def test_teilweise_geloest_hoechstens_9_punkte():
    exp = {
        "pruefpunkte": [
            {"id": f"p{i}", "label": f"Punkt {i}", "keywords": [kw]}
            for i, kw in enumerate(
                ["Gewahrsam", "Zueignungsabsicht", "Rechtswidrigkeit", "Ergebnis"]
            )
        ]
    }
    text = (
        "T könnte sich wegen Diebstahls nach § 242 Abs. 1 StGB strafbar gemacht haben. "
        "Er hat fremden Gewahrsam gebrochen und neuen Gewahrsam begründet. "
        "T handelte mit Zueignungsabsicht, weil er das Parfüm behalten wollte."
    )
    e = HeuristicEvaluator().evaluate(text=text, expectation=exp, structure=analyze(text))
    assert sum(c.hit for c in e.checkpoints) == 2
    assert e.points <= 9.0
