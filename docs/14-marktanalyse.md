# Marktanalyse — Subsumo

> Ersetzt die aus dem Bauch geschriebene Wettbewerbstabelle in
> `docs/01-produktvision.md` durch recherchierte Zahlen. Methodik: Marktgrößen
> stammen aus Primärquellen (Destatis, Bundesamt für Justiz), wo keine
> Primärquelle auffindbar war, ist das explizit vermerkt statt geschätzt.
> Wettbewerbspreise sind Website-Abrufe vom **14.09.2026** (Stand so
> gekennzeichnet, da sich Preise ändern können). Eigene Herleitungen (z. B.
> Persona-Größen) sind als **Annahme** markiert und nachvollziehbar
> vorgerechnet, nicht als Fakt getarnt.

---

## 1. Marktgröße

### 1.1 Rohdaten

| Kennzahl | Wert | Quelle | Stand |
|---|---|---|---|
| Jurastudierende gesamt (Deutschland) | **116.760** (davon 107.355 deutsche Studierende) | Destatis, Tabelle „Studierende insgesamt und Studierende Deutsche im Studienfach Rechtswissenschaft" | WS 2025/26, Tabellenstand 13.08.2026 |
| Studienanfänger:innen Jura | **13.703** | Destatis via LTO Karriere, „Zahl der Einschreibungen fürs Jurastudium geht zurück" | WS 2022/23 (aktuellste belastbare Einzelzahl — s. Einschränkung unten) |
| Teilnehmer:innen 1. jur. Prüfung, bestanden | **9.255** (Bestehensquote 72,6 %) | Bundesamt für Justiz (BfJ), „Statistik der juristischen Prüfungen 2024" | Prüfungsjahr 2024, veröffentlicht 30.06.2026 |
| Teilnehmer:innen 2. jur. Staatsprüfung, bestanden | **8.084** (Bestehensquote 87,5 %) | BfJ, ebenda | Prüfungsjahr 2024 |
| Ø Studiendauer bis 1. Examen | **10,4 Semester** | BfJ, ebenda | Prüfungsjahr 2024 |
| Anteil Studierende mit kommerziellem Repetitorium | **60 %** (2016: 86 %, also −26 Prozentpunkte) | LTO Karriere, Bericht zu Czerny/Steffahn/Schindler-Untersuchung | 2022 (jüngste verfügbare Erhebung) |

**Einschränkungen (explizit, keine Schätzung nachgeliefert):**
- Keine offizielle Studienanfänger-Zahl für WS 2023/24 oder WS 2024/25 auffindbar (Destatis hat 2025 die Fächergruppengliederung revidiert, was neuere Zeitreihen erschwert). Die Anfängerzahlen sind seit dem Höchststand WS 2018/19 (15.926) rückläufig; 13.703 ist die aktuellste belastbare Zahl, nicht die aktuelle.
- Keine bundesweite Gesamtzahl aller Rechtsreferendar:innen auffindbar (nur punktuelle Länderzahlen, z. B. NRW-Zielgröße ~3.000/Jahr — keine bundesweite Bestandszahl, daher nicht hochgerechnet).
- Die Bestehensquote (72,6 %) wird hier vereinfachend als Anteil Bestandene an allen Prüfungsteilnehmenden des Jahres 2024 behandelt, um die Gesamtteilnehmerzahl zurückzurechnen. Mehrfachversuche (Verbesserungsversuch) können zu leichten Verzerrungen führen; für die Größenordnung der Zielgruppe ist das ausreichend genau.

### 1.2 Zielgruppe je Persona

Destatis liefert **keine** Aufschlüsselung der Studierendenzahl nach Fachsemester, deshalb sind die folgenden Bestände **hergeleitet** (Annahme, Rechenweg offengelegt) statt direkt aus einer Quelle zitiert.

