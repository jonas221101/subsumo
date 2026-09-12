"""Tests der Bewertung gegen den Erwartungshorizont."""

import pytest

from app.services.evaluator import (
    HEURISTIK_MAX_PUNKTE,
    HeuristicEvaluator,
    note_fuer_punkte,
    parse_expectation,
)
from app.services.gutachten import analyze

ERWARTUNG = {
    "pruefpunkte": [
        {
            "id": "p1",
            "label": "Anspruchsgrundlage § 433 Abs. 2 BGB",
            "weight": 2.0,
            "required": True,
            "norms": ["§ 433 Abs. 2 BGB"],
        },
        {"id": "p2", "label": "Angebot", "weight": 1.0, "keywords": ["Angebot"]},
        {"id": "p3", "label": "Annahme", "weight": 1.0, "keywords": ["Annahme"]},
        {
            "id": "p4",
            "label": "Kalkulationsirrtum unbeachtlich",
            "weight": 3.0,
            "keywords": ["Kalkulationsirrtum", "Motivirrtum"],
        },
    ]
}

VOLLSTAENDIG = """
A könnte gegen B einen Anspruch auf Kaufpreiszahlung aus § 433 Abs. 2 BGB haben.
Dazu müsste ein Kaufvertrag vorliegen.
Ein Angebot ist eine empfangsbedürftige Willenserklärung mit Rechtsbindungswillen.
Hier hat A ein Angebot abgegeben und B hat die Annahme erklärt.
Der Irrtum des B ist ein blosser Kalkulationsirrtum und damit unbeachtlich.
Mithin besteht der Anspruch aus § 433 Abs. 2 BGB.
"""

OHNE_KERNPUNKT = """
A könnte gegen B einen Anspruch auf Zahlung des Kaufpreises haben.
Ein Angebot ist eine empfangsbedürftige Willenserklärung mit Rechtsbindungswillen.
Hier hat A ein Angebot abgegeben und B hat die Annahme erklärt.
Mithin ist ein Vertrag geschlossen worden und der Anspruch besteht.
"""


@pytest.fixture
def evaluator():
    return HeuristicEvaluator()


def test_erwartungshorizont_wird_geparst():
    punkte = parse_expectation(ERWARTUNG)
    assert [p.id for p in punkte] == ["p1", "p2", "p3", "p4"]
    assert punkte[0].required is True
    assert punkte[1].required is False


def test_leerer_erwartungshorizont_faellt_nicht_um():
    assert parse_expectation(None) == []
    assert parse_expectation({}) == []


def test_vollstaendiges_gutachten_trifft_alle_pruefpunkte(evaluator):
    result = evaluator.evaluate(
        text=VOLLSTAENDIG, expectation=ERWARTUNG, structure=analyze(VOLLSTAENDIG)
    )
    assert all(c.hit for c in result.checkpoints)
    assert result.content_ratio == 1.0
    assert result.missed_required == []
    # Gedeckelt: ein Stichwortabgleich rechtfertigt kein Praedikat.
    assert result.points == HEURISTIK_MAX_PUNKTE
    assert result.note == "vollbefriedigend"
    assert "gedeckelt" in result.summary


def test_jeder_treffer_traegt_einen_beleg(evaluator):
    result = evaluator.evaluate(
        text=VOLLSTAENDIG, expectation=ERWARTUNG, structure=analyze(VOLLSTAENDIG)
    )
    # Ohne Beleg waere die Bewertung eine Blackbox - genau das wollen wir nicht.
    assert all(c.evidence for c in result.checkpoints if c.hit)


def test_normtreffer_zaehlen_auch_ohne_stichwort(evaluator):
    result = evaluator.evaluate(
        text=VOLLSTAENDIG, expectation=ERWARTUNG, structure=analyze(VOLLSTAENDIG)
    )
    p1 = next(c for c in result.checkpoints if c.id == "p1")
    assert p1.hit and "433" in p1.evidence


def test_fehlender_kernpunkt_deckelt_die_punktzahl(evaluator):
    result = evaluator.evaluate(
        text=OHNE_KERNPUNKT, expectation=ERWARTUNG, structure=analyze(OHNE_KERNPUNKT)
    )
    assert result.missed_required == ["Anspruchsgrundlage § 433 Abs. 2 BGB"]
    assert result.points <= 3.5
    assert result.note in ("mangelhaft", "ungenuegend")
    assert "Kernpruefpunkte fehlen" in result.summary


def test_nicht_getroffene_punkte_werden_begruendet(evaluator):
    result = evaluator.evaluate(
        text=OHNE_KERNPUNKT, expectation=ERWARTUNG, structure=analyze(OHNE_KERNPUNKT)
    )
    verfehlt = [c for c in result.checkpoints if not c.hit]
    assert verfehlt and all(c.comment for c in verfehlt)


def test_punkte_bleiben_in_der_jap_skala(evaluator):
    for text in (VOLLSTAENDIG, OHNE_KERNPUNKT, "Kurz." * 30):
        result = evaluator.evaluate(
            text=text, expectation=ERWARTUNG, structure=analyze(text)
        )
        assert 0.0 <= result.points <= HEURISTIK_MAX_PUNKTE
        # Halbe Punkte sind in der Praxis das feinste Raster.
        assert (result.points * 2) % 1 == 0


def test_bewertung_ist_deterministisch(evaluator):
    struktur = analyze(VOLLSTAENDIG)
    a = evaluator.evaluate(text=VOLLSTAENDIG, expectation=ERWARTUNG, structure=struktur)
    b = evaluator.evaluate(text=VOLLSTAENDIG, expectation=ERWARTUNG, structure=struktur)
    assert a.to_dict() == b.to_dict()


def test_ohne_llm_greift_die_heuristik(evaluator):
    result = evaluator.evaluate(
        text=VOLLSTAENDIG, expectation=ERWARTUNG, structure=analyze(VOLLSTAENDIG)
    )
    assert result.engine == "heuristik"


@pytest.mark.parametrize(
    ("punkte", "note"),
    [(0, "ungenuegend"), (2, "mangelhaft"), (5, "ausreichend"), (8, "befriedigend"),
     (11, "vollbefriedigend"), (14, "gut"), (17, "sehr gut")],
)
def test_notenskala(punkte, note):
    assert note_fuer_punkte(punkte) == note
