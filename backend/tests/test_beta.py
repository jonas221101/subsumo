"""Geschlossene Testphase (docs/35): Allowlist, Konten per Skript, Feedback."""

from __future__ import annotations

import uuid

import pytest

from app.config import get_settings

CHRISTINA = "christina@uni-beispiel.de"
JONAS = "jonas@uni-beispiel.de"
PASSWORT = "sehr-geheim-2026"


@pytest.fixture
def beta(client, monkeypatch):
    """Allowlist mit zwei Adressen; Konten ueber das Server-Skript angelegt."""
    monkeypatch.setenv("SUBSUMO_BETA_ALLOWED_EMAILS", f" {CHRISTINA}, {JONAS.upper()} ")
    get_settings.cache_clear()
    from scripts import beta_users

    assert beta_users.set_password(CHRISTINA, PASSWORT, display_name="Christina") == "angelegt"
    assert beta_users.set_password(JONAS, PASSWORT) == "angelegt"
    yield client
    get_settings.cache_clear()


def _login(client, email: str, password: str = PASSWORT):
    return client.post("/v1/auth/login", json={"email": email, "password": password})


def test_registrierung_ist_in_der_testphase_geschlossen(beta):
    for email in (CHRISTINA, f"{uuid.uuid4().hex[:6]}@uni-beispiel.de"):
        resp = beta.post("/v1/auth/register", json={"email": email, "password": PASSWORT})
        assert resp.status_code == 403, resp.text
    assert beta.get("/v1/public/config").json()["registration_open"] is False


def test_nur_gelistete_konten_koennen_sich_anmelden(beta):
    assert _login(beta, CHRISTINA).status_code == 200
    assert _login(beta, JONAS).status_code == 200
    assert _login(beta, "Christina@Uni-Beispiel.de").status_code == 200  # Schreibweise egal
    assert _login(beta, CHRISTINA, "falsch-falsch").status_code == 401
    # Ein Konto, das nicht auf der Liste steht, bekommt dieselbe Meldung wie
    # ein falsches Passwort - kein Hinweis darauf, dass es existiert.
    from scripts import beta_users

    get_settings.cache_clear()
    with pytest.raises(ValueError, match="SUBSUMO_BETA_ALLOWED_EMAILS"):
        beta_users.set_password("fremd@uni-beispiel.de", PASSWORT)
    fremd = _login(beta, "fremd@uni-beispiel.de")
    assert fremd.status_code == 401
    assert fremd.json()["detail"] == _login(beta, CHRISTINA, "falsch-falsch").json()["detail"]


def test_token_verliert_zugang_wenn_adresse_von_der_liste_faellt(beta, monkeypatch):
    token = _login(beta, CHRISTINA).json()["access_token"]
    beta.headers["Authorization"] = f"Bearer {token}"
    assert beta.get("/v1/auth/me").status_code == 200
    monkeypatch.setenv("SUBSUMO_BETA_ALLOWED_EMAILS", JONAS)
    get_settings.cache_clear()
    assert beta.get("/v1/auth/me").status_code == 401


def test_passwort_neu_setzen_und_liste(beta):
    from scripts import beta_users

    assert beta_users.set_password(CHRISTINA, "neues-passwort-99") == "aktualisiert"
    assert _login(beta, CHRISTINA).status_code == 401
    assert _login(beta, CHRISTINA, "neues-passwort-99").status_code == 200
    with pytest.raises(ValueError, match="mindestens"):
        beta_users.set_password(CHRISTINA, "kurz")
    eintraege = {z["email"]: z for z in beta_users.list_users()}
    assert eintraege[CHRISTINA]["zugang"] is True
    assert eintraege[CHRISTINA]["display_name"] == "Christina"


def test_ohne_allowlist_bleibt_alles_offen(client):
    assert get_settings().beta_allowlist() == frozenset()
    assert client.get("/v1/public/config").json()["registration_open"] is True
    resp = client.post(
        "/v1/auth/register",
        json={"email": f"{uuid.uuid4().hex[:6]}@uni-beispiel.de", "password": PASSWORT},
    )
    assert resp.status_code == 201


