# Datenmodell

Vollstaendige Definition: `backend/app/models.py`.

## Leitgedanke: Ereignisse statt Zustand

`reviews` ist ein **unveraenderlicher Ereignisstrom**. `user_cards` ist der
daraus abgeleitete Gedaechtniszustand und jederzeit neu berechenbar
(`srs.rebuild_from_reviews`).

Das loest das Offline-Problem an der Wurzel: Wenn Handy und Laptop tagelang
getrennt gelernt haben, wird beim Sync nichts gemerged. Die Ereignisse werden
in Zeitreihenfolge neu abgespielt, das Ergebnis ist deterministisch und von der
Eintreffreihenfolge unabhaengig (getestet in
`tests/test_srs.py::test_rebuild_aus_dem_ereignisstrom_ist_reihenfolgeunabhaengig`).

## Tabellen

| Tabelle | Zweck | Besonderheit |
|---|---|---|
| `users` | Konto, Examensdatum, Tagesbudget | Examensdatum steuert den Lernplan |
| `topics` | Knoten der Wissenslandkarte | `relevance` 1–5 gewichtet Coverage und Plan |
| `cards` | Karteikarte | `content_hash` erkennt fachliche Aenderungen |
| `user_cards` | FSRS-Zustand je Nutzer und Karte | abgeleitet, neu berechenbar |
| `reviews` | Lernereignis | `client_id` unique → idempotenter Sync |
| `schemata` | Pruefungsschema | `steps` als verschachteltes JSON |
| `cases` | Uebungsfall | `expectation` = Erwartungshorizont |
| `submissions` | Abgegebenes Gutachten + Bewertung | `report` enthaelt Struktur und Bewertung |
| `bundeslaender` | Pruefungsprofil je Land (docs/32) | `data` JSON: Klausurstruktur, Normenspiegel, Checkliste |
| `universitaeten` | Fakultaet mit Studienverlaufsplan | `data.kurse` verweist auf `kurse.slug` |
| `kurse` | Kanonischer Kurs mit Vorbereitungsdeck | `data.topic_slugs` + `landesrecht_kategorien`; Deck wird zur Laufzeit aufgeloest |
| `fachrichtungen` | Profil je Studiengang (docs/34) | `data` JSON: Fachgebiete, Begriffe, Kartentypen, Methodik-Schalter |

Vier Spalten fuer Examensvorbereitung und Individualisierung
(docs/32-examensvorbereitung.md, docs/33-individualisierung.md):
`users.bundesland` und `users.universitaet_slug` (Examensprofil, beide
optional), `users.lernprofil` (JSON, validiert ueber `LernprofilIn`, leer =
Defaults) sowie `topics.bundesland` (Landesrecht-Thema, nur fuer Nutzer
dieses Landes sichtbar). Bestehende Installationen brauchen dafuer ein
manuelles `ALTER TABLE` (docs/22-deploy-runbook.md Abschnitt 2.2).

Fachrichtungen (docs/34-fachrichtungen.md) bringen `users.fachrichtung`,
`topics.fachrichtung` und `kurse.fachrichtung` (alle Default `jura`,
abgeleitet aus dem Fachgebiet) sowie die Tabelle `fachrichtungen`.
`bundeslaender` bekommt den Primaerschluessel `key = "<fachrichtung>:<CODE>"`
(`jura:BY`), weil ein Land je Fachrichtung ein eigenes Pruefungsprofil
haben kann; `code` und `fachrichtung` stehen daneben als Spalten.

## Zwei Entscheidungen, die sich durchziehen

**`client_id` auf `reviews`.** Der Client vergibt die ID, nicht der Server.
Ein Retry nach Netzabbruch ist damit kostenlos: Der Server verwirft Duplikate,
der Client muss nie wissen, was schon angekommen ist.

**`content_hash` auf `cards`.** Aendert die Redaktion eine Karte, wird der
Lernfortschritt des Nutzers **nicht** zurueckgesetzt. Die betroffenen
`user_cards` bekommen `content_changed = true` und werden einmalig mit Hinweis
erneut vorgelegt. Fortschritt zu loeschen, weil ein Tippfehler korrigiert
wurde, waere der sicherste Weg, Nutzer zu verlieren.

## Migrationen

Im M0-Stand erzeugt `Base.metadata.create_all` das Schema. Mit dem Wechsel auf
PostgreSQL in M3 kommt Alembic dazu; bis dahin gibt es keine produktiven Daten,
die eine Migration braeuchten.
