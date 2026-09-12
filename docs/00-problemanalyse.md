# Problemanalyse: Die größten Herausforderungen im Jurastudium

> Grundlage für den Feature-Scope von **Subsumo**. Jede Challenge ist auf ein
> konkretes Produkt-Feature und eine messbare Metrik gemappt.
>
> **Hinweis zu Zahlen:** Die genannten Größenordnungen stammen aus öffentlich
> diskutierten Kennzahlen (Justizprüfungsämter, Fachliteratur, Fachpresse) und
> sind als *Arbeitshypothesen* zu verstehen. Sie sind vor dem Marketing-Einsatz
> gegen Primärquellen (JPA-Jahresberichte, Statistisches Bundesamt) zu
> validieren — siehe `docs/06-recht-compliance.md`, Abschnitt "Claims".

---

## Überblick: 10 Challenges → 10 Lösungen

| # | Challenge | Kern-Feature | Nordstern-Metrik |
|---|-----------|--------------|------------------|
| 1 | Gutachtenstil wird nie systematisch trainiert | Gutachten-Trainer mit Struktur-Feedback | Ø Struktur-Score nach 20 Übungen |
| 2 | Kumulatives Examen → Vergessenskurve | FSRS-Spaced-Repetition über das ganze Studium | Retention Rate @ 6 Monate |
| 3 | Stoffmenge ohne Orientierung | Wissenslandkarte + Coverage-Heatmap | % abgedeckte Prüfungsrelevanz |
| 4 | Kein individuelles Feedback | KI-Korrektur mit Bewertungsbogen (JAP-Skala) | Feedback-Latenz (Ziel < 90 s) |
| 5 | Repetitorium ist teuer (2.000–4.000 €) | Vollwertiger Selbstlernpfad, Freemium | Anteil Nutzer ohne Rep |
| 6 | Klausurtaktik & Zeitdruck (5 h) | Klausur-Simulator mit Echtzeit-Pacing | Δ Zeitüberschreitungen |
| 7 | Streitstände nicht argumentierbar | Streitstand-Trainer (Pro/Contra, Meinungsstreit) | Argumente pro Streitstand |
| 8 | Normkenntnis / Arbeit am Gesetz | Norm-Explorer, offline, tief verlinkt | Normklicks pro Fall |
| 9 | Mentale Belastung & Isolation | Lernroutine, Load-Balancing, Lerngruppen | Streak-Abbruchrate |
| 10 | Inhalte veralten (neue Rspr., Gesetze) | Content-Pipeline mit Versionierung & Diff | Alter des ältesten Inhalts |

---

## Challenge 1 — Gutachtenstil: die zentrale Fertigkeit, die niemand übt

