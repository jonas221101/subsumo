"""Regressionstests der Heuristik-Bewertung (Stresstest 8, Beta-Tester).

Die Varianten in ``fixtures/eval_stresstest.json`` stammen aus dem Stresstest:
gute Loesung (eigene Worte / exakte Begriffe), falsches Ergebnis mit Keyword-Spam,
Stichwortliste, Urteilsstil, ein Satz, Copy-Paste und Loesung zum falschen Fall.
Gepruft wird die *Rangfolge*, nicht jede Einzelpunktzahl.
"""

import json
from pathlib import Path

import pytest

from app.services.evaluator import (
    HEURISTIK_MAX_PUNKTE,
    HeuristicEvaluator,
    parse_expectation,
)
from app.services.gutachten import analyze, extract_norms, norm_matches

DATEN = json.loads((Path(__file__).parent / "fixtures" / "eval_stresstest.json").read_text())
STRAF = "sr-fall-notwehr-schlagstock"
ZIVIL = "zr-fall-zahlendreher-kaufangebot"
OEFF = "or-fall-satireplakat"


def _bewerte(slug: str, text: str):
    erwartung = DATEN[slug]["expectation"]
    normen = [n for p in erwartung["pruefpunkte"] for n in p.get("norms", [])]
    struktur = analyze(text, expected_norms=normen or None)
    return HeuristicEvaluator().evaluate(text=text, expectation=erwartung, structure=struktur)


def _variante(slug: str, name: str) -> str:
    return DATEN[slug]["varianten"][name]


def _eval(erwartung: dict, text: str):
    return HeuristicEvaluator().evaluate(
        text=text, expectation=erwartung, structure=analyze(text)
    )


FALLER = [STRAF, ZIVIL, OEFF]


# --------------------------------------------------------------------------- #
# 1. YAML-Integer-Keywords
# --------------------------------------------------------------------------- #


def test_integer_keyword_stuerzt_nicht_ab():
    erwartung = {"pruefpunkte": [{"id": "p1", "label": "Norm", "keywords": [43, 113]}]}
    assert parse_expectation(erwartung)[0].keywords == ["43", "113"]
    text = "Die Feststellungsklage ist nach § 43 VwGO statthaft, wenn ein Rechtsverhältnis besteht."
    assert _eval(erwartung, text).checkpoints[0].hit is True


def test_zahl_keyword_braucht_paragraphenkontext():
    erwartung = {"pruefpunkte": [{"id": "p1", "label": "Norm", "keywords": ["223"]}]}
    kein_zitat = "Der Kaufpreis betrug 223 Euro und wurde am Montag vollständig bezahlt."
    zitat = "Die Strafbarkeit des A richtet sich nach § 223 Abs. 1 StGB und ist zu prüfen."
    assert _eval(erwartung, kein_zitat).checkpoints[0].hit is False
    assert _eval(erwartung, zitat).checkpoints[0].hit is True
    nur_prefix = "Die Strafbarkeit richtet sich nach § 2230 StGB und wird gleich geprüft."
    assert _eval(erwartung, nur_prefix).checkpoints[0].hit is False


# --------------------------------------------------------------------------- #
# 2. Negation und Wortgrenzen
# --------------------------------------------------------------------------- #

NEGATIONS_ERWARTUNG = {
    "pruefpunkte": [
        {"id": "p1", "label": "Erforderlichkeit bejaht", "keywords": ["erforderlich"]},
    ]
}


@pytest.mark.parametrize(
    "satz",
    [
        "Die Verteidigung des A war hier nicht erforderlich, weil er hätte fliehen können.",
        "Die Verteidigung des A war hier nach Lage der Dinge keinesfalls erforderlich.",
        "Eine erforderliche Verteidigung liegt hier nicht vor, weil ein Ausweichen möglich war.",
    ],
)
def test_verneintes_stichwort_ist_kein_treffer(satz):
    result = _eval(NEGATIONS_ERWARTUNG, satz)
    assert result.checkpoints[0].hit is False
    assert "verneinst" in result.checkpoints[0].comment


def test_bejahtes_stichwort_bleibt_treffer():
    satz = "Die Verteidigung des A war hier erforderlich, weil kein milderes Mittel bestand."
    assert _eval(NEGATIONS_ERWARTUNG, satz).checkpoints[0].hit is True


