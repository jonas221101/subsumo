# Architektur

## 1. Plattform-Entscheidung

**Anforderung:** Android, iOS, Windows, Web — ein Team, eine Codebasis,
Offline-Fähigkeit (Bibliothek, Bahn, Klausurmodus), 5-Stunden-Editor ohne
Datenverlust.

| Option | Android | iOS | Windows | Web | Offline | Urteil |
|---|---|---|---|---|---|---|
| **Flutter** | ✅ | ✅ | ✅ nativ | ✅ CanvasKit | ✅ SQLite (drift) | **Gewählt** |
| React Native + Expo | ✅ | ✅ | ⚠️ nur RN-Windows, schwach | ✅ RNW | ✅ | Windows ist das Problem |
| .NET MAUI | ✅ | ✅ | ✅ | ❌ (Blazor separat) | ✅ | Web fehlt |
| PWA only | ⚠️ | ⚠️ | ⚠️ | ✅ | ⚠️ | Klausurmodus/Store-Präsenz unzureichend |

**Entscheidung: Flutter (Dart).** Einzige Option, die alle vier Ziele aus einer
Codebasis nativ bedient. macOS/Linux fallen kostenlos ab.

Risiken und Gegenmaßnahmen:
- *Web-Bundle groß (CanvasKit ~ 2 MB)* → `--wasm`-Build, Deferred Loading für
  Klausur-Modul, HTML-Renderer-Fallback für Landingpage
- *Text-Editing auf Web historisch schwach* → Klausur-Editor als eigenes,
  früh evaluiertes Spike-Ticket (M1), Fallback: `contenteditable`-Bridge
- *Dart-Talentpool kleiner* → Backend in Python hält die Hürde niedrig

## 2. Systemüberblick

```
┌──────────────── Clients (Flutter, eine Codebasis) ────────────────┐
│  Android    iOS    Windows    Web    (macOS/Linux gratis)         │
│                                                                    │
│  Riverpod (State) · go_router (Nav) · drift/SQLite (lokal)        │
│  Offline-First: alles Lesen lokal, Sync im Hintergrund            │
└────────────────────────────┬───────────────────────────────────────┘
                             │ HTTPS / JSON (REST) + JWT
┌────────────────────────────▼───────────────────────────────────────┐
│  API — FastAPI (Python 3.11+)                                      │
│                                                                     │
│  /auth  /cards  /reviews  /schemata  /cases  /exams  /plan         │
│                                                                     │
│  Services:                                                          │
│   · srs.py        FSRS-Scheduler (deterministisch, getestet)       │
│   · gutachten.py  Gutachtenstil-Analyse (regelbasiert, offline)    │
│   · evaluator.py  LLM-Korrektur gg. Erwartungshorizont (+Fallback) │
│   · planner.py    Adaptiver Lernplan mit Load-Balancing            │
│   · content.py    Laden/Validieren/Seeden der YAML-Inhalte         │
└───────┬─────────────────────────────┬──────────────────────────────┘
        │                             │
┌───────▼────────┐          ┌─────────▼──────────┐
│  PostgreSQL    │          │  LLM-Provider      │
│  (SQLite in    │          │  (Claude API)      │
│   Dev/Test)    │          │  austauschbar      │
└────────────────┘          └────────────────────┘

┌────────────────────────────────────────────────────────────────────┐
│  content/  — Lerninhalte als YAML im Git, Schema-validiert in CI   │
│  Karten · Schemata · Fälle · Streitstände · Erwartungshorizonte     │
└────────────────────────────────────────────────────────────────────┘
```

## 3. Warum diese Aufteilung

**Regelbasiert vor KI.** Die Gutachtenstil-Analyse ist deterministisch und
läuft ohne Netz. Das ist kein Kompromiss, sondern Absicht: Struktur-Feedback
muss reproduzierbar, kostenlos und sofort sein. Die LLM-Schicht kommt erst für
die *inhaltliche* Bewertung dazu und bleibt hinter einem Interface
(`Evaluator`), damit Provider austauschbar sind und Tests ohne Netz laufen.

**Content als Code.** `content/` ist die Quelle der Wahrheit, die Datenbank ist
ein Cache davon. Fachliche Reviews laufen als Pull Request. Das löst Challenge 10.

**Offline-First, nicht Offline-Fallback.** Der Client liest *immer* aus SQLite
und schreibt Reviews in eine lokale Outbox. Sync ist ein Hintergrundprozess.
Ein Klausurdurchgang darf niemals an einer Netzverbindung hängen.

## 4. Sync-Strategie

- **Inhalte (Server → Client):** Pull nach `content_version`. Client fragt
  `GET /v1/content/manifest?since=<version>`, lädt Deltas, schreibt lokal.
- **Lernereignisse (Client → Server):** Append-only Outbox. Jedes Review hat
  eine client-generierte UUID → idempotentes Upsert, `POST /v1/reviews/batch`.
- **Konfliktauflösung:** Reviews sind unveränderliche Ereignisse, der
  Kartenzustand wird serverseitig aus dem Ereignisstrom neu berechnet. Damit
  gibt es strukturell keine Merge-Konflikte (Event Sourcing light).

## 5. Sicherheit

- Passwort-Hashing: PBKDF2-HMAC-SHA256, 600.000 Iterationen (OWASP), pro Nutzer
  zufälliger Salt. *Produktions-Upgrade auf Argon2id in M3 vorgesehen.*
- Tokens: HS256-JWT, kurze Access-Lebensdauer, Refresh-Rotation ab M3.
- Absichtlich **keine** nativen Krypto-Abhängigkeiten im Kern (nur `hashlib`/`hmac`)
  → reproduzierbare Builds auf allen CI-Runnern.
- DSGVO: Datenminimierung, Export- und Löschendpunkt ab M3, EU-Hosting.

## 6. Verzeichnisstruktur

```
jura-lern-app/
├── docs/          Analyse, Vision, Architektur, Roadmap, Compliance
├── backend/       FastAPI-Service
│   ├── app/
│   │   ├── api/v1/    Routen
│   │   ├── core/      Security, Zeit
│   │   ├── services/  SRS, Gutachten, Planner, Evaluator, Content
│   │   ├── models.py  SQLAlchemy
│   │   └── schemas.py Pydantic
│   └── tests/     pytest
├── content/       Lerninhalte (YAML) + JSON-Schema
└── app/           Flutter-Client
```