**Problem.** Die gesamte juristische Prüfungsleistung hängt an einer einzigen
Technik: *Obersatz → Definition → Subsumtion → Ergebnis*. Sie wird in der
Vorlesung in 90 Minuten erklärt und danach implizit vorausgesetzt. In der
Massenuniversität gibt es faktisch keine Einzelkorrektur; viele Studierende
schreiben bis zur ersten Klausur kein einziges korrigiertes Gutachten.
Der häufigste Fehler ist der Rückfall in den **Urteilsstil** ("Da A dem B die
Sache übereignet hat, ist ein Kaufvertrag zustande gekommen") — inhaltlich
richtig, punktetechnisch tödlich.

**Warum bestehende Lösungen scheitern.** Lehrbücher zeigen fertige Gutachten,
aber nicht den Weg dorthin. Karteikarten-Apps trainieren Wissen, nicht Form.
Musterlösungen geben keine Rückmeldung zum *eigenen* Text.

**Lösung.** Ein **Gutachten-Trainer**, der freien Text entgegennimmt und die
Struktur maschinell zerlegt:
- Erkennung der vier Gutachtenschritte über Signalwort-Muster
  (`könnte … haben`, `ist … wenn`, `hier/vorliegend`, `mithin/somit/folglich`)
- Warnung bei Urteilsstil-Einstiegen (`Da …`, `Weil …`, `Der Anspruch besteht,
  weil …`)
- Prüfung der Anspruchsgrundlagen-Nennung (§-Zitat mit Absatz/Satz/Alt.)
- Schrittweiser Modus: Die App gibt den Sachverhalt, der Nutzer schreibt *nur*
  den Obersatz, bekommt Feedback, dann erst die Definition (Constellatio-Prinzip)
- Erst danach optional die LLM-Inhaltsbewertung

**Umsetzung im Code.** `backend/app/services/gutachten.py` (deterministische
Struktur-Analyse, testbar, offline-fähig) + `backend/app/services/evaluator.py`
(LLM-Schicht, austauschbar, mit heuristischem Fallback).

**Metrik.** Ø Struktur-Score (0–100) über die letzten 5 Gutachten; Anteil
Urteilsstil-Verstöße pro 1.000 Wörter.

---

## Challenge 2 — Das Examen ist kumulativ: die Vergessenskurve ist der Gegner

**Problem.** Kein anderes Studium prüft am Ende in einem Block den Stoff aus
acht bis zehn Semestern. Was im 2. Semester im BGB AT gelernt wurde, wird 4
Jahre später abgefragt. Ohne systematische Wiederholung ist der Stoff aus den
ersten Semestern zum Examenszeitpunkt praktisch verloren — und wird in der
Examensvorbereitung ein zweites Mal von null gelernt.

**Warum bestehende Lösungen scheitern.** Anki kann das, aber: die Karten müssen
selbst erstellt werden (Wochen an Arbeit), der Algorithmus kennt keine
juristische Prüfungsrelevanz, und es gibt keine Verbindung zwischen Karte,
Schema und Fall.

**Lösung.** **Spaced Repetition als Rückgrat der gesamten App**, nicht als
Nebenfeature:
- Kuratiertes Kartendeck pro Rechtsgebiet/Vorlesung, ab Tag 1 nutzbar
- **FSRS-artiger Scheduler** (Difficulty/Stability/Retrievability) statt
  SM-2 — deutlich weniger Wiederholungen bei gleicher Retention
- Karten sind *typisiert*: Definition, Schema-Schritt, Streitstand, Norminhalt,
  Leitentscheidung — jeder Typ bekommt eigene Ziel-Retention
  (Definitionen 0.92, Schemata 0.90, Rspr. 0.85)
- Jede Karte ist an einen Knoten der Wissenslandkarte gebunden → Fortschritt
  wird automatisch zu Coverage

**Umsetzung im Code.** `backend/app/services/srs.py` + `tests/test_srs.py`.

**Metrik.** True Retention (Anteil `good`/`easy` bei fälligen Karten) @ 30/90/180 Tage.

---

## Challenge 3 — Stoffmenge ohne Landkarte

**Problem.** Grobe Größenordnung: drei Rechtsgebiete, ~1.500–2.500
examensrelevante Definitionen, mehrere hundert Prüfungsschemata, dazu
Rechtsprechung. Studierende wissen nicht, *was* sie können müssen und *wie
tief*. Das erzeugt Dauer-Unsicherheit ("Ich habe das Gefühl, nichts zu können")
und führt zu ineffizientem Lernen an prüfungsfernen Rändern.

**Lösung.** Eine **Wissenslandkarte** als expliziter, versionierter Baum:

```
Zivilrecht › Schuldrecht AT › Leistungsstörungen › Unmöglichkeit › § 275 I BGB
  ├─ Relevanz: 5/5   (Anteil an Examensklausuren)
  ├─ Karten: 14      (davon 9 reif)
  ├─ Schemata: 2
  └─ Fälle: 3        (davon 1 gelöst)
```

- Jeder Knoten hat eine **Prüfungsrelevanz 1–5**, kuratiert aus
  Examensreports/Klausurstatistiken
- Coverage-Heatmap: grün = reif, gelb = angefangen, rot = nie angefasst
- „Was fehlt mir noch?" als erste Frage, die die App beantwortet

**Metrik.** Gewichtete Coverage = Σ(Relevanz × Reifegrad) / Σ(Relevanz).

---

## Challenge 4 — Kein individuelles Feedback

**Problem.** Klausurkorrekturen dauern an Universitäten oft 6–12 Wochen und
bestehen aus einer Note plus drei Randbemerkungen. Der Lerneffekt verpufft,
weil der Abstand zum eigenen Denkprozess zu groß ist. Feedback ist das teuerste
Gut im Jurastudium.

**Lösung.** **Mehrstufiges Feedback statt eines Gutachtens am Ende:**
1. *Sofort, deterministisch:* Struktur, Gutachtenstil, Normzitate, Länge,
   Zeitverteilung — läuft lokal, kostet nichts, ist reproduzierbar
2. *In < 90 s, KI:* Inhaltliche Bewertung gegen einen hinterlegten
   **Bewertungsbogen** (Erwartungshorizont mit gewichteten Prüfpunkten), Ausgabe
   in der 18-Punkte-JAP-Skala inkl. Begründung pro Punktabzug
3. *Optional, menschlich:* Peer-Review in der Lerngruppe, doppelblind

Kritisch für die Akzeptanz: Die KI bewertet **gegen einen vorher definierten
Erwartungshorizont**, nicht frei. Jeder Punktabzug wird auf einen Prüfpunkt
zurückgeführt und ist anklickbar. Keine Blackbox-Note.

Ebenso wichtig: **keine geschenkten Noten.** Der heuristische Fallback ohne KI
erkennt nur, *ob* ein Prüfpunkt angesprochen wurde — nicht, ob die
Argumentation trägt. Er ist deshalb bei 11 Punkten gedeckelt, und der Nutzer
erfährt warum. Ein Stichwortabgleich, der „sehr gut" vergibt, entwertet jede
spätere ernsthafte Rückmeldung.

**Metrik.** Feedback-Latenz; Abweichung KI-Punkte vs. Dozentenpunkte auf einem
kalibrierten Referenzsatz (Ziel: MAE ≤ 2 Punkte).

---

## Challenge 5 — Das Repetitorium kostet 2.000–4.000 €

**Problem.** Ein sehr großer Teil der Examenskandidaten nimmt ein kommerzielles
Repetitorium — nicht weil die Uni nichts anbietet, sondern weil das Rep
*Struktur und Verbindlichkeit* liefert. Das ist eine soziale Selektion: Wer die
Kosten nicht tragen kann, startet mit Nachteil ins Examen.

**Lösung.** Nicht „billiger als das Rep", sondern **das liefern, wofür man das
Rep eigentlich bezahlt**: einen verbindlichen Plan, wöchentliche Klausuren,
Korrektur, Wiederholung. Freemium mit ernstzunehmendem Free-Tier
(Karteikarten + Schemata + 3 Fälle/Monat vollständig kostenlos), Pro für
Klausurkorrektur und Lernplan. Campus-Lizenzen für Fachschaften.

**Metrik.** Anteil aktiver Examenskandidaten ohne Präsenz-Rep.

---

## Challenge 6 — Klausurtaktik: 5 Stunden, und die Zeit läuft

**Problem.** Die Examensklausur ist ein Zeitmanagement-Problem. Typische
Muster: 90 Minuten Sachverhaltserfassung statt 45, dann Panik, dann ein
abgebrochenes Gutachten in der letzten halben Stunde. Das trainiert niemand,
weil eine 5-Stunden-Klausur eine 5-Stunden-Verpflichtung ist.

**Lösung.** **Klausur-Simulator:**
- Echter Timer (300 min), Vollbild, Ablenkungssperre, offline lauffähig
- **Pacing-Leiste**: Sollzeit pro Prüfungsabschnitt aus dem Erwartungshorizont;
  Warnung bei Überschreitung („Du bist bei 40 % der Zeit und bei 20 % der Punkte")
- Nur Gesetzestext verfügbar, wie in der echten Klausur
- Kurzformate: 45-min-„Sprints" für einzelne Prüfungspunkte, damit überhaupt
  regelmäßig geübt wird
- Auto-Save alle 5 s — ein Absturz darf nie 5 Stunden kosten

**Metrik.** Abweichung Ist- vs. Soll-Zeit pro Abschnitt; Anteil vollständig
zu Ende geschriebener Klausuren.

---

## Challenge 7 — Streitstände: auswendig gelernt statt argumentiert

**Problem.** Punkte gibt es nicht für „h.M. sagt X", sondern für die
Argumentation. Studierende lernen Meinungsstreite als Faktenpaare und stehen in
der Klausur ohne Argumente da, sobald der Sachverhalt die Streitfrage
tatsächlich entscheidungserheblich macht.

**Lösung.** **Streitstand-Trainer** als eigener Kartentyp:
- Struktur: Problem → e.A. + Argumente → a.A. + Argumente → Streitentscheid →
  Konsequenz im Fall
- Übungsmodus „Vertritt die Gegenansicht": Der Nutzer muss die *unterlegene*
  Meinung begründen — das erzeugt echtes Verständnis
- „Streitentscheid nötig?"-Drill: In 60 % der Fälle kommen beide Ansichten zum
  selben Ergebnis; das zu erkennen spart in der Klausur 20 Minuten

**Metrik.** Anzahl frei reproduzierter Argumente pro Streitstand.

---

## Challenge 8 — Arbeit am Gesetz

**Problem.** Der Schönfelder ist das einzige Hilfsmittel in der Klausur. Wer
Normen nicht findet, verliert Zeit; wer Verweisungsketten (§ 280 I → § 241 II →
§ 311 II) nicht lesen kann, verliert Punkte. Digital gelernt wird meist ohne
Gesetzestext daneben.

**Lösung.** **Norm-Explorer**, vollständig offline:
- Gesetzestexte aus amtlichen Quellen (gesetze-im-internet.de, XML), lokal
  indiziert; lizenzrechtlich unkritisch (§ 5 UrhG), siehe Compliance-Doku
- Jedes `§ 280 I BGB` in Karten, Schemata und Fällen ist ein Deep-Link
- Verweisungsketten werden als Graph dargestellt und sind navigierbar
- Norm-Drill: „Welche Norm regelt …?" als eigener Kartentyp
- Klausurmodus zeigt *nur* den Gesetzestext — Training unter Echtbedingungen

**Metrik.** Normklicks pro Fall; Trefferquote im Norm-Drill.

---

## Challenge 9 — Mentale Belastung und Isolation

**Problem.** Das Jurastudium hat eine überdurchschnittliche Belastungslage:
Alles-oder-nichts-Prüfung, ein einziger Versuch (plus Verbesserungsversuch),
12–18 Monate Examensvorbereitung mit wenig Struktur von außen, starker
Vergleichsdruck. Lern-Apps verschärfen das oft noch durch Streak-Mechaniken,
die bei einem Krankheitstag bestrafen.

**Lösung.** Bewusst **anti-toxische Gamification**:
- Kein Streak-Verlust bei geplanten Pausen; „Streak-Freeze" ist Default, nicht Bonus
- **Load-Balancing**: Der Planer verteilt fällige Wiederholungen so, dass die
  Tagesbelastung ein Nutzer-Limit (z. B. 45 min) nicht überschreitet — statt
  eines 400-Karten-Rückstands nach dem Urlaub
- Ehrliche Fortschrittsanzeige statt Punkte-Konfetti: „Du kannst 62 % des
  examensrelevanten Zivilrechts sicher"
- **Lerngruppen**: gemeinsame Klausurtermine, doppelblindes Peer-Review,
  geteilte Decks
- Kein öffentliches Leaderboard nach Note. Vergleich nur mit sich selbst.

**Metrik.** Streak-Abbruchrate; Rückkehrquote nach 7 Tagen Inaktivität.

---

## Challenge 10 — Inhalte veralten

**Problem.** Gesetzesänderungen und neue Leitentscheidungen entwerten Lernstoff
sofort. Ein falsch gelernter Streitstand, den der BGH letztes Jahr entschieden
hat, kostet in der Klausur Punkte. Statische Skripte und selbstgebaute
Anki-Decks haben kein Update-Konzept.

**Lösung.** **Content als versionierter Code**, nicht als Datenbankinhalt:
- Alle Inhalte liegen als YAML im Repo (`content/`), mit Schema-Validierung
  in der CI
- Jeder Inhalt hat `stand:` (Datum), `quellen:` und `status:`
  (draft/review/published)
- Änderung → Pull Request → fachliche Review → Release
- Betroffene Nutzerkarten werden beim Update **nicht zurückgesetzt**, sondern
  als „geändert" markiert und einmalig neu vorgelegt (Diff wird angezeigt)
- Redaktionsalarm: Inhalte, deren `stand` älter als 18 Monate ist, laufen in der
  CI als Warnung auf

**Metrik.** Alter des ältesten veröffentlichten Inhalts; Time-to-Update nach
einer Leitentscheidung.

---

## Was wir bewusst NICHT bauen

| Nicht im Scope | Begründung |
|---|---|
| Rechtsberatung / Fallgutachten für echte Sachverhalte | RDG. Klare Abgrenzung, siehe `docs/06-recht-compliance.md` |
| Eigene Kommentar-/Lehrbuchtexte | Urheberrecht + Redaktionskosten. Wir verlinken und trainieren, wir ersetzen nicht |
| Video-Vorlesungen | Anderes Geschäft, andere Kostenstruktur. Fokus auf aktives Üben |
| Öffentliches Noten-Leaderboard | Widerspricht Challenge 9 |
| KI als unkontrollierter Antwortgeber | Halluzinationsrisiko bei Normzitaten ist untragbar. LLM nur gegen hinterlegten Erwartungshorizont |
