"""Lernmodul-Contentformat (docs/34, Abschnitt 2): Validator, Negativ-Fixtures, Seed."""

from __future__ import annotations

from pathlib import Path

import pytest
import yaml
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.db import Base
from app.models import Lernerlebnis, Lernskript, Visualisierung
from app.services.content import load_content, seed


def gueltig() -> dict:
    return {
        "topic": {"slug": "t", "area": "zivilrecht", "title": "T", "stand": "2026-11"},
        "cards": [{"slug": "k1", "front": "F", "back": "B", "quellen": ["Q"], "stand": "2026-11"}],
        "schemata": [
            {
                "slug": "s1",
                "title": "S",
                "quellen": ["Q"],
                "stand": "2026-11",
                "steps": [{"label": "I. Eins"}, {"label": "II. Zwei"}],
            }
        ],
        "lernskript": {
            "slug": "ls1",
            "title": "Skript",
            "quellen": ["Q"],
            "stand": "2026-11",
            "abschnitte": [
                {
                    "titel": "A",
                    "text": "Text",
                    "card_slugs": ["k1"],
                    "schema_slug": "s1",
                    "checkpoint": {"type": "luecke", "frage": "x ___", "antworten": ["a"]},
                },
                {
                    "titel": "B",
                    "text": "Text",
                    "checkpoint": {
                        "type": "frage",
                        "frage": "?",
                        "optionen": ["a", "b"],
                        "richtig": 0,
                    },
                },
            ],
        },
        "lernerlebnisse": [
            {
                "slug": "fall1",
                "type": "gefuehrter_fall",
                "title": "Fall",
                "quellen": ["Q"],
                "stand": "2026-11",
                "start": "n1",
                "knoten": [
                    {
                        "id": "n1",
                        "frage": "?",
                        "optionen": [
                            {"text": "a", "naechster": "n2"},
                            {"text": "b", "naechster": "ende_ok"},
                        ],
                    },
                    {
                        "id": "n2",
                        "frage": "?",
                        "optionen": [
                            {"text": "a", "naechster": "ende_ok"},
                            {"text": "b", "naechster": "ende_neu"},
                        ],
                    },
                ],
                "ende": {
                    "ende_ok": {"ergebnis": "bestanden", "text": "ok"},
                    "ende_neu": {"ergebnis": "wiederholen", "text": "nochmal"},
                },
            },
            {
                "slug": "sort1",
                "type": "sortieraufgabe",
                "title": "Sortieren",
                "quellen": ["Q"],
                "stand": "2026-11",
                "schema_slug": "s1",
                "ebene": 1,
            },
            {
                "slug": "check1",
                "type": "luecken_check",
                "title": "Check",
                "quellen": ["Q"],
                "stand": "2026-11",
                "fragen": [{"type": "luecke", "frage": "___", "antworten": ["a"]}],
            },
        ],
        "visualisierungen": [
            {
                "slug": "fluss1",
                "type": "flussdiagramm",
                "title": "F",
                "quellen": ["Q"],
                "stand": "2026-11",
                "schema_slug": "s1",
            },
            {
                "slug": "baum1",
                "type": "baum",
                "title": "B",
                "quellen": ["Q"],
                "stand": "2026-11",
                "schema_slug": "s1",
            },
            {
                "slug": "zeit1",
                "type": "zeitstrahl",
                "title": "Z",
                "quellen": ["Q"],
                "stand": "2026-11",
                "punkte": [{"label": "a", "hinweis": "h"}, {"label": "b"}],
            },
        ],
    }


def laden(tmp_path: Path, data: dict, name: str = "t.yaml"):
    (tmp_path / name).write_text(yaml.safe_dump(data, allow_unicode=True), encoding="utf-8")
    return load_content(tmp_path)


def test_gueltiges_bundle_wird_geladen(tmp_path):
    bundle = laden(tmp_path, gueltig())
    assert bundle.ok, bundle.errors
    assert len(bundle.lernskripte) == 1
    assert len(bundle.lernerlebnisse) == 3
    assert len(bundle.visualisierungen) == 3
    assert bundle.lernskripte[0]["topic_slug"] == "t"


def _del(path: list):
    def mutate(d):
        obj = d
        for p in path[:-1]:
            obj = obj[p]
        del obj[path[-1]]

    return mutate


def _set(path: list, value):
    def mutate(d):
        obj = d
        for p in path[:-1]:
            obj = obj[p]
        obj[path[-1]] = value

    return mutate


