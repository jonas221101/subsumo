# 26 — Menschliche Content-Stichprobe (Prüfpaket zu G3)

> **Status 25.09.2026: nicht durchgeführt. Für v1.0 bewusst ausgesetzt.**
>
> Die Entscheidung über diese Stichprobe ist gefallen
> ([SUB-225](/SUB/issues/SUB-225), Interaktion `f754f609`): **Release ohne
> menschliche Stichprobe.** Es wurde also **kein einziges Thema** nach dem
> unten stehenden Raster geprüft; kein Thema trägt eine menschliche
> Prüfsignatur. Wer dieses Dokument findet, soll es nicht für einen
> Prüfnachweis halten — es ist ein unbenutztes Formular.
>
> Das Restrisiko der Aussetzung steht in
> [`docs/17-release-readiness.md`](17-release-readiness.md) Abschnitt 7.1.
>
> **Das Material bleibt gültig und ist für den Nachlauf nach dem Launch
> gedacht.** Es verfällt nicht: Auswahl, Prüfraster und Zitatlisten beziehen
> sich auf Themen, die im Bestand bleiben. Wer die Stichprobe später nachholt,
> fängt hier an und trägt das Ergebnis wie in Abschnitt 7 beschrieben in
> `redaktion.geprueft_von` / `geprueft_am` ein.

**Zweck.** Dieses Dokument ist das Arbeitsmaterial für die einzige noch offene
Position des Content-Freezes: die menschliche Stichprobe nach
`docs/08-ki-redaktion.md`. Es **schließt das Gate nicht** — das kann nur eine
Person mit juristischer Vorbildung. Es nimmt ihr die Vorbereitung ab: Auswahl,
Begründung der Auswahl, Prüfraster und die je Thema zu kontrollierenden
Normzitate.

Angelegt am 24.09.2026 auf [SUB-225](/SUB/issues/SUB-225), bevor die
Entscheidung über den Umfang der Stichprobe (Interaktion `f754f609`) gefallen
ist — die Auswahl ist für alle dort angebotenen Varianten dieselbe, nur die
Anzahl der abzuarbeitenden Zeilen unterscheidet sich.

---

## 1. Ausgangslage, gemessen

`backend/scripts/validate_content.py` auf `main` (Stand `9746172`):

```
60 Themen, 444 Karten, 64 Schemata, 60 Faelle - 0 Fehler, 0 Warnungen
```

- P1 **36/36**, P2 **24/24** vollständig; P3 (14 Themen) laut `docs/12`
  bewusst nach v1.0.
- 57 der 60 Themen tragen einen `redaktion`-Block; die 3 M0-Themen
  (`bgb-at-kaufrecht`, `strafrecht-at`, `grundrechte`) gelten laut `docs/08`
  unverändert als regulär redigiert und stehen deshalb **nicht** zur
  Stichprobe an.
- Alle 57 tragen `geprueft_von: reviewer-agent-v1` — ein LLM-Aufruf, keine
  Person. Menschliche Prüfsignatur: **0 von 60**.

## 2. Wie bindend ist die Stichprobe? — eine Unstimmigkeit in `docs/08`

Vor der Entscheidung sollte man wissen, dass `docs/08-ki-redaktion.md` sich an
dieser Stelle selbst widerspricht:

| Fundstelle | Aussage |
|---|---|
| `docs/08`, Einleitung | „Menschliche Stichprobe bleibt vorgesehen, ist aber **keine Voraussetzung für die Veröffentlichung** — sonst wäre sie wieder derselbe Flaschenhals." |
| `docs/08`, Abschnitt „Grenzen der Positivliste" | „Bis dahin ist **jeder KI-erzeugte Inhalt vor der ersten Nutzung stichprobenartig von einer Person mit juristischer Vorbildung zu prüfen**" |

