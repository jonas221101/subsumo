"""Tests der Gutachtenstil-Analyse an realistischen Beispieltexten."""

from app.services.gutachten import (
    Severity,
    Step,
    analyze,
    classify_sentence,
    extract_norms,
    split_sentences,
)

SAUBER = """
A könnte gegen B einen Anspruch auf Zahlung des Kaufpreises in Höhe von 500 Euro
aus § 433 Abs. 2 BGB haben.
Dazu müsste zwischen A und B ein wirksamer Kaufvertrag zustande gekommen sein.
Ein Kaufvertrag kommt durch zwei übereinstimmende Willenserklärungen zustande,
nämlich Angebot und Annahme.
Ein Angebot ist eine empfangsbedürftige Willenserklärung, die alle wesentlichen
Vertragsbestandteile enthält und der andere Teil nur noch zustimmen muss.
Hier hat A dem B angeboten, ihm das Fahrrad für 500 Euro zu verkaufen.
B hat dieses Angebot vorliegend ausdrücklich angenommen.
Mithin ist zwischen A und B ein wirksamer Kaufvertrag zustande gekommen.
A hat somit gegen B einen Anspruch auf Zahlung von 500 Euro aus § 433 Abs. 2 BGB.
"""

URTEILSSTIL = """
Da A dem B das Fahrrad übereignet hat, ist ein Kaufvertrag zustande gekommen.
Der Anspruch besteht, weil B den Kaufpreis nicht gezahlt hat.
B muss also 500 Euro zahlen.
Ein Anspruch aus § 433 Abs. 2 BGB ist gegeben, da alle Voraussetzungen erfüllt
sind und nichts dagegen spricht.
"""

OFFENER_OBERSATZ = """
A könnte gegen B einen Anspruch auf Schadensersatz aus § 823 Abs. 1 BGB haben.
Dazu müsste B ein Rechtsgut des A verletzt haben.
Eine Eigentumsverletzung ist jede Einwirkung auf die Sachsubstanz oder die
Beeinträchtigung der bestimmungsgemäßen Verwendbarkeit.
Hier hat B die Vase des A zerbrochen und damit deren Substanz zerstört.
"""

SPRUNG = """
A könnte gegen B einen Anspruch auf Herausgabe aus § 985 BGB haben.
Mithin hat A gegen B einen Anspruch auf Herausgabe der Sache aus § 985 BGB.
Weiterhin könnte A ein Anspruch aus § 812 Abs. 1 S. 1 Alt. 1 BGB zustehen.
Hier hat B durch Leistung des A etwas erlangt, nämlich das Eigentum an der Sache.
Somit besteht auch ein Anspruch aus Leistungskondiktion.
"""


# --------------------------------------------------------------------------- #
# Satztrennung und Normerkennung
# --------------------------------------------------------------------------- #


def test_satztrennung_zerbricht_nicht_an_juristischen_abkuerzungen():
    text = (
        "A könnte einen Anspruch aus § 433 Abs. 2 S. 1 BGB haben. "
        "Nach h.M. ist das str. Vgl. dazu BGH, Urt. v. 12.3.2020. "
        "Dies gilt auch i.V.m. § 280 Abs. 1 BGB."
    )
    saetze = split_sentences(text)
    assert len(saetze) == 3
    assert "Abs. 2 S. 1 BGB" in saetze[0]
    assert "i.V.m." in saetze[2]


def test_normerkennung_findet_absatz_satz_und_alternative():
    normen = extract_norms(
        "Anspruch aus § 812 Abs. 1 S. 1 Alt. 1 BGB, daneben §§ 823 I BGB und Art. 2 GG."
    )
    joined = " | ".join(normen)
    assert "§ 812 Abs. 1 S. 1 Alt. 1 BGB" in joined
    assert any("823" in n for n in normen)


# --------------------------------------------------------------------------- #
# Klassifikation
# --------------------------------------------------------------------------- #


def test_klassifikation_der_vier_schritte():
    obersatz = "A könnte gegen B einen Anspruch aus § 433 II BGB haben."
    assert classify_sentence(obersatz) is Step.OBERSATZ
    assert classify_sentence("Fraglich ist, ob hier ein Angebot vorliegt.") is Step.OBERSATZ
    assert classify_sentence("Eine Sache ist jeder körperliche Gegenstand.") is Step.DEFINITION
    assert classify_sentence("Hier hat A dem B das Fahrrad übergeben.") is Step.SUBSUMTION
    assert classify_sentence("Mithin ist ein Kaufvertrag zustande gekommen.") is Step.ERGEBNIS


def test_obersatz_schlaegt_subsumtionsmarker_im_selben_satz():
    # "Hier" ist ein Subsumtionsmarker, "fraglich ist" macht den Satz zum Obersatz.
    assert classify_sentence("Fraglich ist, ob hier eine Sache vorliegt.") is Step.OBERSATZ


# --------------------------------------------------------------------------- #
# Gesamtanalyse
# --------------------------------------------------------------------------- #


