"""Tests fuer den Werkbank-Slug-Katalog-Endpunkt (Ticket 1, SUB-366).

Siehe docs/27-werkbank-spezifikation.md Abschnitt 4.2 und 7.
"""

from __future__ import annotations

from app.services.slug_catalog import SLUG_CATALOG_SCHEMA_ID


def test_katalog_ist_auf_rechtsgebiet_begrenzt(client):
    zivilrecht = client.get("/v1/werkbank/slug-catalog", params={"area": "zivilrecht"})
    strafrecht = client.get("/v1/werkbank/slug-catalog", params={"area": "strafrecht"})
    assert zivilrecht.status_code == 200, zivilrecht.text
    assert strafrecht.status_code == 200, strafrecht.text

    zr_topics = client.get("/v1/content/topics", params={"area": "zivilrecht"}).json()
    zr_schemata = client.get("/v1/content/schemata", params={"area": "zivilrecht"}).json()

    zr_body = zivilrecht.json()
    sr_body = strafrecht.json()

    # Nicht der gesamte Content-Bestand, sondern nur das genannte Rechtsgebiet.
    assert set(zr_body["topic_slugs"]) == {t["slug"] for t in zr_topics}
    assert set(zr_body["schema_slugs"]) == {s["slug"] for s in zr_schemata}
    assert zr_body["topic_slugs"], "Zivilrecht sollte Themen enthalten"

    # Zwei verschiedene Rechtsgebiete duerfen sich nicht ueberschneiden.
    assert set(zr_body["topic_slugs"]).isdisjoint(sr_body["topic_slugs"])


def test_antwort_traegt_versionsfeld(client):
    response = client.get("/v1/werkbank/slug-catalog", params={"area": "strafrecht"})
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["schema"] == SLUG_CATALOG_SCHEMA_ID == "subsumo.werkbank.slug_catalog.v1"
    assert body["area"] == "strafrecht"


def test_unbekanntes_rechtsgebiet_liefert_sauberen_fehler_statt_vollliste(client):
    response = client.get("/v1/werkbank/slug-catalog", params={"area": "atomrecht"})
    assert response.status_code == 422
    assert "topic_slugs" not in response.json()


def test_leeres_rechtsgebiet_liefert_sauberen_fehler(client):
    response = client.get("/v1/werkbank/slug-catalog", params={"area": ""})
    assert response.status_code == 422
    assert "topic_slugs" not in response.json()


def test_fehlendes_rechtsgebiet_liefert_validierungsfehler(client):
    response = client.get("/v1/werkbank/slug-catalog")
    assert response.status_code == 422
