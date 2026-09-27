# Kosten, Preis, Budget

> Antwort auf die drei Preis-/Budgetpunkte aus dem Nutzerkommentar zu
> [SUB-39](/SUB/issues/SUB-39) vom 15.09.2026: *Preis muss die Kosten decken*
> und *Budget wofür?*
>
> Ergänzt `docs/14-marktanalyse.md` um die Kostenseite. Die dortige
> Preisempfehlung (12 €/Monat) gilt für den **vollen** Funktionsumfang
> inklusive KI-Korrektur — dieses Dokument rechnet den Preis für den
> geschnittenen Release-Umfang aus
> [`docs/18-release-2-wochen.md`](18-release-2-wochen.md).
>
> **Charakter der Zahlen:** Listenpreise und Spannen aus
> `docs/17-release-readiness.md` Abschnitt 6, ergänzt um eigene
> Token-Rechnungen. Keine eingeholten Angebote. Umrechnung durchgängig mit
> **1 $ ≈ 0,92 €** (Annahme, nicht tagesaktuell geprüft).

---

## 1. Laufende Kosten v1.0 (pro Monat)

Umfang laut Schnittplan: Web + Android, keine LLM-Bewertung im Produkt
(`llm_provider=none`), Content-Produktion läuft weiter.

| Posten | Spanne | Planwert | Anmerkung |
|---|---|---|---|
| Hosting (App-Server + DB, EU-Region) | 30–80 € | 50 € | Ein Backend-Prozess reicht für die Startnutzerzahl |
| Domain + DNS (anteilig) | 2 € | 2 € | `subsumo.de` / `app.subsumo.de` |
| Transaktions-E-Mail | 0–10 € | 5 € | Registrierung, Passwort-Reset; Free-Tier reicht anfangs |
| Monitoring / Fehler-Tracking | 0–25 € | 10 € | kleinste bezahlte Stufe |
| KI-Redaktion (Content-Produktion) | 50–150 € | 80 € | Collector+Reviewer je Thema, läuft nach Release weiter |
| **Summe** | **82–267 €** | **≈ 150 €** | |

Zahlungsgebühren (~1,5 % + 0,25 € je Transaktion) sind kein Fixposten und
stehen in Abschnitt 3 als Abzug vom Preis, nicht als Kostenzeile.

**Der entscheidende Struktureffekt des Schnitts:** Ohne KI-Bewertung im Produkt
gibt es **keine Kostenzeile, die mit der Nutzerzahl wächst**. Hosting skaliert
stufenweise, nicht linear. Ein zusätzlicher Nutzer kostet in v1.0 praktisch
nichts — das macht die Kostendeckung zu einer reinen Frage der Zahlendenzahl,
nicht des Nutzungsverhaltens.

---

## 2. Einmalkosten vor dem Release

| Posten | Betrag | Release-kritisch? |
|---|---|---|
| Domain `subsumo.de` (Jahr) | 15–25 € | **ja** |
| Google-Play-Entwicklerkonto (einmalig 25 $) | ≈ 23 € | ja, für die Android-Spur |
| Rechtstexte (Impressum, AGB, DSE, Widerruf) — Generator-Abo | 10–25 €/Monat | **ja**, eine der beiden Varianten |
| Rechtstexte — anwaltliche Erstellung/Durchsicht statt Generator | 300–1.500 € | Alternative zur Zeile darüber |
| Apple-Developer-Programm (99 $/Jahr) | ≈ 91 €/Jahr | nein — erst v1.1 (iOS) |
| Microsoft-Store-Konto (einmalig ~19 $) | ≈ 17 € | nein — erst v1.2 |
| Wortmarke DPMA (elektronisch, bis 3 Klassen) | ≈ 290 € | nein, aber vor größerer Reichweite sinnvoll — **Betrag vor Ausgabe verifizieren** |

**Release-kritisches Minimum:** Domain + Play-Konto + Rechtstexte-Generator
≈ **70 €** (plus 10–25 €/Monat Generator-Abo).
**Abgesicherte Variante** mit anwaltlich geprüften Rechtstexten
≈ **350–550 €** einmalig.

---

## 3. Ab wann deckt der Preis die Kosten?

Nettoerlös je Abo = Preis − (1,5 % + 0,25 €). Zwei Kostenszenarien: Planwert
150 €/Monat plus anteilige Einmalkosten (350 € auf 12 Monate ≈ 29 €) ≈
**180 €/Monat** im ersten Jahr; konservativ (Obergrenze aller Spannen)
≈ **300 €/Monat**.

