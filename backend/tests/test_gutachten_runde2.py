"""Regressionstests Strukturanalyse, Runde 2 (Landesrecht, Ergebnis, Hinweise je Rechtsgebiet)."""

import pytest

from app.services.gutachten import (
    Step,
    analyze,
    classify_sentence,
    extract_norms,
    norm_matches,
)

PAD = (
    "Zur Einordnung sei erwähnt, dass der Sachverhalt mehrere Beteiligte nennt und die "
    "folgenden Ausführungen sich auf die wesentlichen Gesichtspunkte beschränken. "
)
SV = PAD + (
    "Die Maßnahme könnte rechtswidrig sein. Rechtswidrig ist eine Maßnahme, wenn sie gegen "
    "geltendes Recht verstößt. Hier hat die Behörde ohne Anhörung entschieden, weshalb ein "
    "Verfahrensfehler vorliegt. "
)


@pytest.mark.parametrize(
    "zitat",
    ["§ 22 GO SH", "§ 8 GO NRW", "Art. 11 PAG", "§ 6 BauO NRW", "§ 3 PolG BW", "§ 17 ASOG"],
)
def test_landesgesetz_zitate_zaehlen_als_gesetzesangabe(zitat):
    text = SV + f"Nach {zitat} ist die Maßnahme unzulässig. Mithin ist sie rechtswidrig."
    assert zitat in extract_norms(text)
    report = analyze(text)
    assert "gesetz_fehlt" not in {f.code for f in report.findings}


def test_paragraph_ohne_gesetz_wird_weiter_gemeldet():
    text = SV + "Nach § 22 Abs. 1 ist die Maßnahme unzulässig. Mithin ist sie rechtswidrig."
    assert "gesetz_fehlt" in {f.code for f in analyze(text).findings}


@pytest.mark.parametrize(
    "satz",
    [
        "IV. Ergebnis: Der Beschluss ist wegen des Mitwirkungsverbots rechtswidrig und unwirksam.",
        "Der Beschluss ist rechtswidrig und unwirksam.",
        "A hat sich wegen Diebstahls strafbar gemacht.",
        "Die Klage ist begründet.",
        "Der Antrag hat Erfolg.",
        "Damit hat K keinen Anspruch auf Übereignung.",
        "Damit ist die Klage unzulässig.",
        "K kann deshalb die Rückzahlung verlangen.",
    ],
)
def test_ergebnissaetze_werden_erkannt(satz):
    assert classify_sentence(satz) is Step.ERGEBNIS


def test_definition_mit_wenn_bleibt_definition():
    assert (
        classify_sentence("Rechtswidrig ist ein Verwaltungsakt, wenn er gegen Recht verstößt.")
        is Step.DEFINITION
    )


def test_ausformuliertes_ergebnis_schliesst_obersatz():
    text = (
        "Der Beschluss könnte rechtswidrig sein. Das Mitwirkungsverbot erfasst Mitglieder, "
        "die einen unmittelbaren Vorteil haben. Hier hat V als Geschäftsführer der B-GmbH "
        "mitgestimmt und die Gesellschaft profitiert. IV. Ergebnis: Der Beschluss ist "
        "wegen der Mitwirkung rechtswidrig und unwirksam, vgl. § 22 GO SH."
    )
    codes = {f.code for f in analyze(text).findings}
    assert "kein_ergebnis" not in codes
    assert "offener_obersatz" not in codes


def test_verneintes_ergebnis_schliesst_obersatz_und_buendelt():
    text = (
        "Fraglich ist, ob der Vertrag formwirksam ist. Hier haben die Parteien nur mündlich "
        "gehandelt, die Form wurde damit nicht eingehalten. "
        "Hilfsweise kommt ein Anspruch auf Rückzahlung aus § 812 Abs. 1 S. 1 Alt. 1 BGB in "
        "Betracht. V hat die Anzahlung durch Leistung von K erlangt, und der Rechtsgrund fehlt. "
        "Damit hat K keinen Anspruch auf Übereignung."
    )
    codes = [f.code for f in analyze(text).findings]
    assert "kein_ergebnis" not in codes
    assert codes.count("offener_obersatz") <= 1


def test_gleichartige_offene_obersaetze_werden_gebuendelt():
    text = PAD + (
        "Der Vertrag könnte wirksam sein. Hier haben die Parteien gehandelt und geeinigt. "
        "Die Form könnte gewahrt sein. Hier wurde schriftlich gehandelt von beiden. "
        "Ein Anspruch könnte bestehen. Hier hat K gezahlt und V geliefert. § 433 BGB"
    )
    offen = [f for f in analyze(text).findings if f.code == "offener_obersatz"]
    assert len(offen) == 1
    assert "×" in offen[0].message


@pytest.mark.parametrize(
    ("area", "erwartet", "nicht"),
    [
        ("strafrecht", "strafbar gemacht", "Angebot"),
        ("oeffentliches-recht", "rechtswidrig", "Angebot"),
        ("zivilrecht", "Anspruch", "Angebot"),
        (None, "Mithin", "Angebot"),
    ],
)
def test_hinweise_je_rechtsgebiet(area, erwartet, nicht):
    text = PAD + "Der Vertrag könnte wirksam sein. Hier haben beide gehandelt und gezahlt. " * 3
    report = analyze(text, area=area)
    hints = " ".join(f.hint for f in report.findings)
    assert erwartet in hints
    assert nicht not in hints


def test_norm_ohne_absatz_und_mit_leerzeichen_trifft():
    erwartet = "§ 311b Abs. 1 S. 1 BGB"
    assert norm_matches(erwartet, "§ 311b")
    assert any(norm_matches(erwartet, n) for n in extract_norms("Nach § 311 b Abs. 1 BGB ..."))
    assert not norm_matches(erwartet, "§ 311")
    assert not norm_matches(erwartet, "§ 312b")
