"""Normtext-Auslieferung: Zitat-Parser und GET /v1/normen."""

from __future__ import annotations

import json

import pytest

from app.config import REPO_ROOT, get_settings
from app.services import normen

FIXTURE_BGB = {
    "§ 433": {
        "titel": "Vertragstypische Pflichten beim Kaufvertrag",
        "text": (
            "(1) Durch den Kaufvertrag wird der Verkaeufer verpflichtet.\n"
            "(2) Der Kaeufer ist verpflichtet."
        ),
    },
    "§ 280": {"titel": "Schadensersatz", "text": "(1) Verletzt der Schuldner ..."},
}
FIXTURE_GG = {"Art. 12": {"titel": "", "text": "(1) Alle Deutschen ...\n(2) Niemand ..."}}
FIXTURE_EGBGB = {
    "Art. 246a § 1": {"titel": "Informationspflichten", "text": "(1) Der Unternehmer ..."}
}


@pytest.fixture
def fixture_dir(tmp_path, monkeypatch):
    d = tmp_path / "content"
    (d / "normtexte").mkdir(parents=True)
    for name, data in (("bgb", FIXTURE_BGB), ("gg", FIXTURE_GG), ("bgbeg", FIXTURE_EGBGB)):
        (d / "normtexte" / f"{name}.json").write_text(json.dumps(data), encoding="utf-8")
    monkeypatch.setenv("SUBSUMO_CONTENT_DIR", str(d))
    get_settings.cache_clear()
    normen.clear_cache()
    yield d
    get_settings.cache_clear()
    normen.clear_cache()


@pytest.mark.parametrize(
    ("zitat", "art", "nummer", "absatz", "satz", "gesetz"),
    [
        ("§ 433 Abs. 1 S. 1 BGB", "§", "433", "1", "1", "bgb"),
        ("§ 433 BGB", "§", "433", "", "", "bgb"),
        ("§§ 280 Abs. 1, 283 BGB", "§", "280", "1", "", "bgb"),
        ("Art. 12 Abs. 1 GG", "Art.", "12", "1", "", "gg"),
        ("Art. 12 I GG", "Art.", "12", "1", "", "gg"),
        ("Art. 28 Abs. 2 S. 1 GG", "Art.", "28", "2", "1", "gg"),
        ("§ 80 Abs. 5 VwGO", "§", "80", "5", "", "vwgo"),
        ("§ 223a StGB", "§", "223a", "", "", "stgb"),
        ("§§ 315 ff. InsO", "§", "315", "", "", "inso"),
        ("§ 14 VersG", "§", "14", "", "", "versg"),
    ],
)
def test_parse_zitat(zitat, art, nummer, absatz, satz, gesetz):
    z = normen.parse_zitat(zitat)
    assert z is not None
    assert (z.art, z.nummer, z.absatz, z.satz, z.gesetz_key) == (art, nummer, absatz, satz, gesetz)


def test_parse_zitat_egbgb_artikel_mit_paragraph():
    z = normen.parse_zitat("Art. 246a § 1 Abs. 2 EGBGB")
    assert z is not None
    assert z.norm_key == "Art. 246a § 1"
    assert z.absatz == "2"
    assert z.gesetz_key == "egbgb"


def test_parse_zitat_ohne_norm_und_landesrecht():
    assert normen.parse_zitat("Wortlaut der Norm") is None
    z = normen.parse_zitat("Art. 7 Abs. 2 LStVG")
    assert z is not None and z.gesetz_key == "" and z.gesetz_text == "LStVG"


def test_endpoint_braucht_login(client):
    assert client.get("/v1/normen", params={"zitat": "§ 433 BGB"}).status_code == 401


def test_endpoint_liefert_text_und_absatz(auth_client, fixture_dir):
    r = auth_client.get("/v1/normen", params={"zitat": "§ 433 Abs. 2 S. 1 BGB"})
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["gesetz"] == "BGB"
    assert body["norm"] == "§ 433"
    assert body["titel"].startswith("Vertragstypische")
    assert body["absatz"] == "2"
    assert "(2) Der Kaeufer" in body["text"]
    assert body["quelle_url"] == "https://www.gesetze-im-internet.de/bgb/__433.html"


def test_endpoint_artikel_und_mehrfachzitat(auth_client, fixture_dir):
    r = auth_client.get("/v1/normen", params={"zitat": "Art. 12 Abs. 1 GG"})
    assert r.status_code == 200
    assert r.json()["quelle_url"].endswith("/gg/art_12.html")
    r = auth_client.get("/v1/normen", params={"zitat": "§§ 280 Abs. 1, 283 BGB"})
    assert r.json()["norm"] == "§ 280"
    r = auth_client.get("/v1/normen", params={"zitat": "Art. 246a § 1 Abs. 2 EGBGB"})
    assert r.json()["norm"] == "Art. 246a § 1"