Beides steht im selben Dokument. Die Einleitung stuft die Stichprobe als
nicht-blockierend ein, der spätere Abschnitt als Pflicht vor der ersten
Nutzung. `docs/18` Gate **G3** verlangt „180 Karten geprüft und gemerged,
**keine offenen Redaktionsfunde**" und nennt als Ausfallpfad „Release mit
Ist-Menge, Zahl wird offen kommuniziert" — dieser Ausfallpfad adressiert die
**Menge**, nicht die Prüftiefe.

**Konsequenz für die Entscheidung:** Ob ein Release ohne Stichprobe
dokumentenkonform ist, lässt sich aus `docs/08` nicht eindeutig beantworten.
Das ist kein Grund, die Stichprobe zu überspringen, aber auch keiner, den
Termin daran scheitern zu lassen — es ist eine offene Festlegung, die der
Nutzer treffen muss. Sie sollte im Zuge der Entscheidung in `docs/08`
vereindeutigt werden (Folgeaufgabe, nicht Teil der Stichprobe selbst).

## 3. Die Stichprobe: 6 Themen

Quote nach `docs/12` Abschnitt 4.2: mindestens 10 % der neuen Themen,
**stratifiziert** (mind. 2 je Rechtsgebiet, Schwerpunkt P1) — bei 57
KI-erzeugten Themen sind 6 Themen 10,5 %.

Gezogen wurde **nicht zufällig**, sondern über zwei Achsen gekreuzt:
Rechtsgebiet (2 je Gebiet) × Liefercharge. Der Grund für die zweite Achse: ein
systematischer Fehler entsteht eher pro Produktionslauf als pro Thema. Alle 6
sind P1.