def _ohne_stand(path: list):
    """``stand`` erbt vom Thema (wie bei Karten) - fuer den Negativtest beide entfernen."""

    def mutate(d):
        del d["topic"]["stand"]
        _del(path)(d)

    return mutate


def _fall(key, value=None, delete=False):
    return _del(["lernerlebnisse", 0, key]) if delete else _set(["lernerlebnisse", 0, key], value)


FALL_N2 = ["lernerlebnisse", 0, "knoten", 1]

NEGATIV = [
    # Pflichtfelder
    ("skript_ohne_quellen", _del(["lernskript", "quellen"]), "quellen"),
    ("skript_ohne_abschnitte", _set(["lernskript", "abschnitte"], []), "abschnitte"),
    ("abschnitt_ohne_text", _del(["lernskript", "abschnitte", 0, "text"]), "text"),
    ("skript_ohne_stand", _ohne_stand(["lernskript", "stand"]), "'stand' fehlt"),
    ("fall_ohne_quellen", _fall("quellen", delete=True), "quellen"),
    ("fall_ohne_start", _fall("start", delete=True), "start"),
    ("viz_ohne_quellen", _del(["visualisierungen", 0, "quellen"]), "quellen"),
    ("viz_ohne_stand", _ohne_stand(["visualisierungen", 0, "stand"]), "'stand' fehlt"),
    ("zeitstrahl_ohne_punkte", _del(["visualisierungen", 2, "punkte"]), "punkte"),
    ("zeitstrahl_ein_punkt", _set(["visualisierungen", 2, "punkte"], [{"label": "a"}]), "punkte"),
    ("sortier_ohne_schema", _del(["lernerlebnisse", 1, "schema_slug"]), "schema_slug"),
    ("sortier_ebene_2", _set(["lernerlebnisse", 1, "ebene"], 2), "ebene"),
    ("fluss_ohne_schema", _del(["visualisierungen", 0, "schema_slug"]), "schema_slug"),
    # unbekannte Typen
    ("unbekannter_erlebnistyp", _set(["lernerlebnisse", 0, "type"], "quiz"), "Lernerlebnis-Typ"),
    ("unbekannter_viztyp", _set(["visualisierungen", 0, "type"], "tortendiagramm"), "Typ"),
    (
        "unbekannter_checkpointtyp",
        _set(["lernskript", "abschnitte", 0, "checkpoint", "type"], "essay"),
        "checkpoint",
    ),
    (
        "frage_richtig_ausserhalb",
        _set(["lernskript", "abschnitte", 1, "checkpoint", "richtig"], 5),
        "richtig",
    ),
    (
        "luecke_ohne_antworten",
        _set(["lernerlebnisse", 2, "fragen", 0, "antworten"], []),
        "antworten",
    ),
    # haengende Referenzen
    (
        "skript_unbekannte_karte",
        _set(["lernskript", "abschnitte", 0, "card_slugs"], ["gibt-es-nicht"]),
        "Card-Slug",
    ),
    (
        "skript_unbekanntes_schema",
        _set(["lernskript", "abschnitte", 0, "schema_slug"], "gibt-es-nicht"),
        "unbekanntes Schema",
    ),
    ("sortier_unbekanntes_schema", _set(["lernerlebnisse", 1, "schema_slug"], "x"), "unbekanntes"),
    ("baum_unbekanntes_schema", _set(["visualisierungen", 1, "schema_slug"], "x"), "unbekanntes"),
    # Slug-Kollision mit bestehender Karte
    ("slug_kollision", _set(["visualisierungen", 0, "slug"], "k1"), "bereits vergeben"),
    # Graph
    (
        "haengendes_naechster",
        _set(FALL_N2 + ["optionen", 0, "naechster"], "nirgendwo"),
        "unbekanntes Ziel",
    ),
    ("start_unbekannt", _fall("start", "nirgendwo"), "start"),
    (
        "unerreichbarer_knoten",
        lambda d: d["lernerlebnisse"][0]["knoten"].append(
            {
                "id": "waise",
                "frage": "?",
                "optionen": [
                    {"text": "a", "naechster": "ende_ok"},
                    {"text": "b", "naechster": "ende_ok"},
                ],
            }
        ),
        "unerreichbar",
    ),
    ("zyklus", _set(FALL_N2 + ["optionen", 1, "naechster"], "n1"), "Zyklus"),
    ("selbstschleife", _set(FALL_N2 + ["optionen", 1, "naechster"], "n2"), "Zyklus"),
    (
        "ende_ungueltiges_ergebnis",
        _set(["lernerlebnisse", 0, "ende", "ende_ok", "ergebnis"], "gewonnen"),
        "ergebnis",
    ),
    (
        "knoten_nur_eine_option",
        _set(FALL_N2 + ["optionen"], [{"text": "a", "naechster": "ende_ok"}]),
        "optionen",
    ),
]


