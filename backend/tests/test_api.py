"""Integrationstests gegen die echte API und die echten Inhalte aus content/."""

from __future__ import annotations

import uuid
from datetime import UTC, date, datetime, timedelta


def test_health(client):
    assert client.get("/health").json()["status"] == "ok"


# --------------------------------------------------------------------------- #
# Auth
# --------------------------------------------------------------------------- #


def test_registrierung_login_und_profil(client):
    email = f"{uuid.uuid4().hex[:8]}@uni-beispiel.de"
    reg = client.post("/v1/auth/register", json={"email": email, "password": "examen2029!"})
    assert reg.status_code == 201

    login = client.post("/v1/auth/login", json={"email": email, "password": "examen2029!"})
    assert login.status_code == 200
    token = login.json()["access_token"]

    me = client.get("/v1/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me.status_code == 200
    assert me.json()["email"] == email


def test_doppelte_registrierung_wird_abgelehnt(client):
    payload = {"email": "doppelt@uni-beispiel.de", "password": "examen2029!"}
    assert client.post("/v1/auth/register", json=payload).status_code == 201
    assert client.post("/v1/auth/register", json=payload).status_code == 409


def test_falsches_passwort_verraet_nicht_ob_der_nutzer_existiert(client):
    client.post(
        "/v1/auth/register", json={"email": "a@uni-beispiel.de", "password": "examen2029!"}
    )
    bekannt = client.post(
        "/v1/auth/login", json={"email": "a@uni-beispiel.de", "password": "falsch123"}
    )
    unbekannt = client.post(
        "/v1/auth/login", json={"email": "b@uni-beispiel.de", "password": "falsch123"}
    )
    assert bekannt.status_code == unbekannt.status_code == 401
    assert bekannt.json()["detail"] == unbekannt.json()["detail"]


def test_geschuetzte_endpunkte_ohne_token(client):
    assert client.get("/v1/cards/due").status_code == 401
    assert client.get("/v1/auth/me", headers={"Authorization": "Bearer muell"}).status_code == 401


# --------------------------------------------------------------------------- #
# Inhalte
# --------------------------------------------------------------------------- #


def test_inhalte_werden_beim_start_geladen(client):
    manifest = client.get("/v1/content/manifest").json()
    assert manifest["topics"] >= 3
    assert manifest["cards"] >= 20
    assert manifest["schemata"] >= 5
    assert manifest["cases"] >= 3


def test_alle_drei_rechtsgebiete_sind_vertreten(client):
    areas = {t["area"] for t in client.get("/v1/content/topics").json()}
    assert areas == {"zivilrecht", "strafrecht", "oeffentliches-recht"}


def test_schemata_liefern_verschachtelte_pruefungsschritte(client):
    schemata = client.get("/v1/content/schemata", params={"area": "zivilrecht"}).json()
    kaufpreis = next(s for s in schemata if "433" in s["title"])
    assert kaufpreis["steps"][0]["label"].startswith("I.")
    assert kaufpreis["steps"][0]["children"][0]["children"], "Verschachtelung fehlt"


def test_jede_karte_traegt_quelle_und_stand(client):
    for card in client.get("/v1/content/cards").json():
        assert card["sources"], f"{card['slug']} ohne Quellenangabe"
        assert card["stand"], f"{card['slug']} ohne Stand"


def test_fall_liefert_den_erwartungshorizont_nicht_vorab(client, auth_client):
    case = auth_client.get("/v1/cases/zr-fall-sonderpreis").json()
    assert "facts" in case
    assert "expectation" not in case, "Der Erwartungshorizont darf vorab nicht sichtbar sein"


# --------------------------------------------------------------------------- #
# Lernschleife
# --------------------------------------------------------------------------- #


def test_neue_karten_kommen_nach_pruefungsrelevanz(auth_client):
    cards = auth_client.get("/v1/cards/due", params={"limit": 5, "new_limit": 5}).json()
    assert len(cards) == 5
    assert all(c["state"] == "new" for c in cards)


def test_review_batch_plant_karte_neu_ein(auth_client):
    card = auth_client.get("/v1/cards/due", params={"limit": 1}).json()[0]
    now = datetime.now(UTC)
    response = auth_client.post(
        "/v1/reviews/batch",
        json={
            "reviews": [
                {
                    "client_id": uuid.uuid4().hex,
                    "card_slug": card["slug"],
                    "rating": 4,
                    "reviewed_at": now.isoformat(),
                    "elapsed_ms": 4200,
                }
            ]
        },
    )
    body = response.json()
    assert body["applied"] == 1
    assert body["results"][0]["state"] == "review"
    assert body["results"][0]["stability_days"] > 0


def test_review_batch_ist_idempotent(auth_client):
    """Der Offline-Client sendet nach einem Netzabbruch erneut - das darf den
    Kartenzustand nicht ein zweites Mal veraendern."""
    card = auth_client.get("/v1/cards/due", params={"limit": 1}).json()[0]
    review = {
        "client_id": "fester-client-key-123",
        "card_slug": card["slug"],
        "rating": 3,
        "reviewed_at": datetime.now(UTC).isoformat(),
    }
    erste = auth_client.post("/v1/reviews/batch", json={"reviews": [review]}).json()
    zweite = auth_client.post("/v1/reviews/batch", json={"reviews": [review]}).json()
    assert erste["applied"] == 1 and erste["duplicates"] == 0
    assert zweite["applied"] == 0 and zweite["duplicates"] == 1


def test_unbekannte_karten_werden_gemeldet_statt_zu_kippen(auth_client):
    body = auth_client.post(
        "/v1/reviews/batch",
        json={
            "reviews": [
                {
                    "client_id": uuid.uuid4().hex,
                    "card_slug": "gibt-es-nicht",
                    "rating": 3,
                    "reviewed_at": datetime.now(UTC).isoformat(),
                }
            ]
        },
    ).json()
    assert body["applied"] == 0
    assert body["unknown_cards"] == ["gibt-es-nicht"]


def test_gelernte_karte_ist_nicht_sofort_wieder_faellig(auth_client):
    card = auth_client.get("/v1/cards/due", params={"limit": 1, "new_limit": 1}).json()[0]
    auth_client.post(
        "/v1/reviews/batch",
        json={
            "reviews": [
                {
                    "client_id": uuid.uuid4().hex,
                    "card_slug": card["slug"],
                    "rating": 4,
                    "reviewed_at": datetime.now(UTC).isoformat(),
                }
            ]
        },
    )
    faellig = auth_client.get("/v1/cards/due", params={"limit": 50, "new_limit": 0}).json()
    assert card["slug"] not in [c["slug"] for c in faellig]


def test_coverage_startet_bei_null_und_bleibt_ehrlich(auth_client):
    coverage = auth_client.get("/v1/progress/coverage").json()
    assert coverage["weighted_coverage"] == 0.0
    assert len(coverage["topics"]) >= 3
    assert all(t["cards_total"] > 0 for t in coverage["topics"])

    # Eine einzelne gute Antwort macht noch keine Beherrschung.
    card = auth_client.get("/v1/cards/due", params={"limit": 1}).json()[0]
    auth_client.post(
        "/v1/reviews/batch",
        json={
            "reviews": [
                {
                    "client_id": uuid.uuid4().hex,
                    "card_slug": card["slug"],
                    "rating": 3,
                    "reviewed_at": datetime.now(UTC).isoformat(),
                }
            ]
        },
    )
    assert auth_client.get("/v1/progress/coverage").json()["weighted_coverage"] == 0.0


def test_forecast_liefert_tagesbelastung(auth_client):
    card = auth_client.get("/v1/cards/due", params={"limit": 1}).json()[0]
    auth_client.post(
        "/v1/reviews/batch",
        json={
            "reviews": [
                {
                    "client_id": uuid.uuid4().hex,
                    "card_slug": card["slug"],
                    "rating": 4,
                    "reviewed_at": datetime.now(UTC).isoformat(),
                }
            ]
        },
    )
    forecast = auth_client.get("/v1/progress/forecast", params={"days": 30}).json()
    assert len(forecast["due_per_day"]) == 30
    assert sum(forecast["due_per_day"]) == 1


# --------------------------------------------------------------------------- #
# Gutachten
# --------------------------------------------------------------------------- #

GUTACHTEN_GUT = """
K könnte gegen V einen Anspruch auf Übergabe und Übereignung des Rennrads aus
§ 433 Abs. 1 S. 1 BGB haben.
Dazu müsste zwischen K und V ein wirksamer Kaufvertrag zustande gekommen sein.
Ein Kaufvertrag kommt durch Angebot und Annahme zustande.
Fraglich ist, ob bereits die Schaufensterauslage ein Angebot darstellt.
Ein Angebot ist eine empfangsbedürftige Willenserklärung, die alle wesentlichen
Vertragsbestandteile enthält und mit Rechtsbindungswillen abgegeben wird.
Hier fehlt es am Rechtsbindungswillen des V, da er sich nicht gegenüber einer
unbestimmten Vielzahl von Interessenten binden will.
Die Auslage ist somit lediglich eine invitatio ad offerendum.
Das Angebot hat vielmehr K abgegeben, indem er erklärte, das Rad für 500 Euro
zu nehmen.
V hat dieses Angebot mit den Worten "Abgemacht" vorliegend angenommen.
Mithin ist ein Kaufvertrag über 500 Euro zustande gekommen.
Der Vertrag könnte jedoch nach § 142 Abs. 1 BGB von Anfang an nichtig sein.
Dazu müsste V einen Anfechtungsgrund haben.
In Betracht kommt ein Erklärungsirrtum nach § 119 Abs. 1 BGB.
Hier wollte V jedoch genau die Zahl erklären, die er erklärt hat.
Sein Irrtum lag allein in der Kalkulation und damit im Beweggrund.
Ein solcher Motivirrtum ist unbeachtlich.
Somit hat V keinen Anfechtungsgrund.
Folglich hat K gegen V einen Anspruch auf Übergabe und Übereignung aus
§ 433 Abs. 1 S. 1 BGB.
"""

GUTACHTEN_SCHLECHT = """
Da V das Rad ins Schaufenster gestellt hat, ist ein Vertrag zustande gekommen.
K bekommt das Rad, weil er es bezahlt hat.
Die Anfechtung geht nicht, weil V sich verrechnet hat und das sein Problem ist.
Der Anspruch besteht also und V muss liefern, da er sich an sein Preisschild
halten muss und nichts anderes vereinbart wurde.
"""


def test_analyse_bewertet_sauberes_gutachten_hoch(auth_client):
    report = auth_client.post(
        "/v1/gutachten/analyze",
        json={"text": GUTACHTEN_GUT, "case_slug": "zr-fall-sonderpreis"},
    ).json()
    assert report["score"] >= 75, report
    assert report["counts"]["obersatz"] >= 4
    assert any("433" in n for n in report["norms"])


def test_analyse_erkennt_urteilsstil(auth_client):
    report = auth_client.post("/v1/gutachten/analyze", json={"text": GUTACHTEN_SCHLECHT}).json()
    codes = [f["code"] for f in report["findings"]]
    assert "urteilsstil" in codes
    assert report["score"] < 50


def test_analyse_mit_unbekanntem_fall_gibt_404(auth_client):
    response = auth_client.post(
        "/v1/gutachten/analyze", json={"text": GUTACHTEN_GUT, "case_slug": "gibt-es-nicht"}
    )
    assert response.status_code == 404


def test_abgabe_bewertet_gegen_den_erwartungshorizont(auth_client):
    response = auth_client.post(
        "/v1/cases/zr-fall-sonderpreis/submit",
        json={"text": GUTACHTEN_GUT, "mode": "uebung", "duration_s": 2400},
    )
    assert response.status_code == 201
    body = response.json()
    evaluation = body["evaluation"]

    assert 0 <= evaluation["points"] <= 18
    assert evaluation["note"]
    assert evaluation["missed_required"] == [], evaluation
    assert evaluation["points"] >= 9, evaluation
    # Ohne KI-Korrektur wird gedeckelt - kein geschenktes Praedikat.
    assert evaluation["points"] <= 11, evaluation
    # Jeder Punkt muss auf einen Pruefpunkt zurueckfuehrbar sein.
    assert len(evaluation["checkpoints"]) == 6
    assert all("label" in c for c in evaluation["checkpoints"])
    # Erst nach der Abgabe gibt es den Erwartungshorizont.
    assert body["expectation"]["pruefpunkte"]
    assert "Rechtsberatung" in evaluation["disclaimer"]


def test_schwaches_gutachten_wird_deutlich_schlechter_bewertet(auth_client):
    gut = auth_client.post(
        "/v1/cases/zr-fall-sonderpreis/submit", json={"text": GUTACHTEN_GUT}
    ).json()["evaluation"]
    schlecht = auth_client.post(
        "/v1/cases/zr-fall-sonderpreis/submit", json={"text": GUTACHTEN_SCHLECHT}
    ).json()["evaluation"]
    assert schlecht["points"] < gut["points"] - 4
    assert schlecht["missed_required"], "Fehlende Kernpruefpunkte muessen benannt werden"


def test_abgaben_erscheinen_in_der_historie(auth_client):
    auth_client.post("/v1/cases/sr-fall-notwehr-schlagstock/submit", json={"text": GUTACHTEN_GUT})
    historie = auth_client.get("/v1/submissions").json()
    assert len(historie) == 1
    assert historie[0]["points"] is not None


# --------------------------------------------------------------------------- #
# Lernplan
# --------------------------------------------------------------------------- #


def test_lernplan_deckt_alle_themen_ab_und_haelt_das_budget(auth_client):
    exam = date.today() + timedelta(days=200)
    plan = auth_client.post(
        "/v1/plan", json={"exam_date": exam.isoformat(), "daily_minutes": 120}
    ).json()

    assert plan["uncovered_topics"] == []
    assert plan["klausur_count"] > 0
    for tag in plan["days"]:
        if any(b["kind"] == "klausur" for b in tag["blocks"]):
            continue
        assert tag["total_minutes"] <= 120, tag


def test_lernplan_lehnt_vergangene_examenstermine_ab(auth_client):
    vergangen = (date.today() - timedelta(days=1)).isoformat()
    assert auth_client.post("/v1/plan", json={"exam_date": vergangen}).status_code == 422


def test_lernplan_respektiert_ruhetage(auth_client):
    exam = date.today() + timedelta(days=60)
    plan = auth_client.post(
        "/v1/plan", json={"exam_date": exam.isoformat(), "rest_weekdays": [6]}
    ).json()
    sonntage = [d for d in plan["days"] if date.fromisoformat(d["date"]).weekday() == 6]
    assert sonntage and all(d["total_minutes"] == 0 for d in sonntage)