def test_keine_enteignung_und_nicht_gewahrt():
    erwartung = {
        "pruefpunkte": [
            {"id": "p1", "label": "Enteignung bejaht", "keywords": ["Enteignung"]},
            {"id": "p2", "label": "Frist gewahrt", "keywords": ["gewahrt"]},
        ]
    }
    text = (
        "Hier liegt nach Ansicht des Gerichts keine Enteignung im Sinne des Grundgesetzes vor. "
        "Die Klagefrist ist im vorliegenden Fall nicht gewahrt worden."
    )
    result = _eval(erwartung, text)
    assert [c.hit for c in result.checkpoints] == [False, False]
    positiv = (
        "Hier liegt nach Ansicht des Gerichts eine Enteignung im Sinne des Grundgesetzes vor. "
        "Die Klagefrist ist im vorliegenden Fall gewahrt worden."
    )
    assert [c.hit for c in _eval(erwartung, positiv).checkpoints] == [True, True]


def test_unbeendeter_versuch_trifft_nicht_beendeter_versuch():
    erwartung = {
        "pruefpunkte": [
            {"id": "p1", "label": "Beendeter Versuch", "keywords": ["beendeter Versuch"]}
        ]
    }
    falsch = "Hier ist nach dem Rücktrittshorizont des A ein unbeendeter Versuch gegeben."
    richtig = "Hier ist nach dem Rücktrittshorizont des A ein beendeter Versuch gegeben."
    assert _eval(erwartung, falsch).checkpoints[0].hit is False
    assert _eval(erwartung, richtig).checkpoints[0].hit is True


def test_label_mit_verneinung_erlaubt_verneinte_formulierung():
    erwartung = {
        "pruefpunkte": [
            {"id": "p1", "label": "Schmähkritik zutreffend verneint", "keywords": ["Schmähkritik"]}
        ]
    }
    text = "Hier liegt im vorliegenden Fall keine Schmähkritik vor, weil ein Sachbezug besteht."
    assert _eval(erwartung, text).checkpoints[0].hit is True


def test_falsches_ergebnis_mit_keyword_spam_liegt_deutlich_unter_der_guten_loesung():
    for slug in FALLER:
        gut = _bewerte(slug, _variante(slug, "2 exakte Begriffe"))
        falsch = _bewerte(slug, _variante(slug, "3 falsch + Spam"))
        assert gut.points == HEURISTIK_MAX_PUNKTE
        assert falsch.points <= gut.points - 5, slug
        assert falsch.hinweise


# --------------------------------------------------------------------------- #
# 3. Stichwortliste, Urteilsstil, Copy-Paste
# --------------------------------------------------------------------------- #


def test_stichwortliste_bekommt_keine_inhaltspunkte():
    for slug in FALLER:
        gut = _bewerte(slug, _variante(slug, "2 exakte Begriffe"))
        liste = _bewerte(slug, _variante(slug, "4 Stichwortliste"))
        assert liste.points <= 4.0, slug
        assert liste.points < gut.points - 6, slug


def test_urteilsstil_wird_gedeckelt_und_erklaert():
    for slug in FALLER:
        gut = _bewerte(slug, _variante(slug, "2 exakte Begriffe"))
        urteil = _bewerte(slug, _variante(slug, "5 Urteilsstil"))
        assert urteil.points <= 6.0, slug
        assert urteil.points < gut.points, slug
        assert "Gutachten" in urteil.summary


def test_ein_satz_ist_hoechstens_vier_punkte():
    for slug in FALLER:
        assert _bewerte(slug, _variante(slug, "6b ein Satz")).points <= 4.0, slug


def test_copy_paste_wird_erkannt_und_gedeckelt():
    for slug in FALLER:
        text = (_variante(slug, "2 exakte Begriffe") + "\n\n") * 40
        struktur = analyze(text)
        assert struktur.duplicate_ratio > 0.9
        result = _bewerte(slug, text)
        assert result.points <= 3.0, slug
        assert "Wiederholung" in result.summary
        # Befunde gleichen Typs werden gebuendelt statt 40-fach gelistet.
        codes = [f.code for f in struktur.findings]
        assert codes.count("sprung_zum_ergebnis") <= 1


# --------------------------------------------------------------------------- #
# 4. Gestaffelter Kernpunkt-Abzug
# --------------------------------------------------------------------------- #


