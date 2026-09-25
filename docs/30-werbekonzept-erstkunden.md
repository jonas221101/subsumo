# Werbekonzept und Erstkundengewinnung (SUB-260)

> Auftrag aus [SUB-254](/SUB/issues/SUB-254) über [SUB-260](/SUB/issues/SUB-260):
> „Baue ein Werbekonzept auf und überlege, wie wir die ersten Kunden
> gewinnen." Befund, auf dem dieses Dokument aufbaut:
> `docs/31-projektreview-sub254.md` Abschnitt 4 und der Nachtrag vom
> 24.09.2026 in `docs/14-marktanalyse.md` Abschnitt 2.1.
>
> **Verhältnis zu bestehenden Dokumenten — keine Wiederholung:**
> `docs/15-go-to-market.md` liefert bereits Kanalplan, Zeitpunkte,
> Messgrößen, das versandfertige Fachschafts-Anschreiben und die
> Nicht-Machen-Liste. `docs/21-landing-preisseite-launchtext.md` liefert die
> fertigen Launch-Texte. Dieses Dokument wiederholt beides nicht, sondern
> ergänzt zwei Dinge, die dort fehlen: ein **Kreativkonzept** (welche
> Botschaft wird wie zu einem Werbemittel, nicht nur zu Fließtext) und einen
> **konkreten Weg zu den ersten zahlenden Kund:innen**, der über das
> Fachschafts-/Warteliste-Programm aus `docs/15` hinausgeht.
>
> **Werbebudget-Rückfrage beantwortet:** Der Auftraggeber hat die Rückfrage
> auf SUB-254 (Interaktion `65179b93-68de-4e49-b2a8-3852889ad7fc`, Frage
> `werbebudget`) am 2026-09-25T05:52Z beantwortet: „Klein: bis ca. 500
> EUR/Monat" — genug für einen zielgruppengenauen Testkanal, nicht für
> Breite. Dieses Dokument baut das Konzept weiterhin auf dem organischen Fall
> auf — **organisch, ohne Budget** — als Hauptfall (Abschnitt 4) und stellt
> die jetzt aktive, budgetabhängige Option daneben (Abschnitt 5, Obergrenze
> 500 €/Monat).
>
> **Stand:** 24.09.2026. Releasetermin 29.09.2026
> (`docs/18-release-2-wochen.md`). Umsetzung der hier beschriebenen
> Kreativ-Assets liegt **nach Release**, wie in `docs/31` Abschnitt 7 Punkt 6
> eingeordnet — dieses Dokument ist Konzept, keine Produktionsbeauftragung.

---

## 1. Die eine Botschaft, in jedem Format

