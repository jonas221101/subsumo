"""Tests der Content-Pipeline: das Format ist die Qualitaetssicherung."""

from pathlib import Path

import pytest

from app.config import REPO_ROOT
from app.services.content import load_content

VALID = """
topic:
  slug: test-thema
  area: zivilrecht
  title: Testthema
  relevance: 4
  stand: "2026-09"
cards:
  - slug: test-karte
    type: definition
    front: Frage
    back: Antwort
    quellen: ["BGB, amtliche Fassung"]
    stand: "2026-09"
"""


def write(tmp_path: Path, name: str, body: str) -> Path:
    (tmp_path / name).write_text(body, encoding="utf-8")
    return tmp_path


def test_echte_inhalte_sind_gueltig():
    """Die ausgelieferten Inhalte muessen jederzeit valide sein - das ist der
    Test, den die CI bei jedem Pull Request faehrt."""
    bundle = load_content(REPO_ROOT / "content")
    assert bundle.ok, bundle.errors
    assert len(bundle.topics) >= 3
    assert len(bundle.cards) >= 20
    assert len(bundle.cases) >= 3


def test_jeder_fall_hat_einen_erwartungshorizont():
    bundle = load_content(REPO_ROOT / "content")
    for case in bundle.cases:
        pruefpunkte = case["expectation"]["pruefpunkte"]
        assert pruefpunkte, case["slug"]
        assert any(p.get("required") for p in pruefpunkte), (
            f"{case['slug']}: kein einziger Pruefpunkt ist als zwingend markiert"
        )


def test_gueltige_datei_wird_gelesen(tmp_path):
    bundle = load_content(write(tmp_path, "t.yaml", VALID))
    assert bundle.ok
    assert bundle.cards[0]["topic_slug"] == "test-thema"


def test_fehlende_quelle_ist_ein_fehler(tmp_path):
    body = VALID.replace('    quellen: ["BGB, amtliche Fassung"]\n', "")
    bundle = load_content(write(tmp_path, "t.yaml", body))
    assert not bundle.ok
    assert any("quellen" in e for e in bundle.errors)


def test_fehlender_stand_ist_ein_fehler(tmp_path):
    body = "\n".join(z for z in VALID.splitlines() if "stand:" not in z)
    bundle = load_content(write(tmp_path, "t.yaml", body))
    assert not bundle.ok
    assert any("stand" in e for e in bundle.errors)


def test_karte_erbt_den_stand_des_themas(tmp_path):
    body = VALID.replace('    stand: "2026-09"\n', "")
    bundle = load_content(write(tmp_path, "t.yaml", body))
    assert bundle.ok, bundle.errors
    assert bundle.cards[0]["stand"] == "2026-09"


def test_ungueltiges_standdatum_wird_abgelehnt(tmp_path):
    bundle = load_content(write(tmp_path, "t.yaml", VALID.replace("2026-09", "irgendwann")))
    assert not bundle.ok
    assert any("YYYY-MM" in e for e in bundle.errors)


def test_unbekanntes_rechtsgebiet_wird_abgelehnt(tmp_path):
    bundle = load_content(write(tmp_path, "t.yaml", VALID.replace("zivilrecht", "seerecht")))
    assert not bundle.ok
    assert any("Rechtsgebiet" in e for e in bundle.errors)


def test_doppelte_slugs_werden_erkannt(tmp_path):
    write(tmp_path, "a.yaml", VALID)
    write(tmp_path, "b.yaml", VALID.replace("slug: test-thema", "slug: anderes-thema"))
    bundle = load_content(tmp_path)
    assert not bundle.ok
    assert any("bereits vergeben" in e for e in bundle.errors)


def test_veralteter_inhalt_erzeugt_eine_warnung_keinen_fehler(tmp_path):
    bundle = load_content(write(tmp_path, "t.yaml", VALID.replace("2026-09", "2015-01")))
    assert bundle.ok
    assert any("redaktionell pruefen" in w for w in bundle.warnings)


def test_fall_ohne_erwartungshorizont_wird_abgelehnt(tmp_path):
    body = VALID + """
faelle:
  - slug: test-fall
    title: Testfall
    facts: Ein Sachverhalt.
    quellen: ["Eigener Sachverhalt"]
    expectation:
      pruefpunkte: []
"""
    bundle = load_content(write(tmp_path, "t.yaml", body))
    assert not bundle.ok
    assert any("Erwartungshorizont" in e for e in bundle.errors)


def test_kaputtes_yaml_bricht_nicht_den_ganzen_lauf(tmp_path):
    write(tmp_path, "gut.yaml", VALID)
    write(tmp_path, "kaputt.yaml", "topic: [unterminated\n  - x")
    bundle = load_content(tmp_path)
    assert not bundle.ok
    assert any("YAML nicht lesbar" in e for e in bundle.errors)
    assert bundle.cards, "Die gueltige Datei muss trotzdem gelesen worden sein"


def test_fehlendes_verzeichnis_meldet_sauber(tmp_path):
    bundle = load_content(tmp_path / "gibt-es-nicht")
    assert not bundle.ok
    assert "nicht gefunden" in bundle.errors[0]


@pytest.mark.parametrize(
    ("suchen", "ersetzen"),
    [
        ("  - slug: test-karte", "  - ignoriert: test-karte"),
        ("    front: Frage", "    ignoriert: Frage"),
        ("    back: Antwort", "    ignoriert: Antwort"),
    ],
)
def test_pflichtfelder_der_karte(tmp_path, suchen, ersetzen):
    bundle = load_content(write(tmp_path, "t.yaml", VALID.replace(suchen, ersetzen)))
    assert not bundle.ok
    assert any("Pflichtfelder fehlen" in e for e in bundle.errors)