def test_gute_loesung_in_eigenen_worten_faellt_nicht_pauschal_auf_3_5():
    straf = _bewerte(STRAF, _variante(STRAF, "1 eigene Worte"))
    assert straf.points > 3.5
    assert straf.missed_required  # mindestens ein Kernpunkt wurde nicht erkannt
    assert straf.points < _bewerte(STRAF, _variante(STRAF, "2 exakte Begriffe")).points


def test_kernpunkt_deckel_staffelt_sich_nach_anteil_fehlender_punkte():
    def erwartung(n_required: int) -> dict:
        return {
            "pruefpunkte": [
                {"id": f"p{i}", "label": f"Punkt{i}", "required": True, "keywords": [f"Wort{i}"]}
                for i in range(n_required)
            ]
        }

    text = (
        "A könnte gegen B einen Anspruch aus § 433 Abs. 2 BGB haben. Dazu müsste ein Vertrag "
        "bestehen. Ein Vertrag ist eine Einigung, wenn zwei Willenserklärungen vorliegen. "
        "Hier hat A dem B ein Angebot gemacht und B hat es angenommen. Wort0 Wort1 Wort2 Wort3 "
        "stehen im Sachverhalt. Mithin besteht der Anspruch aus § 433 Abs. 2 BGB. "
        "Der Vertrag ist wirksam zustande gekommen und der Preis ist fällig."
    )
    # Nur Wort0 kommt im Text vor -> 3 von 4 fehlen.
    eins_fehlt = _eval(erwartung(1), text.replace("Wort0", "X"))
    assert eins_fehlt.points <= 3.5
    viele = erwartung(4)
    teil = text.replace("Wort3", "Y")
    r = _eval(viele, teil)
    assert len(r.missed_required) == 1
    assert 3.5 < r.points <= 9.0


def test_summary_nennt_den_grund_frueh_und_deutlich():
    result = _bewerte(STRAF, _variante(STRAF, "1 eigene Worte"))
    summary = result.summary
    assert summary.index("Kernprüfpunkte fehlen") < summary.index("Ergebnis:")
    assert "übersehen" in summary
    assert "begrenzt" in summary
    assert "ohne diese Begrenzung" in summary


# --------------------------------------------------------------------------- #
# 5. Falscher Fall
# --------------------------------------------------------------------------- #


def test_loesung_zum_falschen_fall_bekommt_hinweis_und_fast_keine_punkte():
    fremd = {
        STRAF: _variante(ZIVIL, "2 exakte Begriffe"),
        ZIVIL: _variante(STRAF, "2 exakte Begriffe"),
        OEFF: _variante(ZIVIL, "2 exakte Begriffe"),
    }
    for slug, text in fremd.items():
        result = _bewerte(slug, text)
        assert result.points <= 1.0, slug
        assert "passt offenbar nicht zum Sachverhalt" in result.summary


# --------------------------------------------------------------------------- #
# 9. Hinweis zur Deckelung am Anfang
# --------------------------------------------------------------------------- #


def test_deckelungs_hinweis_steht_am_anfang_der_zusammenfassung():
    for slug in FALLER:
        summary = _bewerte(slug, _variante(slug, "2 exakte Begriffe")).summary
        assert summary.startswith("Hinweis: Ohne KI-Korrektur")
        assert "gedeckelt" in summary.split(".")[0]


# --------------------------------------------------------------------------- #
# 6. Normerkennung (gutachten.py)
# --------------------------------------------------------------------------- #


def test_art_zitate_werden_erkannt():
    normen = extract_norms(
        "Nach Art. 5 Abs. 3 GG, Art. 12 I GG und Art. 5 Abs. 1 S. 1 GG sowie §§ 143, 121 BGB."
    )
    assert "Art. 5 Abs. 3 GG" in normen
    assert "Art. 12 I GG" in normen
    assert "Art. 5 Abs. 1 S. 1 GG" in normen
    assert "§ 143 BGB" in normen and "§ 121 BGB" in normen


def test_art_zitat_mit_roemischem_absatz_deckt_arabischen_ab():
    assert norm_matches("Art. 12 Abs. 1 GG", "Art. 12 I GG")
    assert not norm_matches("Art. 12 Abs. 1 GG", "Art. 14 GG")
    assert not norm_matches("§ 223 StGB", "§ 223 BGB")