`docs/21` Abschnitt „Update 24.09.2026" legt die neue Argument-Reihenfolge
fest: **unbegrenztes Struktur-Feedback ohne Grenzkosten** und **echtes
Offline auf vier Plattformen** vor Karten/Schemata/Fällen, solange die
KI-Korrektur aus ist. Für ein Werbemittel — anders als für einen Fließtext —
reicht diese Reihenfolge nicht, es braucht einen einzigen, in drei Sekunden
erfassbaren Aufhänger (den „Wedge"). Aus den zwei USPs ergeben sich zwei
mögliche Wedges, nicht einer:

**Wedge A — „Kein Kontingent."** Direkter, faktenbasierter Kontrast: Jeder
geprüfte KI-Korrektur-Wettbewerber (`docs/14` Abschnitt 2, Nachtrag 2.1)
verlangt einen Preis pro Abgabe oder ein monatliches Limit —
KlausurenKiste 4 Abgaben/Monat im Abo bzw. 2,99 € je Einzelabgabe,
KorrekturKai/Constellatio pauschal im Abopreis aber ebenfalls
LLM-kostenpflichtig, Jurversity 10–60 € je Abgabe. Subsumo hat kein
Kontingent, weil der Struktur-Check regelbasiert und offline läuft. Das ist
eine **belegbare, quellenfeste** Aussage (nicht „besser", sondern
„unbegrenzt vs. kontingentiert") und deshalb mit den
Werbeaussagen-Grenzen aus `docs/06-recht-compliance.md` Abschnitt 5
vereinbar, die Aussagen über die *Bewertungsqualität* einschränken, nicht
Aussagen über *Preismodelle*.

**Wedge B — „Funktioniert im Flugzeugmodus."** Nachweisbar per Video
(Gerät in den Flugmodus schalten, Struktur-Check trotzdem ausführen), stärker
visuell als Wedge A, aber schwächer differenzierend, weil auch Jurafuchs
einen (eingeschränkten) Offline-Modus hat — der Unterschied liegt in der
Feinheit „übersteht App-Update" (`docs/14` Abschnitt 2.1), die sich in einem
15-Sekunden-Clip nicht vermitteln lässt.

**Entscheidung: Wedge A führt, Wedge B unterstützt.** Wedge A trägt die
Kernbotschaft (unbegrenzt, weil kostenlos für uns) und ist in jedem Format
in einem Satz sagbar. Wedge B liefert das Beweisstück (Video) für Leute, die
nach dem Aufhänger noch skeptisch sind, ob „offline" wörtlich gemeint ist.

---

## 2. Kreativ-Assets je Format (produzierbar ohne Budget)

Alle Assets entstehen aus bereits vorhandenem Produkt und bereits
vorhandenen Texten (`docs/21`) — kein neuer Content, nur neue Darreichung.

| Asset | Format | Botschaft | Aufwand | Wiederverwendung |
|---|---|---|---|---|
| Flugmodus-Clip (15–20 s) | Kurzvideo für Reels/TikTok/Instagram Story | Wedge B: Gerät in Flugmodus, Struktur-Check läuft trotzdem, Ergebnis erscheint | ~1–2 Std. Aufnahme + Schnitt, kein Kamerateam nötig (Screen-Recording) | Gleicher Clip für Social (Abschnitt 1.3/4.2 aus `docs/15`) und optional Store-Video (Play Store erlaubt kurze Preview-Videos) |
| Kontingent-Vergleichsgrafik | Social-Karussell/Bild, Landing-Page-Sektion 3 | Wedge A als Tabelle: „Abgaben pro Monat — Subsumo: unbegrenzt · KlausurenKiste: 4 · Jurversity: nach Preis pro Abgabe" mit Quellenverweis auf `docs/14` | ~1 Std., reine Textgrafik aus dem Marken-Farbschema (`app/lib/design/tokens/`) | Auch als Slide im Fachschafts-Erklärmaterial (`docs/15` Abschnitt 3.1) |
| Struktur-Check-Screenshot-Serie | Store-Listing, Landing-Page | Echter Screenshot mit farbig markierten Prüfpunkten, keine „KI"-Beschriftung (Bindung an `docs/15` Abschnitt 1.5 und `docs/21` Abschnitt 1) | ~30 Min., Bildauswahl aus dem laufenden Produkt | Store-Auftritt (`docs/15` 1.5), Landing Page Sektion 3 |
| Ein-Seiten-PDF „Warum Subsumo" | Fachschafts-/Dozenten-Ansprache, Presse-Anhang | Wedge A + Wedge B kompakt, plus 180-Karten-Ehrlichkeit aus `docs/21` Abschnitt 2.2 Punkt 5 | ~1 Std. Layout aus bestehenden Textbausteinen | Ergänzt (ersetzt nicht) das Anschreiben aus `docs/15` Abschnitt 3.2 |

**Bewusst kein Asset:** Ein Erklärvideo mit Sprecher:in/Gesicht. Begründung:
Erhöht Produktionsaufwand deutlich (Aufnahme, Schnitt, ggf. mehrere Takes)
gegenüber Screen-Recordings, ohne dass die Zielgruppenrecherche
(`docs/14` Abschnitt 5) einen Bedarf dafür belegt — wenn eine erste
Kampagne Wirkung zeigt, ist das ein Kandidat für eine zweite Welle, nicht für
den Start.

---

## 3. Die ersten Kunden — was über `docs/15` hinausgeht

`docs/15` plant bereits Fachschafts-Beta, Warteliste, Content-Marketing,
Store und Presse mit Zeitpunkten und Abschaltkriterien — das wird hier nicht
neu aufgezogen. Zwei Lücken bleiben, wenn man konkret fragt „wie kommen die
ersten 10, dann 100 *zahlenden* Kund:innen zustande, nicht nur
Registrierungen":

### 3.1 Die ersten 10–20 zahlenden Kund:innen: persönlich, nicht per Kanal

Kanäle (Fachschaft, Social, Presse) brauchen laut `docs/15` Abschnitt 2
mehrere Wochen Anlaufzeit. Für die *ersten* Käufer:innen ist der
schnellste Weg keiner der geplanten Kanäle, sondern direkte Ansprache aus dem
eigenen Umfeld der am Projekt Beteiligten (Kommiliton:innen, Lerngruppen,
Kontakte aus der Kalibrierung in `docs/24-kalibrierungspaket.md`):

1. Persönliche Nachricht (kein Massenversand) an 15–20 Personen aus der
   Zielgruppe mit Bitte um Test **und** die Interviewfragen aus `docs/14`
   Abschnitt 5 — Feedback und Erstkund:innen-Gewinnung in einem Schritt.
2. Wer nach dem Test freiwillig zu Pro wechseln will, bekommt das direkt
   angeboten (Gründerpreis, `docs/21` Abschnitt 3.1) — kein Rabatt obendrauf,
   das würde die Preisgarantie für spätere Kund:innen unterlaufen
   (`docs/legal/02-agb.md`).
3. **Was das bringt, was es nicht bringt:** Das sind keine 100
   Warteliste-Anmeldungen (Skalierungsgrenze: persönliches Netzwerk ist
   endlich), aber es sind die einzigen Nutzer:innen, von denen vor dem
   Launch echtes, verwertbares Feedback zur Kaufbereitschaft vorliegt — das
   `docs/14` Interviewleitfaden bisher nur als Plan, nicht als Ergebnis
   kennt.

### 3.2 Weiterempfehlung als Wachstumsschleife (Konzept, Umsetzung offen)

Zufriedene Nutzer:innen sind laut Zielgruppenlage (kleiner, gut vernetzter
Markt über Lerngruppen und Fachschaften, `docs/14` Abschnitt 1) der
günstigste Kanal, den es gibt — aber es existiert aktuell kein Mechanismus,
der eine Empfehlung belohnt.

**Konzept:** Wer eine Freundin/einen Freund wirbt, der/die sich registriert
und mindestens einen Struktur-Check nutzt, bekommt einen Monat Pro
geschenkt (geworbene Person ebenso). Das braucht **denselben
Redeem-/Freischalt-Mechanismus**, der in `docs/15` Abschnitt 1.1 für die
Fachschafts-Beta bereits als fehlend identifiziert und in
[SUB-262](/SUB/issues/SUB-262) als Backlog-Ticket erfasst ist — dieses
Konzept erweitert den Bedarf für dasselbe Ticket, statt ein zweites zu
verlangen. **Bis zur Umsetzung:** kein eigener manueller Ersatz für die
Weiterempfehlung, weil das Volumen hier — anders als bei 2–5
Fachschaftskooperationen — nicht abschätzbar und damit für manuelle
Einzelvergabe ungeeignet ist. Diese Wachstumsschleife startet deshalb **erst
nach** SUB-262, nicht am 29.09.

---

## 4. Organische Variante — Hauptfall (ohne Werbebudget)

Alle Assets aus Abschnitt 2 und beide Taktiken aus Abschnitt 3 kosten Zeit,
kein Geld — sie nutzen ausschließlich bestehende Kanäle, bestehenden
Content und bestehende Produktfunktionen. Das ist die Variante, die
unabhängig von der Werbebudget-Entscheidung bereits vollständig umsetzbar
ist, sobald Kapazität nach dem Release besteht (`docs/31` Abschnitt 7
Punkt 6: Umsetzung nach Release).

Messung läuft über die bereits in `docs/15` Abschnitt 4 definierten
Herkunfts-Parameter — keine zusätzliche Metrik-Tabelle hier, um keine zweite,
potenziell abweichende Quelle für dieselben Zahlen zu schaffen. Ergänzend
zu `docs/15`: Die Konversion Test → Pro aus Abschnitt 3.1 dieses Dokuments
sollte separat ausgewiesen werden (Kanal „Direktansprache"), weil sie sich
strukturell von Warteliste-/Fachschafts-Konversion unterscheidet
(persönliche Bekanntschaft statt anonymer Reichweite).

---

## 5. Werbebudget-Option — aktiv, Obergrenze ≈ 500 €/Monat

Der Auftraggeber hat die Rückfrage zu SUB-254 (Interaktion
`65179b93-68de-4e49-b2a8-3852889ad7fc`, Frage `werbebudget`) am
2026-09-25T05:52Z beantwortet: **„Klein: bis ca. 500 EUR/Monat" — genug für
einen zielgruppengenauen Testkanal (z. B. Instagram/TikTok auf
Jura-Erstsemester), nicht für Breite.** Dieser Abschnitt ist damit aktiv,
nicht mehr eine für später vorgehaltene Option — er ersetzt nichts aus
Abschnitt 4 (organisch bleibt der Hauptkanal), sondern kommt als einzelner
zusätzlicher Testkanal hinzu, mit einer festen Obergrenze: **500 €/Monat,
keine Ausnahme.** Das war ausdrücklich die kleinste der drei angebotenen
Budgetstufen — keine Agentur, keine Breitenkampagne, kein zweiter bezahlter
Kanal (Stufe 5.2 „mittel" ist damit **nicht** aktiv, siehe unten).

### 5.1 Der aktive Testkanal

Ein einzelner, eng zielgruppengenauer Kanal: bezahlte Instagram/TikTok-Ads,
geografisch auf Städte mit juristischer Fakultät eingegrenzt, zeitlich auf
das Kampagnenfenster 29.09.–20.10. konzentriert (`docs/15` Abschnitt 2).
**Kein neues Creative** — dieselben Assets aus Abschnitt 2
(Flugmodus-Clip, Kontingent-Vergleichsgrafik), nur bezahlt ausgespielt statt
nur organisch gepostet. Zusätzlicher Aufwand ist ausschließlich das
Kampagnen-Setup (Zielgruppen-Targeting, Budget-Cap), keine neue
Content-Produktion.

**Budget-Cap:** 500 €/Monat als plattformseitige Tagesbudget-Grenze
eingerichtet (≈ 16 €/Tag als Kampagnen-Einstellung, nicht als nachträgliche
Abrechnungskontrolle) — die Kampagne darf technisch nicht über die
Obergrenze hinaus ausspielen.

**Messgröße: Kosten je Anmeldung.** Gezählt über dieselben
Herkunfts-Parameter wie in `docs/15` Abschnitt 4 (eigener Kanalwert
„Bezahlt Social"), Ausgabe im Zeitraum durch Anmeldungen im selben Zeitraum
geteilt:

| Zeitraum | Ausgabe (Cap) | Anmeldungen (Zielwert) | Kosten/Anmeldung (Zielwert) | Abschaltkriterium |
|---|---|---|---|---|
| Erste 14 Tage (29.09.–13.10.) | bis 250 € | ≥ 15 | ≤ 16,67 € | — |
| Folgende 14 Tage (14.10.–28.10., bei Fortsetzung) | bis 250 € | ≥ 15 | ≤ 16,67 € | Nach insgesamt 4 Wochen ohne Kosten/Anmeldung ≤ 25 €: Kanal einstellen, verbleibendes Budget bleibt ungenutzt statt weiter ausgespielt |

Der Zielwert (≤ 16,67 €/Anmeldung) ist eine Arbeitsannahme, keine belegte
Kennzahl — er wird nach der ersten Kampagnenwoche mit echten Daten
kalibriert, nicht vor Kampagnenstart weiter verfeinert. In keinem Fall wird
über die 500 €/Monat-Obergrenze hinaus nachgelegt, auch nicht bei gutem
Kosten/Anmeldung-Wert — eine Erhöhung wäre eine neue Auftraggeber-Frage,
keine Entscheidung, die dieses Dokument trifft.

### 5.2 Nicht aktiv: Stufe „mittel" (≈ 500–2.000 €/Monat)

Die Antwort auf die Budgetfrage war ausdrücklich die kleinste der drei
angebotenen Stufen (klein/mittel/groß) — diese Stufe bleibt daher
unbenutzt, nicht nur „separat" wie ursprünglich für den unbeantworteten
Fall vorgesehen. Zur Erinnerung, falls das Budget künftig erhöht wird:
Ein zweiter Kanal zum Parallelvergleich (z. B. Google-Suchanzeigen auf
generische Begriffe wie „Jura Klausur Feedback online") käme erst nach
einer erneuten Auftraggeber-Entscheidung dazu. **Nicht vorgesehen, ohne
Rechtsprüfung:** Anzeigen auf Wettbewerber-Markennamen als Keyword — das
grenzt an vergleichende Werbung und braucht vorab eine Prüfung gegen
`docs/06-recht-compliance.md` Abschnitt 5, die hier nicht vorweggenommen
wird. Voraussetzung für Stufe 5.2 ist außerdem die in `docs/15` Abschnitt 4
als fehlend benannte UTM-/Attributions-Infrastruktur — ohne sie lässt sich
der zweite Kanal nicht von Stufe 5.1 unterscheiden, das Geld liefe blind.

### 5.3 Was budgetabhängig **nicht** automatisch dazukommt

Mehr Budget ändert an der Botschaft nichts — Wedge A/B aus Abschnitt 1
bleiben identisch, unabhängig davon, ob organisch oder bezahlt ausgespielt.
Ein Budget kauft Reichweite für dieselbe Aussage, keine neue Positionierung.

---

## 6. Was auf der Kreativ-Ebene bewusst nicht gemacht wird

Ergänzt `docs/15` Abschnitt 5 (dort: kein Performance-Marketing auf
Verdacht, keine fachlich ungedeckten Influencer:innen, kein Preiskampf) um
Punkte, die erst auf der Ebene konkreter Werbemittel sichtbar werden:

1. **Keine unbelegten Qualitätsvergleiche.** „Besser als Jurafuchs" oder
   „genauer als Constellatio" wären Aussagen zur Bewertungsqualität, die
   `docs/06-recht-compliance.md` Abschnitt 5 einschränkt und die durch
   nichts in `docs/14` gedeckt sind. Vergleiche in Abschnitt 2 dieses
   Dokuments bleiben deshalb strikt auf **Preis- und Kontingentfakten** mit
   Quellenangabe beschränkt, nie auf Qualität.
2. **Keine künstliche Dringlichkeit.** Kein Countdown, kein „nur noch X
   Plätze" ohne reale Kapazitätsgrenze — widerspricht Leitprinzip 5 aus
   `docs/01-produktvision.md` („Kein Druck durch Design"), das `docs/16`
   Abschnitt 5 bereits für Gamification bestätigt hat und hier auf
   Werbemittel übertragen wird.
3. **Keine Stockfotos oder gestellten Screenshots.** Jedes Bild zeigt das
   echte, laufende Produkt (deckt sich mit `docs/15` Abschnitt 1.5).

---

## 7. Abhängigkeiten und offene Punkte

| Punkt | Abhängig von | Status |
|---|---|---|
| Redeem-/Freischaltcode-Mechanismus (Fachschafts-Beta **und** Weiterempfehlungsschleife, Abschnitt 3.2) | Software-Planner | [SUB-262](/SUB/issues/SUB-262) angelegt, Backlog, kein Release-Blocker |
| Werbebudget-Entscheidung | Auftraggeber | Beantwortet 2026-09-25 auf [SUB-254](/SUB/issues/SUB-254) (`werbebudget`): „klein, bis ca. 500 €/Monat" — Abschnitt 5 ist aktiv, Obergrenze 500 €/Monat |
| UTM-/Attributions-Infrastruktur (Voraussetzung für 5.2) | Software-/Backend-Developer | Bereits in `docs/15` Abschnitt 4 als fehlend benannt, hier nicht dupliziert |
| Rechtsprüfung vergleichender Werbeaussagen, falls 5.2 (Keyword-Ads) gezogen wird | Eigene, bisher ungestellte Anwaltsfrage — **nicht** Teil der auf SUB-254 am 25.09.2026 beantworteten Rechtsfragen (`docs/31` Abschnitt 9) | Nicht Teil dieses Konzepts, vorab zu klären |

---

## Quellen

- USP-Hierarchie und Befund: `docs/31-projektreview-sub254.md` Abschnitt 4
- Wettbewerbsdaten (Kontingente, Preise, neue Anbieter): `docs/14-marktanalyse.md`
  Abschnitt 2, Nachtrag 2.1 (Abruf 24.09.2026)
- Kanalplan, Zeitpunkte, Messgrößen, Fachschafts-Anschreiben: `docs/15-go-to-market.md`
- Launch-Texte, Argument-Reihenfolge: `docs/21-landing-preisseite-launchtext.md`
- Werbeaussagen-Grenzen: `docs/06-recht-compliance.md` Abschnitt 5
- Leitprinzipien (kein Druck durch Design): `docs/01-produktvision.md`
- Kostenrahmen, Werbebudget-Antwort: `docs/19-kosten-preis-budget.md` Abschnitt 6
- Freischaltcode-Lücke: `docs/15-go-to-market.md` Abschnitt 1.1, [SUB-262](/SUB/issues/SUB-262)
