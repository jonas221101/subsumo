"""Jeder Landesrecht-Fall liefert nach Abgabe Punktzahl und Erwartungshorizont (Wellen-3-Befund)."""

from pathlib import Path

import pytest
import yaml

from app.config import REPO_ROOT

FAELLE = [
    (fall["slug"], fall)
    for f in sorted((Path(REPO_ROOT) / "content" / "landesrecht").glob("*.yaml"))
    for fall in (yaml.safe_load(f.read_text(encoding="utf-8")).get("faelle") or [])
]


def test_alle_landesrecht_faelle_haben_erwartungshorizont():
    assert FAELLE
    for slug, fall in FAELLE:
        punkte = (fall.get("expectation") or {}).get("pruefpunkte") or []
        assert punkte, slug
        assert all(p.get("keywords") for p in punkte), slug
        assert fall.get("steps") and fall.get("facts"), slug


def test_bauauftrag_fall_liefert_punkte_und_horizont(auth_client):
    slug, fall = next(f for f in FAELLE if f[0] == "sh-fall-kr-mitwirkungsverbot")
    muster = " ".join(s["erwartung"] for s in fall["steps"])
    r = auth_client.post(f"/v1/cases/{slug}/submit", json={"text": muster, "mode": "uebung"})
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["evaluation"]["points"] > 0
    assert body["expectation"]["pruefpunkte"]
    assert body["evaluation"]["checkpoints"]


@pytest.mark.parametrize("slug", ["sh-fall-kr-mitwirkungsverbot"])
def test_analyze_endpoint_nutzt_rechtsgebiet(auth_client, slug):
    text = "Der Beschluss könnte rechtswidrig sein. Hier stimmte V mit. " * 6
    r = auth_client.post("/v1/gutachten/analyze", json={"text": text, "case_slug": slug})
    assert r.status_code == 200, r.text
    hints = " ".join(f["hint"] for f in r.json()["findings"])
    assert "Angebot" not in hints
