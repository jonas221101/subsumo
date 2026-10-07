# Gewerbeanmeldung — Kosten und Aufwand (Entscheidungsgrundlage)

> **Kein Rechts- oder Steuerrat.** Dieses Dokument fasst öffentlich
> zugängliche Verwaltungsinformationen zusammen (Stand 07.10.2026), damit die
> Entscheidung „Privatperson oder Gewerbe" mit Zahlen statt Gefühl getroffen
> werden kann. Für die konkrete steuerliche Gestaltung (Kleinunternehmer ja/
> nein, Nebentätigkeit, Krankenversicherung) ist eine Steuerberatung zuständig.

**Anlass:** Nutzerfrage vom 07.10.2026 auf [SUB-39](/SUB/issues/SUB-39):
„ich würde gerne ein Gewerbe anmelden, wie viel kostet das und was ist das für
ein Aufwand". Bezieht sich auf Frage 1 der offenen Impressum-Karte
(`0ad6613e`, siehe [00-uebersicht.md](00-uebersicht.md) Abschnitt „Offene
Vorbedingung: Rechtsträger").

## 1. Kurzantwort

| | |
|---|---|
| **Einmalige Gebühr** | **15–65 €**, je Gemeinde; Bundesschnitt ca. **30 €** |
| **Zeitaufwand Anmeldung selbst** | **15–30 Minuten** (Formular GewA1), in vielen Städten vollständig online |
| **Zeitaufwand Folgepflichten** | **2–4 Stunden** einmalig in den ersten 4 Wochen (Finanzamt-Fragebogen, BG-Meldung) |
| **Laufender Aufwand** | **2–5 Stunden pro Jahr** (EÜR + Einkommensteuererklärung) bei Kleinunternehmerstatus, oder 300–800 €/Jahr Steuerberatung |
| **Laufende Pflichtbeiträge im Startjahr** | realistisch **0 €** (siehe Abschnitt 4) |

Das ist, gemessen an allen anderen offenen Release-Posten, ein kleiner Posten.
Der Aufwand liegt nicht in der Gebühr, sondern in den drei Folgemeldungen und
darin, dass ab dann jedes Jahr eine Gewinnermittlung fällig ist.

## 2. Einmalkosten

| Posten | Betrag | Anmerkung |
|---|---|---|
| Gewerbeanmeldung beim Gewerbeamt | 15–65 € | Gemeinde legt die Gebühr per eigener Satzung fest. Beispiele aus Ratgeberquellen (2026): Hamburg 20 €, Berlin 26 € (online 15 €), München 47 €, Stuttgart 54 €. **Exakten Betrag beim eigenen Gewerbeamt erfragen** — es gibt keine bundesweite Regelung. |
| Finanzamt-Fragebogen | 0 € | Pflicht über ELSTER, kostenlos |
| Berufsgenossenschaft-Meldung | 0 € | Meldung ist Pflicht, Beitrag ohne Beschäftigte in der Regel nicht |
| Handelsregister / Notar | 0 € | **Entfällt** — ein Einzelunternehmen/Kleingewerbe wird nicht eingetragen, kein Notar, kein Stammkapital |

Die Gebühr ist als Betriebsausgabe absetzbar.

## 3. Ablauf und Fristen

1. **Gewerbeanmeldung (Formular GewA1)** — beim Gewerbeamt/Ordnungsamt der
   Wohn-/Betriebsstättengemeinde, in vielen Kommunen online. Benötigt:
   Ausweis, Anschrift, Beschreibung der Tätigkeit (hier z. B. „Entwicklung und
   Betrieb einer Lernsoftware"), geplanter Starttermin. Eine Erlaubnis ist
   nicht erforderlich: Subsumo ist nach
   [`docs/06-recht-compliance.md`](../06-recht-compliance.md) Abschnitt 1
   Lernhilfe und keine Rechtsdienstleistung i. S. d. § 2 RDG, also ein
   erlaubnisfreies Gewerbe. Der Gewerbeschein kommt sofort oder in wenigen
   Tagen.
2. **Fragebogen zur steuerlichen Erfassung — Frist: 1 Monat** nach Beginn der
   Tätigkeit, elektronisch über ELSTER (seit 2021 Pflicht, Papier nicht mehr
   zulässig). Ergebnis: Steuernummer. Hier wird auch die
   **Kleinunternehmerregelung** (§ 19 UStG) angekreuzt. Realistischer Aufwand
   1–3 Stunden, überwiegend wegen der Umsatz- und Gewinnschätzung.
3. **Berufsgenossenschaft — Frist: 1 Woche** nach Gründung (§ 192 SGB VII).
   Für Software/Dienstleistung ist das in der Regel die VBG. Ohne Beschäftigte
   fallen üblicherweise keine Beiträge an; die BG prüft nach der Meldung, ob
   Pflichtversicherung besteht. Aufwand ca. 15 Minuten.
4. **IHK** — die Mitgliedschaft entsteht automatisch mit der
   Gewerbeanmeldung, es ist nichts zu tun. Zur Beitragsfrage siehe Abschnitt 4.
5. **Laufend** — Einnahmen-Überschuss-Rechnung (EÜR) plus
   Einkommensteuererklärung, einmal jährlich. Als Kleinunternehmer **keine**
   Umsatzsteuer-Voranmeldungen.

## 4. Was im Startjahr voraussichtlich *nicht* anfällt

- **Umsatzsteuer** — Kleinunternehmerregelung nach § 19 UStG greift, solange
  der Umsatz im Vorjahr ≤ 25.000 € und im laufenden Jahr ≤ 100.000 € bleibt
  (Grenzen seit 2025; im Gründungsjahr gilt die 25.000-€-Grenze auf das
  laufende Jahr). Bei einem kostenlosen Early Access ist der Umsatz 0 €.
- **IHK-Beitrag** — Existenzgründer, die nicht im Handelsregister eingetragen
  sind, sind in den ersten zwei Jahren beitragsfrei, wenn der Gewerbeertrag
  25.000 € nicht übersteigt; im 3. und 4. Jahr entfällt zumindest die Umlage
  unter derselben Bedingung. Mitglied ist man trotzdem.
- **Gewerbesteuer** — Freibetrag 24.500 € für natürliche Personen; darunter
  fällt keine Gewerbesteuer an.
- **Rundfunkbeitrag für die Betriebsstätte** — entfällt nach § 5 Abs. 5 Nr. 3
  RBStV, wenn die Betriebsstätte in der eigenen Wohnung liegt, für die schon
  Rundfunkbeitrag gezahlt wird, und keine Beschäftigten vorhanden sind.
- **Geschäftskonto** — rechtlich nicht vorgeschrieben beim Einzelunternehmen
  (bei UG/GmbH schon). Praktisch empfehlenswert zur Trennung; kostenlose
  Angebote existieren.

Zwei Punkte, die man dennoch vorher prüfen sollte:

- **Nebentätigkeit neben einem Arbeitsverhältnis** — viele Arbeitsverträge
  verlangen eine Anzeige oder Genehmigung der Nebentätigkeit.
- **Krankenversicherung** — solange die Selbstständigkeit *nebenberuflich*
  bleibt, ändert sich nichts. Wird sie hauptberuflich, ändert sich die
  Beitragsberechnung der GKV grundlegend. Das ist der einzige Posten, der
  wirklich teuer werden kann, und gehört in eine Beratung.

## 5. Was eine Gewerbeanmeldung für Subsumo *nicht* löst

Diese Abgrenzung ist für die Release-Planung der eigentlich wichtige Teil:

1. **Der kostenlose Early Access braucht kein Gewerbe.** Nach der
   Nutzerentscheidung vom 25.09.2026 (`b1739bd0`) fließt am Tag 1 kein Geld.
   Ohne Entgelt und ohne Gewinnerzielungsabsicht besteht keine
   Gewerbeanzeigepflicht nach § 14 GewO. Ein Gewerbe anzumelden ist also
   möglich und vorausschauend, aber es ist **nicht die Ursache der aktuellen
   Release-Blockade**.
2. **Die Impressumspflicht bleibt identisch.** Ein Impressum nach § 5 DDG ist
   schon bei geschäftsmäßigem Angebot Pflicht — unabhängig von der
   Gewerbeanmeldung (siehe [01-impressum.md](01-impressum.md), Abschnitt
   „Anwendbar sobald Rechtsträger = Privatperson").
3. **Die Adresse wird dadurch nicht privater.** Beim Einzelunternehmen im
   Homeoffice steht im Impressum dieselbe ladungsfähige Privatanschrift wie
   bei einer Privatperson. Nur eine UG/GmbH mit eigener Geschäftsadresse
   ändert das — mit Notar, Handelsregister, Stammkapital (UG ab 1 €, praktisch
   mehr) und Jahresabschluss-Pflicht, also einer ganz anderen Größenordnung
   an Kosten und laufendem Aufwand.
4. **Was den Release tatsächlich blockiert**, sind weiterhin die vier Angaben
   der Karte `0ad6613e` (vor allem Name + ladungsfähige Anschrift + Kontakt-
   E-Mail) und die fehlende DNS-Konfiguration für `subsumo.de`. Ein
   Gewerbeschein beantwortet keine davon.

## 6. Entscheidungsvarianten

| Variante | Kosten | Aufwand | Passt, wenn |
|---|---|---|---|
| **A — Privatperson, jetzt kein Gewerbe** | 0 € | 0 h | Start bleibt kostenlos. Gewerbe wird genau dann angemeldet, wenn die Bezahlfunktion scharf geschaltet wird. Impressum nennt Name + Privatanschrift. |
| **B — Kleingewerbe jetzt anmelden** | 15–65 € einmalig | ~0,5 h + 2–4 h Folgemeldungen, dann 2–5 h/Jahr | Du willst die Struktur früh sauber haben, Betriebsausgaben (Domain, Hosting, Werbebudget 500 €/Monat) absetzen und beim Start der Paywall nichts mehr nachziehen müssen. Impressum ändert sich nur um die Zeile „Einzelunternehmen". |
| **C — UG/GmbH** | Notar + Register + Stammkapital, mehrere Hundert € und laufender Jahresabschluss | deutlich höher | Haftungsbegrenzung oder eine Geschäftsadresse statt der Privatadresse sind wichtiger als der Aufwand. **Für einen Early-Access-Start nicht empfohlen.** |

Empfehlung aus Projektsicht: **A oder B — beide tragen den Release am
29.09./Folgetermin gleich gut.** Variante B ist sinnvoll, sobald echte
Betriebsausgaben laufen (Domain, Hosting, Werbebudget), weil sie absetzbar
werden; sie ist kein Release-Vorbehalt.

---

**Quellen (abgerufen 07.10.2026):**
Gebührenspanne und Städtebeispiele:
[qonto.com — Gewerbe anmelden: Kosten & Gebühren](https://qonto.com/de/blog/unternehmensgruendung/einzelunternehmen/gewerbe-anmelden-kosten),
[taxfix.de — Gewerbe anmelden 2026](https://taxfix.de/ratgeber/selbststaendige/gewerbe-anmelden/),
[gewerbeanmeldung.de — Was kostet eine Gewerbeanmeldung?](https://www.gewerbeanmeldung.de/gewerbe-anmelden-kosten).
Kleinunternehmerregelung:
[mehrwertsteuerrechner.de — § 19 UStG 2026](https://www.mehrwertsteuerrechner.de/kleinunternehmerregelung/),
[sevdesk.de — Kleinunternehmer](https://sevdesk.de/ratgeber/buchhaltung-finanzen/kleinunternehmer/).
ELSTER-Frist:
[Handelskammer Hamburg — Fragebogen zur steuerlichen Erfassung](https://www.handelskammer-hamburg.de/recht-steuern/steuerrecht/existenzgruender-steuern/fragebogen-steuerlichen-erfassung-6682890),
[IHK Darmstadt — Steuerliche Erfassung](https://www.ihk.de/darmstadt/produktmarken/gruendung/existenzgruendung-und-steuern/aufnahme-einer-gewerblichen-taetigkeit-2538356).
IHK-Gründerbefreiung:
[IHK Frankfurt — Beitragsbefreiung für Existenzgründer](https://www.frankfurt-main.ihk.de/ueber-uns/ihk-mitgliedschaft/beitrag-hoehe-und-modalitaeten/beitragsbefreiung-fuer-existenzgruender-5270186).
Berufsgenossenschaft:
[lexware.de — Anmeldung bei der Berufsgenossenschaft](https://www.lexware.de/wissen/gruendung/anmeldung-berufsgenossenschaft/).
Rundfunkbeitrag:
[rundfunkbeitrag.de — Informationen für Unternehmen](https://www.rundfunkbeitrag.de/unternehmen-und-institutionen/informationen).

**Menschliche Prüfung nötig:** exakte Gebühr der eigenen Gemeinde;
Kleinunternehmer-Wahl und Nebentätigkeits-/Krankenversicherungsfolgen mit
Steuerberatung; Anzeigepflicht einer Nebentätigkeit gegenüber einem
Arbeitgeber.