@pytest.mark.parametrize(
    "zitat", ["Art. 7 Abs. 2 LStVG", "§ 9999 BGB", "§ 433", "Wortlaut", "Art. 267 AEUV"]
)
def test_endpoint_unbekannt_404_mit_quelle(auth_client, fixture_dir, zitat):
    r = auth_client.get("/v1/normen", params={"zitat": zitat})
    assert r.status_code == 404
    detail = r.json()["detail"]
    assert detail["message"]
    assert detail["quelle_url"]


def test_echte_daten_zentrale_normen(auth_client):
    """Rauchtest gegen die eingecheckten Normtexte."""
    assert (REPO_ROOT / "content" / "normtexte" / "bgb.json").exists()
    for zitat, snippet in (
        ("§ 433 Abs. 1 S. 1 BGB", "Kaufvertrag"),
        ("Art. 12 Abs. 1 GG", "Beruf"),
        ("§ 80 Abs. 5 VwGO", "aufschiebende Wirkung"),
        ("§ 242 StGB", "fremde bewegliche Sache"),
        ("Art. 246a § 1 EGBGB", "Informationspflichten"),
    ):
        r = auth_client.get("/v1/normen", params={"zitat": zitat})
        assert r.status_code == 200, (zitat, r.text)
        assert snippet in r.json()["text"] + r.json()["titel"]


def test_import_parse_xml_artikel_kontext_und_absaetze():
    import importlib.util

    spec = importlib.util.spec_from_file_location(
        "normtexte_import", REPO_ROOT / "backend" / "scripts" / "normtexte_import.py"
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    xml = (
        "<dokumente>"
        "<norm><metadaten><jurabk>X</jurabk><gliederungseinheit><gliederungsbez>Art 246a"
        "</gliederungsbez><gliederungstitel>T</gliederungstitel></gliederungseinheit>"
        "<enbez>§ 1</enbez><titel>Info</titel></metadaten><textdaten><text><Content>"
        "<P>(1) Eins <DL><DT>1.</DT><DD><LA>a</LA></DD><DT>2.</DT><DD><LA>b</LA></DD></DL></P>"
        "<P>(2) Zwei</P></Content></text></textdaten></norm>"
        "<norm><metadaten><jurabk>X</jurabk><enbez>Anlage 1</enbez></metadaten>"
        "<textdaten><text><Content><P>x</P></Content></text></textdaten></norm>"
        "</dokumente>"
    ).encode()
    out = mod.parse_xml(xml)
    assert list(out) == ["Art. 246a § 1"]
    assert out["Art. 246a § 1"]["text"] == "(1) Eins\n1. a\n2. b\n(2) Zwei"


@pytest.mark.parametrize(
    ("zitat", "kategorie", "url_teil"),
    [
        ("Art. 267 AEUV", "eu", "CELEX:12016E/TXT"),
        ("Art. 4 EUV", "eu", "CELEX:12016M/TXT"),
        ("Art. 7 GRCh", "eu", "CELEX:12016P/TXT"),
        ("§ 12 GO NRW", "landesrecht", "https://recht.nrw.de"),
        ("Art. 7 Abs. 2 LStVG", "landesrecht", "gesetze-bayern.de"),
        ("§ 3 HSOG", "landesrecht", "rv.hessenrecht.hessen.de"),
        ("§ 3 LBO BW", "landesrecht", "landesrecht-bw.de"),
        ("§ 3 NPOG", "landesrecht", "voris.wolterskluwer-online.de"),
        ("§ 3 BauO Bln", "landesrecht", "gesetze.berlin.de"),
    ],
)
def test_404_unterscheidet_unionsrecht_und_landesrecht(auth_client, zitat, kategorie, url_teil):
    r = auth_client.get("/v1/normen", params={"zitat": zitat})
    assert r.status_code == 404
    d = r.json()["detail"]
    assert d["kategorie"] == kategorie
    assert url_teil in d["quelle_url"]
    if kategorie == "eu":
        assert d["message"] == "Unionsrecht – Text bei EUR-Lex"
        assert "eur-lex.europa.eu" in d["quelle_url"]
    else:
        assert d["message"].startswith("Landesrecht ")
        assert "Landesrechtsportal" in d["message"]


def test_404_landesrecht_ohne_land_generisch_ohne_link(auth_client):
    d = auth_client.get("/v1/normen", params={"zitat": "§ 5 PolG"}).json()["detail"]
    assert d["kategorie"] == "landesrecht"
    assert d["quelle_url"] is None
    assert len(d["portale"]) == 16


def test_mehrfachzitat_liefert_weitere(auth_client):
    r = auth_client.get("/v1/normen", params={"zitat": "§§ 214, 215 BauGB"})
    assert r.status_code == 200
    assert r.json()["norm"] == "§ 214"
    assert r.json()["weitere"] == ["§ 215 BauGB"]
    r = auth_client.get("/v1/normen", params={"zitat": "§ 433 Abs. 1 BGB"})
    assert r.json()["weitere"] == []
    r = auth_client.get("/v1/normen", params={"zitat": "§§ 280 Abs. 1 und 2 BGB"})
    assert r.json()["weitere"] == []
