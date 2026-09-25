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

Die KI-Klausurkorrektur ist **bedingt in v1.0** — sie wird gebaut und ist zum
Freeze aktivierbar, aber nur wenn der AVV rechtzeitig unterschrieben ist. Die
Regel dafür steht in Abschnitt 2.1 und ist so gebaut, dass sie den Termin
29.09. unter keinen Umständen gefährdet.

**Nutzerentscheidung vom 16.09.2026: Das Feature bleibt.** Auf die
Klarstellung unten hat der Nutzer auf [SUB-39](/SUB/issues/SUB-39) geantwortet:
*„Ich würde sie gerne behalten."* Damit ist die Rückkehr der KI-Korrektur keine
Option mehr, die dieses Dokument offenhält, sondern eine gesetzte
Produktentscheidung — Option D aus
[`docs/23-llm-provider-avv.md`](23-llm-provider-avv.md) („kein LLM, Status quo
dauerhaft") ist vom Tisch.

**Zur Herkunft der Zurückstellung — Klarstellung (16.09.2026).** Die
Nutzervorgabe („Zugang zu Korrigierenden kann später als Feature kommen")
betrifft wörtlich den Zugang zu **menschlichen** Korrigierenden; der steht in
3.2 als v1.2+. Die **KI**-Korrektur zusätzlich herauszunehmen ging darüber
hinaus und war eine Planungsentscheidung dieses Dokuments, keine
Nutzeranweisung. Frühere Fassungen dieses Absatzes haben beides vermischt. Die
Zurückstellung stützt sich auf drei eigene Gründe; alle drei sprechen gegen
eine *sofortige Aktivierung*, keiner gegen das Feature:

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
   einer Vorbedingung für die Aktivierung — er bleibt das einzige harte Gate
   und entscheidet, wie früh die Aktivierung überhaupt terminierbar ist.
3. **Sie ist der größte variable Kostenblock.** Siehe
   `docs/19-kosten-preis-budget.md` Abschnitt 5 — ohne sie sind die
   Betriebskosten praktisch fix und der kostendeckende Preis niedrig
   kalkulierbar.

Das Struktur- und Stilfeedback zum Gutachtenstil **bleibt drin** — es ist
heuristisch, sofort, kostenlos und wird als das kommuniziert, was es ist
(„Struktur-Check", keine Note).

### 2.1 KI-Korrektur: bedingt in v1.0 (Nutzerentscheidung 16.09.2026)

Auf die Terminfrage hat der Nutzer geantwortet: **„Noch in v1.0, falls der AVV
vor dem 28.09. steht"** — und: **den AVV schließt er selbst ab.** Damit ist die
Zurückstellung aus Abschnitt 2 keine Entscheidung mehr, sondern ein
Rückfallpfad.

Die drei Gründe oben bleiben inhaltlich richtig, aber sie wiegen unterschiedlich
schwer, und nur einer davon ist ein echtes Gate:

| Grund | Bindet er die v1.0-Aktivierung? |
|---|---|
| **AVV fehlt** | **Ja, hart.** Ohne ihn verlässt kein Nutzertext das System — jede LLM-Variante ist unzulässig, auch eine ohne Punkte |
| Kalibrierung fehlt | Nur die **bewertende** Variante mit Punkten. Kommentierendes Feedback ohne Note wäre auch unkalibriert lieferbar |
| Kostenblock | Nein — begrenzbar, siehe Kostenbremse in [SUB-135](/SUB/issues/SUB-135). Die Spanne 0,09–0,30 € wird dort zum ersten Mal **gemessen** statt geschätzt |

**Die Entscheidungsregel.** Sie ist bewusst so gebaut, dass Nichtstun zum
sicheren Ergebnis führt:

> Am **So 27.09., 18:00 Uhr** wird geprüft: AVV unterschrieben **und**
> [SUB-133](/SUB/issues/SUB-133) + [SUB-134](/SUB/issues/SUB-134) gemergt
> **und** Smoke-Test grün? Wenn ja, wird `llm_provider` umgestellt und das
> Feature geht mit v1.0 live. Wenn irgendetwas davon offen ist, bleibt
> `llm_provider=none` und das Feature fällt auf v1.1.
>
> **Der Releasetermin 29.09. steht in keinem der beiden Fälle zur Disposition.**

Der Ziel-Stichtag für die Unterschrift ist **Fr 25.09.**, die harte Grenze
So 27.09. 18:00. Der Abstand ist kein Puffer aus Vorsicht: Zwischen
Unterschrift und Freeze müssen der Key in die Secret-Verwaltung, ein
Smoke-Test gegen den echten Anbieter laufen und die gemessenen Kosten in die
Kalkulation zurückfließen.

**Was daraus folgt, und warum es sofort startet.** Die Aktivierung selbst ist
eine Konfigurationszeile (`evaluator.py:341-344` wählt den `LLMEvaluator` nur
bei gesetztem Provider *und* Key). Alles andere ist providerunabhängig und
hängt weder am AVV noch an der Anbieterwahl — es wird deshalb **jetzt** gebaut,
nicht nach der Unterschrift:

| Aufgabe | Wer | Bis | Hängt am AVV? |
|---|---|---|---|
| [SUB-129](/SUB/issues/SUB-129) Provider-Wahl + unterschriftsreife Vorlage | Software-Planner | 19.09. | nein |
| **AVV unterschreiben** | **Nutzer** | **25.09.** (hart: 27.09.) | — ist der AVV |
| [SUB-133](/SUB/issues/SUB-133) Backend: Einwilligungs-Gate vor LLM-Versand | Backend-Developer | 22.09. | nein |
| [SUB-134](/SUB/issues/SUB-134) Frontend: Zustimmungsdialog vor erster Abgabe | Frontend-Developer | 24.09. | nein |
| [SUB-135](/SUB/issues/SUB-135) Aktivierung, Kostenbremse, Stichtagsentscheid | Lead-Developer | 27.09. | ja |

SUB-133 und SUB-134 sind so geschnitten, dass sie im heutigen Zustand
(`llm_provider=none`) **nichts** am Verhalten ändern. Sie sind damit auch dann
risikolos mergebar, wenn der AVV nicht zustande kommt — im Rückfall auf v1.1
ist die Arbeit nicht verloren, sondern vorgezogen.

**Die eine Unbekannte, die den Ausgang bestimmt,** steckt in
[`docs/23-llm-provider-avv.md`](23-llm-provider-avv.md) Abschnitt 2: ob der
Self-Serve-Zugang bei Anthropic (Option A) automatisch das volle DPA umfasst
oder ein Vertriebsgespräch braucht. Reicht Self-Serve, ist v1.0 machbar. Die
dort empfohlene Option B (EU-Region über Hyperscaler) ist in elf Tagen nicht
erreichbar — neuer Cloud-Vertrag plus 2–4 PT Integration — und wird deshalb zur
v1.1-Migration, nicht zum v1.0-Weg. SUB-129 hat den Auftrag, diese Frage zu
belegen statt zu schätzen.

---

## 3. Umfang: drin, raus, später

### 3.1 Drin (Release-Umfang v1.0)

| Bereich | Umfang v1.0 | Stand heute |
|---|---|---|
| Lernen | Karteikarten mit FSRS-Wiederholung, Schemata, geführte Fälle | Backend + 6 Client-Screens vorhanden |
| Inhalt | **180 Karten** über drei Rechtsgebiete, ≥ 8 Schemata, ≥ 6 Fälle | 143 Karten (Rechnung in 4.) |
| Gutachten | Struktur-/Stil-Check ohne Note, gegen Erwartungshorizont der Übungsfälle | implementiert, heuristisch |
| Konto | Registrierung, Login, Passwort-Reset, DSGVO-Export und -Löschung | vollständig implementiert (SUB-84, `/v1/account/export` + `/v1/account/delete`) |
| Bezahlung | Web-Checkout (Stripe), Free-Tier mit Limit, Pro-Freischaltung | **nicht vorhanden — größter Einzelposten** |
| Plattform | `app.subsumo.de` (Web) + Android als internes/offenes Testing | Web-Build in CI, APK-Artefakt aus SUB-60 |
| Recht | Impressum, AGB, Datenschutzerklärung, Widerrufsbelehrung, Cookie-Hinweis | Entwürfe stehen (`docs/legal/`), Rechtsträger-Angaben offen. AGB-Haftungsklausel und Widerrufsverzicht laufen bewusst ohne anwaltliche Freigabe (Entscheidung 25.09.2026, `docs/17-release-readiness.md` Abschnitt 1) |
| Betrieb | Monitoring, Fehler-Tracking, tägliches DB-Backup, Support-Postfach | offen |

### 3.2 Raus (mit Rückkehrdatum)

| Nicht aktiv in v1.0 | Warum | Kommt in |
|---|---|---|
| KI-Klausurkorrektur mit Punkten | **Feature bleibt und ist bedingt in v1.0** (Nutzerentscheidung 16.09.): heute nur per Konfiguration abgeschaltet (`llm_provider=none`), kein Rückbau | **v1.0, wenn der AVV bis 27.09. steht — sonst automatisch v1.1.** Regel in Abschnitt 2.1 |
| Zugang zu menschlichen Korrigierenden | ausdrücklich vom Nutzer zurückgestellt | v1.2+ |
| 5-Stunden-Klausursimulator | hängt funktional an der Korrektur, aber zusätzlich an Oberflächenarbeit, die in 14 Tagen nicht dazukommt | v1.1 — auch dann, wenn die Korrektur es noch in v1.0 schafft |
| iOS / App Store | Entwicklerkonto-Vorlauf + Review-Zyklus + IAP-Pflicht (30 %/15 %) passen nicht in 14 Tage | v1.1, ca. 3 Wochen nach Release |
| Microsoft Store | kleinster Nutzenbeitrag je Aufwand | v1.2 |
| Norm-Explorer (Gesetzesvolltext) | reiner Umfangsposten, kein Blocker | v1.2 |
| Lerngruppen, Peer-Review | v2-Thema | v2 |
| 500 Karten / 40 Fälle | Zielmenge bleibt, aber als laufende Produktion nach Release | fortlaufend |
| Kalibrierung gegen 30 Dozentengutachten | braucht externe Personen und Vorlauf | Start sofort, Ergebnis für v1.1 |

**„Kommt in v1.1" hat seit dem 16.09.2026 Eigentümer** — und seit der
Nutzerentscheidung vom selben Tag (Abschnitt 2) auch eine Zusage statt einer
Absichtserklärung. Bis dahin war die
Rückkehr der KI-Korrektur nur hier im Dokument versprochen und auf dem Board
nirgends verfolgt. Die beiden Vorbedingungen liegen jetzt als Aufgaben:
[SUB-129](/SUB/issues/SUB-129) (LLM-Provider-Wahl + AVV) und
[SUB-130](/SUB/issues/SUB-130) (Kalibrierungspaket für die 30
Dozentengutachten, inzwischen erledigt: `docs/24-kalibrierungspaket.md`). Von
beiden ist **nur der AVV ein echtes Gate**: er blockt jede LLM-Variante, auch
eine ohne Punkte. Die Kalibrierung bindet allein die bewertende Variante.
Reihenfolge deshalb: AVV zuerst. Seit der Terminentscheidung vom 16.09. ist die
Rückkehr zusätzlich terminiert statt nur zugesagt — siehe Abschnitt 2.1.

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

> **Nachtrag 23.09.2026 — Umfang-Ziel erledigt, Prüf-Gate offen.** Auf
> [SUB-225](/SUB/issues/SUB-225) hatte der Nutzer entschieden, dass auch die
> Stufe **P2 vor dem Release** kommt. Das ist **vollständig geliefert**: 17
> Themen über [SUB-243](/SUB/issues/SUB-243) / [SUB-244](/SUB/issues/SUB-244)
> / [SUB-245](/SUB/issues/SUB-245), gemergt als PR #68/#69/#70.
>
> | Größe | G3-Ziel | Ist auf `main` (23.09.) |
> |---|---|---|
> | Karten | 180 (Streckziel 250) | **444** — 2,5× erfüllt |
> | Themen | — | 60 (P1 36/36, P2 24/24 vollständig) |
> | Fälle | — | 60 |
>
> Ausgezählt mit `backend/scripts/validate_content.py`: 0 Fehler, 0 Warnungen.
> Details in `docs/12-content-produktionsplan.md` Abschnitt 1.1. Die
> **Mengen-Bedingung von G3 ist damit erfüllt und war nie der Engpass.**
>
> **Was G3 noch offen hat, ist die zweite Hälfte seines eigenen Wortlauts:
> „keine offenen Redaktionsfunde".** Die menschliche Stichprobe nach
> `docs/08-ki-redaktion.md` ist für **keines der 60 Themen** erbracht — alle
> tragen `geprueft_von: reviewer-agent-v1`, also einen LLM-Aufruf, keine
> Person. Kein Agent kann dieses Gate schließen. Mindestumfang nach
> `docs/12` Abschnitt 4.2: ≥ 6 Themen, mind. 2 je Rechtsgebiet, Schwerpunkt
> P1. Fällt die Stichprobe bis 25.09. aus, ist das eine bewusste
> Nutzerentscheidung — nicht ein Mengenproblem, und die G3-Regel „Release mit
> Ist-Menge" deckt sie nicht ab.

> **Nachtrag 25.09.2026 — G3 ist entschieden, nicht erfüllt.** Die im
> vorigen Absatz beschriebene Nutzerentscheidung ist gefallen
> ([SUB-225](/SUB/issues/SUB-225), Interaktion `f754f609`): **Release ohne
> menschliche Stichprobe, Gate bewusst ausgesetzt.**
>
> Damit ist G3 aufgelöst — aber über die beiden Hälften auf unterschiedlichen
> Wegen, und das sollte man beim Lesen auseinanderhalten:
>
> | G3-Hälfte | Auflösung |
> |---|---|
> | „180 Karten geprüft und gemerged" | **Erfüllt durch Nachweis.** Neu ausgezählt auf `main` am 25.09.: **446 Karten**, 60 Themen, 64 Schemata, 60 Fälle, 0 Fehler (die 446 statt der oben genannten 444 stammen aus den Karten-Nachträgen SUB-283/284/285 und SUB-305) |
> | „keine offenen Redaktionsfunde" | **Erfüllt durch Entscheidung, nicht durch Prüfung.** Die menschliche Stichprobe entfällt für v1.0 |
>
> Das Restrisiko dieser Aussetzung ist in
> [`docs/17-release-readiness.md`](17-release-readiness.md) Abschnitt 7.1
> ausgeschrieben — Kern: **Normzitate gehen inhaltlich ungeprüft live**, weil
> das deterministische Gate nur Existenz und Form prüft und der Norm-Explorer
> (M2) noch nicht existiert. Das vorbereitete Prüfmaterial
> (`docs/26-content-stichprobe.md`) bleibt für den Nachlauf nach dem Launch
> gültig.
>
> **G3 gilt damit als passiert.** Der Notausgang „Release mit Ist-Menge" wird
> nicht gebraucht: Die Menge ist 2,5-fach erfüllt.

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

**Die KI-Korrektur ist bewusst kein sechstes Gate.** Sie hat seit dem 16.09.
einen Termin (Abschnitt 2.1), aber ein Gate ist etwas, dessen Ausfall den
Release verschiebt — und genau das soll sie nicht können. Sie ist eine
**bedingte Zugabe mit Stichtag 27.09. 18:00**: steht der AVV, geht sie mit
live; steht er nicht, fällt sie lautlos auf v1.1 und niemand am Releasetag
merkt einen Unterschied. Diese Asymmetrie ist der ganze Zweck der Konstruktion.

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

### Nebenspur: KI-Korrektur (bedingt, Abschnitt 2.1)

Bewusst als eigene Tabelle geführt, damit sie den Tagesplan oben nicht
belastet. Keine Zeile hier darf eine Zeile dort verzögern.

| Tag | Wer | Was |
|---|---|---|
| **Mi 17.–Fr 19.09.** | Software-Planner | [SUB-129](/SUB/issues/SUB-129): Self-Serve-DPA-Frage belegen, unterschriftsreife Handlungsanweisung |
| **Fr 19.–Fr 25.09.** | **Nutzer** | AVV prüfen und unterschreiben (Ziel 25.09.) |
| **Mi 17.–Mo 22.09.** | Backend-Developer | [SUB-133](/SUB/issues/SUB-133): Einwilligungs-Gate, kein Nutzertext ohne Zustimmung |
| **Di 23.–Do 24.09.** | Frontend-Developer | [SUB-134](/SUB/issues/SUB-134): Zustimmungsdialog, Ablehnen als vollwertiger Pfad |
| **Do 24.–Sa 26.09.** | Lead-Developer | [SUB-135](/SUB/issues/SUB-135): Kostenbremse, Smoke-Test, Runbook |
| **So 27.09., 18:00** | Lead-Developer | **Stichtagsentscheid** — aktivieren oder auf v1.1 zurückfallen, dokumentiert auf SUB-135 |

---

## 7. Risiken der Zwei-Wochen-Variante

| Risiko | Wirkung | Gegenmaßnahme |
|---|---|---|
| Zahlungskonto nicht rechtzeitig verifiziert (Identitätsprüfung dauert Tage) | Kein bezahlter Release | G1 am 18.09., Fallback kostenloser Early Access mit Preisankündigung |
| 180 Karten wirken gegenüber Jurafuchs (8.000+ Fälle) dünn | Abo nicht verkaufbar | Gründerpreis + offene Kommunikation des Umfangs statt Behauptung von Vollständigkeit (siehe `docs/19-kosten-preis-budget.md` Abschnitt 4) |
| Kein Nutzer kennt das Produkt am Tag 1 | Release ohne Wirkung | Release ist ein Anfang, kein Kampagnenstart; GTM-Spur [SUB-46](/SUB/issues/SUB-46) läuft nach Release weiter |
| Erstes Produktivsystem ohne Betriebserfahrung | Ausfall/Datenverlust in Woche 1 | Tägliches Backup **mit geprobtem Restore** (24.09.), Monitoring ab 22.09. |
| Abschaltung der Korrektur in v1.0 nimmt die Positionierung weg | Produkt ist austauschbar | Positionierung für v1.0 bewusst bescheiden („ordentliche Lern-App zum Gründerpreis"), Differenzierung kommt mit v1.1 — oder früher, falls der Stichtag 27.09. hält (Abschnitt 2.1) |
| AVV kommt knapp vor dem Stichtag und verleitet zum Durchwinken | Ungeprüfter Vertrag, ungemessene Kosten, unkalibrierte Noten live am Tag 1 | Stichtag 27.09. 18:00 ist eine **Und**-Bedingung: AVV **und** SUB-133/134 gemergt **und** Smoke-Test grün. Ein einzelnes fehlendes Stück führt zum Rückfall auf v1.1, ohne Ermessensspielraum |
| Launch-Texte und Stichtagsergebnis widersprechen sich | Entweder ein uneingelöstes Versprechen oder ein FAQ, das ein vorhandenes Feature leugnet | `docs/21-landing-preisseite-launchtext.md` (SUB-88) bewirbt die Korrektur bewusst **nicht** — die Richtung „Versprechen ohne Feature" ist damit ausgeschlossen. Die Gegenrichtung ist offen: die FAQ-Antwort „Eine KI-gestützte Korrektur ist nicht Teil des aktuellen Angebots" wird falsch, sobald aktiviert wird. Marketing-Planner hält für diesen Fall eine Austauschfassung bereit, die erst am 27.09. gezogen wird |
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
| *bedingt* KI-Korrektur (19.09.) | [SUB-129](/SUB/issues/SUB-129) | Software-Planner | Provider-Wahl, belegte Self-Serve-DPA-Antwort, unterschriftsreife Anweisung |
| *bedingt* KI-Korrektur (25.09.) | — | **Nutzer** | AVV unterschreiben — der einzige Schritt der Kette ohne Agenten |
| *bedingt* KI-Korrektur (22.09.) | [SUB-133](/SUB/issues/SUB-133) | Backend-Developer | Einwilligungs-Gate, Test „kein Text ohne Zustimmung" |
| *bedingt* KI-Korrektur (24.09.) | [SUB-134](/SUB/issues/SUB-134) | Frontend-Developer | Zustimmungsdialog, Widerruf, Kennzeichnung maschineller Bewertung |
| *bedingt* KI-Korrektur (27.09.) | [SUB-135](/SUB/issues/SUB-135) | Lead-Developer | Kostenbremse, Smoke-Test, Runbook, **Stichtagsentscheid** |

**G1 hat bewusst keinen Agenten.** Rechtsträger, Zahlungskonto-Verifizierung
und Domainbesitz sind Handlungen, die eine reale Person mit einem Ausweis
vornimmt. Kein Mehraufwand auf Projektseite beschleunigt das, und der Termin
18.09. steht genau deshalb so früh.

Nicht neu geschnitten, weil bereits laufend: die Content-Produktion selbst
([SUB-51](/SUB/issues/SUB-51) mit SUB-54/55/77) und die GTM-Spur
([SUB-46](/SUB/issues/SUB-46)). SUB-87 und SUB-88 priorisieren diese Stränge
auf den Releasetermin um, statt sie zu duplizieren.