| Persona | Definition (aus `docs/01-produktvision.md`) | Bestand | Herleitung | Charakter |
|---|---|---|---|---|
| **Lena** — Studieneinstieg | 1.–2. Semester | **≈ 13.700** | = Studienanfänger-Jahrgang (WS 2022/23), da Verweildauer in dieser Phase ≈ 1 Jahr (2 Semester) | Annahme: Verweildauer 2 Semester |
| **Jonas** — Grundstudium/Schwerpunkt | Semester 3 bis Beginn Examensvorbereitung | **≈ 88.190** | Residual: 116.760 − 13.700 (Lena) − 14.870 (Mira) | Annahme: eigene Herleitung, kein direkter Destatis-Wert je Semesterband |
| **Mira** — Examensvorbereitung | ~14 Monate aktives Vorbereitungsfenster vor der 1. Prüfung (Produktvision-Persona: „Monat 9 von 14") | **≈ 14.870** | = jährliche Prüfungsteilnehmer (9.255 ÷ 72,6 % ≈ 12.748) × 14/12 Monate Verweildauer | Annahme: 14 Monate Verweildauer aus Persona-Beschreibung, Teilnehmerzahl direkt aus BfJ-Daten |

**Lesart:** Lena und Mira sind über Primärdaten (Studienanfänger bzw. Prüfungsteilnehmer) verankert, Jonas ist der Rest. Die Summe reproduziert bewusst exakt die Destatis-Gesamtzahl — es ist keine zusätzliche, unabhängig geschätzte Zielgruppe, sondern eine Aufteilung derselben 116.760 Personen.

---

## 2. Wettbewerbsanalyse

**Wichtigster Einzelbefund:** KI-gestützte Klausurkorrektur ist im deutschen Jura-Lernmarkt **kein Alleinstellungsmerkmal mehr**. Mindestens drei Anbieter bieten sie bereits an — Constellatio seit 30.01.2026 direkt im Kernprodukt, dazu zwei dedizierte Spezialtools (KorrekturKai, KlausurenKiste). Jurafuchs, der reichweitenstärkste Anbieter, hat KI (Foxxy AI), aber bislang **keine belegte Korrektur ganzer Gutachten im Fließtext** — nur strukturierte/kurze Antworten.

| Anbieter | Preis | Funktionsumfang | KI-Korrektur (Fließtext-Gutachten) | Stärke | Schwäche |
|---|---|---|---|---|---|
| **Jurafuchs** | 5,99 €/Monat (71,99 €/Jahr), kein Studierendenrabatt, 10 % Web-Rabatt | Microlearning, 8.000+ interaktive Fälle, Karteikarten, Schemata, Spaced Repetition, Offline-Downloads, separates Klausurportal (3.445 Klausuren, Beta, kostenlos) | ⚠️ **Nein** für Fließtext — Foxxy AI bewertet Definitionsabfragen, MC, formale Checks (Tenorierung); kein Beleg für Gutachten-KI-Korrektur | Größte Reichweite (20.000+ MAU, 200.000+ Nutzer, profitabel), breitestes Karteikarten-/Fallangebot, eigenes trainiertes Modell | Lücke bei Gutachten-KI-Korrektur — genau dort, wo Subsumo und Constellatio ansetzen |
| **Constellatio** | 12,42 €/Monat (149 €/Jahr) oder 399 € Lifetime; Gruppenpläne 10–16,67 €/Person/Monat | Interaktive Fälle, vernetztes Lexikon, Karteikarten, Lernpfade | ✅ **Ja**, seit 30.01.2026 — Bewertung von Inhalt (Anspruchsgrundlagen, Subsumtion) und Stil (Aufbau, Gutachtenstil) | Direktester Wettbewerber zum Subsumo-Kernnutzen, bereits live | Junges Feature (wenig Longitudinaldaten), kleineres Team als Jurafuchs |
| **KorrekturKai** | 29 €/Monat (299 €/Jahr) | Spezialisiert auf 1.-Examens-Klausurkorrektur: wöchentliche Klausuren, Randbemerkungen, Fehlerprofil, Remonstrationsrecht (menschliche Nachprüfung) | ✅ Ja, Kernprodukt | Fokussiertes Korrektur-Produkt mit menschlichem Eskalationsweg | Reines Korrektur-Tool, kein Karten-/Schema-Ökosystem; deutlich teurer als Subsumos Pro-Preisrahmen |
| **KlausurenKiste** | 2,99 €/Klausur einmalig, 7,50 €/Monat oder 89,99 €/Jahr (4 Klausuren + 2 eigene Fälle/Monat inkl.) | KI-Feedback < 1 Minute, Randbemerkungen, Rohpunkte, Fallbibliothek mit aktueller Rspr. | ✅ Ja, Kernprodukt | Günstigster Korrektur-Zugang, sehr schnelles Feedback | Ebenfalls reines Korrektur-Tool ohne Spaced-Repetition-Ökosystem |
| **hemmer / Alpmann Schmidt / Jura Intensiv** | 150–280 €/Monat, Jahreskurs gesamt 1.800–2.400 €+ | Präsenz-/Online-/Hybrid-Repetitorium, Skripten, menschliche Korrektur | ⚠️ Nein — nur Karteikarten-Kooperationen (Alpmann eCards/Repetico, hemmer×StudySmarter), keine eigene KI-Korrektur belegt | Menschliches Feedback, etablierte Marke, volle Stoffabdeckung | 8–15× teurer als eine App, ortsgebunden/feste Kurszeiten, digitale Angebote wirken nachrangig |
| **Anki** | Kostenlos (Windows/Mac/Linux/Android/Web); AnkiMobile iOS 29,99 € einmalig | Spaced-Repetition-Engine, riesige Community/Add-ons | ❌ Nein | Kostenlos, extrem flexibel, wissenschaftlich fundierter Algorithmus | Kein juristischer Content vorgefertigt (hoher Eigenaufwand), kein Gutachten-Feedback, kein Klausur-Simulator |

*Preise/Feature-Stände: Website-Abrufe 14.09.2026, sofern nicht anders vermerkt. Quellen: [jurafuchs.de](https://www.jurafuchs.de/), [legal-tech-verzeichnis.de/jurafuchs](https://legal-tech-verzeichnis.de/jurafuchs/), [jurafuchs.de – Foxxy AI](https://www.jurafuchs.de/jurafuchs-verbessert-die-lernerfahrung-mit-kuenstlicher-intelligenz-gpt-4/), [VC Magazin, 19.12.2025](https://www.vc-magazin.de/blog/2025/12/19/jurafuchs-deal-wachstumskapital/), [constellatio.de/preise](https://www.constellatio.de/preise), [constellatio.de/news – KI-Bewertung, 30.01.2026](https://www.constellatio.de/news/ki-bewertung-juristische-gutachten-constellatio), [korrekturkai.de](https://www.korrekturkai.de/), [klausurenkiste.de](https://www.klausurenkiste.de/), [jurahilfe.de – Repetitorium-Kosten](https://www.jurahilfe.de/blog/jura-repetitorium-kosten-erfahrungen-alternativen), [apps.apple.com – Alpmann eCards](https://apps.apple.com/de/app/alpmann-ecards/id976490537).*

**Weitere gefundene, aber nicht sicher verifizierte Anbieter:** Jurversity (Klausurkorrektur beworben, Details nicht verifiziert), okti.app (wirbt mit „Jura-Karteikarten-App mit KI", nicht verifiziert), DeepWrite (BMBF-Forschungsprojekt Uni Passau zu KI-Klausurbewertung, kein kommerzielles Produkt — Signal, dass auch Hochschulen an KI-Korrektur arbeiten). Zu den ursprünglich vermuteten Namen „Actorial" und „Lernlink" wurden **keine existierenden Produkte gefunden** — explizit als Nicht-Befund vermerkt, nicht geraten.

**Marktkontext:** Der Legal Tech Monitor 2025 (Legal Tech Verband Deutschland) zählt ca. 300 aktive Legal-Tech-Unternehmen in Deutschland (~10.000 Beschäftigte, ~800 Mio. € Bilanzsumme) — jedoch für den gesamten B2B-Legal-Tech-Sektor, nicht spezifisch für B2C-Jura-Lernapps. Eine unabhängige Marktgrößenangabe für den Teilmarkt „Jura-Lern-Apps" konnte nicht gefunden werden. Als Signal für reales, wenn auch bescheidenes VC-Interesse: Jurafuchs hat im Dezember 2025 weiteres Wachstumskapital erhalten (0,5 Mio. €, davon zweckgebunden für Foxxy-AI-Ausbau), Constellatio befindet sich in der Seed-Phase. (Quelle: [LTO zu Legal Tech Monitor 2025](https://www.lto.de/recht/nachrichten/n/studie-legal-tech-monitor-2025-kuenstliche-intelligenz-nachwuchsgewinnung-jura), [inVenture Capital zu Jurafuchs](https://www.inventure.capital/side-letter/financing-rounds/jurafuchs-sichert-sich-erfolgreich-weiteres-wachstumskapital-1768227170548-uvmbdj).)

---

## 3. Positionierung

### These aus der Roadmap

> Verkauft wird die Korrektur (Minuten statt Wochen, begründet bis auf den
> Prüfpunkt) plus die 5-Stunden-Klausur offline — nicht die Karteikarten,
> denn dort ist Jurafuchs billiger und Anki gratis.

### Prüfung anhand der Rechercheergebnisse: teilweise bestätigt, teilweise zu präzisieren

**Bestätigt:** Karteikarten als Hauptnutzen zu verkaufen wäre falsch. Jurafuchs ist bei reinen Karteikarten/Fällen sowohl billiger (5,99 €/Monat) als auch reichweitenstärker (200.000+ Nutzer), Anki ist gratis. Auf diesem Feld gewinnt Subsumo nicht.

**Zu präzisieren:** „Die Korrektur" allein ist **nicht mehr** der Alleinstellungspunkt, den die Roadmap unterstellt. Zum Zeitpunkt dieser Analyse (September 2026) bieten mindestens drei Wettbewerber KI-Korrektur von Gutachten im Fließtext an — Constellatio seit Ende Januar 2026 direkt im Kernprodukt zu einem Preis knapp über Subsumos geplantem Pro-Preis, KorrekturKai und KlausurenKiste als spezialisierte Tools links und rechts vom Subsumo-Preispunkt. Der in `docs/03-roadmap.md` (M3) formulierte Anspruch „Das Alleinstellungsmerkmal ist live" trifft für die KI-Korrektur an sich nicht mehr zu und sollte bei nächster Roadmap-Überarbeitung nachgezogen werden — das ist hier nur ein Hinweis, keine Änderung an `docs/03-roadmap.md` im Rahmen dieser Aufgabe.

Was die Recherche **nicht** widerlegt: Bei keinem der drei KI-Korrektur-Anbieter (Constellatio, KorrekturKai, KlausurenKiste) fand sich ein Beleg für einen **nativen, plattformübergreifenden 5-Stunden-Offline-Klausursimulator mit Pacing/Ablenkungssperre** — alle drei wirken als Web-Einreichungstools für bereits geschriebene Texte, nicht als Prüfungssimulation unter Realbedingungen. Ebenso ist bei keinem Wettbewerber die **Verzahnung** aus Karte → Schema → Fall → Korrektur → Wiederholung in einem System belegt; Constellatio kombiniert Korrektur mit Karten/Lexikon, aber die Klausursituation selbst bleibt offen, KorrekturKai/KlausurenKiste sind reine Korrektur-Insellösungen ohne Karteikarten-Ökosystem.

**Präzisierte Positionierung:** Nicht „wir haben KI-Korrektur" (das haben andere auch), sondern „wir haben KI-Korrektur **eingebettet in dasselbe System, das auch die Klausursituation selbst realistisch simuliert** — offline, auf allen Plattformen, mit derselben Wissenslandkarte, die schon die Karten und Schemata trägt."

### Positionierungssatz

> Subsumo wird gekauft, weil es als einziges Produkt die eigene Klausur in
> Minuten statt Wochen begründet korrigiert **und** die 5-Stunden-Prüfungs-
> situation offline realistisch trainierbar macht — beides verzahnt mit
> demselben Karten- und Schema-Stoff, nicht als isoliertes Korrektur-Tool.

> **Nachtrag 16.09.2026:** Dieser Positionierungssatz beschreibt das
> **Zielbild (v1.2)**, nicht den v1.0-Release-Umfang. Nach der Terminvorgabe
> „Release in zwei Wochen" enthält v1.0 (`docs/18-release-2-wochen.md`) weder
> den Offline-Klausursimulator (dort fest für v1.1 eingeplant) noch
> standardmäßig die KI-Korrektur (`llm_provider=none`; eine bedingte
> Aktivierung bis 27.09.2026 hängt am unterschriebenen AVV, siehe dort
> Abschnitt 2.1). v1.0 liefert Karteikarten, Schemata, geführte Fälle und den
> heuristischen Struktur-Check. Die Preisfolge dazu steht in Abschnitt 4
> dieses Dokuments.

---

## 4. Preisempfehlung

> **Nachtrag 15.09.2026:** Dieser Abschnitt gilt für den **vollen**
> Funktionsumfang inklusive KI-Korrektur. Nach der Terminvorgabe „Release in
> zwei Wochen" enthält v1.0 diese Korrektur nicht mehr
> (`docs/18-release-2-wochen.md`). Der Preis für den Release-Umfang und die
> Kostendeckungsrechnung dazu stehen in
> [`docs/19-kosten-preis-budget.md`](19-kosten-preis-budget.md); die hier
> empfohlenen 12 €/Monat bleiben der Zielpreis für v1.2.

Die Produktvision setzt 12 €/Monat an. Der Marktführer nach Reichweite
(Jurafuchs) startet bei 5,99 €/Monat, der direkteste funktionale Wettbewerber
(Constellatio) liegt bei 12,42 €/Monat — nahezu identisch mit dem
Subsumo-Ansatz. Spezialisierte Korrektur-Tools liegen deutlich darüber
(KorrekturKai 29 €/Monat) oder darunter (KlausurenKiste 7,50 €/Monat).

Alle ARR-Hochrechnungen nutzen als Basis die Pro-relevante Zielgruppe aus
Abschnitt 1.2 (Jonas ≈ 88.190 + Mira ≈ 14.870 = **103.060**), da Lena laut
Geschäftsmodell im großzügigen Free-Tier bleibt und nicht als Pro-Käuferin
kalkuliert wird. Durchdringung bezieht sich auf diese Zielgruppe, nicht auf
alle 116.760 Studierenden.

### Option 1 — 12 €/Monat halten (144 €/Jahr)

Ein Preis für alle Pro-Funktionen.

| Durchdringung | Zahlende | ARR |
|---|---|---|
| 2 % | 2.061 | **≈ 297.000 €** |
| 5 % | 5.153 | **≈ 742.000 €** |
| 10 % | 10.306 | **≈ 1.484.000 €** |

### Option 2 — Staffelung Basis + Korrektur

Basis-Pro (unbegrenzte Fälle, Klausur-Simulator ohne KI-Korrektur, adaptiver
Lernplan) für 6,99 €/Monat (83,88 €/Jahr), gezielt für Jonas. Examens-Pro
(zusätzlich KI-Klausurkorrektur) für 16,99 €/Monat (203,88 €/Jahr), gezielt
für Mira. Gleiche Durchdringungsrate in beiden Segmenten angenommen — real
würde ein niedrigerer Einstiegspreis bei Jonas vermutlich eine *höhere*
Durchdringung erzielen als bei Option 1, das ist hier nicht eingepreist.

| Durchdringung | Jonas-ARR (Basis-Pro) | Mira-ARR (Examens-Pro) | ARR gesamt |
|---|---|---|---|
| 2 % | ≈ 148.000 € | ≈ 61.000 € | **≈ 209.000 €** |
| 5 % | ≈ 370.000 € | ≈ 152.000 € | **≈ 522.000 €** |
| 10 % | ≈ 740.000 € | ≈ 303.000 € | **≈ 1.043.000 €** |

### Option 3 — Examens-Halbjahrespaket

89 € für 6 Monate unbegrenzte KI-Korrektur, ausschließlich für Mira
positioniert (Analogie zu KorrekturKais Jahrespreis, aber günstiger und
semesterweise buchbar). Angenommen: ein aktiver Examenskandidat kauft im
Schnitt 2 Pakete während der 14-monatigen Vorbereitungszeit → 178 €
Jahreswert pro zahlender Person. Nur die Mira-Zielgruppe (14.870) fließt ein.

| Durchdringung | Zahlende | ARR |
|---|---|---|
| 2 % | 297 | **≈ 53.000 €** |
| 5 % | 744 | **≈ 132.000 €** |
| 10 % | 1.487 | **≈ 265.000 €** |

### Empfehlung: Option 1 (12 €/Monat halten), Option 3 als gezielter Akquise-Kanal ergänzen

Drei Gründe für Option 1 als Kernpreis:

1. **Höchstes Umsatzpotenzial bei gleicher Durchdringung.** Der Blended-Preis
   von Option 2 (≈ 8,57 €/Monat gewichtet über beide Segmente) liegt spürbar
   unter 12 €, ohne dass die Recherche einen Beleg liefert, dass die
   zusätzliche Durchdringung durch den niedrigeren Basis-Preis diesen
   Unterschied aufholt.
2. **Operative Einfachheit passt zum Team.** `docs/03-roadmap.md` nennt
   1–2 Entwickler + Teilzeit-Redaktion als Teamgröße. Zwei SKUs mit
   unterschiedlichen Freigabelogiken (Basis-Pro vs. Examens-Pro) erzeugen
   Abrechnungs- und Support-Aufwand, den ein Team dieser Größe im Release-Jahr
   vermutlich nicht braucht.
3. **12 € liegt bereits am Marktkonsens.** Constellatio, der funktional
   nächste Wettbewerber, verlangt fast denselben Preis (12,42 €/Monat) — das
   validiert die Zahlungsbereitschaft in diesem Preisband, statt sie infrage
   zu stellen.

Option 3 (Examens-Halbjahrespaket) sollte **nicht** den 12-€-Kern ersetzen,
aber als zusätzlicher, zeitlich begrenzter Akquisekanal rund um Klausurenphasen
getestet werden — ähnlich wie KorrekturKai und KlausurenKiste explizit auf den
Examens-Moment zielen. Das ist ein Marketing-/Packaging-Experiment auf Basis
des bestehenden Pro-Preises, kein Ersatz für ihn, und braucht vor der Umsetzung
einen eigenen Test (siehe Interviewleitfaden, Frage Mira #7).

Gegen Option 2 spricht zusätzlich: Er verschiebt die Konkurrenzfrage in ein
Segment (Basis-Pro ohne KI-Korrektur), in dem Jurafuchs bei 5,99 €/Monat
strukturell günstiger bleibt — Subsumo würde dort denselben Fehler
wiederholen, den die Positionierung in Abschnitt 3 gerade vermeiden soll.

---

## 5. Interviewleitfaden

Ziel: Preisbereitschaft und den tatsächlichen Nutzen der KI-Korrektur prüfen,
bevor eine der drei Optionen aus Abschnitt 4 final festgelegt wird. Führung
der Interviews ist nicht Teil dieser Aufgabe.

### Lena (Studieneinstieg, 1.–2. Semester)

1. Was nutzt du aktuell, um dir Jura-Stoff zu merken — Karteikarten, eigene
   Notizen, nichts Systematisches?
2. Wie hast du dein aktuelles Lernmittel ausgewählt? Was hat den Ausschlag
   gegeben?
3. Anki ist kostenlos, Jurafuchs kostet 6 €/Monat — wärst du bereit, für eine
   App mit Karten und Schemata zu zahlen? Was müsste sie zusätzlich können?
4. Wie oft hast du bisher ein eigenes Gutachten geschrieben und dazu Feedback
   bekommen?
5. Was wäre dir ein sofortiges, begründetes Feedback auf deinen ersten
   Obersatz wert — auch wenn es (noch) nicht von einem Menschen kommt?
6. Wie wichtig ist dir Offline-Nutzung (Bibliothek ohne WLAN, Bahnfahrt)?
7. Kennst du Jurafuchs oder Constellatio? Was hält dich von der Nutzung ab
   oder überzeugt dich?
8. Hast du schon von KI-Klausurkorrektur gehört? Würdest du ihr vertrauen,
   wenn du gerade erst anfängst?
9. Wie viel gibst du aktuell monatlich für Lernmittel/Bücher aus?
10. Was müsste in den ersten zehn Minuten in der App passieren, damit du sie
    weiterempfiehlst?

### Jonas (Grundstudium/Schwerpunkt, Klausurfokus)

1. Wie viele Klausuren schreibst du pro Semester, und wie lange wartest du im
   Schnitt auf eine Korrektur?
2. Was fehlt dir an der Uni-Korrektur am meisten — Geschwindigkeit, Tiefe,
   Nachvollziehbarkeit der Punktabzüge?
3. Nutzt du aktuell Jurafuchs, Constellatio oder ein anderes Tool? Was zahlst
   du dafür, was fehlt dir?
4. Kennst du Foxxy AI (Jurafuchs) oder die KI-Bewertung von Constellatio?
   Hast du sie genutzt — wie war das Ergebnis?
5. Was wäre dir eine KI-Korrektur wert, die in Minuten statt Wochen kommt und
   jeden Punktabzug auf einen Prüfpunkt zurückführt?
6. Würdest du 12 €/Monat für unbegrenzte Fälle plus KI-Klausurkorrektur
   zahlen? Ab welchem Preis lohnt es sich für dich nicht mehr?
7. Wie wichtig ist dir, dass Karteikarten, Schemata und Klausurkorrektur aus
   einem System statt aus drei Apps kommen?
8. Trainierst du Klausurtaktik/Zeitmanagement gezielt, oder erst kurz vor dem
   Examen?
9. Was müsste eine App bieten, damit sie dein Repetitorium teilweise ersetzt
   statt nur ergänzt?
10. Zahlst du lieber monatlich, im Jahresabo, oder in einem Paket rund um
    Klausurenphasen?

### Mira (Examensvorbereitung, ~14 Monate)

1. Wie viel gibst du insgesamt für deine Examensvorbereitung aus (Rep,
   Bücher, Tools)?
2. Wie viele Klausuren schreibst/korrigierst du pro Woche — was begrenzt
   dich: Zeit, Geld, Verfügbarkeit von Korrektor:innen?
3. Wie lange wartest du aktuell auf eine Klausurkorrektur (Rep, Uni, Tutor)?
4. Hast du KorrekturKai, KlausurenKiste oder die KI-Korrektur von
   Constellatio ausprobiert? Wie war dein Eindruck — Geschwindigkeit,
   Vertrauen, Genauigkeit?
5. Was ist dir wichtiger: mehr Klausuren üben können, oder tieferes Feedback
   auf weniger Klausuren?
6. Vertraust du einer KI-Bewertung genug, um danach deine Priorität zu
   setzen — oder brauchst du zusätzlich eine menschliche Einschätzung?
7. Würdest du 89 € für ein halbes Jahr unbegrenzte KI-Korrektur zahlen,
   verglichen mit dauerhaft 12 €/Monat? Was spricht für dich für das eine
   oder das andere?
8. Wie wichtig ist dir ein realistischer 5-Stunden-Klausursimulator offline,
   verglichen mit einer reinen Korrekturfunktion?
9. Was müsste passieren, damit du dein Repetitorium kündigst oder gar nicht
   erst buchst?
10. Müsstest du dich zwischen einem günstigeren Tool ohne Korrektur und einem
    teureren mit Korrektur entscheiden — wo liegt deine Schmerzgrenze in
    Euro pro Monat?
