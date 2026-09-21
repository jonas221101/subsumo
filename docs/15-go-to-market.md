# Go-to-Market-Plan — T7

> Löst [SUB-46](/SUB/issues/SUB-46), Spur T7 der
> [Release-Roadmap](/SUB/issues/SUB-39#document-plan). Randbedingung aus dem
> Auftrag: ein kleiner, schrumpfender Markt (116.760 Jurastudierende,
> Studienanfängerzahlen seit WS 2018/19 rückläufig — `docs/14-marktanalyse.md`
> Abschnitt 1.1) und ein entsprechend kleines Budget
> (`docs/19-kosten-preis-budget.md` Abschnitt 6: kein Werbebudget vorgesehen).
> Bezahlte Reichweite ist damit keine Option, die hier gegen organische
> Kanäle abgewogen wird — sie ist ausgeschlossen, siehe Abschnitt 5.
>
> **Eingänge:** Positionierung und Preisempfehlung aus
> `docs/14-marktanalyse.md` Abschnitt 3/4, Kostenrahmen aus
> `docs/19-kosten-preis-budget.md`. **Verhältnis zu
> `docs/21-landing-preisseite-launchtext.md`:** Jenes Dokument liefert die
> fertigen Launch-Texte je Kanal für den Releasetag (G5, SUB-88). Dieses
> Dokument liegt eine Ebene darüber — Aufwand/Wirkung/Zeitpunkt je Kanal im
> Dauerbetrieb, nicht nur am Launch-Tag — und verweist für die konkreten
> Texte auf `docs/21`, statt sie zu wiederholen. Eine Abweichung ist unten in
> Abschnitt 1.3 benannt, nicht stillschweigend übernommen.
>
> **Stand:** 21.09.2026. Releasetermin 29.09.2026, Code-Freeze 28.09.2026
> (`docs/18-release-2-wochen.md` Abschnitt 5). Annahmen sind als solche
> markiert.

---

## 1. Kanalplan

Bewertungsmaßstab für „Aufwand": Personenstunden bis zur ersten Wirkung, bei
1–2 Entwickler:innen + Teilzeit-Redaktion ohne dediziertes Marketing-Personal
(`docs/03-roadmap.md` Teamgrößen-Annahme). „Wirkung" ist qualitativ
eingestuft (hoch/mittel/niedrig), da vor Launch keine eigenen Kennzahlen
existieren — siehe Messgrößen in Abschnitt 4.

### 1.1 Fachschaften und Lehrstühle

**Aufwand: niedrig bis mittel** (Anschreiben liegt versandfertig vor,
Abschnitt 3.2; Aufwand liegt im Nachfassen, nicht im Erstkontakt).
**Wirkung: hoch** — einziger Kanal, der eine ganze Universität auf einmal
erreicht, ohne dass jede einzelne Person gefunden werden muss.
**Zeitpunkt: Anschreiben ab sofort (21.09.), laufend über das ganze
Semester** — Fachschaftsräte sind zwischen den Semestern (jetzt, vor
Vorlesungsbeginn Mitte Oktober) oft weniger aktiv besetzt, ein einzelner
Versand vor Semesterstart erreicht deshalb nicht zwingend eine
beschlussfähige Sitzung. Deshalb kein einmaliger Versand, sondern ein
Nachfass-Rhythmus (Abschnitt 3.1) über die ersten Semesterwochen.

**Angebotsmodell für die Beta-Campus-Lizenz.** `docs/01-produktvision.md`
Geschäftsmodell nennt eine eigene Campus-Stufe (Fachschafts-/
Lehrstuhllizenz, eigene Klausuren einstellen) — die ist für v1.2 vorgesehen
und in v1.0 nicht gebaut. Das Beta-Angebot an Fachschaften darf deshalb
nichts versprechen, was das Produkt heute nicht kann:

> Kostenloser Pro-Zugang (alle drei Rechtsgebiete, unbegrenzte Karten,
> Schemata, Fälle, Struktur-Checks) für alle Mitglieder der Fachschaft über
> einen Freischaltcode, für sechs Monate ab Ausgabe. Gegenleistung: Verlinkung/
> Ankündigung von Subsumo in den Fachschafts-Kanälen (Newsletter, Website,
> Erstsemester-Infomaterial) und — sofern gewünscht — kurzes Feedback nach
> 4–6 Wochen Nutzung.

Das ist mit den bestehenden Tarifen (Free/Pro aus `docs/19` Abschnitt 4)
umsetzbar, sobald es einen Freischaltcode-Mechanismus gibt — dieser existiert
laut Repo-Suche noch nicht (kein Treffer für Gutschein-/Redeem-Code im
Bezahlmodell) und ist damit eine technische Abhängigkeit an den
Software-Planner, keine Marketing-Entscheidung. Bis dahin ist der Ersatz ein
manuell vergebener zeitlich befristeter Pro-Status pro E-Mail-Adresse
(Aufwand: wenige Minuten pro Fachschaft, vertretbar bei der hier geplanten
Größenordnung von 2–5 Kooperationen).

### 1.2 Content-Marketing (Schemata/Definitionen als öffentliche Webseiten)

**Aufwand: niedrig** im Grenzkostensinn — die Schemata und Definitionen
entstehen ohnehin über die Content-Pipeline (`docs/05-content-pipeline.md`,
`docs/08-ki-redaktion.md`) für die App. Zusätzlicher Aufwand ist nur das
Veröffentlichen als eigenständige, indexierbare Webseite pro Schema/Begriff
mit Quellenangabe (Norm, Rechtsprechung, Stand) — keine neue Content-Produktion.
**Wirkung: mittel, aber compoundierend** — SEO-Reichweite baut sich über
Wochen/Monate auf (Suchmaschinenindexierung, Backlinks), nicht am Tag der
Veröffentlichung; gleichzeitig ist jede Seite ein öffentlicher
Qualitätsbeweis für Content, den man vor dem Kauf ohne Anmeldung prüfen kann.
**Zeitpunkt: nach Release, nicht als Launch-Feature.** Technische
Umsetzung (öffentliche, nicht-eingeloggte Rendering-Route für Schema-/
Glossar-Seiten) ist im Zwei-Wochen-Schnitt (`docs/18`) nicht enthalten und
würde G3 (Content-Freeze) und G4 (Code-Freeze) gefährden, wenn sie jetzt
hineingezogen würde. **Annahme:** Start in Phase B (`docs/03-roadmap.md`,
„T7 Landing Page, Beta-Warteliste, Content-Marketing beginnt") — realistisch
2.–4. Woche nach Release, sobald der Content-Freeze vorbei ist und wieder
Kapazität für eine neue Ausgabeform besteht. Bis dahin liegt der Content
ohnehin nur im eingeloggten Produkt, es gibt nichts zu verlieren, wenn der
Kanal nach dem Launch-Trubel startet statt davor.

### 1.3 Landing Page mit Warteliste, Entwicklungsberichte in der Öffentlichkeit

**Aufwand: niedrig** — Landing Page und Warteliste sind laut Tagesplan
(`docs/18` Abschnitt 6) ohnehin release-kritisch geplant (Warteliste/
Newsletter 22.09., Landing live 24.09.), Text liegt in `docs/21` Abschnitt 2
fertig vor. Zusätzlicher Aufwand hier ist nur der laufende Teil:
regelmäßige, kurze Entwicklungsberichte („Build in Public").
**Wirkung: mittel** — Warteliste ist die einzige Größe, die vor dem
eigentlichen Launch schon Reichweite in Zahlende umwandeln lässt; Berichte
in der Öffentlichkeit schaffen Vertrauen bei einer Zielgruppe (Jurastudierende),
die skeptisch gegenüber „fertig wirkenden" EdTech-Versprechen ist — passt zur
Leitplanke „Umfang offen kommunizieren" aus `docs/21` Abschnitt 1.
**Zeitpunkt:** Warteliste ab 22.09. (bereits terminiert), Entwicklungsberichte
ab demselben Datum im Wochentakt, fortlaufend über Release hinaus.

**Abweichung zu `docs/21` benannt statt stillschweigend übernommen:** `docs/21`
Abschnitt 4.1 lässt die konkreten Tag-1-Kanäle (Fachschaft, Jura-Kanal,
Lerngruppe) bewusst offen, weil das laut `docs/18` Abschnitt 8 Punkt 4 eine
noch offene Nutzerentscheidung ist. Dieser Plan geht davon aus, dass diese
Entscheidung bis zum Launch nicht zwingend fällt (Abschnitt 8 dort blockiert
„Teile, nicht den Termin") — deshalb plant Abschnitt 3 unten das
Beta-Programm unabhängig von einer bereits vorhandenen Fachschafts-Beziehung,
mit Kaltakquise als Normalfall.

### 1.4 Dozentennetzwerk aus der Kalibrierung

**Aufwand: kein Zusatzaufwand** — der Kontaktaufbau zu Dozent:innen/
Korrekturassistent:innen läuft bereits für die Kalibrierung
(`docs/24-kalibrierungspaket.md` Abschnitt 5, `docs/13-lernarchitektur.md`
Abschnitt 4.6) und nutzt laut jenen Dokumenten explizit dieselben
T7-Fachschaftskontakte. **Wirkung: niedrig als Reichweitenkanal, aber hoch als
Glaubwürdigkeitssignal** — ein Dozent, der öffentlich sagt, er habe bei der
Kalibrierung mitgewirkt, ist ein stärkerer Vertrauensbeweis als jede eigene
Werbeaussage, gerade weil `docs/06-recht-compliance.md` Abschnitt 5
Werbeaussagen zur Bewertungsqualität einschränkt. **Zeitpunkt:** sobald die
Kalibrierung selbst Dozent:innen gewinnt (laut `docs/24` Abschnitt 4.2 ist
die Opt-in-Beta-Gutachten-Quelle sogar von der hier geplanten
Fachschafts-Beta abhängig — Reihenfolge ist also: Fachschafts-Beta zuerst,
Dozentennetzwerk-Nutzung als Marketingkanal danach, nicht umgekehrt). Diese
Abhängigkeit ist der Grund, warum Abschnitt 3 (Beta-Programm) mit höherer
Priorität als dieser Kanal behandelt wird.

### 1.5 Store-Auftritte als Konversionsfläche

**Aufwand: niedrig** — Screenshots entstehen aus dem ohnehin gebauten
Produkt, kein zusätzlicher Produktionsaufwand außer Bildauswahl/-beschnitt.
**Wirkung: niedrig zum Start, steigend mit Android-Reichweite** — laut
Tagesplan (`docs/18` Abschnitt 6) geht Android am 29.09. zunächst im
**Testing-Track** live, nicht in der offenen Produktion; die Konversionsfläche
Play Store wird erst wirksam, sobald der Track auf offene Produktion
umgestellt wird (kein festes Datum im Schnittplan — Annahme: Wochen 1–2 nach
Release, sobald Testing-Feedback eingearbeitet ist).
**Inhalt — Klarstellung zur Aufgabenstellung:** Der Auftrag verlangt
„Screenshots der Korrektur, nicht der Karteikarten". Das ist mit den
Leitplanken aus `docs/21` Abschnitt 1 nur kompatibel, wenn diese Screenshots
den **heuristischen Struktur-Check** zeigen (Feedback zu Aufbau/Stil, ohne
Note) — **nicht** mit dem Wort „KI" beschriftet, unabhängig davon, ob die
KI-Korrektur zum Stichtag 27.09. aktiviert wird oder nicht. Store-Texte
folgen damit ohne Ausnahme Fassung A aus `docs/21` Abschnitt 2.2/2.3, auch
wenn Fassung B intern gezogen wird — Store-Metadaten sind in der
Austauschregel aus `docs/21` Abschnitt 2.3 nicht als zu ändernder Text
gelistet und bleiben deshalb bewusst unverändert.
**Zeitpunkt:** Store-Eintrag existiert ab G5 (29.09., Testing-Track),
Screenshots/Beschreibung so vorbereiten, dass sie unabhängig vom
KI-Korrektur-Stichtagsentscheid sofort korrekt sind (siehe oben).

### 1.6 Fachpresse und Studierendenmedien

**Aufwand: mittel** — Pressemitteilung/Kurzvorstellung an namentlich bekannte
Redaktionen (LTO Karriere, azur, Uni-Zeitungen der Standorte mit
Fachschaftskontakt) erfordert individuelle Ansprache, keine Massen-E-Mail;
Rückmeldungszeiten bei Redaktionen liegen typischerweise bei Wochen, nicht
Tagen. **Wirkung: mittel bis hoch bei Erfolg, aber unsicher** — diese Medien
entscheiden redaktionell, ob sie berichten; das ist kein Kanal, auf dessen
Wirkung sich ein Termin stützen lässt. **Annahme:** kein belastbarer Kontakt
zu diesen Redaktionen liegt aktuell vor (keine Erwähnung in den
Eingangsdokumenten) — Erstansprache ist deshalb Kaltakquise mit
entsprechend niedriger Erfolgswahrscheinlichkeit beim ersten Versuch.
**Zeitpunkt:** Erstansprache nach Landing-Page-Launch (ab 24.09., damit ein
Link zum Verweisen existiert), realistische Wirkung frühestens
2.–4. Woche nach Release — passt zeitlich mit dem Content-Marketing-Start
(Abschnitt 1.2) zusammen und kann in derselben Ansprache gebündelt werden
(„Wir sind live, und hier ist unser öffentliches Schema-Glossar").

---

## 2. Zeitplan am Semesterrhythmus

**Kaufentscheidungen konzentrieren sich laut Aufgabenstellung auf
Semesterbeginn (Oktober/April) und den Start der Examensvorbereitung.** Für
Subsumo ergeben sich daraus zwei strukturell unterschiedliche Fenster:

- **Semesterbeginn ist ein fester Kalendertermin** (Vorlesungsbeginn
  Wintersemester typischerweise Mitte Oktober — **Annahme**, da kein
  einheitliches bundesweites Datum existiert und keine Quelle dafür in den
  Eingangsdokumenten steht) und betrifft vor allem Lena (Studieneinstieg)
  und, in geringerem Maß, Jonas (Grundstudium/Schwerpunkt, neue
  Klausurenphase).
- **Der Start der Examensvorbereitung ist kein fester Kalendertermin**,
  sondern für jede Mira individuell der Beginn ihres persönlichen
  14-Monats-Fensters (`docs/14-marktanalyse.md` Abschnitt 1.2) — diese
  Zielgruppe lässt sich nicht durch einen einzelnen Stichtag adressieren,
  sondern braucht einen ganzjährig verfügbaren Einstiegspunkt.

**Daraus abgeleitetes Launchfenster:** Der bereits gesetzte Releasetermin
29.09.2026 liegt günstig — 1–2 Wochen vor dem Wintersemester-Vorlesungsbeginn.
Das eigentliche **Kampagnenfenster ist deshalb nicht der 29.09. selbst,
sondern der Zeitraum 29.09.–20.10.2026** (Release bis kurz nach
Vorlesungsbeginn): Die Landing Page und die ersten Fachschafts-Kontakte laufen
bereits vor dem 29.09. an, die eigentliche Reichweitenwirkung (Ersti-Wochen,
Fachschafts-Infomaterial, Vorlesungsankündigungen) entsteht aber erst, wenn
Studierende überhaupt wieder vor Ort und ansprechbar sind. Diese
Einschätzung deckt sich mit der Roadmap-Aussage „Release ist ein Anfang, kein
Kampagnenstart; GTM-Spur läuft nach Release weiter" (`docs/18` Abschnitt 7,
Risikotabelle).

Für Mira (Examensvorbereitung) gibt es **kein vergleichbares Zeitfenster** —
das Examens-Halbjahrespaket (`docs/14-marktanalyse.md` Abschnitt 4, Option 3)
ist deshalb bewusst als ganzjährig buchbares Angebot konzipiert, nicht als
kampagnengebundene Aktion, und wird über denselben Dauerbetrieb (Content-
Marketing, Landing-Page-Segment für Mira) beworben, nicht über ein eigenes
Zeitfenster.

**Zweites jährliches Fenster (April/Sommersemester):** Kleiner als der
Oktober-Termin, weil weniger Studienanfänger:innen im Sommersemester
beginnen (**Annahme**, kein Beleg in den Eingangsdokumenten, aber konsistent
mit dem allgemein bekannten Muster, dass die Mehrheit der
grundständigen Studiengänge zum Wintersemester startet) — wird hier als
zweiter, kleinerer Wiederholungspunkt für dieselben Kanäle vorgemerkt, nicht
gesondert ausgeplant, da bis April 2027 zunächst Betriebserfahrung aus dem
Oktober-Fenster vorliegt, die diesen Plan aktualisieren sollte.

---

## 3. Beta-Programm

### 3.1 Wie kommen 2 Fachschaftskooperationen zustande

**Vorgehen:**

1. Kontaktliste aus öffentlich auffindbaren Fachschafts-Kontaktseiten
   (typischerweise `jura.fachschaft@<hochschule>.de` oder vergleichbar) für
   eine erste Welle von 10–15 juristischen Fakultäten — bevorzugt dort, wo
   bereits ein Kalibrierungs-/Dozentenkontakt beabsichtigt ist (Abschnitt
   1.4), um Doppelansprache an derselben Fakultät zu vermeiden.
2. Anschreiben (Abschnitt 3.2) versenden, adressiert an den Fachschaftsrat,
   nicht an Einzelpersonen.
3. **Nachfass-Rhythmus:** Erinnerung nach 10 Werktagen ohne Antwort, danach
   ein zweiter Kanal (z. B. Kontaktformular der Fachschafts-Website oder
   Instagram-Nachricht), falls vorhanden — keine dritte Erinnerung ohne neuen
   Anlass.
4. Erfolg ist eine schriftliche Zusage (E-Mail reicht, kein Vertrag nötig)
   zu Gegenleistung und Freischaltcode-Ausgabe.

**Realistische Einordnung — Befund statt passend gerechneter Plan.** Die
Aufgabenstellung nennt 2 Fachschaftskooperationen als Release-Gate für diese
Spur. Zwei Punkte sprechen dagegen, dass „Gate" hier „abgeschlossen bis
29.09." bedeuten kann, und werden deshalb offen benannt statt im Zeitplan
verschwiegen:

- Fachschaftsräte sind ehrenamtliche, kollektiv entscheidende Gremien ohne
  Vorlesungsbetrieb in der Woche vor Semesterstart; eine belastbare
  Rückmeldung *und* interne Abstimmung innerhalb von acht Tagen (21.–29.09.)
  ist unrealistisch, unabhängig davon, wie gut das Anschreiben ist.
- `docs/03-roadmap.md` selbst verortet „Beta mit 2 Fachschaften" ursprünglich
  in Phase C (Wochen 17–24 der 28-Wochen-Planung, also deutlich nach
  Release) — nicht in Phase A/B, die zeitlich mit dem jetzigen
  Zwei-Wochen-Schnitt zusammenfällt.

**Konsequenz für diesen Plan:** Der Reaktivierungs-Kommentar auf
[SUB-46](/SUB/issues/SUB-46) verlangt, dass der Kanal „vor dem Launchfenster
anlaufen kann, nicht danach" — das ist
erfüllbar (Versand ab 21.09., siehe Abschnitt 1.1) und wird hiermit als
Zeitplan gesetzt. Der **Abschluss** von 2 Kooperationen bis exakt 29.09. ist
dagegen kein realistisches Versprechen dieses Plans. Realistisches Ziel:
**erste 1–2 Zusagen bis Ende der Ersti-Woche (ca. 20.10.2026)**, im laufenden
Nachfass-Betrieb weiter bis 2 Kooperationen erreicht sind. Sollte das
Unblocker-/Coordinator-seitig anders benötigt werden (z. B. weil 2
Kooperationen zwingend vor 29.09. vorliegen müssen), ist das eine Rückfrage
an den Auftraggeber, keine Annahme, die dieser Plan sich selbst geben darf.

### 3.2 Anschreibenvorlage für Fachschaften (versandfertig)

> Betreff: Kostenloser Beta-Zugang zu Subsumo für eure Fachschaft
>
> Hallo liebe Fachschaft [Name der Hochschule],
>
> mein Name ist [Name/Team], wir bauen gerade Subsumo — eine neue Lern-App
> für Jurastudierende mit Karteikarten, Prüfungsschemata, geführten
> Übungsfällen und einem automatischen Struktur-Check für eigene Gutachten
> (Lernhilfe, keine Note, kein Ersatz für eine Korrektur durch Lehrpersonal).
>
> Ehrlich gesagt: Wir sind neu und starten mit 180 Karten über Zivilrecht,
> Strafrecht und Öffentliches Recht — weniger als etablierte Anbieter mit
> Tausenden Fällen. Genau deshalb würden wir uns freuen, wenn eure Fachschaft
> als eine unserer ersten Beta-Kooperationen dabei ist.
>
> **Unser Angebot:** Kostenloser Pro-Zugang (alle Rechtsgebiete, unbegrenzt
> Karten, Fälle, Struktur-Checks) für sechs Monate für alle Mitglieder eurer
> Fachschaft — per Freischaltcode, den ihr über euren Newsletter, eure
> Website oder das Erstsemester-Infomaterial verteilen könnt.
>
> **Worum wir bitten:** Eine kurze Erwähnung/Verlinkung in euren Kanälen und,
> wenn ihr mögt, ein kurzes Feedback nach vier bis sechs Wochen Nutzung — was
> funktioniert, was fehlt, was nervt. Keine Verpflichtung, keine Kosten, keine
> versteckten Bedingungen.
>
> Wenn das interessant klingt, meldet euch gerne — wir schicken dann direkt
> den Freischaltcode und ein kurzes Erklär-Material für eure Kanäle.
>
> Viele Grüße
> [Name/Team Subsumo]
> [Kontakt-E-Mail]

**Hinweis zur Rechtstexte-Abhängigkeit:** Dieses Anschreiben nennt keinen
Firmennamen oder keine Rechtsform (nur die Marke „Subsumo"), analog zur
Regel aus `docs/21` Abschnitt 1 Punkt 5, solange der Rechtsträger (G1) nicht
feststeht.

### 3.3 Wie kommen 100 Warteliste-Anmeldungen zustande

**Kanäle, die zur Warteliste beitragen** (keine neuen Kanäle, Bündelung der
bereits oben geplanten): Landing Page (Abschnitt 1.3, ab 22.09.), eigene
Social-Kanäle laut `docs/21` Abschnitt 4.1 (ab 28.09. terminiert), sowie —
sofern in der ersten Welle bereits Rückmeldungen vorliegen — Fachschafts-
Verlinkung (Abschnitt 1.1/3.1). Kein zusätzlicher Aufwand über das im
Tagesplan (`docs/18` Abschnitt 6) bereits Geplante hinaus.

**Realistische Einordnung:** 100 Anmeldungen ohne bestehende Reichweite
(kein Social-Media-Bestand, keine E-Mail-Liste vor dem 22.09.) sind
ambitioniert, aber anders als die Fachschaftskooperationen **nicht** an eine
fremde Entscheidungsgeschwindigkeit gebunden — eine einzelne gut platzierte
Weiterleitung (z. B. durch eine Person mit Reichweite in einer Jura-
Lerngruppe oder einem größeren Studi-Kanal) kann die Zahl an einem Tag
verändern. Deshalb hier kein Befund wie in 3.1, sondern ein Messpunkt: siehe
Abschnitt 4, Abschaltkriterium für „Landing Page/Warteliste" nach zwei
Wochen, nicht erst nach acht.

---

## 4. Messgrößen

Ausgangslage: Es existiert aktuell **keine** Analytics-/Attributions-
Infrastruktur für Marketingkanäle (Repo-Suche ohne Treffer für UTM-Parameter,
Referral-Codes oder ein Analytics-Tool außerhalb von
Fehler-Tracking/Monitoring aus `docs/22-deploy-runbook.md` Abschnitt 8). Die
folgende Messung braucht deshalb minimal einen Herkunfts-Parameter pro
Anmeldelink (z. B. `?quelle=fachschaft-<kürzel>` an der Warteliste/
Registrierung) — das ist eine kleine technische Abhängigkeit an den
Software-/Backend-Developer, kein neues Analytics-System, und **nicht** Teil
dieser Aufgabe, aber Voraussetzung dafür, dass die Tabelle unten überhaupt
befüllbar ist.

| Kanal | Messgröße | Ab wann gezählt | Abschaltkriterium |
|---|---|---|---|
| Fachschaften/Lehrstühle | Zahl beantworteter Anschreiben, Zahl geschlossener Kooperationen, aktivierte Freischaltcodes je Kooperation | ab Erstversand 21.09. | Nach 15 angeschriebenen Fakultäten und einem vollen Nachfass-Zyklus (≈ 6 Wochen) **0 Zusagen**: Anschreiben/Angebot ist das Problem, nicht die Fakultätsauswahl — Text überarbeiten statt weiter Fakultäten anschreiben |
| Warteliste/Landing Page | Anmeldungen gesamt, Anmeldungen je Herkunftsquelle | ab Landing live 24.09. | Nach 14 Tagen (bis 08.10.) **unter 20 Anmeldungen**: Reichweite über eigene Kanäle allein trägt nicht — Fachschafts-/Presse-Kanäle stärker gewichten statt Landing-Page-Text weiter zu optimieren |
| Content-Marketing (Schema-Seiten) | Organische Suchmaschinen-Impressionen/Klicks je Seite, Zahl indexierter Seiten | ab erster Veröffentlichung (Annahme Start Phase B, s. 1.2) | Nach 8 Wochen **keine messbare Impressionssteigerung** (Search-Console-Trend flach): Kanal auf Wartungsmodus (Seiten bleiben online als Content, aber keine aktive Ausweitung) statt weiter Seiten zu produzieren |
| Store-Auftritt | Listing-Impressionen, Installationsrate (Impressionen → Installs) | ab Produktions-Freigabe des Play-Tracks (Annahme Wochen 1–2 nach Release) | Kein eigenes Abschaltkriterium — Grenzkosten sind bereits nahe null (Abschnitt 1.5), ein „Abschalten" des Play-Store-Eintrags ist ohnehin nicht sinnvoll möglich, solange die App im Store bleibt |
| Fachpresse/Studierendenmedien | Zahl beantworteter Presseanfragen, Zahl tatsächlicher Erwähnungen/Artikel | ab Erstansprache (Annahme ab 24.09.) | Nach 3 angesprochenen Redaktionen ohne Reaktion **innerhalb von 4 Wochen**: Kanal ruht, Reaktivierung erst mit neuem Anlass (z. B. Kalibrierungsergebnis, Nutzerzahlen-Meilenstein) statt wiederholter Kaltakquise ohne neuen Aufhänger |
| Dozentennetzwerk | Zahl Dozent:innen, die nach Kalibrierungsteilnahme öffentlich referenzierbar sind (mit Einwilligung) | ab erster Kalibrierungsteilnahme (folgt Fachschafts-Beta, Abschnitt 1.4) | Kein eigenständiges Abschaltkriterium — Kanal ist ein Nebenprodukt der Kalibrierung (`docs/24-kalibrierungspaket.md`), sein Ausbleiben ist ein Kalibrierungs-, kein Marketingrisiko |

---

## 5. Was bewusst nicht gemacht wird

1. **Performance-Marketing auf Verdacht** (bezahlte Anzeigen ohne
   vorherigen Nachweis, dass ein Kanal konvertiert). Begründung:
   `docs/19-kosten-preis-budget.md` Abschnitt 6 weist explizit **0 €** für
   Werbung/Agentur/bezahlte Reichweite aus — das ist keine
   Marketing-Zurückhaltung, sondern eine bereits getroffene
   Budgetentscheidung. Selbst mit Budget wäre der Rücklauf in einem Markt
   von 116.760 potenziellen Nutzer:innen mit sinkenden Anfängerzahlen
   (`docs/14-marktanalyse.md` Abschnitt 1.1) schwer zu rechtfertigen, bevor
   ein organischer Kanal überhaupt Konversionsdaten geliefert hat.
2. **Influencer ohne fachliche Deckung.** Reichweite ohne juristische
   Fachkompetenz widerspricht der Positionierung aus
   `docs/14-marktanalyse.md` Abschnitt 3 („Verzahnung mit demselben Karten-
   und Schema-Stoff") — eine Empfehlung, die inhaltlich nicht geprüft werden
   kann, unterläuft genau das Vertrauen, das der Struktur-Check und die
   Kalibrierung aufbauen sollen. Das Dozentennetzwerk (Abschnitt 1.4) ist der
   fachlich gedeckte Ersatz für Reichweite durch Dritte.
3. **Preiskampf gegen Jurafuchs.** Jurafuchs ist profitabel, hat frisches
   Wachstumskapital erhalten (`docs/14-marktanalyse.md` Abschnitt 2, Dezember
   2025) und ist bei 5,99 €/Monat bereits günstiger als Subsumos
   3,99–12 €-Spanne kaum unterbietbar, ohne die Kostendeckung aus
   `docs/19` Abschnitt 3 zu gefährden. In einem schrumpfenden Markt gegen
   einen kapitalisierten, günstigeren Marktführer über den Preis zu
   konkurrieren, verbrennt Marge, ohne die eigentliche Differenzierung (siehe
   `docs/14-marktanalyse.md` Abschnitt 3, präzisierte Positionierung)
   überhaupt zur Wirkung zu bringen.

---

## Quellen

- Marktgröße, Wettbewerb, Positionierung, Preisempfehlung:
  `docs/14-marktanalyse.md`
- Kostenrahmen, Budgetantwort, Preispfad: `docs/19-kosten-preis-budget.md`
- Landing Page/Preisseite/Launch-Texte für den Releasetag:
  `docs/21-landing-preisseite-launchtext.md`
- Releasetermin, Gates, Tagesplan, offene Entscheidungen:
  `docs/18-release-2-wochen.md`
- Sieben-Spuren-Übersicht, Phasenmodell (Nach-Release-Roadmap):
  `docs/03-roadmap.md`
- Campus-Lizenz-Konzept (v1.2), Geschäftsmodell: `docs/01-produktvision.md`
- Kalibrierungs-Dozentenakquise, Abhängigkeit von der Fachschafts-Beta:
  `docs/24-kalibrierungspaket.md`, `docs/13-lernarchitektur.md` Abschnitt 4.6
- Werbeaussagen-Grenzen, Einwilligung für Telemetrie:
  `docs/06-recht-compliance.md`