def test_sauberes_gutachten_erhaelt_hohen_score_und_lob():
    report = analyze(SAUBER)
    assert report.score >= 85, report.to_dict()
    assert not [f for f in report.findings if f.severity is Severity.FEHLER]
    assert any(f.code == "sauberer_aufbau" for f in report.findings)
    assert report.counts["obersatz"] >= 2
    assert report.counts["subsumtion"] >= 2
    assert report.gutachtenstil_quote >= 0.75


def test_urteilsstil_wird_erkannt_und_deutlich_abgewertet():
    report = analyze(URTEILSSTIL)
    verstoesse = [f for f in report.findings if f.code == "urteilsstil"]
    assert len(verstoesse) >= 3
    assert report.score < analyze(SAUBER).score - 30
    # Der Befund muss den konkreten Satz zeigen, sonst ist er nutzlos.
    assert verstoesse[0].excerpt
    assert verstoesse[0].sentence_index is not None


def test_nicht_abgeschlossener_obersatz_wird_gemeldet():
    report = analyze(OFFENER_OBERSATZ)
    offen = [f for f in report.findings if f.code == "offener_obersatz"]
    assert len(offen) == 2  # beide Obersaetze bleiben ohne Ergebnis
    # Der nie beantwortete Obersatz ist ein Fehler, der bearbeitete, aber nicht
    # ausdruecklich abgeschlossene nur ein Hinweis.
    assert {f.severity for f in offen} == {Severity.FEHLER, Severity.HINWEIS}


def test_schlussergebnis_schliesst_auch_uebergeordnete_obersaetze():
    """Gutachten fassen das Endergebnis zusammen, statt jede Ebene einzeln
    abzuschliessen - das darf nicht als offener Obersatz gemeldet werden."""
    text = (
        "A könnte gegen B einen Anspruch auf Zahlung aus § 433 Abs. 2 BGB haben. "
        "Dazu müsste ein wirksamer Kaufvertrag vorliegen. "
        "Ein Kaufvertrag ist eine Einigung über Ware und Preis, wenn beide Seiten "
        "übereinstimmende Willenserklärungen abgegeben haben. "
        "Hier haben sich A und B über das Fahrrad und den Preis geeinigt. "
        "Mithin liegt ein wirksamer Kaufvertrag vor."
    )
    report = analyze(text)
    assert not [f for f in report.findings if f.code == "offener_obersatz"]


def test_sprung_vom_obersatz_direkt_zum_ergebnis():
    report = analyze(SPRUNG)
    spruenge = [f for f in report.findings if f.code == "sprung_zum_ergebnis"]
    assert len(spruenge) == 1
    # Der zweite Pruefungspunkt ist sauber subsumiert und darf nicht mitgemeldet werden.
    assert spruenge[0].sentence_index == 0


def test_fehlende_normzitate_werden_bemaengelt():
    report = analyze(
        "A könnte gegen B einen Anspruch auf Zahlung des vereinbarten Kaufpreises "
        "in Höhe von fünfhundert Euro haben. "
        "Ein Kaufvertrag ist eine Einigung über Ware und Preis, wenn beide Seiten "
        "übereinstimmende Willenserklärungen abgegeben haben. "
        "Hier haben sich A und B über den Verkauf des Fahrrads zu diesem Preis "
        "ausdrücklich und ohne Vorbehalt geeinigt. "
        "Mithin besteht der geltend gemachte Anspruch auf Zahlung des Kaufpreises."
    )
    assert any(f.code == "keine_norm" for f in report.findings)


def test_erwartete_normen_werden_abgeglichen():
    report = analyze(SAUBER, expected_norms=["§ 433 Abs. 2 BGB", "§ 280 Abs. 1 BGB"])
    assert report.missing_norms == ["§ 280 Abs. 1 BGB"]
    assert any(f.code == "norm_nicht_geprueft" for f in report.findings)


def test_erwartete_normen_matchen_unabhaengig_von_leerzeichen():
    report = analyze(SAUBER, expected_norms=["§433 Abs.2 BGB"])
    assert report.missing_norms == []


def test_zu_kurzer_text_liefert_score_null_statt_falschem_lob():
    report = analyze("Der Anspruch besteht.")
    assert report.score == 0
    assert report.findings[0].code == "zu_kurz"


def test_analyse_ist_deterministisch():
    # Reproduzierbarkeit ist die Existenzberechtigung des regelbasierten Ansatzes.
    assert analyze(SAUBER).to_dict() == analyze(SAUBER).to_dict()


def test_schachtelsatz_wird_gemeldet():
    langer_satz = (
        "A könnte gegen B einen Anspruch aus § 433 Abs. 2 BGB haben, "
        + "und zwar deshalb, weil die Parteien sich über alle wesentlichen "
        * 6
        + "Vertragsbestandteile geeinigt haben."
    )
    report = analyze(langer_satz + " Hier ist das der Fall. Mithin besteht der Anspruch.")
    assert any(f.code == "schachtelsatz" for f in report.findings)


def test_report_ist_json_serialisierbar():
    import json

    json.dumps(analyze(SAUBER).to_dict())