def test_norm_alternativen_werden_nur_einmal_als_fehlend_gemeldet():
    text = "Die Strafbarkeit des A richtet sich allein nach § 15 StGB und ist zu prüfen. " * 6
    report = analyze(text, expected_norms=["§ 223 Abs. 1 StGB", "§ 223 StGB"])
    assert report.missing_norms == ["§ 223 StGB"]


def test_zitierte_alternative_gilt_als_vorhanden():
    text = "Hier ist § 223 Abs. 1 StGB einschlägig und deshalb zu prüfen. " * 6
    report = analyze(text, expected_norms=["§ 223 Abs. 1 StGB", "§ 223 StGB"])
    assert report.missing_norms == []


def test_ger_art_zitat_ohne_gesetz_fuehrt_nicht_zu_fehlalarm():
    text = (
        "Die Entfernungsanordnung könnte K in seiner Meinungsfreiheit aus Art. 5 Abs. 1 S. 1 GG "
        "verletzen. Der Schutzbereich ist eröffnet, weil das Plakat eine wertende Äußerung ist. "
        "Hier liegt ein Eingriff vor. Mithin ist Art. 5 Abs. 1 S. 1 GG betroffen. "
    ) * 2
    report = analyze(text, expected_norms=["Art. 5 Abs. 1 S. 1 GG", "Art. 5 Abs. 1 S. 1 GG"])
    assert report.missing_norms == []
    assert not any(f.code == "keine_norm" for f in report.findings)


def test_hinweis_zu_fehlenden_normen_ist_rechtsgebietsneutral():
    text = "Hier prüfen wir etwas Allgemeines ohne jede Norm und ohne jeden Bezug. " * 6
    straf = analyze(text, expected_norms=["§ 223 StGB"])
    oeff = analyze(text, expected_norms=["Art. 5 Abs. 1 GG"])
    zivil = analyze(text, expected_norms=["§ 433 BGB"])

    def hint(report):
        return next(f.hint for f in report.findings if f.code == "norm_nicht_geprueft")

    assert "Anspruchsgrundlagen" not in hint(straf)
    assert "Anspruchsgrundlagen" not in hint(oeff)
    assert "Anspruchsgrundlagen" in hint(zivil)


# --------------------------------------------------------------------------- #
# 7. Strukturanalyse in eigenen Worten
# --------------------------------------------------------------------------- #


def test_gute_loesung_loest_keinen_sprung_fehlalarm_aus():
    for slug in FALLER:
        for name in ("1 eigene Worte", "2 exakte Begriffe"):
            report = analyze(_variante(slug, name))
            assert not [f for f in report.findings if f.code == "sprung_zum_ergebnis"], (
                slug,
                name,
            )


def test_definition_und_subsumtion_in_eigenen_worten_werden_gezaehlt():
    text = (
        "Eine Misshandlung ist jede Behandlung, die das Wohlbefinden mehr als unerheblich "
        "beeinträchtigt. Unter Vorsatz versteht man Wissen und Wollen der Tat. "
        "Eine Rechtfertigung liegt vor, wenn alle Voraussetzungen erfüllt sind. "
        "Im vorliegenden Fall hat B eine Prellung erlitten. "
        "A wusste, was er tat, und wollte den Schlag. "
        "Dies ist der Fall, da der Angriff unmittelbar bevorstand. "
        "Somit ist das Merkmal erfüllt. "
        "Folglich besteht der Anspruch. Mithin ist A nicht strafbar."
    )
    counts = analyze(text).counts
    assert counts["definition"] >= 3
    assert counts["subsumtion"] >= 3
    assert counts["ergebnis"] >= 2


# --------------------------------------------------------------------------- #
# 8. Leere Abgaben
# --------------------------------------------------------------------------- #


@pytest.mark.parametrize("text", ["", " ", "\n\n  \t "])
def test_leere_abgabe_wird_mit_deutscher_meldung_abgelehnt(auth_client, text):
    vorher = auth_client.get("/v1/submissions").json()
    response = auth_client.post("/v1/cases/zr-fall-sonderpreis/submit", json={"text": text})
    assert response.status_code == 422
    assert "leer" in response.json()["detail"]
    assert "String should" not in response.text
    # Es wird keine 0-Punkte-Abgabe gespeichert.
    assert auth_client.get("/v1/submissions").json() == vorher
