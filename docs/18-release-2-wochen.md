# Release in zwei Wochen — Schnittplan v1.0

> **Auslöser:** Nutzerkommentar auf [SUB-39](/SUB/issues/SUB-39) vom 15.09.2026:
> *„Zieltermin: Release in zwei Wochen, Preis: mache eine Marktanalyse, muss
> Kosten decken, Zugang zu Korrigierenden kann später als Feature kommen,
> Budget wofür?"*
>
> Dieses Dokument ersetzt die Phasen A–D aus `docs/03-roadmap.md` für den
> Release. Die 28-Wochen-Planung ist damit nicht falsch — sie wird zur
> Nach-Release-Roadmap (v1.1+). Preis, Kosten und die Budgetantwort stehen
> separat in [`docs/19-kosten-preis-budget.md`](19-kosten-preis-budget.md).

**Releasetermin: Dienstag, 29.09.2026.** Code-Freeze Montag, 28.09.2026.

---

## 1. Was der Termin erzwingt

Die alte Roadmap brauchte 28 Wochen bis v1.0. Zwei Wochen sind ein Vierzehntel
davon. Der Termin ist erreichbar — aber nur, wenn v1.0 neu definiert wird. Was
nicht geht, ist der alte Funktionsumfang in der neuen Zeit; was geht, ist ein
ehrlich kleineres Produkt, das am Tag 1 funktioniert und Geld annimmt.

**Die Termintreue ist das Gate, nicht der Umfang.** Fällt eine Position aus der
Zeit, fällt die Position — nicht der Termin. Jede Zeile in Abschnitt 3 ist
deshalb einzeln streichbar, ohne dass das Release kippt. Einzige Ausnahme sind
die fünf Gates in Abschnitt 5: die sind nicht verhandelbar, weil sie rechtliche
oder Zahlungs-Pflichten abbilden.

---

## 2. v1.0 neu definiert

> **v1.0 = eine öffentlich erreichbare Lern-App im Web (plus Android-Beta), mit
> der man ab Semester 1 Karteikarten, Schemata und geführte Fälle über drei
> Rechtsgebiete lernt, mit funktionierender Registrierung, Bezahlung und
> vollständigen Rechtstexten.**