| Preis | Nettoerlös/Monat | Zahlende für 180 €/Monat | Zahlende für 300 €/Monat |
|---|---|---|---|
| 3,99 €/Monat | 3,68 € | **49** | 82 |
| 4,99 €/Monat | 4,67 € | **39** | 65 |
| 5,99 €/Monat | 5,65 € | **32** | 54 |
| 7,99 €/Monat | 7,62 € | **24** | 40 |
| 39 €/Jahr | 3,18 € | **57** | 94 |
| 49 €/Jahr | 4,00 € | **45** | 75 |

**Befund:** Kostendeckung tritt zwischen **24 und 94 Zahlenden** ein — je nach
Preis und Kostenszenario. Gemessen an der Pro-relevanten Zielgruppe aus
`docs/14-marktanalyse.md` (103.060 Personen) entsprechen 50 Zahlende einer
Durchdringung von **0,05 %**.

Daraus folgt die wichtigste Aussage dieses Dokuments:

> **Die Kostendeckung ist keine bindende Nebenbedingung.** Jeder Preis zwischen
> 3,99 € und 12 € deckt die Kosten, sobald ein paar Dutzend Menschen zahlen.
> Der Preis ist deshalb keine Kostenfrage, sondern eine Frage danach, was das
> Produkt am Tag des Release **wert ist** — und das ist nach dem Schnitt
> deutlich weniger als der Vollausbau, für den `docs/14-marktanalyse.md`
> 12 €/Monat empfiehlt.

---

## 4. Preisempfehlung für v1.0

### Ausgangslage nach dem Schnitt

v1.0 liefert Karteikarten, Schemata, geführte Fälle und einen heuristischen
Struktur-Check — **ohne** KI-Korrektur. Genau in diesem Feld hält
`docs/14-marktanalyse.md` fest: Jurafuchs ist mit 5,99 €/Monat und 8.000+
interaktiven Fällen billiger *und* deutlich umfangreicher, Anki ist kostenlos.
Subsumo startet mit 180 Karten. Ein Preis auf oder über Marktführerniveau wäre
für diesen Umfang nicht vertretbar.

### Empfehlung

| | Free | **Pro (Gründerpreis)** |
|---|---|---|
| Preis | 0 € | **3,99 €/Monat oder 39 €/Jahr** |
| Karten | 20 fällige Karten/Tag, ein Rechtsgebiet | alle, unbegrenzt, drei Rechtsgebiete |
| Schemata | lesen | lesen + Reihenfolge-Drill |
| Geführte Fälle | 2 | alle |
| Struktur-Check Gutachten | 3/Woche | unbegrenzt |
| Preisgarantie | — | **Bestandspreis bleibt dauerhaft, auch wenn der Listenpreis steigt** |

Drei Gründe für 3,99 €:

1. **Ehrlich gegenüber dem Umfang.** Deutlich unter dem Marktführer, weil das
   Produkt am Tag 1 deutlich kleiner ist. Das lässt sich vertreten, ohne den
   Umfang zu beschönigen.
2. **Deckt die Kosten ab 49 Zahlenden** (Planwert) — erreichbar, ohne dass
   irgendeine Marketing-Annahme optimistisch sein muss.
3. **Die Preisgarantie macht den frühen Kauf rational.** Wer jetzt 39 €/Jahr
   zahlt, behält den Preis, wenn mit v1.1 die Korrektur kommt und der
   Listenpreis auf 8,99 € steigt. Das verwandelt den dünnen Startumfang aus
   einem Verkaufshindernis in ein Argument.

### Preispfad

| Version | Umfang | Listenpreis (Neukunden) |
|---|---|---|
| v1.0 (29.09.2026) | Karten, Schemata, Fälle, Struktur-Check | **3,99 €/Monat · 39 €/Jahr** |
| v1.1 (ca. +4 Wochen) | + kalibrierte KI-Korrektur, iOS | 8,99 €/Monat · 89 €/Jahr |
| v1.2 | + Klausursimulator, Norm-Explorer | 12 €/Monat (Zielpreis aus `docs/14-marktanalyse.md`) |

Bestandskunden behalten in jeder Stufe ihren Einstiegspreis.

---

## 5. Was sich mit der KI-Korrektur ändert (v1.1)

Ab v1.1 entsteht erstmals eine mit der Nutzung wachsende Kostenzeile.

