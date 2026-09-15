"""Tests fuer das deterministische Normzitat-Gate (docs/08-ki-redaktion.md,
Abschnitt "Was der Reviewer nicht leistet"). Kein LLM, keine Netzwerkfahrt -
reine Funktionspruefung gegen die kuratierte Positivliste.
"""

from __future__ import annotations

import pytest

from app.services.redaktion.norm_gate import check_norms, pruefe_zitat

GUELTIGE_ZITATE = [
    "§ 242 StGB",
    "§ 433 Abs. 2 BGB",
    "§ 25 Abs. 1 Var. 1 StGB",
    "Art. 12 Abs. 1 GG",
    "Art. 93 Abs. 1 Nr. 4a GG",
    "§§ 166-181 BGB",
    "§ 90 Abs. 1 BVerfGG",
    "§ 35 VwVfG",
    "§ 42 Abs. 1 Var. 1 VwGO",
]

UNGUELTIGE_ZITATE = [
    ("§ 9999 BGB", "ausserhalb des bekannten Bereichs"),
    ("§ 5 UrhG", "Unbekanntes Gesetzeskuerzel"),
    ("Art. 242 StGB", "wird mit"),
    ("§ 242 Abs. StGB", "Unerwartetes Element"),
    ("BGB § 242", "Unbekanntes Zitatformat"),
    ("§ BGB", "zu kurz"),
]


@pytest.mark.parametrize("zitat", GUELTIGE_ZITATE)
def test_pruefe_zitat_akzeptiert_bekannte_normen(zitat: str):
    ergebnis = pruefe_zitat(zitat)
    assert ergebnis.ok is True, ergebnis.grund


@pytest.mark.parametrize("zitat,erwarteter_grund", UNGUELTIGE_ZITATE)
def test_pruefe_zitat_lehnt_unplausible_zitate_ab(zitat: str, erwarteter_grund: str):
    ergebnis = pruefe_zitat(zitat)
    assert ergebnis.ok is False
    assert erwarteter_grund in ergebnis.grund


def test_check_norms_findet_zitate_in_karten_schemata_und_faellen():
    draft = {
        "cards": [{"slug": "k1", "norms": ["§ 242 StGB", "§ 9999 BGB"]}],
        "schemata": [{"slug": "s1", "norms": ["Art. 999 GG"]}],
        "faelle": [
            {
                "slug": "f1",
                "expectation": {"pruefpunkte": [{"id": "p1", "norms": ["§ 5 UrhG"]}]},
            }
        ],
    }
    fehler = check_norms(draft)
    assert len(fehler) == 3
    assert any("cards[k1]" in f for f in fehler)
    assert any("schemata[s1]" in f for f in fehler)
    assert any("faelle[f1].pruefpunkte[0]" in f for f in fehler)


def test_check_norms_leer_bei_entwurf_ohne_beanstandungen():
    draft = {
        "cards": [{"slug": "k1", "norms": ["§ 242 StGB"]}],
        "schemata": [{"slug": "s1", "norms": ["§ 433 Abs. 1 BGB"]}],
        "faelle": [],
    }
    assert check_norms(draft) == []


def test_check_norms_ignoriert_karten_ohne_norms_feld():
    draft = {"cards": [{"slug": "k1"}], "schemata": [], "faelle": []}
    assert check_norms(draft) == []
