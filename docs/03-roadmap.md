# Roadmap

> **Stand 15.09.2026 — Termin vom Nutzer gesetzt: Release am 29.09.2026.**
> Damit ist dieses Dokument nicht mehr der Releaseplan, sondern die
> **Nach-Release-Roadmap**. Der Schnitt für v1.0 steht in
> [`docs/18-release-2-wochen.md`](18-release-2-wochen.md), Preis- und
> Kostenmodell in [`docs/19-kosten-preis-budget.md`](19-kosten-preis-budget.md).
> Die Phasen A–D unten beschreiben ab sofort den Weg von v1.0 zum hier
> ursprünglich definierten Vollausbau (v1.1 bis v2), nicht den Weg zum Release.

## Was v1.0 heißt

**v1.0 (29.09.2026) = Web-Release plus Android-Beta mit Karteikarten,
Schemata, geführten Fällen und funktionierender Bezahlschranke** — ohne
KI-Klausurkorrektur, ohne iOS, ohne Klausursimulator. Maßgeblich sind die fünf
Gates aus `docs/18-release-2-wochen.md` Abschnitt 5.

**Vollausbau (v1.2, früher „v1.0") = öffentlicher Launch auf vier Plattformen
mit funktionierender Bezahlschranke.** Nicht Feature-Vollständigkeit, sondern:
ein Erstsemester und eine Examenskandidatin können die App sinnvoll nutzen, und
mindestens eine der beiden ist bereit, dafür zu zahlen. Erreicht, wenn alle
sieben Spur-Gates grün sind (Abschnitt „Release-Gates" unten) — kein Gate ist
durch „später" ersetzbar, ein nicht erreichbares Gate verschiebt den Termin
statt das Gate aufzuweichen. Herleitung im Roadmap-Dokument zu
[SUB-39](/SUB/issues/SUB-39#document-plan).

---

## Sieben Spuren bis v1.0

Die technische Meilensteinliste (M0–M6 unten) ist die T1-Spur — eine von
sieben, die bis zum Release fertig sein müssen. Jede Spur liefert ein eigenes
Repo-Dokument, damit die Roadmap nicht nur auf dem Board lebt.

- **T1 — Technik & Produkt.** Diese Datei, Meilensteine M0–M6 unten.
- **T2 — Design.** Markenbasis, Designsystem v1, vier Leitflächen (Review,
  Fall, Gutachten-Trainer, Dashboard). [`docs/11-designsystem.md`](11-designsystem.md)
  ([SUB-42](/SUB/issues/SUB-42)).
- **T3 — Inhalt.** Themenlandkarte und Produktionsrechnung für 500 Karten und
  40 Fälle über alle drei Rechtsgebiete.
  [`docs/12-content-produktionsplan.md`](12-content-produktionsplan.md)
  ([SUB-43](/SUB/issues/SUB-43)).
- **T4 — Lernstrukturen.** Explizites Lernmodell, Lernpfade je Persona,
  Fehlertaxonomie, Kalibrierung gegen 30 Dozentengutachten (Ziel MAE ≤ 2).
  `docs/13-lernarchitektur.md` (in Arbeit, [SUB-44](/SUB/issues/SUB-44)).
- **T5 — Innovation.** Die Verzahnungsthese aus `docs/01-produktvision.md`
  belegen oder verwerfen; Entscheidung je Differenzierungskandidat.
  `docs/16-innovationsthesen.md` (in Arbeit, [SUB-45](/SUB/issues/SUB-45)).
- **T6 — Markt.** Marktgröße, Wettbewerb (Jurafuchs, Constellatio, klassische
  Repetitorien, Anki), Positionierung, Preis. [`docs/14-marktanalyse.md`](14-marktanalyse.md)
  ([SUB-41](/SUB/issues/SUB-41)).
- **T7 — Marketing & Go-to-Market.** Kanäle, Beta-Partner, Launch-Plan.
  `docs/15-go-to-market.md` (in Arbeit, [SUB-46](/SUB/issues/SUB-46)).
- **T8 — Recht, Compliance, Betrieb** (Querschnitt, kein eigenes Zeitfenster,
  aber release-blockierend: Impressum, AGB, DSGVO, Store-Richtlinien,
  Zahlungsabwicklung). `docs/17-release-readiness.md` (in Arbeit,
  [SUB-47](/SUB/issues/SUB-47)).

---

## Release-Gates

> Diese vier Phasen galten für den ursprünglichen 28-Wochen-Plan. Seit der
> Terminvorgabe vom 15.09.2026 beschreiben sie den Weg **nach** v1.0: Phase A
> ist zum Release weitgehend abgearbeitet (T2, T3, T4, T6, T8 liegen als
> Dokumente vor), Phase B–D sind der Ausbau zu v1.1/v1.2. Die Gates für den
> Release selbst stehen in `docs/18-release-2-wochen.md` Abschnitt 5.

Vier Phasen über alle sieben Spuren, Wochenangaben relativ zum Start der
Gesamt-Roadmap, für **1–2 Entwickler + Teilzeit-Fachredaktion + KI-Redaktion**.

### Phase A — Fundament (W1–W6)
- T2 Markenbasis + Designsystem v1
- T3 Themenlandkarte + Produktionsrechnung, Redaktionstakt hochgefahren
- T4 Lernmodell + Fehlertaxonomie schriftlich
- T6 Marktanalyse, Positionierung, Preisentscheidung
- T1 M1 abschließen (Delta-Sync)
- **Gate A:** Designsystem steht, Content-Takt gemessen und hochgerechnet,
  Positionierung und Preis entschieden.

### Phase B — Kern (W7–W16)
- T1 M2 (Schemata, Fälle, Norm-Explorer) und M3 (Gutachten-Korrektur)
- T2 vier Leitflächen gestaltet
- T3 laufende Produktion Richtung 500/40
- T4 Lernpfade live, Kalibrierung gestartet (braucht Vorlauf!)
- T5 Verzahnungsthese implementiert und gemessen
- T7 Landing Page, Beta-Warteliste, Content-Marketing beginnt
- **Gate B:** Lernzyklus Wissen → Struktur → Anwendung end-to-end nutzbar,
  Kalibrierung MAE ≤ 2, 250 Karten / 20 Fälle.

### Phase C — Examenstauglich (W17–W24)
- T1 M4 (Klausur-Simulator, adaptiver Plan, Wissenslandkarte)
- T3 Zielmenge erreicht
- T4 Wirksamkeitsmessung ausgewertet
- T7 geschlossene Beta mit 2 Fachschaften
- T8 Recht/Compliance vollständig
- **Gate C:** Beta-Feedback eingearbeitet, keine offenen Compliance-Punkte.

### Phase D — Launch (W25–W28)
- T1 M5: Play Store, App Store, Microsoft Store, app.subsumo.de
- Abrechnung, Onboarding, Telemetrie
- T7 Launch-Kampagne
- **Gate D:** Vier Plattformen live, Bezahlvorgang end-to-end getestet,
  Support-Kanal besetzt.

**Kritischer Pfad:** T3 (Inhalt) und T4-Kalibrierung. Beide brauchen
Vorlaufzeit, die Code nicht braucht. Die Kalibrierung hängt an externen
Dozenten und muss spätestens in Phase B angefragt werden, sonst kippt Gate B.

---

## Technikspur (T1): Meilensteine M0–M6

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
- Flutter: Review-Screen (Karte zeigen/aufdecken/bewerten) ✅
- **Offline-Grundschicht ✅ (Zwischenstand, kein vollwertiger Ersatz für drift):**
  Kartencache und Review-Outbox überleben Neustart und Netzausfall
  (`SharedPreferences`, `app/lib/state.dart`) — ein Review wird lokal
  gespeichert, *bevor* der Sendeversuch beginnt, und die zuletzt geladenen
  Karten bleiben nach einem Netzfehler sichtbar statt eines leeren Screens.
  11 Tests mit `http.MockClient` (kein Server nötig), `test/state_test.dart`.
  Bewusst **kein** Volltext-Cache für Schemata/Fälle und keine echte
  Konfliktauflösung jenseits der ohnehin idempotenten Server-API — der
  Wechsel auf drift bleibt für M2 vorgesehen, sobald auch Schemata und Fälle
  offline gebraucht werden
- Backend: `/reviews/batch` ✅, Content-Manifest mit Delta-Sync (Manifest
  existiert, Client zieht noch keine Deltas — offen)
- 500 kuratierte Karten BGB AT + Strafrecht AT (Stand: 62/500) — KI-Redaktion
  auf den kuratierten Rückstand (`backend/scripts/redaktion_cli.py backlog`)
  ansetzen und die Ausbeute stichprobenartig prüfen, statt alles von Hand zu
  schreiben. 5 von 10 BACKLOG-Themen live über den Brücken-Modus erzeugt, alle
  im ersten Anlauf freigegeben und je per End-to-End-Test gegen den Evaluator
  verifiziert (`docs/08-ki-redaktion.md`): `zr-at-stellvertretung`,
  `zr-schuldrecht-at-unmoeglichkeit`, `sr-bt-diebstahl`, `or-berufsfreiheit`,
  `zr-deliktsrecht-823`, `sr-versuch-ruecktritt` — beim zweiten Thema deckte
  der End-to-End-Test einen zu eng gefassten Prüfpunkt auf (ein einzelnes
  Stichwort traf eine stilistisch korrekte Formulierung nicht) und wurde
  direkt korrigiert. Offen aus dem BACKLOG: Eigentumsherausgabe (§ 985 BGB),
  Täterschaft/Teilnahme (§§ 25 ff. StGB), Anfechtungsklage (§ 42 VwGO),
  Verwaltungsakt (§ 35 VwVfG)
- ~~Aus dem Spike mitgenommen: eigene Schriftdatei als Flutter-Asset bündeln~~
  **Erledigt** (siehe `docs/07-spike-web-editor.md`); ~~`package:web` statt
  `dart:html` konsequent in jedem Web-spezifischen Code~~ **Erledigt**
  (`app/spike/editor_bench.dart`, letzter verbliebener `dart:html`-Import)
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
| Kalibrierungsdozenten nicht gewinnbar | Gate B fällt, Kernfeature (T4) unbelegt | Anfrage in Phase A starten, Fallback erfahrene Korrekturassistenten, Notlösung Deckelung auf 11 Punkte beibehalten und offen kommunizieren | Phase A/B |
| Content-Takt (T3) reicht nicht für 500/40 | Release verschiebt sich | Durchsatzrechnung in Phase A statt Hoffnung; Notfallschnitt v1.0 auf zwei statt drei Rechtsgebiete | Phase A |
| Preis 12 €/Monat nicht durchsetzbar | Geschäftsmodell trägt nicht | Nutzerinterviews + Preis-Staffelung in Phase A entscheiden (T6) | Phase A |
| Markt schrumpft weiter (rückläufige Studienanfängerzahlen) | Obergrenze des adressierbaren Markts sinkt | Referendariat/Zweitexamen als Erweiterung früher einplanen | laufend |
| Design bleibt Nebensache | Abbruch im Onboarding trotz guter fachlicher Substanz | Designsystem ist Gate A, nicht Phase C | Gate A |
| Ein-Personen-Abhängigkeit | Stillstand bei Ausfall | Board-Struktur, jede Spur als eigenes Issue mit Dokument im Repo | laufend |
