"""Regressionstests Heuristik-Bewertung, Runde 2 (Befunde B1-B6 des Testers)."""

from app.services.evaluator import (
    HeuristicEvaluator,
    _hat_verb,
    _ist_vollstaendiger_satz,
    _normalize,
    _verneint,
    _vorkommen,
)
from app.services.gutachten import analyze


def _eval(pruefpunkte: list[dict], text: str):
    return HeuristicEvaluator().evaluate(
        text=text, expectation={"pruefpunkte": pruefpunkte}, structure=analyze(text)
    )


def _verneint_kw(satz: str, kw: str) -> list[bool]:
    n = _normalize(satz)
    return [_verneint(v, a, b) for v, a, b in _vorkommen(n, _normalize(kw))]


FUELL = (
    " Die Prüfung erfolgt im Gutachtenstil und berücksichtigt den gesamten Sachverhalt "
    "sorgfältig, weshalb die Einzelheiten hier ausführlich dargestellt werden."
)


def test_b1_label_mit_kein_erlaubt_verneinung():
    pp = [{"id": "p1", "label": "Keine tätige Reue", "keywords": ["tätige Reue"]}]
    text = "Eine tätige Reue liegt hier nicht vor, weil der Täter nicht gelöscht hat."
    e = _eval(pp, text + FUELL)
    assert e.checkpoints[0].hit


def test_b1_kein_mitten_im_label_erlaubt_verneinung_nicht():
    pp = [
        {
            "id": "p1",
            "label": "Kündigung unwirksam wegen Rechtsmissbrauchs; Kein Räumungsanspruch",
            "keywords": ["Rechtsmissbrauch"],
        }
    ]
    e = _eval(pp, "Ein Rechtsmissbrauch liegt nicht vor, die Kündigung ist wirksam." + FUELL)
    assert not e.checkpoints[0].hit


def test_b2_verneintes_keyword_hebt_anderen_treffer_nicht_auf():
    pp = [
        {
            "id": "p1",
            "label": "Verbot nur im Notstand",
            "keywords": ["Notstand", "Gegendemonstranten"],
        }
    ]
    text = (
        "Ein Notstand liegt hier nicht vor, weil ausreichend Kräfte bereitstehen. "
        "Die Gegendemonstranten sind als Störer in Anspruch zu nehmen." + FUELL
    )
    assert _eval(pp, text).checkpoints[0].hit


def test_b2_verneinung_im_selben_satz_vor_zweitem_keyword_bleibt_widerspruch():
    pp = [{"id": "p1", "label": "Erforderlichkeit", "keywords": ["erforderlich", "Flucht"]}]
    text = "Die Verteidigung war nicht erforderlich, denn A hätte Flucht ergreifen müssen." + FUELL
    assert not _eval(pp, text).checkpoints[0].hit


def test_b3_verneinungsformeln():
    faelle = [
        ("Die Notwehrlage und die Erforderlichkeit scheiden aus.", "Notwehrlage"),
        ("Ein Rücktritt kommt nicht in Betracht.", "Rücktritt"),
        ("Ein Rücktritt vom Versuch kommen hier nicht in Betracht.", "Rücktritt"),
        ("Ein Anspruch aus Rechtsmissbrauch besteht nicht.", "Rechtsmissbrauch"),
        ("Die Kündigung ist wirksam, ein Rechtsmissbrauch greift nicht ein.", "Rechtsmissbrauch"),
        ("Der Eigenbedarf wurde nicht nachgewiesen.", "Eigenbedarf"),
        ("Eine Gesamtschuld ist unzulässig.", "Gesamtschuld"),
        ("Der Antrag ist unbegründet.", "Antrag"),
    ]
    for satz, kw in faelle:
        assert any(_verneint_kw(satz, kw)), satz


def test_b4_sondern_schneidet_verneinung_ab():
    satz = "A ist nicht Nichtstörer sondern Verhaltensstörer."
    assert _verneint_kw(satz, "Nichtstörer") == [True]
    assert _verneint_kw(satz, "Verhaltensstörer") == [False]
    satz = "Der Gegner ist nicht Zustandsstörer, vielmehr Verhaltensstörer."
    assert _verneint_kw(satz, "Verhaltensstörer") == [False]


def test_b5a_deklinierte_adjektive_sind_keine_verben():
    for text in (
        "am selben Tag",
        "die unbefugte Verwendung",
        "die aufschiebende Wirkung",
        "im öffentlichen Interesse",
        "durch die konkrete und unmittelbare Gefahr",
    ):
        assert not _hat_verb(text), text
    assert _hat_verb("Der Täter nutzte die Gelegenheit")


def test_b5a_liste_ohne_satzzeichen_braucht_verb_aus_liste():
    zeile = (
        "Computerbetrug § 263a Abs. 1 StGB, unbefugte Verwendung von Daten, Täuschungsäquivalenz"
    )
    assert not _ist_vollstaendiger_satz(zeile)
    assert _ist_vollstaendiger_satz(
        "Der Tatbestand ist erfüllt, weil A die Daten verwendet hat, § 263a StGB, "
        "und handelte vorsätzlich"
    )


def test_b5b_normfallback_nur_bei_seltener_norm_und_inhalt():
    def pp(n_punkte: int):
        return [
            {"id": f"p{i}", "label": f"Punkt {i}", "keywords": [f"Spezialbegriff{i}"],
             "norms": ["§ 242 StGB"]}
            for i in range(n_punkte)
        ]

    text = "A ist wegen Diebstahls nach § 242 StGB zu bestrafen." + FUELL
    assert _eval(pp(2), text).checkpoints[0].hit
    assert not _eval(pp(3), text).checkpoints[0].hit  # Norm in mehr als zwei Pruefpunkten
    kahl = [{"id": "p0", "label": "x", "keywords": ["Spezialbegriff"], "norms": ["§ 242 StGB"]}]
    kurz = "Siehe § 242 StGB und weitere Normen, Hinweise, Quellen, Listen"
    assert not _eval(kahl, kurz).checkpoints[0].hit