def test_feedback_absenden_lesen_und_auf_dem_server_auswerten(beta):
    from scripts import beta_users

    beta.headers["Authorization"] = f"Bearer {_login(beta, CHRISTINA).json()['access_token']}"
    leer = beta.post("/v1/feedback", json={"category": "fehler", "message": "  "})
    assert leer.status_code == 422
    falsch = beta.post("/v1/feedback", json={"category": "lob", "message": "Super App"})
    assert falsch.status_code == 422
    resp = beta.post(
        "/v1/feedback",
        json={
            "category": "inhalt",
            "message": "  Die Definition zu § 263 StGB fehlt der Hinweis auf Dreiecksbetrug. ",
            "context": "Karten / Strafrecht",
            "platform": "web",
            "app_version": "1.4.0",
        },
    )
    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["category"] == "inhalt" and body["erledigt"] is False
    assert body["message"].startswith("Die Definition") and body["context"] == "Karten / Strafrecht"
    beta.post("/v1/feedback", json={"category": "idee", "message": "Dunkelmodus im Lernmodus"})

    mine = beta.get("/v1/feedback/mine").json()
    assert [m["category"] for m in mine] == ["idee", "inhalt"]

    # Der Betreiber liest auf dem Server, nicht ueber die API.
    assert beta.get("/v1/feedback").status_code in (404, 405)
    alle = beta_users.list_feedback()
    assert [e["von"] for e in alle] == [CHRISTINA, CHRISTINA]
    assert alle[1]["plattform"] == "web" and alle[1]["kontext"] == "Karten / Strafrecht"
    markdown = beta_users._markdown(alle)
    assert "Dreiecksbetrug" in markdown and "christina@uni-beispiel.de" in markdown
    assert beta_users.mark_done(alle[1]["id"]) is True
    assert beta_users.mark_done(999_999) is False
    assert [e["id"] for e in beta_users.list_feedback(offen=True)] == [alle[0]["id"]]
    assert beta.get("/v1/feedback/mine").json()[1]["erledigt"] is True


def test_feedback_tageslimit(beta, monkeypatch):
    monkeypatch.setenv("SUBSUMO_FEEDBACK_MAX_PER_DAY", "2")
    get_settings.cache_clear()
    beta.headers["Authorization"] = f"Bearer {_login(beta, JONAS).json()['access_token']}"
    for _ in range(2):
        assert beta.post("/v1/feedback", json={"message": "Kurz notiert"}).status_code == 201
    assert beta.post("/v1/feedback", json={"message": "Noch eins"}).status_code == 429


def test_feedback_braucht_login(client):
    assert client.post("/v1/feedback", json={"message": "anonym"}).status_code == 401


def test_cli_set_password_ueber_stdin(beta, monkeypatch, capsys):
    import io

    from scripts import beta_users

    monkeypatch.setattr("sys.stdin", io.StringIO("stdin-passwort-123\n"))
    assert beta_users.main(["set-password", JONAS, "--password-stdin", "--display-name", "J"]) == 0
    assert "aktualisiert" in capsys.readouterr().out
    assert _login(beta, JONAS, "stdin-passwort-123").status_code == 200
    assert beta_users.main(["list"]) == 0
    out = capsys.readouterr().out
    assert "geschlossen, 2 Adresse(n)" in out and JONAS in out
    assert beta_users.main(["feedback", "--json"]) == 0
    assert capsys.readouterr().out.strip() == "[]"


def test_feedback_steht_im_export_und_verschwindet_mit_dem_konto(beta):
    from scripts import beta_users

    beta.headers["Authorization"] = f"Bearer {_login(beta, CHRISTINA).json()['access_token']}"
    beta.post("/v1/feedback", json={"category": "idee", "message": "Export bitte als PDF"})
    export = beta.get("/v1/account/export").json()
    assert [f["message"] for f in export["feedback"]] == ["Export bitte als PDF"]
    assert (
        beta.post("/v1/account/delete", json={"password": PASSWORT, "confirm": True}).status_code
        == 200
    )
    assert beta_users.list_feedback() == []
