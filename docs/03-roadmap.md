# Roadmap

Zeitangaben in Wochen, gerechnet für **1–2 Entwickler + 1 juristische
Fachredaktion (Teilzeit)**. Jeder Meilenstein endet mit etwas Benutzbarem.

## M0 — Fundament ✅
- Monorepo, Problemanalyse, Architekturentscheidung
- Backend lauffähig: Datenmodell, Auth, FSRS-Scheduler, Gutachten-Analyse,
  Lernplaner, Content-Loader, REST-API, Testsuite
- Content-Format + Schema-Validierung + erste echte Inhalte
- Flutter-Client-Gerüst mit Navigation und API-Schicht
- CI (Backend-Tests + Content-Validierung)

## M0+ — KI-Redaktion & Spike ✅
- **Spike Text-Editor-Qualität auf Flutter Web: abgeschlossen, Ergebnis GO.**
  48 ms Ø-Latenz/Tastendruck (p95 54 ms) bei 38.754 Zeichen, gemessen mit
  echtem Flutter-Release-Build unter headless Chromium — deutlich unter der
  100-ms-Wahrnehmbarkeitsschwelle, ohne Degradation über den Testlauf. Der
  native Editor trägt den Klausur-Simulator, kein Bridge-Fallback nötig.
  Details, Methodik und drei Nebenbefunde (Font-Bundling, `dart:html` vs.
  `package:web`, `--web-renderer` entfernt): `docs/07-spike-web-editor.md`
- **KI-Redaktion:** Zwei-Agenten-Pipeline (Collector schreibt, Reviewer prüft
  unabhängig gegen Urheberrecht/RDG/fachliche Plausibilität), Struktur-Gate
  identisch zur CI, Herkunftsblock je Inhalt. Löst den Content-Engpass aus
  Challenge 10 direkt an der Wurzel. Details: `docs/08-ki-redaktion.md`,
  Code: `backend/app/services/redaktion/`

## M1 — Karteikarten end-to-end (3–4 Wochen)
- Flutter: Review-Screen (Karte zeigen/aufdecken/bewerten), Offline-Speicher
  (drift), Outbox-Sync
- Backend: `/reviews/batch`, Content-Manifest mit Delta-Sync
- 500 kuratierte Karten BGB AT + Strafrecht AT — Kandidat: KI-Redaktion auf den
  kuratierten Rückstand (`backend/scripts/redaktion_cli.py backlog`) ansetzen
  und die Ausbeute stichprobenartig prüfen, statt alles von Hand zu schreiben
- Aus dem Spike mitgenommen: eigene Schriftdatei als Flutter-Asset bündeln
  (nicht auf Googles Font-CDN verlassen), `package:web` statt `dart:html`
- *Ergebnis:* Eine App, mit der man ab Semester 1 sinnvoll lernt

## M2 — Schemata & Fälle (4–5 Wochen)
- Interaktive Prüfungsschemata (aufklappbar, Reihenfolge-Drill)
- Geführte Fall-Lösung: Schritt-für-Schritt mit Freitext + Musterlösung
- Norm-Explorer: Import gesetze-im-internet.de-XML, Volltextsuche, Deep-Links
- 40 Fälle über die drei Rechtsgebiete
- *Ergebnis:* Der Kern-Lernzyklus Wissen → Struktur → Anwendung steht

## M3 — Gutachten-Trainer & Korrektur (4–5 Wochen)
- Freitext-Gutachten mit sofortigem Struktur-Feedback (bereits implementiert,
  jetzt im Client)
- LLM-Korrektur gegen Erwartungshorizont, JAP-Punkteskala, Begründung je Abzug
- **Kalibrierung:** 30 von Dozenten bewertete Referenzgutachten, Ziel MAE ≤ 2 Punkte
- Argon2id, Refresh-Token-Rotation, DSGVO-Export/Löschung
- *Ergebnis:* Das Alleinstellungsmerkmal ist live

## M4 — Klausur-Simulator & Lernplan (4 Wochen)
- 300-Minuten-Modus, Pacing-Leiste, Auto-Save, Ablenkungssperre, offline
- Adaptiver Lernplan mit Examensdatum, Load-Balancing, Wochenreview
- Wissenslandkarte mit Coverage-Heatmap
- *Ergebnis:* Die App trägt durch die Examensvorbereitung

## M5 — Release auf allen vier Plattformen (3 Wochen)
- Play Store, App Store, MSIX/Microsoft Store, Web unter app.subsumo.de
- Abrechnung (Freemium), Onboarding, Crash-/Analytics-Telemetrie (opt-in)
- Beta mit 2 Fachschaften

## M6 — Lerngruppen & Redaktion im Maßstab (laufend)
- Lerngruppen, doppelblindes Peer-Review, gemeinsame Klausurtermine
- Redaktions-Backoffice, Autoren-Workflow, Update-Diffs für Nutzer
- Content-Ausbau auf Examensvollständigkeit

---

## Kritischer Pfad und Risiken

| Risiko | Wirkung | Gegenmaßnahme | Wann |
|---|---|---|---|
| **Content ist der Engpass, nicht der Code** | Ohne Inhalte ist die App wertlos | KI-Redaktion (Collector+Reviewer) ab M0+ produktiv, Format steht seit M0 | laufend |
| ~~Flutter-Web-Texteditor untauglich für 5-h-Klausur~~ | ~~M4 kippt~~ | **Erledigt:** Spike in M0+ statt M4, Ergebnis GO (48ms Ø-Latenz), siehe `docs/07-spike-web-editor.md` | ✅ M0+ |
| KI-Korrektur (Klausur) wird als unfair empfunden | Kernfeature verliert Vertrauen | Bewertung nur gegen Erwartungshorizont, jeder Abzug anklickbar, Kalibrierung gegen Dozenten | M3 |
| KI-Redaktion halluziniert Normzitate | Falscher Lernstoff, Vertrauensverlust | Reviewer-Agent als zweite Instanz, menschliche Stichprobe empfohlen; echter Normindex-Abgleich erst ab M2 (Norm-Explorer) - siehe Grenzen in `docs/08-ki-redaktion.md` | laufend, verschärft bis M2 |
| Urheberrecht bei Inhalten | Abmahnrisiko | Nur amtliche Werke (§ 5 UrhG) + Eigenproduktion, Quellenpflicht im Format, Reviewer-Agent prüft zusätzlich | laufend |
| RDG-Abgrenzung | Rechtliches Risiko | Keine Bewertung echter Sachverhalte, Hinweis im Produkt, Reviewer-Agent prüft Fiktivität jedes Falls | laufend |