Nicht mehr enthalten: die KI-Klausurkorrektur als bewertendes Feature und
alles, was auf ihr aufbaut. Das folgt direkt der Nutzervorgabe („Zugang zu
Korrigierenden kann später als Feature kommen") — und ist auch ohne diese
Vorgabe der richtige Schnitt, aus drei Gründen:

1. **Die Korrektur ist unkalibriert.** `docs/13-lernarchitektur.md` und der
   Kalibrierungs-Harness aus [SUB-69](/SUB/issues/SUB-69) setzen MAE ≤ 2 Punkte
   gegen 30 Dozentengutachten als Freigabebedingung. Diese 30 Gutachten
   existieren nicht und sind in zwei Wochen nicht zu beschaffen. Eine
   Punktebewertung ohne Kalibrierung auszuliefern, beschädigt genau das
   Vertrauen, von dem das Feature später lebt.
2. **Sie ist der einzige DSGVO-Blocker im Release-Pfad.**
   `docs/17-release-readiness.md` Abschnitt 1 nennt den fehlenden AVV mit einem
   LLM-Provider als release-kritisch offen. Ohne LLM-Bewertung verlässt **kein
   Nutzertext** das eigene System: `/gutachten/analyze` ist ausdrücklich
   heuristisch (`backend/app/api/v1/gutachten.py`), und
   `backend/app/services/evaluator.py` fällt ohne gesetzten `llm_provider`
   automatisch auf den heuristischen Evaluator zurück. **Konsequenz: v1.0 läuft
   mit `llm_provider=none`.** Der AVV wird damit von einer Release-Blockade zu
   einer Vorbedingung für v1.1.
3. **Sie ist der größte variable Kostenblock.** Siehe
   `docs/19-kosten-preis-budget.md` Abschnitt 5 — ohne sie sind die
   Betriebskosten praktisch fix und der kostendeckende Preis niedrig
   kalkulierbar.

Das Struktur- und Stilfeedback zum Gutachtenstil **bleibt drin** — es ist
heuristisch, sofort, kostenlos und wird als das kommuniziert, was es ist
(„Struktur-Check", keine Note).

---

## 3. Umfang: drin, raus, später

### 3.1 Drin (Release-Umfang v1.0)

| Bereich | Umfang v1.0 | Stand heute |
|---|---|---|
| Lernen | Karteikarten mit FSRS-Wiederholung, Schemata, geführte Fälle | Backend + 6 Client-Screens vorhanden |
| Inhalt | **180 Karten** über drei Rechtsgebiete, ≥ 8 Schemata, ≥ 6 Fälle | 143 Karten (Rechnung in 4.) |
| Gutachten | Struktur-/Stil-Check ohne Note, gegen Erwartungshorizont der Übungsfälle | implementiert, heuristisch |
| Konto | Registrierung, Login, Passwort-Reset, DSGVO-Export und -Löschung | Auth vorhanden, Export/Löschung offen |
| Bezahlung | Web-Checkout (Stripe), Free-Tier mit Limit, Pro-Freischaltung | **nicht vorhanden — größter Einzelposten** |
| Plattform | `app.subsumo.de` (Web) + Android als internes/offenes Testing | Web-Build in CI, APK-Artefakt aus SUB-60 |
| Recht | Impressum, AGB, Datenschutzerklärung, Widerrufsbelehrung, Cookie-Hinweis | Entwürfe stehen (`docs/legal/`), anwaltliche Freigabe + Rechtsträger-Angaben offen |
| Betrieb | Monitoring, Fehler-Tracking, tägliches DB-Backup, Support-Postfach | offen |

### 3.2 Raus (mit Rückkehrdatum)

| Gestrichen aus v1.0 | Warum | Kommt in |
|---|---|---|
| KI-Klausurkorrektur mit Punkten | unkalibriert (MAE-Nachweis fehlt), AVV fehlt | v1.1 |
| Zugang zu menschlichen Korrigierenden | ausdrücklich vom Nutzer zurückgestellt | v1.2+ |
| 5-Stunden-Klausursimulator | hängt funktional an der Korrektur | v1.1 |
| iOS / App Store | Entwicklerkonto-Vorlauf + Review-Zyklus + IAP-Pflicht (30 %/15 %) passen nicht in 14 Tage | v1.1, ca. 3 Wochen nach Release |
| Microsoft Store | kleinster Nutzenbeitrag je Aufwand | v1.2 |
| Norm-Explorer (Gesetzesvolltext) | reiner Umfangsposten, kein Blocker | v1.2 |
| Lerngruppen, Peer-Review | v2-Thema | v2 |
| 500 Karten / 40 Fälle | Zielmenge bleibt, aber als laufende Produktion nach Release | fortlaufend |
| Kalibrierung gegen 30 Dozentengutachten | braucht externe Personen und Vorlauf | Start sofort, Ergebnis für v1.1 |

**Was das Streichen der iOS-Spur zusätzlich spart:** Apple erzwingt für
digitale Abos In-App-Purchase (`docs/06-recht-compliance.md` Abschnitt 4). Mit
Web-only-Abrechnung entfällt in v1.0 die zweite Preisstufe für iOS und die
gesamte IAP-Integration.

---

## 4. Contentrechnung für 14 Tage

`docs/12-content-produktionsplan.md` Abschnitt 3 misst den Engpass nicht an der
Maschine, sondern an der **menschlichen Prüfung**: Ø 7,0 Karten je Thema,
35 min (optimistisch) / 60 min (realistisch) / 105 min (pessimistisch)
Kuration + Stichprobe je Thema.

Fehlmenge auf 180 Karten: 180 − 143 = 37 Karten → ⌈37 / 7,0⌉ = **6 zusätzliche
Themen**. (Ist-Stand 143 Karten über 21 Themendateien zum PR-Commit — 66 mehr
als die 77, mit denen `docs/12-content-produktionsplan.md` Abschnitt 3
gerechnet hat; seither über SUB-56 und SUB-54 gemergt.)

| Szenario | Aufwand/Thema | Aufwand für 6 Themen | Über 10 Werktage |
|---|---|---|---|
| Optimistisch | 35 min | 3,5 Std. | 0,35 Std./Tag |
| Realistisch | 60 min | 6,0 Std. | 0,6 Std./Tag |
| Pessimistisch | 105 min | 10,5 Std. | 1,05 Std./Tag |

**Bewertung:** 180 Karten sind selbst im pessimistischen Szenario mit
komfortablem Abstand erreichbar (1,05 Std./Tag Prüfkapazität). Bei 250 Karten
(Fehlmenge 107 → 16 Themen) läge der pessimistische Fall bei 2,8 Std./Tag —
immer noch unkritisch. Die Content-Frage ist damit kein Terminrisiko mehr für
G3; **180 bleibt trotzdem die Zielmenge, 250 das Streckziel**, weil die
Priorisierung auf Klausurrelevanz-Stufe P1 unabhängig vom reinen Kartenstand
gilt.

Die Produktion selbst läuft bereits über die Content-Agenten
([SUB-51](/SUB/issues/SUB-51), SUB-54/55/56/77) und den Redaktionspfad aus
`docs/08-ki-redaktion.md`; neu ist nur die Priorisierung auf
Klausurrelevanz-Stufe P1 und das Einfrieren am 25.09.

---

## 5. Die fünf harten Gates

Nicht verhandelbar. Fällt eines, verschiebt sich der Termin — nicht das Gate.

| # | Gate | Termin | Inhalt | Fällt es, dann |
|---|---|---|---|---|
| **G1** | Konten & Rechtsträger | **Fr 18.09.** | Zahlungskonto verifiziert, Domain aktiv, Impressumspflichtangaben vorhanden | Release wird kostenlos (Early Access), Paywall zieht nach |
| **G2** | Kaufstrecke auf Staging | **Mi 23.09.** | Registrierung → Lernen → Kauf → Pro-Freischaltung → Kündigung, end-to-end | Paywall fällt aus v1.0, Release bleibt |
| **G3** | Content-Freeze | **Fr 25.09.** | 180 Karten geprüft und gemerged, keine offenen Redaktionsfunde | Release mit Ist-Menge, Zahl wird offen kommuniziert |
| **G4** | Rechtstexte & Release Candidate | **Mo 28.09.** | Impressum, AGB, DSE, Widerruf live; Code-Freeze; Backup nachweislich einspielbar | **Termin verschiebt sich** — hier gibt es keinen Notausgang |
| **G5** | Produktivschaltung | **Di 29.09.** | Web live, Android-Testing offen, Support-Postfach besetzt, Monitoring scharf | — |

G4 ist das einzige Gate ohne Umgehung: Ein öffentliches Angebot ohne
Impressum, AGB und Datenschutzerklärung ist abmahnfähig, und ein Backup, das
nie eingespielt wurde, ist kein Backup.

---

## 6. Tagesplan

| Tag | Technik | Inhalt | Recht/Betrieb | Design/GTM |
|---|---|---|---|---|
| **Di 15.09.** | Re-Scope, Issues geschnitten | BACKLOG auf P1-Themen priorisiert | Entscheidungsfragen an Nutzer | — |
| **Mi 16.09.** | Stripe-Checkout + Entitlement-Feld am Nutzer | Produktion Themen 1–3 | Impressum/AGB/DSE-Entwurf | Landing-Page-Struktur |
| **Do 17.09.** | Free-Tier-Limit serverseitig, Pro-Gating im Client | Themen 4–6 | Datenschutzerklärung Entwurf | Onboarding-Screen |
| **Fr 18.09.** | Deploy-Pipeline auf Zielserver | Themen 7–8 | **G1** Konten verifiziert | Landing-Page-Text |
| **Sa/So 19.–20.09.** | Puffer | Produktion läuft (Agenten) | — | — |
| **Mo 21.09.** | `app.subsumo.de` live auf Staging, TLS, DB-Backup | Themen 9–11 | DSGVO-Export/Löschung Endpunkte | Preisseite |
| **Di 22.09.** | Android-Build signiert, Testing-Track | Themen 12–13 | Monitoring + Fehler-Tracking scharf | Warteliste/Newsletter |
| **Mi 23.09.** | **G2** Kaufstrecke end-to-end | Themen 14–15 | Store-Datenschutzangaben (Android) | Launch-Ankündigung entworfen |
| **Do 24.09.** | Bugfix aus G2 | Stichprobenprüfung | Backup-Restore geprobt | Landing live |
| **Fr 25.09.** | Bugfix, Performance-Check | **G3** Content-Freeze | Support-Postfach eingerichtet | Launch-Text final |
| **Sa/So 26.–27.09.** | Testlauf 5–10 echte Nutzer, Fixes | — | — | Testnutzer-Feedback |
| **Mo 28.09.** | **G4** Code-Freeze, RC | — | Rechtstexte live, Preise im Zahlungskonto | Ankündigung terminiert |
| **Di 29.09.** | **G5 Release** | — | Bereitschaft | Launch |

---

## 7. Risiken der Zwei-Wochen-Variante

| Risiko | Wirkung | Gegenmaßnahme |
|---|---|---|
| Zahlungskonto nicht rechtzeitig verifiziert (Identitätsprüfung dauert Tage) | Kein bezahlter Release | G1 am 18.09., Fallback kostenloser Early Access mit Preisankündigung |
| 180 Karten wirken gegenüber Jurafuchs (8.000+ Fälle) dünn | Abo nicht verkaufbar | Gründerpreis + offene Kommunikation des Umfangs statt Behauptung von Vollständigkeit (siehe `docs/19-kosten-preis-budget.md` Abschnitt 4) |
| Kein Nutzer kennt das Produkt am Tag 1 | Release ohne Wirkung | Release ist ein Anfang, kein Kampagnenstart; GTM-Spur [SUB-46](/SUB/issues/SUB-46) läuft nach Release weiter |
| Erstes Produktivsystem ohne Betriebserfahrung | Ausfall/Datenverlust in Woche 1 | Tägliches Backup **mit geprobtem Restore** (24.09.), Monitoring ab 22.09. |
| Streichung der Korrektur nimmt die Positionierung weg | Produkt ist austauschbar | Positionierung für v1.0 bewusst bescheiden („ordentliche Lern-App zum Gründerpreis"), Differenzierung kommt mit v1.1 |
| Zwei Wochen Volllast, danach Erschöpfung | v1.1 verzögert sich | v1.1-Fenster bewusst auf 4 Wochen nach Release gelegt, nicht auf 2 |

---

## 8. Offene Entscheidungen (blockieren Teile, nicht den Termin)

Als Interaktion an [SUB-39](/SUB/issues/SUB-39) gestellt:

1. **Rechtsträger für Abrechnung und Impressum** — existiert eine Firma/ein
   Gewerbe, oder läuft der Release auf eine Privatperson? Bestimmt Impressum,
   Zahlungskonto und Umsatzsteuer-Behandlung.
2. **Zahlungskonto vorhanden?** Ein neu eröffnetes Stripe/Mollie-Konto braucht
   Identitäts- und Kontoprüfung — das ist der einzige Posten, den kein
   Mehraufwand beschleunigt.
3. **Bezahlt oder kostenlos am Tag 1?** Kostendeckung greift ab ~50 Zahlenden
   (Abschnitt 3 in `docs/19-kosten-preis-budget.md`); kostenloser Start
   maximiert Nutzerzahl, verschiebt aber die Kostendeckung.
4. **Reichweite für Tag 1** — gibt es Zugang zu einer Fachschaft, einem
   Jura-Kanal oder einer Lerngruppe? Bestimmt, ob der Release 10 oder 300
   Menschen erreicht.

---

## 9. Wer macht was — Gates auf Aufgaben abgebildet

Am 15.09.2026 auf Zuruf des Nutzers („go ahead") geschnitten und zugewiesen.
Jede Zeile hat genau einen Verantwortlichen; ohne Zuweisung ist ein Gate nur
eine Absichtserklärung.

| Gate | Aufgabe | Verantwortlich | Liefert |
|---|---|---|---|
| **G2** Kaufstrecke (23.09.) | [SUB-83](/SUB/issues/SUB-83) | Software-Planner → Developer | Abnahmekriterien + Zerlegung Stripe-Checkout, Entitlement, Free-Tier, Kündigung |
| **G4** Konto/DSGVO (28.09.) | [SUB-84](/SUB/issues/SUB-84) | Backend-Developer | Export (Art. 15) und Löschung (Art. 17) mit Tests |
| **G4** Rechtstexte (28.09.) | [SUB-85](/SUB/issues/SUB-85) | Marketing-Planner | Impressum, AGB, DSE, Widerruf, Cookie-Hinweis |
| **G4/G5** Betrieb (24.–29.09.) | [SUB-86](/SUB/issues/SUB-86) | Lead-Developer | Deploy-Runbook, TLS, Backup **mit geprobtem Restore**, Monitoring |
| **G3** Content-Freeze (25.09.) | [SUB-87](/SUB/issues/SUB-87) | Content-Koordinator | 6 P1-Themen → 180 Karten, geprüft und gemergt (Rechnung: Abschnitt 4) |
| **G5** Launch (29.09.) | [SUB-88](/SUB/issues/SUB-88) | Marketing-Planner | Landing Page, Preisseite, Launch-Text |
| **G1** Konten (18.09.) | — | **Nutzer** | Rechtsträger, Zahlungskonto, Domain — siehe Abschnitt 8 |

**G1 hat bewusst keinen Agenten.** Rechtsträger, Zahlungskonto-Verifizierung
und Domainbesitz sind Handlungen, die eine reale Person mit einem Ausweis
vornimmt. Kein Mehraufwand auf Projektseite beschleunigt das, und der Termin
18.09. steht genau deshalb so früh.

Nicht neu geschnitten, weil bereits laufend: die Content-Produktion selbst
([SUB-51](/SUB/issues/SUB-51) mit SUB-54/55/77) und die GTM-Spur
([SUB-46](/SUB/issues/SUB-46)). SUB-87 und SUB-88 priorisieren diese Stränge
auf den Releasetermin um, statt sie zu duplizieren.