| # | Thema | Gebiet | Prio | Einheiten | Liefercharge | warum dieses |
|---|---|---|---|---|---|---|
| 1 | `zr-at-stellvertretung` | Zivilrecht | P1 | 9 | 12.09. (Einzel) | Allererstes Thema der Pipeline überhaupt, im Brücken-Modus entstanden — der älteste Prompt-Stand |
| 2 | `zr-sr-gutglaeubiger-erwerb-932` | Zivilrecht | P1 | 10 | 23.09. (PR #65) | Jüngste Charge, unter Termindruck vor dem Freeze geliefert; zudem normdichtestes Thema der Auswahl (14 Zitate) |
| 3 | `sr-bt-diebstahl` | Strafrecht | P1 | 9 | 13.09. (Sammellauf) | Aus dem frühen Sammellauf vom 13.09.; zitiert gebietsfremd in das BGB hinein (§ 90) — typische Fehlerstelle |
| 4 | `sr-at-kausalitaet-zurechnung` | Strafrecht | P1 | 9 | 23.09. (PR #65) | Jüngste Charge; stark dogmatisches Thema mit den wenigsten Normankern (3) — Plausibilität trägt hier der Fließtext, nicht das Zitat |
| 5 | `or-berufsfreiheit` | Öff. Recht | P1 | 8 | 13.09. (Sammellauf) | Früheste Charge im Öff. Recht; Drei-Stufen-Theorie ist die klassische Stelle für veraltete Darstellung |
| 6 | `or-vwvfg-verwaltungsakt` | Öff. Recht | P1 | 9 | 15.09. (Sammellauf) | Größter Sammellauf (6 Themen); VwVfG ist das Gebiet mit der dünnsten Abdeckung in der Normzitat-Positivliste |

**Lesehinweis zu „Liefercharge":** Die Datumsangabe ist der erste Zeitpunkt, zu
dem die Datei auf `main` auftaucht. Bei squash-gemergten Chargen (PR #65) ist
das der **Merge-Zeitpunkt**, nicht der Produktionszeitpunkt — als Gruppierung
nach Liefercharge belastbar, als Aussage über Produktionsgeschwindigkeit
nicht.

**Falls nur 3 Themen geprüft werden** (Variante „kleinere Stichprobe"): #2, #3
und #6 — je ein Gebiet, die beiden riskantesten Chargen (jüngste und größte)
plus die dünnste Normabdeckung. Die Unterschreitung der 10-%-Quote ist dann
offen als Risiko zu vermerken.

## 4. Prüfraster — die fünf Punkte aus `docs/08`

Für jede Karte, jedes Schema und jeden Fall des Themas:

1. **Urheberrecht** — liest sich ein Text wie eine wörtliche oder nur leicht
   umformulierte Übernahme aus einem bekannten Lehrbuch/Kommentar?
2. **RDG** — ist jeder Fall zweifelsfrei fiktiv (keine realen Namen, Firmen,
   Aktenzeichen, keine Bezugnahme auf ein tatsächliches Verfahren)?
3. **Fachliche Plausibilität** — wirkt eine Norm, Definition oder ein
   Prüfungsschritt falsch, veraltet oder erfunden?
4. **Erwartungshorizont** — hat jeder Fall mindestens einen zwingenden
   Prüfpunkt, und sind die Prüfpunkte klausurrelevant statt trivial?
5. **Slug-Kollisionen** mit bereits vorhandenem Content.

**Der Punkt, auf den es besonders ankommt.** Das Normzitat-Gate ist eine
kuratierte Positivliste, kein Normindex. Es fängt erfundene Kürzel und
Nummern außerhalb des Bereichs ab — **nicht** einen real existierenden
Paragraphen mit falsch behauptetem Inhalt. Der Norm-Explorer (M2), der das
deterministisch könnte, existiert noch nicht. Die menschliche Stichprobe ist
damit derzeit die **einzige** Instanz, die ein inhaltlich falsch zugeordnetes
Zitat überhaupt finden kann. Deshalb steht in Abschnitt 5 je Thema die
vollständige Zitatliste: Punkt 3 ist der teuerste, aber auch der einzige mit
echtem Alleinstellungswert.

## 5. Zitatlisten je Thema

Normalisiert aus der jeweiligen YAML-Datei. Zu prüfen ist nicht die Existenz
(das erledigt das Gate), sondern **ob der Paragraph das sagt, was das Thema
ihm zuschreibt**.

### 1 — `zr-at-stellvertretung` · `content/zivilrecht/zr-at-stellvertretung.yaml`
§ 26 Abs. 1 BGB; § 133 BGB; § 157 BGB; § 164 Abs. 1 BGB; § 164 Abs. 1 S. 1 BGB;
§ 164 Abs. 1 S. 2 BGB; § 166 Abs. 2 BGB; § 166 Abs. 2 S. 1 BGB; § 167 BGB;
§ 167 Abs. 1 BGB; § 177 BGB; § 177 Abs. 1 BGB; § 179 BGB; § 181 BGB; § 242 BGB;
§ 433 Abs. 2 BGB; § 1629 BGB; § 2064 BGB

### 2 — `zr-sr-gutglaeubiger-erwerb-932` · `content/zivilrecht/zr-sr-gutglaeubiger-erwerb-932.yaml`
§ 855 BGB; § 929 BGB; § 929 S. 1 BGB; § 930 BGB; § 931 BGB; § 932 BGB;
§ 932 Abs. 1 BGB; § 932 Abs. 2 BGB; § 933 BGB; § 934 BGB; § 935 BGB;
§ 935 Abs. 1 BGB; § 935 Abs. 2 BGB; § 985 BGB

### 3 — `sr-bt-diebstahl` · `content/strafrecht/sr-bt-diebstahl.yaml`
§ 90 BGB; § 15 StGB; § 242 StGB; § 242 Abs. 1 StGB; § 243 StGB;
§ 243 Abs. 1 S. 2 Nr. 1 StGB; § 248a StGB

### 4 — `sr-at-kausalitaet-zurechnung` · `content/strafrecht/sr-at-kausalitaet-zurechnung.yaml`
§ 212 StGB; § 222 StGB; § 229 StGB

### 5 — `or-berufsfreiheit` · `content/oeffentliches-recht/or-berufsfreiheit.yaml`
Art. 2 Abs. 1 GG; Art. 12 Abs. 1 GG; Art. 12 Abs. 1 S. 2 GG; Art. 19 Abs. 3 GG;
Art. 116 GG

### 6 — `or-vwvfg-verwaltungsakt` · `content/oeffentliches-recht/or-vwvfg-verwaltungsakt.yaml`
§ 1 Abs. 4 VwVfG; § 28 VwVfG; § 35 VwVfG; § 35 S. 1 VwVfG; § 35 S. 2 VwVfG;
§ 40 VwVfG; § 44 VwVfG; § 44 Abs. 1 VwVfG; § 44 Abs. 2 VwVfG; § 44 Abs. 3 VwVfG

## 6. Befundformular

Je geprüftem Thema auszufüllen. Ein Thema ohne Befund wird abgehakt, ein Thema
mit Befund läuft nach Abschnitt 7 zurück.

```
Thema:            <slug>
Geprüft von:      <Name>            Datum: <YYYY-MM-DD>
Dauer:            <Minuten>         (bitte wirklich stoppen, siehe unten)

(1) Urheberrecht            [ ] ohne Befund   [ ] Befund:
(2) RDG / Fiktivität        [ ] ohne Befund   [ ] Befund:
(3) Fachliche Plausibilität [ ] ohne Befund   [ ] Befund:
    davon Normzitate        [ ] alle korrekt zugeordnet   [ ] falsch:
(4) Erwartungshorizont      [ ] ohne Befund   [ ] Befund:
(5) Slug-Kollisionen        [ ] ohne Befund   [ ] Befund:

Gesamt: [ ] mensch-freigegeben   [ ] in-pruefung (Befund, siehe oben)
```

**Bitte die Zeit mitschreiben.** `docs/12` Abschnitt 3.2 rechnet mit 35/60/105
Minuten je Thema und weist diese Werte ausdrücklich als *geschätzt, nicht
gemessen* aus. Dies ist der erste reale Durchlauf — sechs Ist-Werte ersetzen
das Annahme-Modell und verbessern jede künftige Durchsatzrechnung.

## 7. Eintragen des Ergebnisses

**Ohne Befund** — im `topic.redaktion`-Block der Datei:

```yaml
    geprueft_von: <Name oder Kürzel der prüfenden Person>
    geprueft_am: "<YYYY-MM-DD>"
    status: mensch-freigegeben
```

`mensch-freigegeben` ist in `docs/08` bereits als zulässiger Wert definiert;
es ersetzt `ki-freigegeben`. Der Eintrag `normzitate_geprueft: true` bleibt
unberührt — er dokumentiert das deterministische Gate, nicht die menschliche
Prüfung.

**Mit Befund** — Weg nach `docs/12` Abschnitt 4.3:

1. Befund als Issue anlegen, mit `topic.slug` **und** dem betroffenen
   Karten-/Schema-/Fall-`slug`.
2. `topic.redaktion.status` auf `in-pruefung` setzen. Die CI läuft damit
   weiter, erzeugt aber eine Warnung (`app/services/content.py`) — der Befund
   bleibt also sichtbar, blockiert aber nicht den Baum.
3. Korrektur über den regulären Redaktionspfad, danach erneute Prüfung.
4. Befundrate protokollieren: Steigt sie, wird die Quote für das betroffene
   Gebiet nach `docs/12` Abschnitt 4.2 („adaptiv nachschärfen") erhöht.

## 8. Was dieses Dokument nicht leistet

- Es ersetzt die Prüfung nicht und nimmt ihr Ergebnis nicht vorweg. Kein Agent
  kann `mensch-freigegeben` setzen — die Signatur muss von einer Person
  stammen, sonst ist sie eine Falschangabe.
- Es entscheidet die Unstimmigkeit aus Abschnitt 2 nicht.
- Es deckt die 3 M0-Themen nicht ab (Abschnitt 1).
- Die Zitatlisten in Abschnitt 5 sind maschinell aus dem gesamten Text der
  YAML-Dateien extrahiert — sowohl aus den `norms:`-Blöcken als auch aus dem
  Fließtext (`front`/`back`). Sie sind trotzdem eine Arbeitshilfe, kein
  Ersatz für das Lesen des Themas.
