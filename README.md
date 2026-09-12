# Subsumo — Jura-Lern-App

Eine Lern-App, die vom ersten Semester bis zum Staatsexamen trägt.
**Android, iOS, Windows und Web aus einer Codebasis.**

> **Rechtlicher Rahmen:** Lernhilfe, keine Rechtsberatung. Bewertet werden
> ausschließlich fiktive Übungsfälle gegen einen hinterlegten
> Erwartungshorizont — siehe [`docs/06-recht-compliance.md`](docs/06-recht-compliance.md).

---

## Warum diese App

Das Jurastudium hat Probleme, die kein Lehrbuch löst. Die zehn größten sind in
[`docs/00-problemanalyse.md`](docs/00-problemanalyse.md) analysiert und je auf
ein Feature und eine messbare Metrik abgebildet. Die vier wichtigsten:

| Problem | Antwort im Produkt | Wo im Code |
|---|---|---|
| **Gutachtenstil wird nie systematisch korrigiert** | Strukturanalyse jedes Textes in Millisekunden: Obersatz/Definition/Subsumtion/Ergebnis, Urteilsstil-Warnung, Normzitat-Prüfung | `backend/app/services/gutachten.py` |
| **Das Examen ist kumulativ — Stoff aus Semester 1 wird nach 5 Jahren geprüft** | FSRS-Spaced-Repetition als Rückgrat, mit Ziel-Retention je Kartentyp | `backend/app/services/srs.py` |
| **Kein individuelles Feedback, Korrekturen dauern Wochen** | Bewertung gegen Erwartungshorizont in der 18-Punkte-Skala, jeder Abzug auf einen Prüfpunkt zurückführbar; ohne KI bei 11 Punkten gedeckelt statt geschenkt | `backend/app/services/evaluator.py` |
| **Repetitorium kostet 2.000–4.000 €** | Verbindlicher Lernplan mit Load-Balancing bis zum Examenstermin | `backend/app/services/planner.py` |

---

## Loslegen

### Backend

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt

pytest -q                                    # 103 Tests
ruff check .
python scripts/validate_content.py           # Lerninhalte prüfen

uvicorn app.main:app --reload                # http://localhost:8000/docs
```

Die Inhalte aus `content/` werden beim Start automatisch in die Datenbank
geladen (SQLite in Dev, PostgreSQL in Produktion).

### Client

```bash
cd app
flutter create . --platforms=android,ios,windows,web --org de.subsumo   # einmalig
flutter pub get
flutter run -d chrome          # oder: windows, android, ios
```

### Konfiguration

Alles über Umgebungsvariablen mit Präfix `SUBSUMO_` (siehe `backend/app/config.py`):

```bash
export SUBSUMO_DATABASE_URL="postgresql+psycopg://..."
export SUBSUMO_JWT_SECRET="$(openssl rand -hex 32)"   # in Produktion zwingend
export SUBSUMO_LLM_PROVIDER="anthropic"               # ohne Key: heuristischer Fallback
export SUBSUMO_LLM_API_KEY="sk-ant-..."
```

Ohne LLM-Key läuft die App vollständig — nur die inhaltliche Klausurbewertung
ist dann heuristisch statt KI-gestützt.

---

## Aufbau

```
jura-lern-app/
├── docs/       Problemanalyse, Vision, Architektur, Roadmap, Datenmodell,
│               Content-Pipeline, Recht & Compliance
├── backend/    FastAPI + SQLAlchemy, 103 Tests
│   ├── app/services/   srs · gutachten · evaluator · planner · content
│   ├── app/api/v1/     auth · content · learn · gutachten · plan
│   └── scripts/        validate_content.py (läuft in der CI)
├── content/    Lerninhalte als versioniertes YAML, schema-validiert
└── app/        Flutter-Client für alle vier Plattformen
```

Architekturentscheidungen und ihre Begründung:
[`docs/02-architektur.md`](docs/02-architektur.md).
Zeitplan und Risiken: [`docs/03-roadmap.md`](docs/03-roadmap.md).

---

## Stand

**M0 abgeschlossen.** Lauffähig und getestet:

- FSRS-Scheduler mit Ziel-Retention je Kartentyp, Lernschritten, Lastprognose
  und Neuberechnung aus dem Ereignisstrom
- Gutachtenstil-Analyse: Satztrennung mit Schutz juristischer Abkürzungen,
  Klassifikation der vier Gutachtenschritte, verschachtelte Prüfungsblöcke,
  Urteilsstil-Erkennung, Normabgleich
- Bewertung gegen Erwartungshorizont mit JAP-Punkteskala; LLM-Anbindung
  austauschbar, mit Halluzinationsschutz (Belege müssen im Text vorkommen)
- Lernplaner mit harter Tagesobergrenze, Rückstandsverwaltung, Interleaving
  über die Rechtsgebiete und Klausurterminen
- REST-API mit Auth, idempotentem Offline-Sync und Coverage-Auswertung
- Content-Pipeline mit Pflichtfeldern, Slug-Eindeutigkeit und Altersprüfung
- Flutter-Client: Login, Fortschritt, Karteikarten, Schemata, Fälle,
  Gutachten-Trainer mit Live-Feedback

**Inhalte:** 3 Themen, 21 Karten, 5 Prüfungsschemata, 3 Fälle mit
Erwartungshorizont — über alle drei Rechtsgebiete.

Was als Nächstes kommt: [`docs/03-roadmap.md`](docs/03-roadmap.md).

---

## Eigenes Repository

Das Projekt liegt derzeit als Unterordner in einem bestehenden Repository.
So wird daraus ein eigenständiges Repo mit vollständiger Historie:

```bash
git subtree split --prefix=jura-lern-app -b subsumo-main
git init --bare ../subsumo.git          # oder: leeres Repo auf GitHub anlegen
git push git@github.com:<user>/subsumo.git subsumo-main:main
```

Danach greift auch `.github/workflows/ci.yml` — GitHub Actions liest Workflows
nur aus dem Wurzelverzeichnis eines Repositories.