**Eigene Rechnung je Korrektur:** Gutachtentext 8.000–12.000 Zeichen
≈ 3.000–4.500 Token, plus Erwartungshorizont und Systemprompt ≈ 2.000 Token →
Eingabe ≈ 6.000 Token; Ausgabe mit Begründung je Prüfpunkt ≈ 2.000 Token. Bei
Listenpreisen eines Sonnet-Modells (3 $/Mio Eingabe, 15 $/Mio Ausgabe):
0,018 $ + 0,030 $ = 0,048 $ ≈ **0,044 €**. Mit doppeltem Sicherheitsaufschlag
für lange Gutachten und Wiederholungen: **≈ 0,09 €/Korrektur**.

`docs/17-release-readiness.md` Abschnitt 6 setzt konservativer an
(0,075–0,30 €/Korrektur). Diese Spanne bleibt die Obergrenze, bis gemessen ist.

| Annahme | Kosten bei 20 Korrekturen/Monat | Anteil am Nettoerlös (8,99 € → 8,58 €) |
|---|---|---|
| 0,09 €/Korrektur (eigene Rechnung) | 1,80 € | 21 % |
| 0,30 €/Korrektur (konservativ) | 6,00 € | 70 % |

**Konsequenz:** Der Unterschied zwischen beiden Annahmen entscheidet, ob die
Korrektur ein Randposten oder der größte Kostenblock ist. **Vor der
Preisfestsetzung für v1.1 sind 20 echte Korrekturen zu messen** — der
Kalibrierungs-Harness aus [SUB-69](/SUB/issues/SUB-69) liefert dafür ohnehin
die Durchläufe. Bis dahin gilt: Pro-Tarif mit Fair-Use von 20 Korrekturen pro
Monat, darüber gedrosselt statt abgerechnet.

---

## 6. Antwort auf „Budget wofür?"

Die frühere Annahme „Marketing organisch, kein Performance-Budget" ist durch
die Antwort des Auftraggebers auf die SUB-254-Rückfrage (Interaktion
`65179b93-68de-4e49-b2a8-3852889ad7fc`, Frage `werbebudget`, 2026-09-25T05:52Z)
überholt: **„Klein: bis ca. 500 €/Monat" — genug für einen
zielgruppengenauen Testkanal (z. B. Instagram/TikTok auf
Jura-Erstsemester), nicht für Breite.** Das ist eine Obergrenze für eine
Entscheidung, keine Pflichtausgabe — Aktivierung und konkreter Kanal stehen
in `docs/30-werbekonzept-erstkunden.md` Abschnitt 5. Was davon unabhängig,
also unabhängig von einer Werbeentscheidung, tatsächlich Geld kostet, ist
diese Liste:

| Zweck | Betrag | Wann fällig |
|---|---|---|
| **Pflicht vor Release** — Domain, Play-Konto, Rechtstexte (Generator) | ≈ 70 € einmalig + 10–25 €/Monat | bis 18.09.2026 |
| **Pflicht laufend** — Hosting, Monitoring, E-Mail, KI-Redaktion | 82–267 €/Monat, Planwert 150 € | ab Release |
| **Optional, empfohlen** — anwaltliche Prüfung der Rechtstexte statt Generator | 300–1.500 € einmalig | vor Release, wenn Reichweite erwartet wird |
| **Aufschiebbar** — Apple 91 €/Jahr, Microsoft 17 €, Wortmarke ≈ 290 € | ≈ 400 € | v1.1/v1.2 |
| **Bedingt freigegeben** — Werbung, ein zielgruppengenauer Testkanal (Obergrenze, keine Pflichtausgabe) | bis 500 €/Monat | ab Aktivierung, siehe `docs/30` Abschnitt 5 |

**Gesamtbedarf für die ersten drei Monate:** **≈ 320 €** in der schlanken
Variante (Generator-Rechtstexte, untere Kostenspanne) bis **≈ 1.150 €** in der
abgesicherten Variante (anwaltliche Rechtstexte, obere Kostenspanne). Die
Werbe-Obergrenze aus der Zeile „Bedingt freigegeben" ist hier **nicht**
eingerechnet, weil sie eine Entscheidungsobergrenze ist, keine
Pflichtausgabe — bei voller Nutzung über drei Monate kämen zusätzlich bis
zu 1.500 € hinzu (`docs/30` Abschnitt 5).

**Was Budget nicht ersetzt:** Die menschliche Prüfkapazität für den Content —
2,5 bis 3 Stunden pro Werktag über die zwei Wochen
(`docs/18-release-2-wochen.md` Abschnitt 4). Das ist der eigentliche Engpass
bis zum Release, und er ist mit Geld nicht auflösbar, solange niemand
eingestellt wird.