@pytest.mark.parametrize(("name", "mutation", "meldung"), NEGATIV, ids=[n[0] for n in NEGATIV])
def test_kaputtes_fixture_erzeugt_fehler(tmp_path, name, mutation, meldung):
    data = gueltig()
    mutation(data)
    bundle = laden(tmp_path, data)
    assert not bundle.ok, f"{name}: kein Fehler gemeldet"
    assert any(meldung in e for e in bundle.errors), bundle.errors


def test_schema_eines_anderen_themas_wird_abgelehnt(tmp_path):
    a = gueltig()
    b = gueltig()
    b["topic"]["slug"] = "u"
    # Alles in Thema u bekommt eigene Slugs, nur die Sortieraufgabe zeigt auf s1 (Thema t).
    for block in ("cards", "schemata"):
        b[block][0]["slug"] += "-u"
    b["lernskript"]["slug"] = "ls-u"
    b["lernskript"]["abschnitte"][0]["card_slugs"] = ["k1-u"]
    b["lernskript"]["abschnitte"][0]["schema_slug"] = "s1-u"
    for e in b["lernerlebnisse"]:
        e["slug"] += "-u"
    for v in b["visualisierungen"]:
        v["slug"] += "-u"
    for v in b["visualisierungen"][:2]:
        v["schema_slug"] = "s1-u"
    b["lernerlebnisse"][1]["schema_slug"] = "s1"  # Thema t!
    (tmp_path / "a.yaml").write_text(yaml.safe_dump(a, allow_unicode=True), encoding="utf-8")
    (tmp_path / "b.yaml").write_text(yaml.safe_dump(b, allow_unicode=True), encoding="utf-8")
    bundle = load_content(tmp_path)
    assert any("gehoert zu Thema 't'" in e for e in bundle.errors), bundle.errors


def test_schema_aus_alphabetisch_spaeterer_datei_wird_akzeptiert(tmp_path):
    data = gueltig()
    schemata = data.pop("schemata")
    (tmp_path / "a.yaml").write_text(yaml.safe_dump(data, allow_unicode=True), encoding="utf-8")
    zz = {"topic": dict(data["topic"]), "schemata": schemata}
    zz["topic"]["slug"] = "t"
    # gleiches Thema in zweiter Datei waere ein Duplikat; Querverweis muss trotzdem aufloesen
    (tmp_path / "z.yaml").write_text(yaml.safe_dump(zz, allow_unicode=True), encoding="utf-8")
    bundle = load_content(tmp_path)
    assert bundle.ok, bundle.errors


def test_veralteter_stand_ist_nur_warnung(tmp_path):
    data = gueltig()
    data["lernskript"]["stand"] = "2020-01"
    bundle = laden(tmp_path, data)
    assert bundle.ok, bundle.errors
    assert any("redaktionell" in w and "lernskript" in w for w in bundle.warnings)


def test_seed_ist_idempotent(tmp_path):
    bundle = laden(tmp_path, gueltig())
    engine = create_engine(f"sqlite:///{tmp_path}/s.db")
    Base.metadata.create_all(engine)
    db = sessionmaker(bind=engine)()
    for _ in range(2):
        stats = seed(db, bundle)
    assert (stats["lernskripte"], stats["lernerlebnisse"], stats["visualisierungen"]) == (1, 3, 3)
    assert db.query(Lernskript).count() == 1
    assert db.query(Lernerlebnis).count() == 3
    assert db.query(Visualisierung).count() == 3
    fall = db.query(Lernerlebnis).filter_by(slug="fall1").one()
    assert fall.type == "gefuehrter_fall"
    assert fall.data["start"] == "n1" and "slug" not in fall.data
    zeit = db.query(Visualisierung).filter_by(slug="zeit1").one()
    assert zeit.schema_slug is None and len(zeit.data["punkte"]) == 2
    assert db.query(Visualisierung).filter_by(slug="baum1").one().schema_slug == "s1"
